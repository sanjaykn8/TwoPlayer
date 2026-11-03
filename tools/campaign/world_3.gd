extends RefCounted
## World 3, Abandoned Ruins: communication becomes essential. Timed gates, synchronised
## strikes, ordered strikes, plates on separate floors, a guarded plate, a bridge held from a
## balcony, two parallel routes that open each other's doors, and a final multi-lock seal.

const WORLD := {"id": "ruins", "title": "Abandoned Ruins", "theme": "ruins", "music": "ruins",
	"dir": "world_03_abandoned_ruins"}


static func levels() -> Array:
	return [l09(), l10(), l11(), l12()]


## Sunken Gatehouse: a target opens a timed gate too far away for the striker to reach in time
## (a switch past the gate reopens it); twin targets that must be struck together; plates on
## the colonnade and in the crypt below, pressed at once. Optional: a colonnade ledge (red
## fruit, coins), crypt coins.
static func l09() -> Dictionary:
	return {"id": "l09", "title": "Sunken Gatehouse", "world": "ruins", "width": 170, "height": 36,
		"difficulty": 5, "minutes": 4.5, "spawn": [3, 30], "ops": [
		["fill", 0, 0, 0, 35], ["fill", 169, 0, 169, 35], ["ground", 1, 168, 30],
		["fill", 56, 1, 56, 25], ["fill", 100, 1, 100, 25],
		["fill", 106, 20, 138, 22], ["ledge", 104, 105, 20], ["ladder", 104, 20, 30],
		["ledge", 112, 115, 17], ["fill", 147, 1, 147, 26],
		["clue", 6, 30, "The old doors\nstill listen."],
		["slime", "g", 22, 30, -5, 5],
		["clue", 30, 30, "One strikes.\nOne runs."],
		["target", "StrikeA", 36, 30, {"mode": 1, "active_time": 0.4}],
		["switch", "FarSwitch", 61, 30, {"mode": 1, "active_time": 0.4}],
		["logic", "GateLogic", ["StrikeA", "FarSwitch"], 1],
		["gate", "TimedGate", 56, 30, 4, "GateLogic", 2, {"open_time": 2.6, "warning_time": 0.8}],
		["save", 64, 30], ["jar", "yellow", 67, 30],
		["slime", "p", 72, 30, -6, 6], ["tile", 77, 29], ["slime", "g", 81, 30, -3, 3],
		["clue", 88, 30, "Strike as one."],
		["target", "TargetL", 84, 30], ["target", "TargetR", 96, 30],
		["logic", "Sync", ["TargetL", "TargetR"], 2, {"window": 2.0, "latch": true, "distinct_players": true}],
		["gate", "SyncGate", 100, 30, 4, "Sync", 1],
		["clue", 102, 30, "Above and below,\nat once."],
		["fruit", "red", 2, 113, 17], ["coins", 3, 115, 17],
		["plate", "PlateUp", 124, 20], ["plate", "PlateDown", 124, 30],
		["logic", "Both", ["PlateUp", "PlateDown"], 0, {"distinct_players": true, "latch": true}],
		["gate", "CryptGate", 147, 30, 3, "Both", 1],
		["slime", "g", 132, 30, -4, 4], ["coins", 4, 142, 30],
		["fruit", "green", 2, 151, 30], ["slime", "p", 157, 30, -5, 5],
		["exit", 164, 30],
	]}


