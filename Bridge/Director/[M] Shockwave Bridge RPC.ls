-- [Script] [M] Shockwave Bridge RPC
-- Script Type: Movie
--
--------------------------------------------------------------------------------
-- Shockwave Bridge: message dispatch, the ops a Godot peer can ask for, and the API
-- the movie itself calls. Everything here obeys PROTOCOL.md 4, 5 and 6; the argument
-- shapes are the same ones Bridge/tools/bridge_peer.py::handle_op uses, because that
-- file is the reference implementation the conformance vectors come from.
--
-- Two rules the whole file is built around:
--
-- 1. NOTHING HAPPENS OUTSIDE enterFrame. Godot's writes are applied once per frame, in
--    this script, in the movie's own thread -- so a write can never land in the middle
--    of the game's own handler, and `gGame` stays consistent by construction.
--
-- 2. EVERY ACCESS IS ALLOW-LISTED. `expose` decides what may be read, `write` what may
--    be written, `call` which handlers may be invoked, `event` which events may be
--    raised, and `allowEval` alone decides `eval`/`exec`. A peer that asks for anything
--    else gets `err denied` back, and the game does not care. That is what makes it
--    safe to leave a bridge open in a build you hand to other people.
--
-- Lingo has no closures, so a request from the movie side carries an optional handler
-- name instead of a function: the reply is delivered as a sprite message the way
-- [M] Event Manager delivers every other event, and `BridgeReply(rid)` is the polling
-- form for the Message window and tools.
--------------------------------------------------------------------------------

global gSystem, gData, gGame, gBridge

--------------------------------------------------------------------------------
-- INBOUND: verbs
--------------------------------------------------------------------------------

on BridgeDispatch me, tVerb, tFields
	-- One parsed message. Every verb either needs no reply (SNAP/EVT/LOG/BYE/RSP) or
	-- queues exactly one (REQ), so a batch is answered in one flush (§4).
	case tVerb of
		"SNAP", "DELTA":
			BridgeAcceptSnapshot(0, tFields)
			exit
		"EVT":
			if tFields.count >= 2 then
				BridgeRaiseEvent(0, tFields[2], BridgeDecodeKvList(0, BridgeFieldOf(0, tFields, 3)))
			end if
			exit
		"HELLO":
			BridgeAcceptHello(0, tFields)
			exit
		"BYE":
			gBridge.peerReady = 0
			gBridge.status = "degraded"
			BridgeLog(0, "info", "peer said bye: " & BridgeFieldOf(0, tFields, 1))
			exit
		"PING":
			BridgePush(0, BridgeBuild(0, "PONG", [BridgeFieldOf(0, tFields, 1), _system.milliSeconds]))
			exit
		"PONG":
			if tFields.count >= 2 then
				gBridge.latency = (_system.milliSeconds - BridgeToInt(0, tFields[2])) / 2.0
			end if
			exit
		"LOG":
			-- the peer's log lines, relayed into the movie's own Message window
			LogMessage(0, "[godot] " & BridgeJoinFields(0, tFields))
			exit
		"REQ":
			tRid = BridgeFieldOf(0, tFields, 1)
			tOp = BridgeFieldOf(0, tFields, 2)
			tArgs = []
			repeat with i = 3 to tFields.count
				tArgs.add(tFields[i])
			end repeat
			BridgeAnswerReq(0, tRid, tOp, tArgs)
			exit
		"CMD":
			-- a REQ without a reply: the sender does not care what came back
			if tFields.count >= 2 then
				tArgs = []
				repeat with i = 3 to tFields.count
					tArgs.add(tFields[i])
				end repeat
				tReply = BridgeRunOp(0, BridgeFieldOf(0, tFields, 2), tArgs)
				if (BridgeChars(0, tReply, 1, 3)) = "err" then
					BridgeLog(0, "warn", "cmd refused: " & tReply)
				end if
			end if
			exit
		"RSP":
			BridgeAcceptRsp(0, tFields)
			exit
		otherwise:
			BridgeLog(0, "warn", "ignored unknown verb `" & tVerb & "`")
	end case
end

on BridgeFieldOf me, tFields, tIndex
	if tIndex <= tFields.count then
		return tFields[tIndex]
	end if
	return EMPTY
end

on BridgeJoinFields me, tFields
	tOut = EMPTY
	repeat with tField in tFields
		if tOut.length > 0 then
			tOut = tOut & " "
		end if
		tOut = tOut & string(tField)
	end repeat
	return tOut
end

on BridgeDecodeKvList me, tText
	-- An event's data arrives as `path=value;path=value` (§4); as a propList that is
	-- what a Lingo handler expects, so this is the shape we hand to `event`.
	tList = BridgeDecodeKV(0, tText)
	tResult = [:]
	repeat with tPair in tList
		tResult.addProp(symbol(tPair[1]), tPair[2])
	end repeat
	return tResult
end

--------------------------------------------------------------------------------
-- HANDSHAKE, HEARTBEAT, STATUS
--------------------------------------------------------------------------------

