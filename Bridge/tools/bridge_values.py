"""Shared sample corpus for the bridge: used to generate ``test/vectors.json`` and to drive
both the Python codec selftest and the Godot selftest against one set of expectations.

Values here are drawn from Burnin' Rubber 4's real data (``Director Movie File (.dcr)/Globals.txt``,
``[M] Main.ls``), so the vectors exercise the shapes the game actually produces -- symbols like
``#Racing``, ``#propList`` payloads, points/vectors from the 3D models, and the game's TAB idiom.
"""

from bridge_proto import Batch, Color, Point, Rect, Symbol, Vector, VOID, encode_kv, lingo_prints

#: ``(note, python value)`` -- one per wire type in PROTOCOL.md §2, plus edge cases.
SAMPLES = [
    ("zero", 0),
    ("negative int", -4213),
    ("int64 max", 9223372036854775807),
    ("float", 1.5),
    ("negative float", -0.03125),
    ("integral float", 2.0),
    ("tiny float", 1e-06),
    ("large float", 1.7976931348623157e308),
    ("string", "Bullet350"),
    ("string with spaces", "Burnin Rubber 4"),
    ("empty string", ""),
    ("string with dot", "1.0"),
    ("string that looks typed", "i:12"),
    ("true", True),
    ("false", False),
    ("void", VOID),
    ("none", None),
    ("symbol", Symbol("#Racing")),
    ("symbol underscore", Symbol("#update_KeyInput")),
    ("point", Point(12, -0.5)),
    ("vector", Vector(0.0001, 0.0001, -1.0)),
    ("color", Color(255, 128, 0)),
    ("color alpha", Color(10, 20, 30, 128)),
    ("rect", Rect(0, 0, 800, 450)),
    ("list of ints", [1, 2, 3]),
    ("list of strings", ["Tank", "Taxi", "Rebel"]),
    ("nested list", [[1, 2], [3, 4]]),
    ("proplist", {"mass": 1200.5, "wheels": [1, 2, 3]}),
    ("proplist mixed", {"name": "Bullet350", "ok": True, "nil": VOID, "sym": Symbol("#Racing")}),
    ("proplist nested list", {"states": [Symbol("#update_keyInput"), Symbol("#update_Waypoints")]}),
    ("empty list", []),
    ("tab flattened", "a\tb"),
    ("lf flattened", "line1\nline2"),
    ("crlf flattened", "a\r\nb"),
    ("unicode", "Größe Ünicode 42"),
    ("quoted string", 'He said "no"'),
]

#: ``(note, raw line)`` -- exactly what ``bridge_proto.build`` emits, checked for round-trip.
MESSAGE_SAMPLES = [
    ("hello", "HELLO\tgodot\tBR4-Demo\t1\t7\twrite,eval,snap,sub,event"),
    ("hello bare caps", "HELLO\tdirector\tBurnin Rubber 4\t1\t3\t"),
    ("bye", "BYE\tquit"),
    ("ping", "PING\t11\t99123"),
    ("pong", "PONG\t11\t99124"),
    ("log", "LOG\tinfo\tbridge ready"),
    ("log warn fields", "LOG\twarn\ttransport files: reconnecting\tattempt=3"),
    ("snap empty", "SNAP\t12\t214\t99123\t213\t"),
    ("snap scalars", "SNAP\t12\t214\t99123\t213\tgGame.Cash=i:1000;gGame.kmh=f:187.5;gGame.Vehicle=y:Car"),
    (
        "delta nested",
        "DELTA\t13\t215\t99154\t214\tgGame.vehicles[1].general.pos=v:1,2,3;bridge.mode=b:1",
    ),
    ("event", "EVT\t14\tGodotCommand\tkind=s:boost;amount=f:1.5"),
    ("req get", "REQ\t12\tget\tgGame.Vehicle"),
    ("req gets", "REQ\t13\tgets\tgGame.Cash;gGame.Money"),
    ("req set", "REQ\t14\tset\tgGame.Cash=i:999999"),
    ("req sets", "REQ\t15\tsets\tgGame.Cash=i:99;bridge.tick=i:1"),
    ("req call", 'REQ\t16\tcall\tPutMessage\t\t[#text: "hi", #type: #alert]'),
    ("req eval", "REQ\t17\teval\tgGame.resolution[1] * 2"),
    ("rsp value", "RSP\t12\tget\tok\tgGame.Vehicle\ty:Car"),
    ("rsp void", "RSP\t13\tget\tok\tgGame.Missing\tn"),
    ("rsp err denied", "RSP\t14\tset\terr\tdenied\tgGame.nope"),
    ("rsp err timeout", "RSP\t15\teval\terr\ttimeout\t"),
    ("cmd one way", "CMD\t18\tsets\tgGame.Cash=i:99;bridge.mode=y:autopilot"),
    ("cmd snap on", "CMD\t19\tsnap\tb:1\t2\tdelta"),
    ("trailing empty", "PING\t20\t"),
]