## Hall of Echoes: three targets struck in an order the sign gives; a plate in a pit guarded
## by a purple slime (lure it, stagger it, or endure it) holds a gate open until the runner
## latches it; a bridge that extends only while a balcony plate is held, latched from the far
## side; a dense slime hall after a yellow jar; a quick timed gate. Optional: a ledge above
## the chasm (coins, purple fruit).
static func l10() -> Dictionary:
	return {"id": "l10", "title": "Hall of Echoes", "world": "ruins", "width": 180, "height": 40,
		"difficulty": 6, "minutes": 5.0, "spawn": [3, 32], "ops": [
		["fill", 0, 0, 0, 39], ["fill", 179, 0, 179, 39],
		["ground", 1, 59, 32], ["ground", 60, 75, 36], ["ground", 76, 99, 32], ["ground", 121, 178, 32],
		["fill", 44, 1, 44, 27], ["fill", 88, 1, 88, 27], ["fill", 160, 1, 160, 27],
		["ladder", 75, 32, 36], ["ledge", 92, 98, 24], ["ladder", 93, 24, 32], ["ledge", 100, 103, 21],
		["clue", 10, 32, "Left, right,\nthen the heart."],
		["target", "TL", 18, 32, {"mode": 1, "active_time": 0.4}],
		["target", "TM", 25, 32, {"mode": 1, "active_time": 0.4}],
		["target", "TR", 32, 32, {"mode": 1, "active_time": 0.4}],
		["logic", "Seq", ["TL", "TR", "TM"], 3, {"latch": true, "window": 5.0}],
		["gate", "SeqGate", 44, 32, 4, "Seq", 1],
		["slime", "g", 38, 32, -3, 3],
		["save", 50, 32],
		["clue", 55, 32, "The guard sleeps\nfor no one."],
		["plate", "PitPlate", 66, 36],
		["slime", "p", 70, 36, -8, 4],
		["switch", "FarSwitch", 92, 32, {"mode": 2}],
		["logic", "PitLogic", ["PitPlate", "FarSwitch"], 1],
		["gate", "PitGate", 88, 32, 4, "PitLogic", 0],
		["plate", "BridgePlate", 95, 24],
		["moving", "Bridge", 100, 32, 3, {"travel": Vector2i(17, 0), "speed": 45.0, "auto_start": false}],
		["switch", "BridgeLatch", 124, 32, {"mode": 2}],
		["logic", "BridgeLogic", ["BridgePlate", "BridgeLatch"], 1],
		["control", "Bridge", "BridgeLogic", 1],
		["coins", 4, 101, 21], ["fruit", "purple", 2, 103, 21],
		["jar", "yellow", 128, 32],
		["slime", "p", 134, 32, -4, 4], ["slime", "g", 142, 32, -4, 4], ["slime", "p", 150, 32, -4, 4],
		["tile", 146, 31],
		["clue", 154, 32, "The door forgets\nquickly."],
		["switch", "SwA", 156, 32, {"mode": 1, "active_time": 0.4}],
		["switch", "SwB", 165, 32, {"mode": 1, "active_time": 0.4}],
		["logic", "TLogic", ["SwA", "SwB"], 1],
		["gate", "TGate", 160, 32, 4, "TLogic", 2, {"open_time": 3.0, "warning_time": 1.0}],
		["exit", 173, 32],
	]}


## Twin Sanctums: the knights split at the first ladder. The upper knight walks the temple
## roof, the lower one the crypt corridor beneath, and each route's switches open the other's
## doors in three stages (a held plate below keeps a roof door open until the roof latch).
## Spikes, a spiked trench crossed on timed steps, slimes in both routes; the routes join at
## the far end. Optional: a roof ledge above a power tile (coins, green fruit).
static func l11() -> Dictionary:
	return {"id": "l11", "title": "Twin Sanctums", "world": "ruins", "width": 170, "height": 44,
		"difficulty": 6, "minutes": 5.0, "spawn": [3, 36], "ops": [
		["fill", 0, 0, 0, 43], ["fill", 169, 0, 169, 43], ["ground", 1, 168, 36],
		["fill", 21, 16, 150, 30], ["ladder", 20, 16, 36],
		["fill", 80, 1, 80, 11], ["fill", 110, 1, 110, 11],
		["clear", 86, 16, 90, 17], ["ledge", 66, 69, 12],
		["clue", 6, 36, "Two roads.\nEach opens the other."],
		["switch", "SwitchU1", 40, 16, {"mode": 2}],
		["gate", "GL1", 50, 36, 5, "SwitchU1", 1],
		["switch", "SwitchL1", 70, 36, {"mode": 2}],
		["gate", "GU1", 80, 16, 4, "SwitchL1", 1],
		["spikes", 30, 31, 16], ["slime", "g", 55, 16, -5, 5], ["spikes", 60, 62, 16],
		["tile", 66, 15], ["coins", 5, 67, 12], ["fruit", "green", 3, 69, 12],
		["spikes", 86, 90, 18],
		["timed", "TA", 87, 16, 2, {"active_time": 2.2, "disabled_time": 1.4}],
		["slime", "p", 100, 16, -6, 6],
		["slime", "p", 40, 36, -5, 5], ["slime", "g", 64, 36, -4, 3], ["spikes", 75, 76, 36],
		["tile", 100, 35],
		["plate", "PlateL2", 95, 36],
		["switch", "SwitchU2", 115, 16, {"mode": 2}],
		["logic", "L2", ["PlateL2", "SwitchU2"], 1],
		["gate", "GU2", 110, 16, 4, "L2", 0],
		["gate", "GL2", 125, 36, 5, "SwitchU2", 1],
		["slime", "g", 132, 16, -6, 6], ["slime", "p", 135, 36, -5, 5],
		["save", 153, 36], ["fruit", "yellow", 2, 157, 36],
		["exit", 164, 36],
	]}