on BridgeAcceptHello me, tFields
	-- HELLO role name proto seq caps
	gBridge.peerReady = 1
	gBridge.peerRole = BridgeFieldOf(0, tFields, 1)
	gBridge.peerName = BridgeFieldOf(0, tFields, 2)
	gBridge[#peerProto] = BridgeToInt(0, BridgeFieldOf(0, tFields, 3))
	gBridge[#peerFrame] = BridgeToInt(0, BridgeFieldOf(0, tFields, 4))
	tCaps = BridgeFieldOf(0, tFields, 5)
	tList = []
	tOld = the itemDelimiter
	the itemDelimiter = ","
	repeat with i = 1 to tCaps.numItems
		tList.add(tCaps.item[i])
	end repeat
	the itemDelimiter = tOld
	gBridge.peerCaps = tList
	gBridge.lastSeen = _system.milliSeconds
	-- HELLO also means "my frame counter has started over". The 4th field is the greeter's own seq;
	-- when it is behind ours the peer restarted while we kept running, and the dedupe below would
	-- discard every one of its frames until its count caught up. Re-arm instead (PROTOCOL.md 4 and 8).
	tAnnounced = BridgeToInt(0, BridgeFieldOf(0, tFields, 4))
	if tAnnounced < gBridge.inSeq then
		gBridge.inSeq = 0
		gBridge[#lastInSeq] = -1
		gBridge.stats.dupes = 0
		BridgeLog(0, "info", "peer restarted at seq " & tAnnounced & ": re-armed the frame dedupe")
	end if
	if gBridge.helloSent = 0 then
		-- greeted first: answer once, and only once, so two hellos never ping-pong
		gBridge.helloSent = 1
		BridgePush(0, BridgeHelloLine(0))
	end if
	BridgeLog(0, "info", "peer is " & gBridge.peerRole & " `" & gBridge.peerName & "` proto " & gBridge.peerProto & " caps " & tCaps)
	BridgeNotify(0, #BridgePeerConnected)
	BridgeUpdateStatus(0)
end

on BridgeHelloLine me
	return BridgeBuild(0, "HELLO", [gBridge.role, gBridge.name, gBridge.proto, gBridge.outSeq, gBridge.caps])
end

on BridgeSendHelloIfNeeded me
	if gBridge.helloSent = 1 then
		exit
	end if
	-- Retried every frame until answered: on the files transport there is no connection
	-- to wait for, so the first HELLO is how each side learns the other exists at all.
	BridgePush(0, BridgeHelloLine(0))
	gBridge[#helloSent] = 1
	gBridge[#helloAt] = _system.milliSeconds
end

on BridgeUpdateStatus me
	if gBridge.status = "blocked" then
		exit
	end if
	if gBridge.peerReady = 0 then
		if gBridge.status <> "waiting" then
			gBridge.status = "waiting"
		end if
		exit
	end if
	tQuiet = _system.milliSeconds - gBridge.lastSeen
	if tQuiet > gBridge.cfg.peerTimeoutMs then
		if gBridge.status <> "stalled" then
			gBridge.status = "stalled"
			BridgeLog(0, "warn", "peer silent for " & tQuiet & " ms (timeout " & gBridge.cfg.peerTimeoutMs & ") -- is Godot still running?")
		end if
		exit
	end if
	if gBridge.status <> "up" then
		gBridge.status = "up"
		BridgeLog(0, "info", "peer up, " & gBridge.peerName)
	end if
end

on BridgeReapTimeouts me
	-- A request that never gets an answer must still resolve, or a caller waiting on it
	-- hangs forever: `timeout` is the error that says "the other half is not there".
	if voidp(gBridge.pending) = 1 then
		exit
	end if
	if gBridge.pending.count = 0 then
		exit
	end if
	tNow = _system.milliSeconds
	tExpired = []
	repeat with tRid in gBridge.pending.propNames
		tEntry = gBridge.pending[tRid]
		if tNow - tEntry.sent > gBridge.cfg.requestTimeoutMs then
			tExpired.add(tRid)
		end if
	end repeat
	repeat with tRid in tExpired
		tEntry = gBridge.pending[tRid]
		gBridge.pending.deleteProp(tRid)
		gBridge.stats.timeouts = gBridge.stats.timeouts + 1
		BridgeDeliver(0, tRid, [#bridgeError: "timeout", #message: "no RSP within " & gBridge.cfg.requestTimeoutMs & " ms"], 1, tEntry)
	end repeat
end

on BridgeAcceptSnapshot me, tFields
	-- SNAP seq frame tms ack kv -- deduplicated by seq, because a batch may be read twice
	-- while a file is being replaced under us (§8).
	if tFields.count < 1 then
		exit
	end if
	tSeq = BridgeToInt(0, tFields[1])
	if tSeq <= gBridge.inSeq then
		gBridge.stats.dupes = gBridge.stats.dupes + 1
		exit
	end if
	gBridge.inSeq = tSeq
	gBridge.peerFrame = BridgeToInt(0, BridgeFieldOf(0, tFields, 2))
	gBridge.peerTms = BridgeToInt(0, BridgeFieldOf(0, tFields, 3))
	gBridge.peerAck = BridgeToInt(0, BridgeFieldOf(0, tFields, 4))
	repeat with tPair in BridgeDecodeKV(BridgeFieldOf(0, tFields, 5))
		BridgeApplyRemote(0, tPair[1], tPair[2], 0)
	end repeat
end

--------------------------------------------------------------------------------
-- OUTBOUND requests (the movie asking Godot)
--------------------------------------------------------------------------------

on BridgeRequest me, tOp, tArgs, tHandler, tTarget
	-- REQ rid op args... -- one message per frame, one RSP per request (§4).
	gBridge.nextRid = gBridge.nextRid + 1
	tRid = gBridge.nextRid
	BridgePush(0, BridgeBuild(0, "REQ", [tRid, tOp] & tArgs))
	tEntry = [:]
	tEntry[#op] = tOp
	tEntry[#sent] = _system.milliSeconds
	tEntry[#handler] = tHandler
	tEntry[#target] = tTarget
	gBridge.pending.addProp(tRid, tEntry)
	gBridge.stats.requests = gBridge.stats.requests + 1
	return tRid
end

on BridgeAcceptRsp me, tFields
	-- RSP rid op ok|err payload...
	if tFields.count < 3 then
		exit
	end if
	tRid = BridgeToInt(0, tFields[1])
	tEntry = VOID
	if voidp(gBridge.pending[tRid]) = 0 then
		tEntry = gBridge.pending[tRid]
		gBridge.pending.deleteProp(tRid)
	else
		gBridge.stats.dupes = gBridge.stats.dupes + 1
		exit
	end if
	gBridge.stats.replies = gBridge.stats.replies + 1
	if tFields[3] = "ok" then
		tPayload = []
		repeat with i = 4 to tFields.count
			tPayload.add(BridgeDecode(0, tFields[i]))
		end repeat
		-- one field is the value itself; several stay a list (mirrors bridge_peer.py)
		if tPayload.count = 1 then
			tValue = tPayload[1]
		else
			tValue = tPayload
		end if
		BridgeDeliver(0, tRid, tValue, 0, tEntry)
		exit
	end if
	BridgeDeliver(0, tRid, [#bridgeError: BridgeFieldOf(0, tFields, 4), #message: BridgeFieldOf(0, tFields, 5)], 1, tEntry)
end

on BridgeDeliver me, tRid, tValue, tIsError, tEntry
	-- Two ways to hand a reply back: the polling form (gBridge.reply, what the Message
	-- window and the tools use) and the message form (what game code uses), named at
	-- request time as `BridgeRequest("get", [path], #OnGotCash, 0)`.
	if voidp(gBridge.reply) = 1 then
		gBridge[#reply] = [:]
	end if
	gBridge.reply.addProp(tRid, tValue)
	if tIsError = 1 then
		BridgeLog(0, "warn", "request " & tRid & " failed: " & tValue)
	end if
	if tEntry = VOID then
		exit
	end if
	if tEntry.handler = VOID then
		exit
	end if
	_movie.sendSprite(0, tEntry.handler, tEntry.target, [tRid, tValue])
end

on BridgeUnquote me, tText
	-- The vectors file's `render` column is the reference implementation's display form; for a
	-- string it is the text with quotes around it, so peel them before comparing.
	if tText.length > 1 then
		if tText[1] = quote and tText[tText.length] = quote then
			return BridgeChars(0, tText, 2, tText.length - 1)
		end if
	end if
	return tText
end

on BridgeReply me, tRid
	-- VOID while it is outstanding -- poll this from an enterFrame of your own, or use
	-- BridgeWait in a tool. Once read, it is removed, so a second call cannot re-serve
	-- a stale answer for the same id.
	if voidp(gBridge.reply) = 1 then
		return VOID
	end if
	if voidp(gBridge.reply[tRid]) = 1 then
		return VOID
	end if
	tValue = gBridge.reply[tRid]
	gBridge.reply.deleteProp(tRid)
	return tValue
end

on BridgeWait me, tRid, tTimeoutMs
	-- Blocking, and only ever for a tool or the Message window: this reads the mailbox
	-- directly instead of waiting for the frame boundary, because a tool has no frames.
	tDeadline = _system.milliSeconds + tTimeoutMs
	repeat while _system.milliSeconds < tDeadline
		BridgePollTransport(0)
		tValue = BridgeReply(0, tRid)
		if tValue <> VOID then
			return tValue
		end if
		waitForRedraw(0)
	end repeat
	return [#bridgeError: "timeout", #message: "no reply for request " & tRid]
end

--------------------------------------------------------------------------------
-- OPS: what Godot is allowed to ask for
--------------------------------------------------------------------------------

on BridgeAnswerReq me, tRid, tOp, tArgs
	-- Exactly one RSP per REQ, ok or err -- a request with no answer is a bug, and the
	-- sender's timeout is only a safety net (§4).
	tResult = BridgeRunOp(0, tOp, tArgs)
	BridgePush(0, BridgeRspLine(0, tRid, tOp, tResult))
end

on BridgeRspLine me, tRid, tOp, tResult
	if tResult.ilk = #propList then
		if tResult[#bridgeError] <> VOID then
			return BridgeBuild(0, "RSP", [tRid, tOp, "err", tResult[#bridgeError], tResult[#message]])
		end if
	end if
	tFields = []
	if tResult.ilk = #list then
		tFields = tResult
	else
		tFields.add(tResult)
	end if
	return BridgeBuild(0, "RSP", [tRid, tOp, "ok"] & tFields)
end

on BridgeError me, tCode, tMessage
	-- The one shape every refusal takes, so a caller can test `reply[#bridgeError]`.
	return [#bridgeError: tCode, #message: tMessage]
end

on BridgeRunOp me, tOp, tArgs
	-- The op table. Argument order is PROTOCOL.md 4 verbatim; the same table is
	-- bridge_peer.py::handle_op, and BridgeSelfTest checks both against the vectors file.
	case tOp of
		"get":
			-- get <path> -> path value
			if tArgs.count < 1 then
				return BridgeError(0, "badargs", "get <path>")
			end if
			tPath = tArgs[1]
			tRefusal = BridgeCheckRead(0, tPath)
			if tRefusal <> VOID then
				return tRefusal
			end if
			return [tPath, BridgeEncode(0, BridgeResolvePath(0, tPath))]
		"gets":
			-- gets path;path;path -> "path=wire;path=wire", per path, denials inline
			tOut = []
			tList = BridgeSplitOn(0, BridgeFieldOf(0, tArgs, 1), ";")
			repeat with tPath in tList
				if tPath.length = 0 then
					next repeat
				end if
				if BridgeCheckRead(0, tPath) <> VOID then
					tOut.add(tPath & "=denied")
				else
					tOut.add(tPath & "=" & BridgeEncode(0, BridgeResolvePath(0, tPath)))
				end if
			end repeat
			return [BridgeJoinWith(0, tOut, ";")]
		"set":
			-- set <path> <value> -> path value
			if tArgs.count < 2 then
				return BridgeError(0, "badargs", "set <path> <value>")
			end if
			tRefusal = BridgeCheckWrite(0, tArgs[1])
			if tRefusal <> VOID then
				return tRefusal
			end if
			tValue = BridgeDecode(0, tArgs[2])
			BridgeApplyRemote(0, tArgs[1], tValue, 1)
			BridgeMarkDirty(0, tArgs[1], tValue)
			return [tArgs[1], BridgeEncode(0, tValue)]
		"sets":
			-- sets path=value;path=value -> atomic-enough batch; denials are per path
			tOut = []
			repeat with tChunk in BridgeSplitOn(0, BridgeFieldOf(0, tArgs, 1), ";")
				if tChunk.length = 0 then
					next repeat
				end if
				tEquals = BridgeIndexOf(0, tChunk, "=", 1)
				if tEquals < 2 then
					next repeat
				end if
				tPath = BridgeChars(0, tChunk, 1, tEquals - 1)
				tRaw = BridgeChars(0, tChunk, tEquals + 1, tChunk.length)
				tRefusal = BridgeCheckWrite(0, tPath)
				if tRefusal <> VOID then
					gBridge.stats.denied = gBridge.stats.denied + 1
					tOut.add(tPath & "=denied")
					next repeat
				end if
				tValue = BridgeDecode(0, tRaw)
				BridgeApplyRemote(0, tPath, tValue, 1)
				BridgeMarkDirty(0, tPath, tValue)
				tOut.add(tPath & "=" & BridgeEncode(0, tValue))
			end repeat
			return [BridgeJoinWith(0, tOut, ";")]
		"sub":
			-- sub <path> [rate] -> path value  (and the path starts being mirrored)
			if tArgs.count < 1 then
				return BridgeError(0, "badargs", "sub <path>")
			end if
			tRefusal = BridgeCheckRead(0, tArgs[1])
			if tRefusal <> VOID then
				return tRefusal
			end if
			BridgeSubscribe(0, tArgs[1], BridgeToInt(0, BridgeFieldOf(0, tArgs, 2)))
			return [tArgs[1], BridgeEncode(0, BridgeResolvePath(0, tArgs[1]))]
		"unsub":
			if tArgs.count < 1 then
				return BridgeError(0, "badargs", "unsub <path>")
			end if
			BridgeUnsubscribe(0, tArgs[1])
			return [tArgs[1]]
		"snap":
			-- snap on|off [rate] [delta|full]
			tOn = 1
			tMode = BridgeFieldOf(0, tArgs, 1)
			if (BridgeChars(0, tMode, tMode.length, tMode.length)) = "0" then
				tOn = 0
			end if
			if tMode = "off" then
				tOn = 0
			end if
			if tArgs.count > 1 then
				gBridge.cfg.rate = integer(BridgeToInt(0, tArgs[2]))
				if gBridge.cfg.rate < 1 then
					gBridge.cfg.rate = 1
				end if
			end if
			if tArgs.count > 2 then
				gBridge.cfg.snapshot = tArgs[3]
			end if
			if tOn = 0 then
				-- stopping the mirror drops the subscriptions it was driven by, so a
				-- restart cannot leave paths mirroring that nobody asked for any more
				gBridge.subs = [:]
				gBridge.dirty = [:]
				gBridge.lastSent = [:]
			end if
			return ["b:" & tOn, string(gBridge.cfg.rate), gBridge.cfg.snapshot]
		"call":
			-- call <handler> [target] [literal] -> value
			if tArgs.count < 1 then
				return BridgeError(0, "badargs", "call <handler> [target] [literal]")
			end if
			return [BridgeExecuteCall(0, tArgs[1], BridgeFieldOf(0, tArgs, 2), BridgeFieldOf(0, tArgs, 3))]
		"event":
			-- event <name> [kvlist] -> 1
			if tArgs.count < 1 then
				return BridgeError(0, "badargs", "event <name> [kvlist]")
			end if
			BridgeRaiseEvent(0, tArgs[1], BridgeDecodeKvList(0, BridgeFieldOf(0, tArgs, 2)))
			return ["b:1"]
		"eval":
			if gBridge.cfg.allowEval = 0 then
				return BridgeError(0, "disabled", "eval needs allowEval TRUE in Bridge.Data.txt")
			end if
			return [BridgeEncode(0, value(BridgeJoinWith(0, tArgs, " ")))]
		"exec":
			if gBridge.cfg.allowEval = 0 then
				return BridgeError(0, "disabled", "exec needs allowEval TRUE in Bridge.Data.txt")
			end if
			do(BridgeJoinWith(0, tArgs, " "))
			return ["b:1"]
		"list":
			-- list [prefix] [depth] -> "path=wire;path=wire"
			tOut = []
			repeat with tEntry in BridgeEnumerate(0, BridgeFieldOf(0, tArgs, 1), BridgeToInt(0, BridgeFieldOf(0, tArgs, 2)))
				tOut.add(tEntry[1] & "=" & tEntry[2])
			end repeat
			return [BridgeJoinWith(0, tOut, ";")]
		"ping":
			-- ping <tms> -> our own tms, so the caller can measure the round trip
			return [string(_system.milliSeconds), BridgeFieldOf(0, tArgs, 1)]
		"quit":
			BridgePushBye(0, "quit")
			return ["b:1"]
		otherwise:
			return BridgeError(0, "unknownop", tOp)
	end case
end

on BridgeSplitOn me, tText, tDelimiter
	tOld = the itemDelimiter
	the itemDelimiter = tDelimiter
	tOut = []
	repeat with i = 1 to tText.numItems
		tOut.add(tText.item[i])
	end repeat
	the itemDelimiter = tOld
	return tOut
end

on BridgeJoinWith me, tList, tDelimiter
	tOut = EMPTY
	repeat with tItem in tList
		if tOut.length > 0 then
			tOut = tOut & tDelimiter
		end if
		tOut = tOut & string(tItem)
	end repeat
	return tOut
end

--------------------------------------------------------------------------------
-- ALLOW-LISTS
--------------------------------------------------------------------------------

on BridgeCheckRead me, tPath
	if BridgeAllowed(0, tPath, gBridge.cfg.expose) then
		return VOID
	end if
	gBridge.stats.denied = gBridge.stats.denied + 1
	return BridgeError(0, "denied", tPath)
end

on BridgeCheckWrite me, tPath
	if BridgeIsBridgePath(0, tPath) then
		-- the replicated store is writable from either side, always: that is the whole
		-- point of it, and it cannot break the movie's own state machine
		return VOID
	end if
	if gBridge.cfg.write.count = 0 then
		gBridge.stats.denied = gBridge.stats.denied + 1
		return BridgeError(0, "disabled", "no `write` allow-list in Bridge.Data.txt")
	end if
	if BridgeAllowed(0, tPath, gBridge.cfg.write) then
		return VOID
	end if
	gBridge.stats.denied = gBridge.stats.denied + 1
	return BridgeError(0, "denied", tPath)
end

on BridgeCheckCall me, tHandler
	if BridgeAllowed(0, tHandler, gBridge.cfg.call) then
		return VOID
	end if
	gBridge.stats.denied = gBridge.stats.denied + 1
	return BridgeError(0, "denied", "call " & tHandler)
end

on BridgeCheckEvent me, tName
	if gBridge.cfg.event.count = 0 then
		-- no list means "any event", which is what a single-player game on its own machine
		-- wants; a list narrows it to exactly the ones the movie can survive being raised
		-- from outside at any moment.
		return VOID
	end if
	if BridgeAllowed(0, tName, gBridge.cfg.event) then
		return VOID
	end if
	gBridge.stats.denied = gBridge.stats.denied + 1
	return BridgeError(0, "denied", "event " & tName)
end

--------------------------------------------------------------------------------
-- HANDLERS AND EVENTS, INTO THE MOVIE
--------------------------------------------------------------------------------

on BridgeExecuteCall me, tHandler, tTarget, tLiteral
	-- The `call` op: invoke a movie handler by name with a Lingo propList, exactly the way
	-- [M] Event Manager invokes everything else -- `_movie.sendSprite(0, handler, target,
	-- dataList)`, which returns whatever the handler returns. Only names on the `call`
	-- list get through, so the string that reaches Lingo is never attacker-chosen.
	tHandler = BridgeTrim(0, tHandler)
	if tHandler.length = 0 then
		return BridgeError(0, "badargs", "empty handler name")
	end if
	tRefusal = BridgeCheckCall(0, tHandler)
	if tRefusal <> VOID then
		return tRefusal
	end if
	tData = VOID
	if tLiteral <> VOID then
		if tLiteral.length > 0 then
			tData = value(tLiteral)
		end if
	end if
	tSprite = 0
	if tTarget <> VOID then
		if tTarget.length > 0 then
			tSprite = value(tTarget)
		end if
	end if
	tFunction = symbol(tHandler)
	if tFunction = VOID then
		return BridgeError(0, "notfound", tHandler)
	end if
	tResult = _movie.sendSprite(0, tFunction, tSprite, tData)
	if voidp(tResult) = 1 then
		-- nothing answered: the handler does not exist in this movie
		return BridgeError(0, "notfound", "no movie handler " & tHandler)
	end if
	return BridgeEncode(0, tResult)
end

on BridgeRaiseEvent me, tName, tData
	-- The `event` op. `event` here is the game's own handler in [M] Event Manager, which
	-- looks the name up in gData[#Events] and runs the registered targets -- so raising an
	-- event the movie does not know is a logged no-op, not a crash, which is what makes it
	-- safe to expose. tData is stashed where the event's own handlers can pick it up, since
	-- the movie's event dispatcher takes no payload.
	tName = BridgeTrim(0, string(tName))
	if tName.length = 0 then
		exit
	end if
	tRefusal = BridgeCheckEvent(0, tName)
	if tRefusal <> VOID then
		BridgeLog(0, "warn", "event refused: " & tRefusal[#message])
		exit
	end if
	gBridge[#lastEventData] = tData
	gGame[#bridgeEventData] = tData
	gGame[#bridgeEventName] = symbol(tName)
	event(0, symbol(tName))
end

on BridgeEventData me
	-- Called from a movie event handler to read what Godot sent with it:
	--     on MyBridgeEvent me
	--       tData = BridgeEventData(0)
	--     end
	if voidp(gBridge) = 1 then
		return VOID
	end if
	return gBridge.lastEventData
end

--------------------------------------------------------------------------------
-- LIST
--------------------------------------------------------------------------------

on BridgeEnumerate me, tPrefix, tDepth
	-- Every leaf under a prefix, as `path=wiretext` pairs, capped by depth -- what Godot's
	-- `list_paths` and the dock's `list` command show. Only exposed paths are listed: a
	-- bridge that would hand over the whole of gGame on request is not a bridge you want
	-- left running in a shipped build.
	tOut = []
	if tPrefix = VOID or tPrefix.length = 0 or tPrefix = "gBridge" or tPrefix = "bridge" or BridgeIsBridgePath(0, tPrefix) then
		repeat with tKey in gBridge.store.propNames
			tOut.add(["bridge." & tKey, BridgeEncode(0, gBridge.store[tKey])])
		end repeat
		if tPrefix = VOID or tPrefix.length = 0 or BridgeIsBridgePath(0, tPrefix) then
			if tPrefix <> "gBridge" and tPrefix <> "bridge" then
				if tPrefix.length = 0 then
					return tOut
				end if
			end if
		end if
		if tPrefix = "gBridge" or tPrefix = "bridge" then
			return tOut
		end if
		if tPrefix.length = 0 then
			return tOut
		end if
	end if
	if tDepth < 1 then
		tDepth = 1
	end if
	tNode = BridgeResolvePath(0, tPrefix)
	BridgeCollect(0, tPrefix, tNode, tDepth, tOut)
	return tOut
end

on BridgeCollect me, tPath, tNode, tDepth, tOut
	if tNode = VOID then
		exit
	end if
	if tNode.ilk = #propList then
		if tDepth <= 0 then
			tOut.add([tPath, BridgeEncode(0, tNode)])
			exit
		end if
		repeat with i = 1 to tNode.count
			tKey = tNode.getPropAt(i)
			tChild = BridgePathChild(0, tPath, BridgeKeyText(0, tKey))
			BridgeCollect(0, tChild, tNode[i], tDepth - 1, tOut)
		end repeat
		exit
	end if
	if tNode.ilk = #list then
		if tDepth <= 0 then
			tOut.add([tPath, BridgeEncode(0, tNode)])
			exit
		end if
		repeat with i = 1 to tNode.count
			BridgeCollect(0, BridgePathChild(0, tPath, i), tNode[i], tDepth - 1, tOut)
		end repeat
		exit
	end if
	if BridgeAllowed(0, tPath, gBridge.cfg.expose) then
		tOut.add([tPath, BridgeEncode(0, tNode)])
	end if
end

on BridgePathChild me, tPath, tKey
	-- Same rule as the reference: an integer key is `[n]`, anything else is `.name`, and a
	-- list index stays 1-based across the wire because that is what Lingo means by it.
	if tPath.length = 0 then
		return string(tKey)
	end if
	if tKey.ilk = #integer then
		return tPath & "[" & tKey & "]"
	end if
	return tPath & "." & tKey
end

--------------------------------------------------------------------------------
-- THE MOVIE'S OWN API
--------------------------------------------------------------------------------

on BridgeGet me, tPath
	-- Read something Godot has written (or the movie's own state) with no round trip: the
	-- mirror is always current as of this frame.
	tPath = BridgeResolveAlias(0, tPath)
	if voidp(gBridge.mirror[tPath]) = 0 then
		return gBridge.mirror[tPath]
	end if
	if BridgeIsBridgePath(0, tPath) then
		tKey = BridgeBridgeKey(0, tPath)
		if voidp(gBridge.store[tKey]) = 1 then
			return VOID
		end if
		return gBridge.store[tKey]
	end if
	return BridgeResolvePath(0, tPath)
end

on BridgeSet me, tPath, tValue
	-- Write into the game. The movie's own scripts are not sandboxed the way a peer is --
	-- this is you talking to your own state -- but it marks the path dirty, so the change
	-- reaches Godot on this same frame instead of waiting for the next subscription read.
	tPath = BridgeResolveAlias(0, tPath)
	if BridgeWritePath(0, tPath, tValue) = 0 then
		BridgeLog(0, "warn", "BridgeSet could not write " & tPath)
		return 0
	end if
	BridgeMarkDirty(0, tPath, tValue)
	return 1
end

on BridgeStore me, tKey, tValue
	-- The replicated store: `bridge.<key>`, readable and writable from both sides, arriving
	-- on the next frame either way. This is the channel for data the game has no variable for
	-- -- and it needs no allow-list, because it cannot touch the movie's own state.
	if voidp(tValue) = 1 then
		gBridge.store.deleteProp(tKey)
	else
		gBridge.store.addProp(tKey, tValue)
	end if
	BridgeMarkDirty(0, "bridge." & tKey, tValue)
	return 1
end

on BridgeFetch me, tPath, tHandler, tTarget
	-- Ask Godot for something this movie cannot see: a `gd:` path, or anything not mirrored
	-- yet. The answer comes back next frame, to tHandler if you name one:
	--     on OnBridgeValue me, tRid, tValue
	-- or you can poll it with BridgeReply(rid).
	return BridgeRequest(0, "get", [BridgeResolveAlias(0, tPath)], tHandler, tTarget)
end

on BridgeWatch me, tPath, tRate
	-- Ask to be told when something changes -- the mirror is bidirectional, so a path can
	-- be subscribed from either end; this end's subscriptions are what we send out.
	tPath = BridgeRequest(0, "sub", [BridgeResolveAlias(0, tPath), voidp(tRate) = 1 then 0 else tRate], VOID, VOID)
	return tPath
end

on BridgeUnwatch me, tPath
	return BridgeRequest(0, "unsub", [BridgeResolveAlias(0, tPath)], VOID, VOID)
end

on BridgeEvent me, tName, tData
	-- Raise an event on the *other* side. On the Godot end this becomes a
	-- `bridge_event` call on the bound node and the `bridge_event_raised` signal.
	tPairs = []
	if tData <> VOID then
		if tData.ilk = #propList then
			repeat with i = 1 to tData.count
				tKey = tData.getPropAt(i)
				tPairs.add([BridgeKeyText(0, tKey), BridgeEncode(0, tData[i])])
			end repeat
		end if
	end if
	gBridge.outSeq = gBridge.outSeq + 1
	BridgePush(0, BridgeBuild(0, "EVT", [gBridge.outSeq, tName, BridgeEncodeKV(0, tPairs)]))
	BridgeFlush(0)
	return 1
end

on BridgeCallRemote me, tHandler, tTarget, tLiteral
	-- Ask Godot to call into its own scene (a bound node method). The reply is the return
	-- value; the movie-side equivalent is what Godot's `call_director` does to us.
	tArgs = [tHandler]
	if tTarget <> VOID then
		tArgs.add(tTarget)
	else
		tArgs.add(EMPTY)
	end if
	if tLiteral <> VOID then
		tArgs.add(tLiteral)
	end if
	return BridgeRequest(0, "call", tArgs, VOID, VOID)
end

on BridgeSnap me, tOn, tRate, tMode
	-- Tell Godot to start or stop mirroring *its* state (the peer's half of the same op).
	return BridgeRequest(0, "snap", ["b:" & BridgeToInt(0, tOn), string(voidp(tRate) = 1 then 0 else tRate), voidp(tMode) = 1 then "delta" else tMode], VOID, VOID)
end

on BridgeStatus me
	-- A propList, for scripts; BridgeStatusText() is the same thing for the Message window.
	tOut = [:]
	tOut[#status] = gBridge.status
	tOut[#transport] = gBridge.cfg.transport
	tOut[#io] = gBridge.io
	tOut[#role] = gBridge.role
	tOut[#peer] = gBridge.peerName
	tOut[#peerRole] = gBridge.peerRole
	tOut[#peerReady] = gBridge.peerReady
	tOut[#frame] = gBridge.frame
	tOut[#outSeq] = gBridge.outSeq
	tOut[#inSeq] = gBridge.inSeq
	tOut[#subs] = gBridge.subs.count
	tOut[#store] = gBridge.store.count
	tOut[#mirror] = gBridge.mirror.count
	tOut[#pending] = gBridge.pending.count
	tOut[#latency] = gBridge.latency
	tOut[#mailbox] = gBridge.outPath
	tOut[#stats] = gBridge.stats
	return tOut
end

on BridgeStatusText me
	-- One line for the Message window, in the order you debug a bridge in: is it up, over
	-- what, with whom, and is anything stuck.
	tStats = gBridge.stats
	tLine = "status " & gBridge.status & "  transport " & gBridge.cfg.transport & "  io " & gBridge.io
	tLine = tLine & "  peer " & gBridge.peerRole & " " & quote & gBridge.peerName & quote & " (" & gBridge.peerReady & ")"
	tLine = tLine & "  frame " & gBridge.frame & "  seq " & gBridge.outSeq & "/" & gBridge.inSeq
	tLine = tLine & "  latency " & BridgeFloatText(0, gBridge.latency) & " ms"
	tLine = tLine & "  subs " & gBridge.subs.count & "  store " & gBridge.store.count & "  mirror " & gBridge.mirror.count & "  pending " & gBridge.pending.count
	tLine = tLine & "  msgs " & tStats[#msgsOut] & "/" & tStats[#msgsIn] & "  frames " & tStats[#framesOut] & "/" & tStats[#framesIn]
	tLine = tLine & "  torn " & tStats[#torn] & "  denied " & tStats[#denied] & "  errors " & tStats[#errors] & "  timeouts " & tStats[#timeouts]
	return tLine
end

on BridgeDump me
	-- Everything the bridge knows, in the Message window, in the order you debug it:
	-- status, then the store, then the mirror, then the subscriptions.
	put BridgeStatusText(0)
	put "-- store --"
	repeat with tKey in gBridge.store.propNames
		put "  bridge." & tKey & " = " & BridgePrintLiteral(0, gBridge.store[tKey])
	end repeat
	put "-- mirror --"
	repeat with tPath in gBridge.mirror.propNames
		put "  " & tPath & " = " & BridgePrintLiteral(0, gBridge.mirror[tPath])
	end repeat
	put "-- subscriptions --"
	repeat with tPath in gBridge.subs.propNames
		put "  " & tPath & "  rate " & gBridge.subs[tPath]
	end repeat
	return 1
end

--------------------------------------------------------------------------------
-- CONFORMANCE: the same vectors file both engines must agree on
--------------------------------------------------------------------------------

on BridgeSelfTest me
	-- Reads Bridge.Vectors.txt -- the file `python3 bridge_proto.py vectors` generates from
	-- the reference implementation's own sample table -- and checks this engine's encoder and
	-- decoder against it. Lingo has no JSON, which is the entire reason the file is
	-- TAB-separated rather than the JSON the Godot side also ships.
	--
	-- Records (first field is the kind):
	--   value<TAB>note<TAB>wire<TAB>render
	--   message<TAB>note<TAB>verb<TAB>fieldcount<TAB>line
	--   literal<TAB>note<TAB>input<TAB>flattened
	--   kv<TAB>note<TAB>text
	--   path<TAB>path<TAB>namespace<TAB>parent<TAB>tail
	tText = BridgeVectorsText(0)
	if tText = VOID or tText.length = 0 then
		put "BRIDGE SELFTEST: no Bridge.Vectors.txt found (import it as a text member named" && quote & "Bridge.Vectors" & quote & ", or leave it next to the movie)"
		return 0
	end if
	tPass = 0
	tFail = 0
	tOldDelimiter = the itemDelimiter
	tCounts = [:]
	repeat with tLine in BridgeLines(0, tText)
		the itemDelimiter = tab
		tFields = []
		repeat with i = 1 to tLine.numItems
			tFields.add(tLine.item[i])
		end repeat
		if tFields.count < 2 then
			next repeat
		end if
		if tFields[1][1] = "#" then
			next repeat
		end if
		tKind = tFields[1]
		tNote = tFields[2]
		if voidp(tCounts[tKind]) = 1 then
			tCounts.addProp(tKind, 0)
		end if
		tCounts[tKind] = tCounts[tKind] + 1
		tOk = 1
		tWhy = EMPTY
		if tKind = "value" or tKind = "literal" or tKind = "message" then
			if tFields.count < 4 then
				tOk = 0
				tWhy = "record has only " & tFields.count & " fields"
			end if
		end if
		case tKind of
			"value":
				-- decode then re-encode must be byte-identical: that is the whole contract.
				-- The 4th field is the reference's own human-readable `render` form, which
				-- is compared only where float text cannot differ -- see the note below.
				tWire = tFields[3]
				tAgain = BridgeEncode(0, BridgeDecode(0, tWire))
				if tAgain <> tWire then
					tOk = 0
					tWhy = "encode(decode(" & tWire & ")) gave " & tAgain
				else
					if tFields.count > 4 then
						if tWire[1] = "s" or tWire[1] = "y" then
							if BridgePrintLiteral(0, BridgeDecode(0, tWire)) <> BridgeUnquote(0, tFields[4]) then
								tOk = 0
								tWhy = "literal form is " & BridgePrintLiteral(0, BridgeDecode(0, tWire)) & ", expected " & tFields[4]
							end if
						end if
					end if
				end if
			"literal":
				-- parse the Lingo literal, flatten it to `path=wire`, and compare each leaf
				tFlatten = BridgeFlatten(0, value(tFields[3]), EMPTY)
				tWant = BridgeSplitOn(0, tFields[4], "|")
				if tFlatten.count <> tWant.count then
					tOk = 0
					tWhy = tFlatten.count & " leaves, expected " & tWant.count
				else
					repeat with i = 1 to tWant.count
						if tFlatten[i] <> tWant[i] then
							tOk = 0
							tWhy = "leaf " & i & " is " & tFlatten[i] & ", expected " & tWant[i]
							exit repeat
						end if
					end repeat
				end if
			"message":
				-- a record's `line` field CONTAINS tabs, so it is every field from 5 on,
				-- rejoined -- the same rule bridge_proto.read_compat_vectors documents and
				-- the GDScript reader follows.
				tLine = EMPTY
				repeat with i = 5 to tFields.count
					if i > 5 then
						tLine = tLine & tab
					end if
					tLine = tLine & tFields[i]
				end repeat
				tParts = BridgeSplitOn(0, tLine, tab)
				tArgs = []
				repeat with i = 2 to tParts.count
					tArgs.add(tParts[i])
				end repeat
				if BridgeBuild(0, tParts[1], tArgs) <> tLine then
					tOk = 0
					tWhy = "build(verb, fields) did not reproduce " & tLine
				else
					tParsed = BridgeParse(0, tLine)
					if tParsed[#verb] <> tFields[3] then
						tOk = 0
						tWhy = "parse saw verb " & tParsed[#verb]
					else
						if tParsed[#fields].count <> BridgeToInt(0, tFields[4]) then
							tOk = 0
							tWhy = "parse saw " & tParsed[#fields].count & " fields, expected " & tFields[4]
						end if
					end if
				end if
			"kv":
				tBack = BridgeEncodeKV(0, BridgeDecodeKV(0, tFields[3]))
				if tBack <> tFields[3] then
					tOk = 0
					tWhy = "kv round trip gave " & tBack
				end if
			"path":
				tNamespace = BridgePathNamespace(0, tFields[2])
				if tNamespace <> tFields[3] then
					tOk = 0
					tWhy = "namespace gave " & tNamespace & ", expected " & tFields[3]
				end if
		end case
		if tOk = 1 then
			tPass = tPass + 1
		else
			tFail = tFail + 1
			put "FAIL " & tKind & " " & quote & tNote & quote & " -- " & tWhy
		end if
	end repeat
	the itemDelimiter = tOldDelimiter
	put "BRIDGE SELFTEST: " & tPass & " of " & (tPass + tFail) & " vectors pass " & BridgePrintLiteral(0, tCounts)
	if tFail = 0 then
		BridgeRunLoopbackCheck(0)
	end if
	return tFail = 0
end

on BridgeVectorsText me
	if member("Bridge.Vectors") <> VOID then
		return member("Bridge.Vectors").text
	end if
	tCandidates = []
	if voidp(gSystem) = 0 then
		tCandidates.add(gSystem.path & "Bridge\\Bridge.Vectors.txt")
	end if
	tCandidates.add(_movie.path & "Bridge\\Bridge.Vectors.txt")
	tCandidates.add(_movie.path & "Bridge.Vectors.txt")
	tCandidates.add(_movie.path & "Bridge\\Director\\Bridge.Vectors.txt")
	repeat with tPath in tCandidates
		tText = BridgeFileRead(0, tPath)
		if tText <> VOID then
			return tText
		end if
	end repeat
	return EMPTY
end

on BridgeFlatten me, tNode, tPath
	-- Leaves of a parsed literal as `path=wiretext`, 1-based indices, `root` for an empty
	-- prefix -- the definition the vectors file was generated with (see bridge_proto.flatten).
	tOut = []
	if tNode.ilk = #propList then
		repeat with i = 1 to tNode.count
			tKey = tNode.getPropAt(i)
			tOut = tOut & BridgeFlatten(0, tNode[i], BridgePathChild(0, tPath, BridgeKeyText(0, tKey)))
		end repeat
		return tOut
	end if
	if tNode.ilk = #list then
		repeat with i = 1 to tNode.count
			tOut = tOut & BridgeFlatten(0, tNode[i], BridgePathChild(0, tPath, i))
		end repeat
		return tOut
	end if
	if tPath.length = 0 then
		tPath = "root"
	end if
	return [tPath & "=" & BridgeEncode(0, tNode)]
end

on BridgeRunLoopbackCheck me
	-- End-to-end, with no Godot in sight: feed our own dispatcher a frame and check the
	-- movie actually changed. If this passes and the peer still sees nothing, the problem
	-- is the transport, not the protocol -- which is the split worth knowing at 1 a.m.
	tBefore = gGame.Cash
	BridgeFeed(0, "REQ" & tab & "9001" & tab & "set" & tab & "gGame.Cash" & tab & "i:" & (tBefore + 7))
	BridgeFlush(0)
	tAfter = BridgeResolvePath(0, "gGame.Cash")
	if tAfter <> tBefore + 7 then
		put "FAIL loopback -- gGame.Cash is" && tAfter && "after a CMD set of" && (tBefore + 7)
		return 0
	end if
	gGame.Cash = tBefore
	BridgeFeed(0, "REQ" & tab & "9002" & tab & "get" & tab & "gGame.Cash")
	tReply = BridgeReply(0, 9002)
	if tReply = VOID then
		put "FAIL loopback -- no RSP for a get"
		return 0
	end if
	BridgeFeed(0, "REQ" & tab & "9003" & tab & "get" & tab & "gGame.UPStatistics.money")
	if BridgeReply(0, 9003)[#bridgeError] <> "denied" then
		put "FAIL loopback -- a read outside `expose` was not refused"
		return 0
	end if
	BridgeStore(0, "selfTest", "b:1")
	if BridgeGet(0, "bridge.selfTest") <> "b:1" then
		put "FAIL loopback -- the store did not round trip"
		return 0
	end if
	gBridge.store.deleteProp("selfTest")
	-- and the restart rule (PROTOCOL.md 4, 8): a Godot that is re-run greets again with its frame
	-- counter back at 1, which is *lower* than whatever we last applied. Reading that as "stale" is
	-- what makes a movie deaf after the other side restarts, so a greeting from behind us re-arms.
	tSaveSeq = gBridge.inSeq
	gBridge.inSeq = tSaveSeq + 100
	BridgeFeed(0, "HELLO" & tab & "godot" & tab & "selftest" & tab & "1" & tab & "1" & tab & "snap,sub,event")
	BridgeFeed(0, "SNAP" & tab & "2" & tab & "2" & tab & "0" & tab & "900" & tab & "gGame.Cash=i:" & (tBefore + 11))
	-- a missing mirror key reads as VOID, and VOID <> a number is true, so this covers "nothing
	-- arrived" and "something stale arrived" with one branch
	tMirrored = gBridge.mirror["gGame.Cash"]
	if tMirrored <> tBefore + 11 then
		put "FAIL loopback -- a restarted peer's snapshot was discarded as stale (inSeq " & gBridge.inSeq & ", mirror " & string(tMirrored) & ")"
		gBridge.inSeq = tSaveSeq
		return 0
	end if
	-- the re-arm must not have cost us the dedupe: the same snapshot seq again is still one frame
	BridgeFeed(0, "SNAP" & tab & "2" & tab & "3" & tab & "0" & tab & "900" & tab & "gGame.Cash=i:" & (tBefore + 12))
	if gBridge.mirror["gGame.Cash"] <> tBefore + 11 then
		put "FAIL loopback -- a repeated snapshot seq was applied twice after the re-arm"
		gBridge.inSeq = tSaveSeq
		return 0
	end if
	gBridge.mirror.deleteProp("gGame.Cash")
	gBridge.inSeq = tSaveSeq
	put "BRIDGE LOOPBACK: pass (write, read, denial, store, restart)"
	return 1
end
