-- [Script] [M] Shockwave Bridge
-- Script Type: Movie
--
--------------------------------------------------------------------------------
-- Shockwave <-> Godot bridge, Director half. PROTOCOL.md is the spec; this is the
-- Lingo implementation of it, the counterpart of Godot's addons/shockwave_bridge.
-- tools/*.py speak the same wire and are how it is tested without Director.
--
-- WHAT IT DOES
--   * mirrors gGame (and whatever else the config exposes) to Godot every frame as
--     DELTA batches, so Godot reads live state with zero round trips;
--   * answers reads, writes, handler calls and events from Godot, applied inside
--     the movie's own enterFrame so nothing can re-enter the engine mid-frame;
--   * keeps a replicated store, gBridge.store, writable from both sides -- that is
--     the channel for your own custom data.
--
-- HOW TO USE IT (Bridge/Director/INSTALL.md has the long version)
--   * import these three files as movie scripts:
--         [M] Shockwave Bridge            (this one: codec, config, state)
--         [M] Shockwave Bridge Transport  (files / http / tcp)
--         [M] Shockwave Bridge RPC        (message dispatch, ops, your API)
--   * import Bridge.Data.txt as a Text cast member named "Bridge.Data" (or leave it
--     on disk next to the movie; both are found);
--   * that is all. `on enterFrame` below is called by the engine, and the bridge
--     initialises itself on the first frame.
--   * from the Message window or any script:
--         BridgeStatus()
--         BridgeGet("gGame.Cash")
--         BridgeSet("bridge.targetKmh", 140.0)
--         BridgeCall("PutMessage", 0, [#message: "hi from Lingo"])
--         BridgeEvent(#BridgePause, [#reason: "cutscene"])
--         BridgeSelfTest()
--
-- HOT PATH RULE
--   Lingo is slow at parsing and fast at indexing, so per-frame work here is string
--   concat plus `item[]` / `getProp` lookups only: the wire is TAB-separated because
--   this movie already uses TAB as its itemDelimiter, and the encoder never builds an
--   expression. `value()` is reached for exactly two things -- decoding a Lingo
--   literal (`l:`) and resolving an exotic path (`member("Console").text.line[3]`).
--   Plain paths are walked instead, which is faster than evaluating them and cannot
--   run arbitrary code.
--------------------------------------------------------------------------------

global gSystem, gData, gGame, gSound, gBridge

--------------------------------------------------------------------------------
-- LIFECYCLE
--------------------------------------------------------------------------------

on BridgeInit me
	if voidp(gBridge) = 0 then
		if gBridge.initialized = 1 then
			return 0
		end if
	end if
	gBridge = [:]
	gBridge[#initialized] = 0
	gBridge[#role] = "director"
	gBridge[#name] = "Shockwave (Director)"
	gBridge[#proto] = 1
	gBridge[#outSeq] = 0
	gBridge[#inSeq] = 0
	gBridge[#frame] = 0
	gBridge[#status] = "down"
	gBridge[#peerReady] = 0
	gBridge[#peerRole] = ""
	gBridge[#peerName] = ""
	gBridge[#peerCaps] = []
	gBridge[#peerFrame] = 0
	gBridge[#lastSeen] = 0
	gBridge[#latency] = 0.0
	gBridge[#store] = [:]
	gBridge[#mirror] = [:]
	gBridge[#subs] = [:]
	gBridge[#lastSent] = [:]
	gBridge[#dirty] = [:]
	gBridge[#pending] = [:]
	gBridge[#nextRid] = 0
	gBridge[#out] = []
	gBridge[#caps] = "snap,sub,event,write,call,list"
	gBridge[#stats] = [#framesOut: 0, #framesIn: 0, #msgsOut: 0, #msgsIn: 0, #bytesOut: 0, #bytesIn: 0, #errors: 0, #dupes: 0, #torn: 0, #timeouts: 0, #denied: 0, #requests: 0, #replies: 0]
	gBridge[#helloSent] = 0
	gBridge[#pollId] = 0
	gBridge[#httpBusy] = 0
	gBridge[#warnOnce] = [:]
	gBridge[#io] = "none"
	gBridge[#fx] = VOID
	BridgeConfigLoad(0)
	BridgeDetectIo(0)
	BridgeOpenTransport(0)
	BridgeSubscribeExposed(0)
	gBridge.initialized = 1
	BridgeLog(0, "info", "bridge up: " & BridgeConfigSummary(0))
	BridgeNotify(0, #BridgeConnected)
	return 1
end

on BridgeShutdown me
	if voidp(gBridge) = 1 then
		return 0
	end if
	BridgePushBye(0, "quit")
	BridgeFlush(0)
	BridgeCloseTransport(0)
	BridgeNotify(0, #BridgeDisconnected)
	gBridge.initialized = 0
	return 1
end

-- The engine calls this on a movie script every frame. Every change the bridge
-- makes to the game happens here and only here (PROTOCOL.md 6): a batch is applied
-- at the top of the frame, and the frame's snapshot goes out at the bottom.
on enterFrame me
	if voidp(gBridge) = 1 then
		BridgeInit(0)
		exit
	end if
	if gBridge.initialized = 0 then
		exit
	end if
	gBridge.frame = _movie.frame
	BridgePollTransport(0)
	BridgeBuildSnapshot(0)
	BridgeSendHelloIfNeeded(0)
	BridgeReapTimeouts(0)
	BridgeFlush(0)
end

on BridgeNotify me, tEvent
	-- Fire one of the movie's own events for a bridge lifecycle moment, if the
	-- config asked for it with a `hook` line.
	if voidp(gBridge.cfg.hooks) = 1 then
		exit
	end if
	repeat with tHook in gBridge.cfg.hooks
		if tHook = tEvent then
			event(0, tEvent)
			exit repeat
		end if
	end repeat
end

on BridgeLog me, tLevel, tText
	-- The movie's own logging convention: PutMessage/LogMessage live in
	-- [M] Event Manager and a Message window member shows them when one exists.
	if tLevel = "warn" or tLevel = "error" or voidp(gSystem) = 1 or gSystem.debug = 1 then
		PutMessage(0, "[bridge " & tLevel & "] " & tText, 0)
	end if
	if tLevel = "error" then
		gBridge.stats.errors = gBridge.stats.errors + 1
	end if
	return 1
end

--------------------------------------------------------------------------------
-- CONFIG  (Bridge.Data.txt: TAB-separated key/value, the game's own data idiom)
--------------------------------------------------------------------------------

on BridgeConfigLoad me
	if voidp(gBridge) = 1 then
		gBridge = [:]
	end if
	gBridge[#configText] = BridgeConfigText(0)
	gBridge[#cfg] = BridgeConfigParse(0, gBridge.configText)
	-- `root` may name a folder that does not exist yet; the Godot peer creates it,
	-- and so do we when we can (see BridgeEnsureDir in the transport script).
	gBridge[#outPath] = BridgeMailboxPath(0, BridgeOutName(0))
	gBridge[#inPath] = BridgeMailboxPath(0, BridgeInName(0))
	return 1
end

on BridgeConfigText me
	-- Cast member first: this game keeps every data file in the cast, and a member
	-- works in a projector with no file access at all. Then the disk.
	if member("Bridge.Data") <> VOID then
		return member("Bridge.Data").text
	end if
	tCandidates = []
	if voidp(gSystem) = 0 then
		tCandidates.add(gSystem.path & "Bridge\\Bridge.Data.txt")
	end if
	tCandidates.add(_movie.path & "Bridge\\Bridge.Data.txt")
	tCandidates.add(_movie.path & "Bridge.Data.txt")
	tCandidates.add(_movie.path & "Bridge\\Director\\Bridge.Data.txt")
	repeat with tPath in tCandidates
		tText = BridgeFileRead(0, tPath)
		if tText <> VOID then
			return tText
		end if
	end repeat
	return EMPTY
end

on BridgeConfigParse me, tText
	-- One pass with the engine's own line chunking (`line[i]`), because scanning for
	-- LF by hand inside a per-line loop is O(n^2) in Lingo and this file is a few
	-- hundred lines. lineDelimiter is set, used, and restored -- the same discipline
	-- the game applies to itemDelimiter in SetItemDelimiter/ResetItemDelimiter.
	tCfg = [:]
	tCfg[#transport] = "files"
	tCfg[#root] = "BridgeData"
	tCfg[#snapshot] = "delta"
	tCfg[#rate] = 1
	tCfg[#verify] = 1
	tCfg[#httpHost] = "127.0.0.1"
	tCfg[#httpPort] = 7778
	tCfg[#httpWaitMs] = 1500
	tCfg[#tcpHost] = "127.0.0.1"
	tCfg[#tcpPort] = 7777
	tCfg[#peerTimeoutMs] = 2000
	tCfg[#requestTimeoutMs] = 2000
	tCfg[#allowEval] = 0
	tCfg[#allowExec] = 0
	tCfg[#allowCall] = 0
	tCfg[#allowEvent] = 1
	tCfg[#expose] = []
	tCfg[#ignore] = []
	tCfg[#write] = []
	tCfg[#call] = []
	tCfg[#event] = []
	tCfg[#hooks] = []
	tCfg[#alias] = [:]
	if tText = VOID then
		tText = EMPTY
	end if
	tOldLine = the lineDelimiter
	tOldItem = the itemDelimiter
	the lineDelimiter = numToChar(10)
	the itemDelimiter = tab
	tCount = tText.numLines
	repeat with i = 1 to tCount
		tLine = BridgeTrim(0, tText.line[i])
		if tLine.length > 0 then
			if (BridgeChars(0, tLine, 1, 2)) <> "//" then
				if (BridgeChars(0, tLine, 1, 2)) <> "--" then
					if tLine[1] <> "#" then
						BridgeConfigLine(0, tCfg, tLine)
					end if
				end if
			end if
		end if
	end repeat
	the itemDelimiter = tOldItem
	the lineDelimiter = tOldLine
	return tCfg
end

on BridgeConfigLine me, tCfg, tLine
	-- Indented lines belong to the game's own block parsers, not to us, so a key
	-- only counts when it starts at column 1 -- same rule as [M] Event Manager.
	if tLine[1] = " " or tLine[1] = tab then
		exit
	end if
	tKey = BridgeTrim(0, tLine.item[1])
	if tLine.numItems > 1 then
		tValue = BridgeTrim(0, tLine.item[2])
	else
		tValue = EMPTY
	end if
	if tKey = "alias" then
		if tLine.numItems > 2 then
			tCfg.alias.addProp(symbol(BridgeTrim(0, tLine.item[2])), BridgeTrim(0, tLine.item[3]))
		end if
		exit
	end if
	case tKey of
		"expose", "ignore", "call", "event":
			if tValue.length > 0 then
				tCfg[tKey].add(tValue)
			end if
			exit
		"hook":
			if tValue.length > 0 then
				tCfg.hooks.add(symbol(tValue.item[1]))
			end if
			exit
		"transport", "root", "snapshot", "httpHost", "tcpHost":
			if tValue.length > 0 then
				tCfg[tKey] = tValue
			end if
			exit
		"rate", "httpPort", "httpWaitMs", "tcpPort", "peerTimeoutMs", "requestTimeoutMs", "verify", "allowEval", "allowExec", "allowCall", "allowEvent":
			tCfg[tKey] = BridgeToInt(0, tValue)
			exit
	end case
	-- Unknown keys are ignored on purpose: forward compatibility (PROTOCOL.md 9).
end

on BridgeConfigSummary me
	tCfg = gBridge.cfg
	return "transport=" & tCfg.transport & "  root=" & tCfg.root & "  snapshot=" & tCfg.snapshot & " rate=" & tCfg.rate & "  verify=" & tCfg.verify & "  allowEval=" & tCfg.allowEval & "  expose=" & tCfg.expose.count & "  write=" & tCfg.write.count & "  io=" & gBridge.io
end

on BridgeMailboxPath me, tName
	-- `root` may be relative to the movie (the usual case) or absolute.
	tRoot = gBridge.cfg.root
	if BridgeIsAbsolutePath(0, tRoot) then
		return BridgeJoinPath(0, tRoot, tName)
	end if
	tBase = _movie.path
	if voidp(gSystem) = 0 then
		tBase = gSystem.path
	end if
	return BridgeJoinPath(0, BridgeJoinPath(0, tBase, tRoot), tName)
end

on BridgeOutName me
	-- director -> godot is d2g.txt for us, g2d.txt for the Godot peer (§7.1)
	return "d2g.txt"
end

on BridgeInName me
	return "g2d.txt"
end

on BridgeIsAbsolutePath me, tPath
	if tPath.length < 2 then
		return 0
	end if
	if tPath[1] = "\" or tPath[1] = "/" then
		return 1
	end if
	-- Windows drive letter, e.g. "D:\games\br4"
	if tPath[2] = ":" then
		return 1
	end if
	return 0
end

on BridgeJoinPath me, tBase, tTail
	-- The movie's own separator convention: backslash on Windows, slash on Mac.
	-- ConvertPath in [M] File & System does the same job for the game's data files.
	if tBase.length = 0 then
		return tTail
	end if
	if tTail.length = 0 then
		return tBase
	end if
	tSep = "\"
	if voidp(gSystem) = 0 then
		if gSystem.Mac = 1 then
			tSep = "/"
		end if
	else
		if the platform contains "Mac" then
			tSep = "/"
		end if
	end if
	tLast = tBase[tBase.length]
	if tLast = "\" or tLast = "/" then
		return tBase & tTail
	end if
	return tBase & tSep & tTail
end

--------------------------------------------------------------------------------
-- FRAMING  (PROTOCOL.md 1, 4)
--------------------------------------------------------------------------------

on BridgeSanitize me, tString
	-- No escaping exists on this wire (§1): a framing byte becomes a space. The
	-- common case is a string with no TAB in it, so that is one comparison.
	if tString.ilk <> #string then
		tString = string(tString)
	end if
	if tString contains tab then
		repeat with i = 1 to tString.length
			if tString.char[i] = tab then
				put " " into tString.char[i]
			end if
		end repeat
	end if
	if tString contains numToChar(10) then
		tString = BridgeReplace(0, tString, numToChar(10), " ")
	end if
	if tString contains numToChar(13) then
		tString = BridgeReplace(0, tString, numToChar(13), " ")
	end if
	return tString
end

on BridgeReplace me, tSource, tFind, tWith
	-- `String.replace` is not in older Directors; this is the portable one. Only used
	-- on rare paths (sanitising a stray CR, un-escaping a URL), never per frame.
	tOut = EMPTY
	tLen = tSource.length
	tFromLen = tFind.length
	i = 1
	repeat while i <= tLen
		if (BridgeChars(0, tSource, i, i + tFromLen - 1)) = tFind then
			tOut = tOut & tWith
			i = i + tFromLen
		else
			tOut = tOut & tSource.char[i]
			i = i + 1
		end if
	end repeat
	return tOut
end

on BridgeBuild me, tVerb, tFields
	-- verb TAB field TAB field ...
	tLine = BridgeSanitize(0, tVerb)
	repeat with tField in tFields
		tLine = tLine & tab & BridgeSanitize(0, string(tField))
	end repeat
	return tLine
end

on BridgeParse me, tLine
	-- -> [#verb: ..., #fields: [...]] . Trailing empty fields are kept (§9).
	tLine = BridgeTrim(0, tLine)
	tResult = [:]
	if tLine.length = 0 then
		tResult[#verb] = EMPTY
		tResult[#fields] = []
		return tResult
	end if
	tOld = the itemDelimiter
	the itemDelimiter = tab
	tCount = tLine.numItems
	tResult[#verb] = tLine.item[1]
	tFields = []
	repeat with i = 2 to tCount
		tFields.add(tLine.item[i])
	end repeat
	tResult[#fields] = tFields
	the itemDelimiter = tOld
	return tResult
end

on BridgeItemOf me, tText, tIndex
	-- The game's idiom with the delimiter pinned here rather than left at whatever
	-- another handler last set it to, and index-or-empty (never an out-of-range error).
	tOld = the itemDelimiter
	the itemDelimiter = tab
	if tIndex <= tText.numItems then
		tValue = tText.item[tIndex]
	else
		tValue = EMPTY
	end if
	the itemDelimiter = tOld
	return tValue
end

on BridgeLines me, tText
	-- -> list of non-empty lines, LF or CRLF. The engine does the splitting; that is
	-- the difference between a frame budget and a stutter.
	tOut = []
	if tText = VOID or tText.length = 0 then
		return tOut
	end if
	tOld = the lineDelimiter
	the lineDelimiter = numToChar(10)
	tCount = tText.numLines
	repeat with i = 1 to tCount
		tLine = BridgeTrim(0, tText.line[i])
		if tLine.length > 0 then
			tOut.add(tLine)
		end if
	end repeat
	the lineDelimiter = tOld
	return tOut
end

on BridgeLineCount me, tText
	-- How many LF-terminated messages a payload holds -- the file transport's witness
	-- that a write finished (§7.1). numLines with LF as the delimiter counts exactly
	-- the LF characters plus one, so subtract it here.
	if tText = VOID or tText.length = 0 then
		return 0
	end if
	tOld = the lineDelimiter
	the lineDelimiter = numToChar(10)
	tCount = tText.numLines - 1
	if tCount < 0 then
		tCount = 0
	end if
	the lineDelimiter = tOld
	return tCount
end

on BridgeChars me, tText, tFrom, tTo
	-- Clamp empty or invalid ranges before using Lingo's character chunk expression.
	if tTo > tText.length then
		tTo = tText.length
	end if
	if tTo < 1 then
		return EMPTY
	end if
	if tFrom < 1 then
		tFrom = 1
	end if
	if tTo < tFrom then
		return EMPTY
	end if
	return char tFrom to tTo of tText
end

on BridgeTrim me, tText
	if tText.ilk <> #string then
		tText = string(tText)
	end if
	return the trim of tText
end

on BridgeToInt me, tValue
	if tValue.ilk = #integer then
		return tValue
	end if
	if tValue.ilk = #float then
		return integer(tValue)
	end if
	if tValue.ilk = #symbol then
		tValue = string(tValue)
	end if
	tValue = BridgeTrim(0, string(tValue))
	case tValue of
		"TRUE", "true", "1", "yes", "on":
			return 1
		"FALSE", "false", "0", "no", "off", EMPTY:
			return 0
	end case
	tNum = value(tValue)
	if tNum.ilk = #integer or tNum.ilk = #float then
		return integer(tNum)
	end if
	return 0
end

--------------------------------------------------------------------------------
-- TYPED VALUES  (PROTOCOL.md 2)
--------------------------------------------------------------------------------

on BridgeEncode me, tValue
	-- Any Lingo value -> `tag:payload`. Never builds an expression.
	if voidp(tValue) = 1 then
		return "n"
	end if
	tIlk = tValue.ilk
	case tIlk of
		#integer:
			return "i:" & tValue
		#float:
			return "f:" & BridgeFloatText(0, tValue)
		#point:
			return "p:" & BridgeFloatText(0, tValue[1]) & "," & BridgeFloatText(0, tValue[2])
		#vector:
			return "v:" & BridgeFloatText(0, tValue[1]) & "," & BridgeFloatText(0, tValue[2]) & "," & BridgeFloatText(0, tValue[3])
		#color:
			-- 3 components: alpha does not survive a Director<->Godot hop usefully
			-- (Godot composites its own), and `color.alpha` is not in every Director.
			return "c:" & tValue.red & "," & tValue.green & "," & tValue.blue
		#rect:
			return "r:" & tValue[1] & "," & tValue[2] & "," & tValue[3] & "," & tValue[4]
		#symbol:
			return "y:" & BridgeSymbolName(0, tValue)
		#string:
			if BridgeIsTypedText(0, tValue) then
				-- already `tag:payload`: pass through (see BridgeEncodeKV)
				return tValue
			end if
			return "s:" & BridgeSanitize(0, tValue)
		#list, #propList:
			return "l:" & BridgePrintLiteral(0, tValue)
	end case
	return "s:" & BridgeSanitize(0, string(tValue))
end

on BridgeIsTypedText me, tText
	-- "is this String already a typed value?" -- true for `i:12`, false for `12`.
	if tText.ilk <> #string then
		return 0
	end if
	if tText.length < 2 then
		return 0
	end if
	if tText[2] <> ":" then
		return 0
	end if
	if tText[1] contains "ifsbpyvqcrdl" then
		return 1
	end if
	return 0
end

on BridgeDecode me, tText
	-- `tag:payload` -> Lingo value. `n` -> VOID. Anything unrecognised stays the raw
	-- text it came as: a debug channel must not die on data (spec 2).
	if tText.ilk <> #string then
		return tText
	end if
	if tText = "n" then
		return VOID
	end if
	if not BridgeIsTypedText(0, tText) then
		return tText
	end if
	tTag = tText[1]
	tPayload = BridgeChars(0, tText, 3, tText.length)
	case tTag of
		"i", "f", "d":
			return value(tPayload)
		"s":
			return tPayload
		"b":
			if tPayload = "1" then
				return 1
			end if
			return 0
		"y":
			return symbol(tPayload)
		"p":
			return point(BridgeNumAt(0, tPayload, 1), BridgeNumAt(0, tPayload, 2))
		"v":
			return vector(BridgeNumAt(0, tPayload, 1), BridgeNumAt(0, tPayload, 2), BridgeNumAt(0, tPayload, 3))
		"c":
			tA = BridgeNumAt(0, tPayload, 4)
			if voidp(tA) = 1 then
				return color(BridgeNumAt(0, tPayload, 1), BridgeNumAt(0, tPayload, 2), BridgeNumAt(0, tPayload, 3))
			end if
			return color(BridgeNumAt(0, tPayload, 1), BridgeNumAt(0, tPayload, 2), BridgeNumAt(0, tPayload, 3), tA)
		"r":
			return rect(BridgeNumAt(0, tPayload, 1), BridgeNumAt(0, tPayload, 2), BridgeNumAt(0, tPayload, 3), BridgeNumAt(0, tPayload, 4))
		"l":
			return value(tPayload)
	end case
	return tText
end

on BridgeNumAt me, tText, tIndex
	-- n-th comma-separated part as a number, VOID when absent (colors have 3 or 4).
	tOld = the itemDelimiter
	the itemDelimiter = ","
	if tIndex <= tText.numItems then
		tValue = value(tText.item[tIndex])
	else
		tValue = VOID
	end if
	the itemDelimiter = tOld
	return tValue
end

on BridgeFloatText me, tNumber
	-- Director prints 2.0 as "2."; Godot (and Director's own value()) want a digit
	-- after the dot, because a float must stay a float across the wire (spec 2).
	tText = string(tNumber)
	if not (tText contains ".") then
		tText = tText & ".0"
	else
		if tText[tText.length] = "." then
			tText = tText & "0"
		end if
	end if
	if (tText contains "e") and not (tText contains ".") then
		tText = BridgeReplace(0, tText, "e", ".0e")
	end if
	return tText
end

on BridgeSymbolName me, tSymbol
	tText = string(tSymbol)
	if tText[1] = "#" then
		delete char 1 of tText
	end if
	return tText
end

on BridgeEncodeKV me, tPairs
	-- tPairs is a list of [path, wireText] pairs. Values are typed by the caller,
	-- because typing and un-typing them here would be pure waste.
	tOut = EMPTY
	repeat with tPair in tPairs
		if tOut.length > 0 then
			tOut = tOut & ";"
		end if
		tOut = tOut & BridgeSanitize(0, string(tPair[1])) & "=" & string(tPair[2])
	end repeat
	return tOut
end

on BridgeDecodeKV me, tText
	-- -> list of [path, value]. `;` splits pairs, the FIRST `=` splits key from value
	-- (a value may contain `=`, e.g. `s:a=b`).
	tList = []
	if tText = VOID then
		return tList
	end if
	if tText.ilk <> #string then
		return tList
	end if
	if tText.length = 0 then
		return tList
	end if
	tOld = the itemDelimiter
	the itemDelimiter = ";"
	tCount = tText.numItems
	repeat with i = 1 to tCount
		tChunk = tText.item[i]
		tPosition = BridgeIndexOf(0, tChunk, "=", 1)
		if tPosition > 1 then
			tKey = BridgeChars(0, tChunk, 1, tPosition - 1)
			tValue = BridgeChars(0, tChunk, tPosition + 1, tChunk.length)
			tList.add([tKey, BridgeDecode(0, tValue)])
		end if
	end repeat
	the itemDelimiter = tOld
	return tList
end

on BridgeIndexOf me, tText, tChar, tFrom
	-- `find` for a single char, from an offset. Used once per kv pair, so a plain
	-- loop is as fast as anything Lingo offers.
	repeat with i = tFrom to tText.length
		if tText.char[i] = tChar then
			return i
		end if
	end repeat
	return 0
end

--------------------------------------------------------------------------------
-- LINGO LITERALS  (PROTOCOL.md 3) -- only reached for `l:` payloads and `call`
--------------------------------------------------------------------------------

on BridgePrintLiteral me, tValue
	-- Godot's BridgeLingo reads this and Director's own value() reads it back, so the
	-- rules in spec 3 are exactly what makes a round trip work: #symbol keys, quoted
	-- strings, a dot on every float, VOID/TRUE/FALSE spelled the Lingo way.
	if voidp(tValue) = 1 then
		return "VOID"
	end if
	tIlk = tValue.ilk
	case tIlk of
		#integer:
			return string(tValue)
		#float:
			return BridgeFloatText(0, tValue)
		#string:
			return quote & BridgeEscapeString(0, tValue) & quote
		#symbol:
			return "#" & BridgeSymbolName(0, tValue)
		#point:
			return "[" & BridgeFloatText(0, tValue[1]) & ", " & BridgeFloatText(0, tValue[2]) & "]"
		#vector:
			return "[" & BridgeFloatText(0, tValue[1]) & ", " & BridgeFloatText(0, tValue[2]) & ", " & BridgeFloatText(0, tValue[3]) & "]"
		#color:
			return "color(" & tValue.red & ", " & tValue.green & ", " & tValue.blue & ")"
		#rect:
			return "[" & tValue[1] & ", " & tValue[2] & ", " & tValue[3] & ", " & tValue[4] & "]"
		#propList:
			tOut = "["
			repeat with i = 1 to tValue.count
				if i > 1 then
					tOut = tOut & ", "
				end if
				tOut = tOut & BridgeKeyText(0, tValue.getPropAt(i)) & ": " & BridgePrintLiteral(0, tValue[i])
			end repeat
			return tOut & "]"
		#list:
			tOut = "["
			repeat with i = 1 to tValue.count
				if i > 1 then
					tOut = tOut & ", "
				end if
				tOut = tOut & BridgePrintLiteral(0, tValue[i])
			end repeat
			return tOut & "]"
	end case
	if tValue = TRUE then
		return "TRUE"
	end if
	if tValue = FALSE then
		return "FALSE"
	end if
	return quote & BridgeEscapeString(0, string(tValue)) & quote
end

on BridgeKeyText me, tKey
	if tKey.ilk = #symbol then
		return "#" & BridgeSymbolName(0, tKey)
	end if
	tText = string(tKey)
	if tText[1] = "#" then
		delete char 1 of tText
		if BridgeIsSymbolic(0, tText) then
			return "#" & tText
		end if
		return quote & tText & quote
	end if
	if BridgeIsSymbolic(0, tText) then
		return "#" & tText
	end if
	return quote & BridgeEscapeString(0, tText) & quote
end

on BridgeIsSymbolic me, tText
	-- A #symbol key must be [A-Za-z_][A-Za-z0-9_]*.
	if tText.length = 0 then
		return 0
	end if
	tFirst = tText.char[1]
	if not (tFirst = "_" or (tFirst >= "a" and tFirst <= "z") or (tFirst >= "A" and tFirst <= "Z")) then
		return 0
	end if
	repeat with i = 1 to tText.length
		tChar = tText.char[i]
		if not (tChar = "_" or (tChar >= "a" and tChar <= "z") or (tChar >= "A" and tChar <= "Z") or (tChar >= "0" and tChar <= "9")) then
			return 0
		end if
	end repeat
	return 1
end

on BridgeEscapeString me, tText
	-- The one form Director's own value() reads: a quote inside a string is DOUBLED, and a
	-- backslash is just a backslash, because Lingo has no backslash escapes at all (`"C:\temp"`
	-- is five characters plus the closing quote, which is why this movie writes paths that way).
	-- Framing bytes become spaces here too, because they are flattened on the whole line (§1).
	tOut = EMPTY
	repeat with i = 1 to tText.length
		tChar = tText.char[i]
		if tChar = quote then
			tOut = tOut & quote & quote
		else
			if tChar = numToChar(10) or tChar = numToChar(13) or tChar = tab then
				tOut = tOut & " "
			else
				tOut = tOut & tChar
			end if
		end if
	end repeat
	return tOut
end

--------------------------------------------------------------------------------
-- PATHS  (PROTOCOL.md 5)
--------------------------------------------------------------------------------

on BridgeResolvePath me, tPath
	-- Read a value out of the running movie. Two ways: a plain walk of propLists and
	-- lists (fast, no eval, no risk) for the ordinary `gGame.a.b[2]` shape, and
	-- `value()` for anything with function calls or member/sprite accessors in it.
	if tPath = VOID or tPath.length = 0 then
		return VOID
	end if
	if BridgeIsBridgePath(0, tPath) then
		tKey = BridgeBridgeKey(0, tPath)
		if voidp(gBridge.store[tKey]) = 1 then
			if voidp(gBridge.mirror[tPath]) = 1 then
				return VOID
			end if
			return gBridge.mirror[tPath]
		end if
		return gBridge.store[tKey]
	end if
	if voidp(gBridge.mirror[tPath]) = 0 then
		-- the bridge's own copy of a mirrored value is the cheapest answer there is
		return gBridge.mirror[tPath]
	end if
	if BridgeNeedsEval(0, tPath) then
		return value(tPath)
	end if
	return BridgeWalk(0, tPath)
end

on BridgeNeedsEval me, tPath
	-- `(`, `member`, `sprite`, `_movie`, `_player`, `_system`, `.text.line[n]`: anything
	-- that is not a chain of property keys and integer indices has to go through value().
	if tPath contains "(" then
		return 1
	end if
	if tPath contains "_movie" then
		return 1
	end if
	if tPath contains "_player" then
		return 1
	end if
	if tPath contains "_system" then
		return 1
	end if
	if tPath contains "member" then
		return 1
	end if
	if tPath contains "sprite" then
		return 1
	end if
	if tPath contains "the " then
		return 1
	end if
	return 0
end

on BridgeWalk me, tPath
	-- `gGame.vehicles[2].general.kmh` -> segments -> walk. Never creates an object or
	-- runs a handler, which is the point of keeping it separate from value().
	tSegments = BridgePathSegments(0, tPath)
	if tSegments.count = 0 then
		return VOID
	end if
	tRootName = tSegments[1]
	case tRootName of
		"gGame":
			tCurrent = gGame
		"gSystem":
			tCurrent = gSystem
		"gData":
			tCurrent = gData
		"gSound":
			tCurrent = gSound
		"gBridge":
			tCurrent = gBridge
		otherwise:
			-- a global we do not know: let value() decide whether it exists
			return value(tRootName)
	end case
	if voidp(tCurrent) = 1 then
		return VOID
	end if
	repeat with i = 2 to tSegments.count
		tValue = BridgeGetSegment(0, tCurrent, tSegments[i])
		if voidp(tValue) = 1 then
			return VOID
		end if
		tCurrent = tValue
	end repeat
	return tCurrent
end

on BridgePathSegments me, tPath
	-- "gGame.vehicles[2].general" -> ["gGame", "vehicles", "2", "general"]. Indices are
	-- strings here; BridgeGetSegment decides how to use them.
	tOut = []
	tOld = the itemDelimiter
	the itemDelimiter = "."
	tCount = tPath.numItems
	repeat with i = 1 to tCount
		tChunk = tPath.item[i]
		tBracket = BridgeIndexOf(0, tChunk, "[", 1)
		if tBracket > 1 then
			tOut.add(BridgeChars(0, tChunk, 1, tBracket - 1))
			tRest = BridgeChars(0, tChunk, tBracket + 1, tChunk.length)
			repeat while tRest.length > 0
				tClose = BridgeIndexOf(0, tRest, "]", 1)
				if tClose > 0 then
					tOut.add(BridgeChars(0, tRest, 1, tClose - 1))
					tRest = BridgeChars(0, tRest, tClose + 1, tRest.length)
					if tRest[1] = "[" then
						tRest = BridgeChars(0, tRest, 2, tRest.length)
					else
						tRest = EMPTY
					end if
				else
					tRest = EMPTY
				end if
			end repeat
		else
			tOut.add(tChunk)
		end if
	end repeat
	the itemDelimiter = tOld
	return tOut
end

on BridgeGetSegment me, tContainer, tKey
	if voidp(tContainer) = 1 then
		return VOID
	end if
	tIlk = tContainer.ilk
	if tIlk = #propList then
		tSymbol = symbol(tKey)
		if voidp(tContainer[tSymbol]) = 1 then
			return VOID
		end if
		return tContainer[tSymbol]
	end if
	if tIlk = #list then
		tIndex = value(tKey)
		if tIndex.ilk <> #integer then
			return VOID
		end if
		-- Lingo lists are 1-based, and they stay 1-based on the wire (spec 5): that is
		-- what a Director script means by vehicles[1], and what Godot sees as [0].
		if tIndex < 1 or tIndex > tContainer.count then
			return VOID
		end if
		return tContainer[tIndex]
	end if
	if tIlk = #point or tIlk = #vector or tIlk = #rect or tIlk = #color then
		tIndex = value(tKey)
		tMax = 4
		if tIlk = #point then
			tMax = 2
		else
			if tIlk = #vector then
				tMax = 3
			end if
		end if
		if tIndex.ilk = #integer and tIndex >= 1 and tIndex <= tMax then
			return tContainer[tIndex]
		end if
		return VOID
	end if
	-- an object (a sprite, a member, a 3D model): read the property by name
	tSymbol = symbol(tKey)
	if voidp(tContainer[tSymbol]) = 1 then
		return VOID
	end if
	return tContainer[tSymbol]
end

on BridgeWritePath me, tPath, tValue
	-- Write into the movie. The caller has already checked the allow-list; this only
	-- resolves the parent and assigns the last segment. Returns 1 on success.
	if BridgeIsBridgePath(0, tPath) then
		tKey = BridgeBridgeKey(0, tPath)
		if voidp(tValue) = 1 then
			gBridge.store.deleteProp(tKey)
		else
			gBridge.store.addProp(tKey, tValue)
		end if
		return 1
	end if
	tSegments = BridgePathSegments(0, tPath)
	if tSegments.count < 2 then
		return 0
	end if
	tLeaf = tSegments[tSegments.count]
	tParentSegments = []
	repeat with i = 1 to tSegments.count - 1
		tParentSegments.add(tSegments[i])
	end repeat
	tParent = BridgeWalkSegments(0, tParentSegments)
	if voidp(tParent) = 1 then
		if BridgeNeedsEval(0, tPath) then
			-- e.g. `sprite(12).locH = 100`: only an expression can address that
			do(tPath & " = " & BridgePrintLiteral(0, tValue))
			return 1
		end if
		return 0
	end if
	if tParent.ilk = #propList then
		tParent[symbol(tLeaf)] = tValue
		return 1
	end if
	if tParent.ilk = #list then
		tIndex = value(tLeaf)
		if tIndex.ilk <> #integer then
			return 0
		end if
		if tIndex < 1 or tIndex > tParent.count then
			return 0
		end if
		tParent[tIndex] = tValue
		return 1
	end if
	tParent[symbol(tLeaf)] = tValue
	return 1
end

on BridgeWalkSegments me, tSegments
	if tSegments.count = 0 then
		return VOID
	end if
	case tSegments[1] of
		"gGame":
			tCurrent = gGame
		"gSystem":
			tCurrent = gSystem
		"gData":
			tCurrent = gData
		"gSound":
			tCurrent = gSound
		"gBridge":
			tCurrent = gBridge
		otherwise:
			return VOID
	end case
	if voidp(tCurrent) = 1 then
		return VOID
	end if
	repeat with i = 2 to tSegments.count
		tValue = BridgeGetSegment(0, tCurrent, tSegments[i])
		if voidp(tValue) = 1 then
			return VOID
		end if
		tCurrent = tValue
	end repeat
	return tCurrent
end

on BridgeIsBridgePath me, tPath
	if tPath.ilk <> #string then
		return 0
	end if
	if BridgeChars(0, tPath, 1, 7) = "bridge." then
		return 1
	end if
	if BridgeChars(0, tPath, 1, 8) = "gBridge." then
		return 1
	end if
	return 0
end

on BridgeBridgeKey me, tPath
	tDot = BridgeIndexOf(0, tPath, ".", 1)
	if tDot < 1 then
		return tPath
	end if
	return BridgeChars(0, tPath, tDot + 1, tPath.length)
end

on BridgeAllowed me, tPath, tPatterns
	-- A pattern authorises itself and its whole subtree: `gGame.vehicles` allows
	-- `gGame.vehicles[3].general.kmh`. (§6)
	repeat with tPattern in tPatterns
		tPattern = BridgeTrim(0, string(tPattern))
		if tPattern.length = 0 then
			next repeat
		end if
		if tPath = tPattern then
			return 1
		end if
		tPrefix = tPattern & "."
		if BridgeChars(0, tPath, 1, tPrefix.length) = tPrefix then
			return 1
		end if
		tPrefix = tPattern & "["
		if BridgeChars(0, tPath, 1, tPrefix.length) = tPrefix then
			return 1
		end if
	end repeat
	return 0
end

on BridgePathNamespace me, tPath
	tOld = the itemDelimiter
	the itemDelimiter = "."
	tHead = tPath.item[1]
	the itemDelimiter = "["
	tHead = tHead.item[1]
	the itemDelimiter = tOld
	return BridgeTrim(0, tHead)
end

on BridgeOwns me, tPath
	-- Only a path's owner puts it in a snapshot. That single rule is what keeps the two
	-- mirrors from feeding each other forever (spec 8).
	if BridgeIsBridgePath(0, tPath) then
		return 1
	end if
	tHead = BridgePathNamespace(0, tPath)
	case tHead of
		"gGame", "gSystem", "gData", "gSound", "gBridge", "member", "sprite", "_movie", "_player", "_system":
			return 1
	end case
	return 0
end

on BridgeResolveAlias me, tPath
	-- config `alias` lines give the HUD short names: `kmh` -> the full path.
	if tPath.ilk <> #string then
		return tPath
	end if
	if BridgeIndexOf(0, tPath, ".", 1) > 0 then
		return tPath
	end if
	if tPath contains ":" then
		return tPath
	end if
	if voidp(gBridge.cfg.alias[symbol(tPath)]) = 1 then
		return tPath
	end if
	return gBridge.cfg.alias[symbol(tPath)]
end

--------------------------------------------------------------------------------
-- STATE: mirror, replicated store, snapshots
--------------------------------------------------------------------------------

on BridgeSubscribeExposed me
	-- Everything in `expose` (minus `ignore`) becomes a mirror subscription, so Godot
	-- reads it without ever asking. Aliases point at the same values, so they mirror too.
	repeat with tPath in gBridge.cfg.expose
		if not BridgeIgnored(0, tPath) then
			BridgeSubscribe(0, tPath, 0)
		end if
	end repeat
end

on BridgeIgnored me, tPath
	if gBridge.cfg.ignore.count = 0 then
		return 0
	end if
	repeat with tPattern in gBridge.cfg.ignore
		if BridgeAllowed(0, tPath, [tPattern]) then
			return 1
		end if
	end repeat
	return 0
end

on BridgeSubscribe me, tPath, tRate
	tPath = BridgeResolveAlias(0, tPath)
	if voidp(gBridge.subs[tPath]) = 1 then
		gBridge.subs.addProp(tPath, tRate)
		gBridge.lastSent.addProp(tPath, VOID)
	end if
	return tPath
end

on BridgeUnsubscribe me, tPath
	tPath = BridgeResolveAlias(0, tPath)
	if voidp(gBridge.subs[tPath]) = 0 then
		gBridge.subs.deleteProp(tPath)
		gBridge.lastSent.deleteProp(tPath)
		-- drop it from the mirror too, so a stale value is never read as current
		if voidp(gBridge.mirror[tPath]) = 0 then
			gBridge.mirror.deleteProp(tPath)
		end if
	end if
	return tPath
end

on BridgeMarkDirty me, tPath, tValue
	-- Called by game code that wants a value pushed now rather than on its next
	-- subscription read. Cheap: one propList set.
	if not BridgeOwns(0, tPath) then
		return 0
	end if
	gBridge.dirty.addProp(tPath, tValue)
	return 1
end

on BridgeBuildSnapshot me
	-- One DELTA (or SNAP) per frame: what moved among the subscribed paths, plus our
	-- half of the replicated store. Values received from Godot are not re-broadcast.
	if gBridge.cfg.rate > 1 then
		if gBridge.frame mod gBridge.cfg.rate <> 0 then
			exit
		end if
	end if
	tPairs = []
	if gBridge.cfg.snapshot = "full" then
		gBridge.lastSent = [:]
		repeat with tPath in gBridge.subs.propNames
			tPairs.add([tPath, BridgeEncode(0, BridgeResolvePath(0, tPath))])
		end repeat
	else
		-- dirty first: writes we just applied are known without re-resolving them
		repeat with tPath in gBridge.dirty.propNames
			tValue = gBridge.dirty[tPath]
			if gBridge.lastSent[tPath] <> tValue or voidp(gBridge.lastSent[tPath]) = 1 then
				tPairs.add([tPath, BridgeEncode(0, tValue)])
				gBridge.lastSent.addProp(tPath, BridgeEncode(0, tValue))
			end if
		end repeat
		gBridge.dirty = [:]
		repeat with tPath in gBridge.subs.propNames
			if voidp(gBridge.dirty[tPath]) = 1 then
				tValue = BridgeResolvePath(0, tPath)
				tWire = BridgeEncode(0, tValue)
				if gBridge.lastSent[tPath] <> tWire then
					tPairs.add([tPath, tWire])
					gBridge.lastSent.addProp(tPath, tWire)
				end if
			end if
		end repeat
		-- the replicated store, so both sides always agree on bridge.*
		repeat with tKey in gBridge.store.propNames
			tPath = "bridge." & tKey
			tWire = BridgeEncode(0, gBridge.store[tKey])
			if gBridge.lastSent[tPath] <> tWire then
				tPairs.add([tPath, tWire])
				gBridge.lastSent.addProp(tPath, tWire)
			end if
		end repeat
	end if
	if tPairs.count = 0 then
		exit
	end if
	gBridge.outSeq = gBridge.outSeq + 1
	if gBridge.cfg.snapshot = "full" then
		tVerb = "SNAP"
	else
		tVerb = "DELTA"
	end if
	BridgePush(0, BridgeBuild(0, tVerb, [gBridge.outSeq, gBridge.frame, _system.milliSeconds, gBridge.inSeq, BridgeEncodeKV(0, tPairs)]))
	gBridge.stats.framesOut = gBridge.stats.framesOut + 1
end

on BridgeApplyRemote me, tPath, tValue, tLocalWrite
	-- A value the peer sent us. `bridge.*` also lands in our own store, because the
	-- store is replicated, not mirrored. Anything else is the movie's truth, held as a
	-- mirror; with tLocalWrite it is applied to gGame as well (that is a `set`).
	if BridgeIsBridgePath(0, tPath) then
		tKey = BridgeBridgeKey(0, tPath)
		if voidp(tValue) = 1 then
			gBridge.store.deleteProp(tKey)
		else
			gBridge.store.addProp(tKey, tValue)
		end if
		gBridge.mirror.addProp(tPath, tValue)
		gBridge.lastSent.addProp(tPath, BridgeEncode(0, tValue))
		BridgeOnValue(0, tPath, tValue)
		exit
	end if
	if tLocalWrite = 1 then
		BridgeWritePath(0, tPath, tValue)
	end if
	gBridge.mirror.addProp(tPath, tValue)
	gBridge.lastSent.addProp(tPath, BridgeEncode(0, tValue))
	BridgeOnValue(0, tPath, tValue)
end

on BridgeOnValue me, tPath, tValue
	-- Optional hook for the movie, in the Event Manager's own shape: set
	-- `gGame.bridgeValueHandler = #yourHandler` anywhere and that handler gets
	--     on yourHandler me, tTarget, tData      -- tData[#path], tData[#value]
	-- for every mirrored value, so a HUD or a debug recorder can listen instead of polling
	-- gBridge.mirror. Nobody sets it, nobody pays for it.
	if voidp(gGame) = 1 then
		exit
	end if
	if gGame[#bridgeValueHandler] <> VOID then
		_movie.sendSprite(0, gGame.bridgeValueHandler, 0, [#path: tPath, #value: tValue])
	end if
end