#: A realistic full-game snapshot (what a 40-key Burnin' Rubber tick looks like on the wire).
SNAPSHOT_PAIRS = [
    ("gGame.name", "Burnin Rubber 4"),
    ("gGame.version", 2.2),
    ("gGame.Scene", Symbol("#World")),
    ("gGame.World", Symbol("#City")),
    ("gGame.Track", Symbol("#OperationSandStorm1")),
    ("gGame.RaceState", Symbol("#Racing")),
    ("gGame.Cash", 1000),
    ("gGame.Money", 50000),
    ("gGame.AI", 4),
    ("gGame.AIsBuild", 2),
    ("gGame.PlayersBuild", 1),
    ("gGame.pause", 0),
    ("gGame.Input", 1),
    ("gGame.tempo", 32.0),
    ("gGame.resolution", [800, 450]),
    ("gGame.stageSize", Point(800, 450)),
    ("gGame.Bloom", 1),
    ("gGame.BloomSize", 0.0625),
    ("gGame.Lightmaps", 1),
    ("gGame.worldscale", 1.0),
    ("gGame.TimeMP", 1.0),
    ("gGame.Iteration", 3),
    ("gGame.frameRate", Symbol("#limit")),
    ("gGame.CurrentVehicle.kmh", 187.5),
    ("gGame.CurrentVehicle.general.pos", Vector(1523.25, -88.5, 4.0)),
    ("gGame.CurrentVehicle.general.rot", Vector(0.0, 0.0, 1.7309)),
    ("gGame.CurrentVehicle.general.health", 78.5),
    ("gGame.CurrentVehicle.general.nitro", 0.25),
    ("gGame.CurrentVehicle.Input.forward", 1),
    ("gGame.CurrentVehicle.Input.brake", 0),
    ("gGame.CurrentVehicle.Input.left", 0),
    ("gGame.CurrentVehicle.Input.right", 1),
    ("gGame.CurrentVehicle.wheelSpin", 42.75),
    ("gGame.interface.kmh", Point(700, 400)),
    ("gGame.MiniMap.rotation", 1.5708),
    ("gGame.traffic.count", 26),
    ("gGame.CheckPoints.done", 4),
    ("gGame.CheckPoints.total", 9),
    ("gGame.Weapons.primary", Symbol("#MachineGun")),
    ("gGame.Weapons.secondary", Symbol("#RocketPod")),
    ("gGame.Weapons.ammo", [120, 24]),
]


def snapshot_line(seq: int = 1, frame: int = 1, tms: int = 0, ack: int = 0) -> str:
    from bridge_proto import build

    return build("SNAP", [seq, frame, tms, ack, encode_kv(SNAPSHOT_PAIRS)])


def snapshot_batch() -> Batch:
    batch = Batch()
    batch.add_line(snapshot_line())
    return batch


__all__ = ["SAMPLES", "MESSAGE_SAMPLES", "SNAPSHOT_PAIRS", "snapshot_line", "snapshot_batch", "lingo_prints"]
