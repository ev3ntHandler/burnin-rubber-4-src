-- [Script] [M] Shockwave Bridge Transport
-- Script Type: Movie
--
--------------------------------------------------------------------------------
-- Shockwave Bridge: PROTOCOL.md 7, the three transports, plus the only three ways a
-- Director movie can touch a disk.
--
--   files  the default, and the reason the bridge needs no installer. Director writes
--          <root>/d2g.txt, Godot writes <root>/g2d.txt, each with a `<name>.seq`
--          marker saying how big its batch is. A reader that finds a payload that does
--          not match its marker waits a frame and tries again -- so a half-written file
--          is never half-applied, with no locking, no ports and no firewall rule.
--          Projector and Director-editor only: a browser movie has no disk access.
--   http   Director is the client, Godot the listener on 127.0.0.1:7778. One long-poll
--          GET in each direction per frame. Only getNetText/netDone/netTextResult --
--          the same NetLingo the game already uses in [PS] Shockwave Sitelock -- so it
--          also works in a browser-hosted movie, which is where the browser half of
--          this game plays.
--   tcp    Needs a socket xtra (stock Director has none). `BridgeTcpAttach(xtraInstance)`
--          hands the bridge one; until then the transport reports `blocked`, honestly,
--          rather than pretending to work.
--
-- DISK ACCESS, IN THE ORDER WE PREFER IT (`io` in Bridge.Data.txt)
--   filextra4  `fx = xtra("FileXtra4").new()` -- the xtra [M] Mods.ls already uses for
--              mod textures, so this game's audience may already have it. Reads AND
--              writes, and can make folders. Opt-in because calling a method an xtra
--              does not have is a script error, not a return value.
--   projector  Director's own file API (fileOpen/fileWrite/fileLength/fileClose) for
--              writes, a #file cast member for reads. Nothing to install.
-- The write order is the protocol: payload closed first, then the marker. That is what
-- lets a reader tell "not yet" from "corrupt", and it is why `bytes` in the marker is a
-- minimum: Lingo counts characters, not UTF-8 bytes (PROTOCOL.md 7.1).
--------------------------------------------------------------------------------

global gSystem, gData, gGame, gBridge

--------------------------------------------------------------------------------
-- CAPABILITY DETECTION
--------------------------------------------------------------------------------