## The Gilded Seal: the World 3 finale, a great chamber whose final gate needs three locks.
## Left gallery: twin targets struck together. Centre pit (guarded by a purple slime): two
## plates that only count when stepped on within moments of each other. Right gallery (a
## lift): three switches in the order the sign tells. Optional: a red jar above the right
## gallery, reached from a power tile.
static func l12() -> Dictionary:
	return {"id": "l12", "title": "The Gilded Seal", "world": "ruins", "width": 190, "height": 46,
		"difficulty": 7, "minutes": 6.0, "spawn": [3, 40], "ops": [
		["fill", 0, 0, 0, 45], ["fill", 189, 0, 189, 45], ["ground", 1, 188, 40],
		["fill", 30, 28, 60, 29], ["ladder", 29, 28, 40],
		["clear", 75, 40, 105, 43], ["ladder", 76, 40, 44], ["ladder", 104, 40, 44],
		["fill", 120, 26, 158, 27], ["clear", 117, 40, 119, 40],
		["ledge", 140, 143, 22], ["fill", 165, 1, 165, 33],
		["clue", 6, 40, "Three locks.\nOne seal."],
		["save", 22, 40],
		["clue", 32, 40, "Strike as one."],
		["target", "TA1", 35, 28], ["target", "TA2", 55, 28],
		["logic", "LockA", ["TA1", "TA2"], 2, {"window": 2.0, "latch": true, "distinct_players": true}],
		["slime", "g", 45, 40, -6, 6], ["slime", "p", 65, 40, -5, 5],
		["clue", 72, 40, "Two stones that\ncount together."],
		["plate", "PB1", 78, 44, {"mode": 2, "active_time": 1.5}],
		["plate", "PB2", 101, 44, {"mode": 2, "active_time": 1.5}],
		["logic", "LockB", ["PB1", "PB2"], 0, {"distinct_players": true, "latch": true}],
		["slime", "p", 90, 44, -8, 8],
		["save", 109, 40],
		["moving", "GalleryLift", 117, 40, 3, {"travel": Vector2i(0, -14), "speed": 38.0}],
		["clue", 124, 26, "First, last,\nthen between."],
		["switch", "S1", 126, 26, {"mode": 1, "active_time": 0.4}],
		["switch", "S3", 137, 26, {"mode": 1, "active_time": 0.4}],
		["switch", "S2", 150, 26, {"mode": 1, "active_time": 0.4}],
		["logic", "LockC", ["S1", "S2", "S3"], 3, {"latch": true, "window": 5.0}],
		["slime", "p", 132, 26, -4, 3],
		["tile", 145, 25], ["jar", "red", 141, 22],
		["logic", "FinalLock", ["LockA", "LockB", "LockC"], 0, {"latch": true}],
		["gate", "SealGate", 165, 40, 6, "FinalLock", 1],
		["slime", "p", 175, 40, -6, 6],
		["exit", 183, 40],
	]}