on BridgeDetectIo me
	-- Which disk back end this movie really has. `_movie.movieURL` starting with "http"
	-- is the browser: a Shockwave movie gets no file access at all, in any Director.
	if _movie.movieURL begins with "http" then
		gBridge.io = "none"
		gBridge[#browser] = 1
		BridgeLog(0, "warn", "browser movie: no disk access, so transport `files` cannot work -- write `transport http` in Bridge.Data.txt")
		exit
	end if
	gBridge[#browser] = 0
	tWanted = gBridge.cfg.io
	if tWanted = "filextra4" then
		if BridgeFxInit(0) then
			exit
		end if
		BridgeLog(0, "warn", "`io filextra4` asked for, but the xtra is not registered -- falling back to the projector file API")
	end if
	gBridge.io = "projector"
end

on BridgeFxInit me
	-- Same call [M] Mods.ls makes, so if the game's own mods folder works, so does this.
	tList = BridgeXtraNames(0)
	if tList = VOID then
		return 0
	end if
	repeat with tName in tList
		if string(tName) contains "FileXtra4" then
			gBridge[#fx] = xtra("FileXtra4").new()
			if voidp(gBridge.fx) = 1 then
				return 0
			end if
			gBridge.io = "filextra4"
			return 1
		end if
	end repeat
	return 0
end

on BridgeXtraNames me
	-- `the registeredXtras` is the list Director actually has; probing it beats calling
	-- xtra("...") on something that is not there, which is a script error and not a VOID.
	tList = the registeredXtras
	if tList = VOID then
		return []
	end if
	return tList
end

on BridgeIoAvailable me
	return gBridge.io = "filextra4" or gBridge.io = "projector"
end

on BridgeEnsureDir me, tPath
	-- Godot's peer creates the mailbox folder when it starts; whoever is first does it.
	if gBridge.io = "filextra4" then
		gBridge.fx.fx_CreateFolderTree(tPath)
		return 1
	end if
	-- There is no mkdir in the projector file API. A missing folder shows up as a write
	-- failure, and BridgeWarnOnce turns that into one readable line with the path in it.
	return 0
end

--------------------------------------------------------------------------------
-- OPEN / CLOSE
--------------------------------------------------------------------------------

on BridgeOpenTransport me
	gBridge[#outBuf] = []
	gBridge[#torn] = 0
	gBridge[#tcpTail] = EMPTY
	BridgeEnsureDir(0, BridgeDirOf(0, gBridge.outPath))
	case gBridge.cfg.transport of
		"files":
			if not BridgeIoAvailable(0) then
				BridgeWarnOnce(0, "io", "no file access in this movie (browser?) -- the files transport needs a projector, or use `transport http`")
				gBridge.status = "blocked"
				exit
			end if
			gBridge.status = "waiting"
			BridgeLog(0, "info", "mailbox " & gBridge.outPath & "  (io: " & gBridge.io & ")")
			exit
		"http":
			gBridge[#httpPushUrl] = BridgeHttpUrl(0, "/push")
			gBridge[#httpPollUrl] = BridgeHttpUrl(0, "/poll")
			gBridge[#httpHandshakeUrl] = BridgeHttpUrl(0, "/handshake")
			gBridge.status = "waiting"
			BridgeHttpStartPoll(0)
			exit
		"tcp":
			if voidp(gBridge.sock) = 1 then
				BridgeWarnOnce(0, "tcp", "transport `tcp` needs a socket xtra handed to BridgeTcpAttach(xtraInstance) first")
				gBridge.status = "blocked"
				exit
			end if
			gBridge.status = "waiting"
			exit
		otherwise:
			BridgeWarnOnce(0, "transport", "unknown transport `" & gBridge.cfg.transport & "` in Bridge.Data.txt; expected files, http or tcp")
			gBridge.status = "blocked"
			exit
	end case
	return gBridge.status
end

on BridgeCloseTransport me
	if gBridge.cfg.transport = "http" then
		BridgeHttpReset(0)
	end if
	if gBridge.cfg.transport = "tcp" then
		if voidp(gBridge.sock) = 0 then
			gBridge.sock.disConnect()
		end if
	end if
	gBridge.status = "down"
	return 1
end

on BridgeDirOf me, tPath
	-- everything up to the last separator, whichever kind this platform is using
	tBack = BridgeLastIndex(0, tPath, "\")
	tFront = BridgeLastIndex(0, tPath, "/")
	if tFront > tBack then
		tBack = tFront
	end if
	if tBack < 1 then
		return tPath
	end if
	return BridgeChars(0, tPath, 1, tBack - 1)
end

on BridgeLastIndex me, tText, tChar
	repeat with i = tText.length down to 1
		if tText.char[i] = tChar then
			return i
		end if
	end repeat
	return 0
end

on BridgeWarnOnce me, tKey, tText
	-- A bridge that cannot connect must say so once, in a way a developer acts on, and
	-- then be quiet: 30 warnings a second teaches everyone to ignore the Message window.
	if voidp(gBridge.warnOnce[tKey]) = 0 then
		exit
	end if
	gBridge.warnOnce.addProp(tKey, 1)
	BridgeLog(0, "warn", tText)
end

--------------------------------------------------------------------------------
-- SEND / RECEIVE  (one flush per frame, one read per frame: PROTOCOL.md 8)
--------------------------------------------------------------------------------

on BridgePush me, tLine
	gBridge.outBuf.add(tLine)
end

on BridgePushBye me, tReason
	BridgePush(0, BridgeBuild(0, "BYE", [tReason]))
	BridgeFlush(0)
end

on BridgeFlush me
	if gBridge.outBuf.count = 0 then
		exit
	end if
	tLines = gBridge.outBuf
	gBridge.outBuf = []
	tText = EMPTY
	repeat with tLine in tLines
		-- LF-terminated, always including the last line: a reader counts LF characters
		-- to decide whether a payload is whole, so the trailing LF is part of the frame.
		tText = tText & tLine & numToChar(10)
	end repeat
	gBridge.stats.msgsOut = gBridge.stats.msgsOut + tLines.count
	gBridge.stats.bytesOut = gBridge.stats.bytesOut + tText.length
	if gBridge.cfg.transport = "files" then
		BridgeFilesWrite(0, tText)
	else
		if gBridge.cfg.transport = "http" then
			BridgeHttpPush(0, tText)
		else
			if gBridge.cfg.transport = "tcp" then
				BridgeTcpSend(0, tText)
			end if
		end if
	end if
end

on BridgePollTransport me
	if gBridge.cfg.transport = "files" then
		BridgeFilesPoll(0)
	else
		if gBridge.cfg.transport = "http" then
			BridgeHttpPoll(0)
		else
			if gBridge.cfg.transport = "tcp" then
				BridgeTcpPoll(0)
			end if
		end if
	end if
	BridgeUpdateStatus(0)
end

on BridgeFeed me, tText
	-- One received batch -> messages -> dispatch. Shared by all three transports, so a
	-- torn file and a torn socket read obey the same rules.
	if tText = VOID then
		exit
	end if
	if tText.length = 0 then
		exit
	end if
	gBridge.stats.bytesIn = gBridge.stats.bytesIn + tText.length
	gBridge.stats.framesIn = gBridge.stats.framesIn + 1
	gBridge.lastSeen = _system.milliSeconds
	repeat with tLine in BridgeLines(0, tText)
		gBridge.stats.msgsIn = gBridge.stats.msgsIn + 1
		tMessage = BridgeParse(0, tLine)
		BridgeDispatch(0, tMessage[#verb], tMessage[#fields])
	end repeat
end

--------------------------------------------------------------------------------
-- files  (PROTOCOL.md 7.1)
--------------------------------------------------------------------------------

on BridgeFilesWrite me, tText
	-- Payload first, marker last, and the payload closed before the marker opens: that
	-- ordering is the only synchronisation either side needs.
	tPayload = gBridge.outPath
	tMarker = tPayload & ".seq"
	tLines = BridgeLineCount(0, tText)
	if gBridge.io = "filextra4" then
		gBridge.fx.fx_WriteFileText(tPayload, tText)
		gBridge.fx.fx_WriteFileText(tMarker, string(gBridge.outSeq) & " " & string(tText.length) & " " & string(tLines) & numToChar(10))
		return 1
	end if
	tRef = fileOpen(tPayload, 2)
	if tRef = VOID then
		BridgeWarnOnce(0, "write", "cannot write " & tPayload & " -- the folder has to exist first (Godot makes it when it starts; INSTALL.md 3)")
		return 0
	end if
	fileWrite(tRef, tText)
	tBytes = fileLength(tRef)
	fileClose(tRef)
	-- `tBytes` is the honest byte count when the file API reports it; `tText.length` is
	-- characters. The marker's contract is a minimum, so either is usable -- bytes when we
	-- have them, because they are what Godot measures.
	if tBytes = VOID then
		tBytes = tText.length
	end if
	tRef = fileOpen(tMarker, 2)
	if tRef = VOID then
		return 0
	end if
	fileWrite(tRef, string(gBridge.outSeq) & " " & string(tBytes) & " " & string(tLines) & numToChar(10))
	fileClose(tRef)
	return 1
end

on BridgeFilesPoll me
	-- Read the marker, then the payload, then check they agree. Anything else is "not
	-- ready", and the next frame will be.
	if voidp(gBridge[#lastInSeq]) = 1 then
		-- -1, not 0: a Python-side peer writes its first frame with seq 0, and 0 would read as
		-- "already seen". Anything below the smallest legal seq works as the empty sentinel.
		gBridge[#lastInSeq] = -1
	end if
	tPayload = gBridge.inPath
	tMark = BridgeMarkerRead(0, tPayload & ".seq")
	if tMark = VOID then
		BridgeWarnOnce(0, "in", "no " & tPayload & ".seq yet -- waiting for Godot (normal on the first frames)")
		exit
	end if
	if tMark[#seq] = gBridge.lastInSeq then
		-- Only an exact repeat means "already applied". A *lower* seq is Godot restarting its
		-- counter (PROTOCOL.md 7.1), and skipping everything below a stale high-water mark would
		-- leave the movie deaf until Godot's count caught up.
		exit
	end if
	tText = BridgeFileRead(0, tPayload)
	if tText = VOID then
		gBridge.torn = gBridge.torn + 1
		exit
	end if
	if gBridge.cfg.verify = 1 then
		if BridgeLineCount(0, tText) <> tMark[#lines] then
			gBridge.torn = gBridge.torn + 1
			gBridge.stats.torn = gBridge.stats.torn + 1
			exit
		end if
		if tMark[#bytes] > 0 then
			if tText.length < tMark[#bytes] then
				-- shorter than promised: the write is still landing
				gBridge.torn = gBridge.torn + 1
				gBridge.stats.torn = gBridge.stats.torn + 1
				exit
			end if
		end if
	end if
	gBridge.lastInSeq = tMark[#seq]
	BridgeFeed(0, tText)
end

on BridgeMarkerRead me, tPath
	-- "<seq> <bytes> <lines> [crc]". The 4th token is optional in the spec, and neither
	-- Godot (no CRC32) nor Lingo writes one, so it is read and ignored, never required.
	tText = BridgeFileRead(0, tPath)
	if tText = VOID then
		return VOID
	end if
	tText = BridgeTrim(0, tText)
	if tText.length = 0 then
		return VOID
	end if
	tMark = [:]
	tMark[#seq] = BridgeToInt(0, BridgeItemOf2(0, tText, " ", 1))
	tMark[#bytes] = BridgeToInt(0, BridgeItemOf2(0, tText, " ", 2))
	tMark[#lines] = BridgeToInt(0, BridgeItemOf2(0, tText, " ", 3))
	if tMark[#lines] = 0 then
		if tMark[#bytes] > 0 then
			-- a marker with no line count still means "one message"
			tMark[#lines] = 1
		end if
	end if
	return tMark
end

on BridgeItemOf2 me, tText, tDelimiter, tIndex
	tOld = the itemDelimiter
	the itemDelimiter = tDelimiter
	if tIndex <= tText.numItems then
		tValue = tText.item[tIndex]
	else
		tValue = EMPTY
	end if
	the itemDelimiter = tOld
	return tValue
end

--------------------------------------------------------------------------------
-- RAW FILE ACCESS  (one read path, one write path, two possible back ends)
--------------------------------------------------------------------------------

on BridgeFileRead me, tPath
	-- -> the file's text, or VOID when it is not readable. Never throws, because the
	-- mailbox is allowed to not exist yet: the other half may simply not be running.
	if tPath = VOID then
		return VOID
	end if
	if tPath.length = 0 then
		return VOID
	end if
	if gBridge.io = "filextra4" then
		tText = gBridge.fx.fx_ReadFileText(tPath)
		if tText = VOID then
			return VOID
		end if
		if string(tText) = "File not found" then
			return VOID
		end if
		return tText
	end if
	-- A #file cast member is the read path every Director has, and it is how this movie
	-- already reads data files. Re-pointing `fileName` is what forces a re-read: a member
	-- otherwise keeps whatever it loaded the first time, which for a mailbox would mean
	-- seeing the same frame forever.
	tMember = member("BridgeIn")
	if tMember = VOID then
		tMember = newMember("BridgeIn", #file, tPath)
		if tMember = VOID then
			return VOID
		end if
		tMember.fileSource = #online
		return tMember.text
	end if
	if tMember.fileName <> tPath then
		tMember.fileName = EMPTY
		tMember.fileName = tPath
	end if
	return tMember.text
end

on BridgeFileExists me, tPath
	if gBridge.io = "filextra4" then
		return gBridge.fx.fx_FileExists(tPath)
	end if
	if BridgeFileRead(0, tPath) = VOID then
		return 0
	end if
	return 1
end

--------------------------------------------------------------------------------
-- http  (PROTOCOL.md 7.2) -- NetLingo only, the way [PS] Shockwave Sitelock uses it
--------------------------------------------------------------------------------

on BridgeHttpUrl me, tSuffix
	return "http://" & gBridge.cfg.httpHost & ":" & string(gBridge.cfg.httpPort) & "/bridge" & tSuffix
end

on BridgeHttpStartPoll me
	-- One long poll outstanding at a time: `?ack=` tells Godot which of its frames we have
	-- applied, and the listener holds the connection open until it has a frame for us or
	-- the wait expires, so inbound latency is one frame instead of one poll interval.
	if gBridge.httpBusy = 1 then
		exit
	end if
	tUrl = gBridge.httpPollUrl & "?ack=" & string(gBridge.inSeq) & "&wait=" & string(gBridge.cfg.httpWaitMs)
	gBridge[#pollStart] = _system.milliSeconds
	gBridge[#pollId] = getNetText(tUrl)
	gBridge.httpBusy = 1
	return gBridge.pollId
end

on BridgeHttpPoll me
	if gBridge.httpBusy = 0 then
		BridgeHttpStartPoll(0)
		exit
	end if
	tId = gBridge.pollId
	if tId = VOID then
		gBridge.httpBusy = 0
		exit
	end if
	if netDone(tId) then
		gBridge.httpBusy = 0
		gBridge.pollId = 0
		if netError(tId) = "OK" or netError(tId) = EMPTY then
			tText = netTextResult(tId)
			if tText <> VOID then
				BridgeFeed(0, tText)
			end if
			gBridge.status = "up"
		else
			gBridge.stats.errors = gBridge.stats.errors + 1
			gBridge.status = "degraded"
			BridgeLog(0, "warn", "poll failed: " & netError(tId) & " -- is Godot listening on " & gBridge.cfg.httpHost & ":" & gBridge.cfg.httpPort & "?")
		end if
		exit
	end if
	-- still in flight: the long poll is supposed to stay open, so only complain past the wait
	if _system.milliSeconds - gBridge.pollStart > gBridge.cfg.httpWaitMs + 6000 then
		gBridge.status = "degraded"
		gBridge.httpBusy = 0
		gBridge.pollId = 0
		BridgeWarnOnce(0, "http", "no answer from " & gBridge.httpPollUrl & " -- start the Godot project (autoload ShockwaveBridge) with transport http")
	end if
end

on BridgeHttpPush me, tText
	-- The batch rides in the query, percent-encoded, as a GET. `newNetText(url, data)` would
	-- be the POST form, but its content-type and chunking behaviour differ across Director
	-- builds in ways that cannot be tested from here, and one frame's batch is small -- so a
	-- GET is the version that works everywhere. Godot's listener accepts both (§7.2).
	if tText.length = 0 then
		exit
	end if
	tUrl = gBridge.httpPushUrl & "?b=" & BridgeUrlEncode(0, tText) & "&seq=" & string(gBridge.outSeq)
	gBridge[#pushId] = getNetText(tUrl)
end

on BridgeHttpReset me
	gBridge[#httpBusy] = 0
	gBridge[#pollId] = 0
	gBridge[#pushId] = 0
	return 1
end

on BridgeUrlEncode me, tText
	-- Only what a URL cannot carry: TAB, LF, CR, space, %, &, ?, #, +, and anything outside
	-- printable ASCII. Everything else passes through, so a batch stays readable in a
	-- browser address bar while you debug it.
	tOut = EMPTY
	repeat with i = 1 to tText.length
		tChar = tText.char[i]
		tNum = charToNum(tChar)
		case tChar of
			"%":
				tOut = tOut & "%25"
			" ":
				tOut = tOut & "%20"
			"&":
				tOut = tOut & "%26"
			"?":
				tOut = tOut & "%3F"
			"#":
				tOut = tOut & "%23"
			"+":
				tOut = tOut & "%2B"
			"=":
				tOut = tOut & "%3D"
			otherwise:
				if tNum = 9 or tNum = 10 or tNum = 13 then
					tOut = tOut & "%" & BridgeHex2(0, tNum)
				else
					if tNum < 33 or tNum > 126 then
						tOut = tOut & "%" & BridgeHex2(0, tNum)
					else
						tOut = tOut & tChar
					end if
				end if
		end case
	end repeat
	return tOut
end

on BridgeHex2 me, tNumber
	tDigits = "0123456789ABCDEF"
	tHigh = integer(tNumber / 16)
	tLow = tNumber - (tHigh * 16)
	return tDigits[tHigh + 1] & tDigits[tLow + 1]
end

--------------------------------------------------------------------------------
-- tcp  (PROTOCOL.md 7.3) -- only with a socket xtra, which stock Director lacks
--------------------------------------------------------------------------------

on BridgeTcpAttach me, tSocket
	-- Hand the bridge any object that speaks `connect(host, port)`, `send(text)`,
	-- `inputString()`/`input()` -> string and `connected()` -> bool. Most socket xtras
	-- settle on that shape (INSTALL.md 4 names two), and everything above the adapter is
	-- the same frame protocol the file transport uses.
	gBridge[#sock] = tSocket
	if gBridge.initialized = 1 then
		if gBridge.cfg.transport = "tcp" then
			BridgeOpenTransport(0)
		end if
	end if
	return 1
end

on BridgeTcpSend me, tText
	if voidp(gBridge.sock) = 1 then
		BridgeWarnOnce(0, "tcp", "no socket attached -- call BridgeTcpAttach(xtraInstance)")
		exit
	end if
	gBridge.sock.send(tText)
end

on BridgeTcpPoll me
	if voidp(gBridge.sock) = 1 then
		exit
	end if
	if not gBridge.sock.connected() then
		if gBridge.peerReady = 1 then
			BridgeLog(0, "warn", "socket closed by the peer")
			gBridge.peerReady = 0
			gBridge.status = "degraded"
		end if
		gBridge.sock.connect(gBridge.cfg.tcpHost, gBridge.cfg.tcpPort)
		exit
	end if
	tText = gBridge.sock.input()
	if tText = VOID then
		exit
	end if
	if tText.length = 0 then
		exit
	end if
	-- A socket is a byte stream, not a sequence of frames, so the reader keeps the last
	-- line until its LF shows up and prepends that tail to the next read (spec 7.3).
	if gBridge.tcpTail.length > 0 then
		tText = gBridge.tcpTail & tText
	end if
	if tText[tText.length] = numToChar(10) then
		gBridge[#tcpTail] = EMPTY
	else
		tCut = BridgeLastIndex(0, tText, numToChar(10))
		if tCut < 1 then
			gBridge[#tcpTail] = tText
			exit
		end if
		gBridge[#tcpTail] = BridgeChars(0, tText, tCut + 1, tText.length)
		tText = BridgeChars(0, tText, 1, tCut)
	end if
	BridgeFeed(0, tText)
end
