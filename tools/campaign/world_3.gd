extends RefCounted
## World 3, Abandoned Ruins: communication becomes essential. Orc shieldbearers block from the
## front (one knight draws the shield, the other strikes from behind, or break the guard with a
## charged slash), hollow archers shoot at chest height (crouch, jump or cut the arrow), saw
## blades run along the floors, synchronised and ordered strikes, plates on separate floors,
## parallel routes that open each other's doors, and the Orc Warchief at the end.

const WORLD := {"id": "ruins", "title": "Abandoned Ruins", "theme": "ruins", "music": "ruins",
	"dir": "world_03_abandoned_ruins"}


static func levels() -> Array:
	return [l09(), l10(), l11(), l12()]


## Sunken Gatehouse: the first shieldbearer in the courtyard, a spring to a ledge outside the
## gatehouse tower (a cracked wall into a hidden room), saws in the tunnel under the tower (jump
## the floor blade, time the falling one), a courtyard with an archer on the battlement and a
## gate that opens when one knight on the battlement and one below strike their targets
## together, then a guarded hall that locks until its defenders fall.
static func l09() -> Dictionary:
	return {"id": "l09", "title": "Sunken Gatehouse", "world": "ruins", "width": 120, "height": 48,
		"difficulty": 5, "minutes": 4.5, "layout": 2, "spawn": [3, 40], "ops": [
		["fill", 0, 0, 0, 47], ["fill", 119, 0, 119, 47],
		["ground", 1, 24, 40],
		["clue", 6, 40, "Strike where\nthe shield is not."],
		["enemy", "guard", 16, 40, -3, 3],
		["ground", 28, 82, 40],
		["spring", 36, 40], ["ledge", 33, 39, 34],
		["fill", 41, 12, 56, 33],
		["crack", "TowerWall", 41, 31, 1, 2], ["clear", 42, 30, 47, 32],
		["coins", 5, 44, 33], ["fruit", "red", 2, 46, 33],
		["saw", 44, 39, 8, 0], ["saw", 53, 34, 0, 5, {"start_phase": 0.5}],
		["save", 58, 40],
		["fill", 60, 30, 66, 31], ["ladder", 59, 30, 40],
		["enemy", "archer", 65, 30, -1, 0],
		["clue", 62, 40, "Strike as one."],
		["target", "Upper", 61, 30], ["target", "Lower", 74, 40],
		["logic", "Sync", ["Upper", "Lower"], 2, {"window": 2.0, "latch": true, "distinct_players": true}],
		["enemy", "guard", 69, 40, -2, 2], ["enemy", "grunt", 77, 40, -2, 2],
		["fill", 82, 0, 82, 35],
		["gate", "CourtGate", 82, 40, 4, "Sync", 1],
		["ground", 83, 118, 38],
		["fill", 89, 10, 111, 30],
		["arena", "GuardHall", 91, 31, 109, 37],
		["gate", "HallIn", 89, 38, 7, "GuardHall", 0], ["gate", "HallOut", 111, 38, 7, "GuardHall", 0],
		["enemy", "guard", 96, 38, -3, 3], ["enemy", "archer", 106, 38, 0, 0], ["slime", "p", 100, 38, -3, 3],
		["fruit", "green", 2, 86, 38],
		["exit", 115, 38],
	]}


## Hall of Echoes: three targets in the order the sign gives (a shieldbearer watches), a pit
## whose plate holds a gate while a saw runs the pit floor, a bridge held from a balcony
## (archers wait on the far side), a timed door between two switches. Optional: a balcony
## ledge (coins, purple fruit) and the yellow jar past the bridge.
static func l10() -> Dictionary:
	return {"id": "l10", "title": "Hall of Echoes", "world": "ruins", "width": 180, "height": 40,
		"difficulty": 6, "minutes": 5.0, "layout": 2, "spawn": [3, 32], "ops": [
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
		["enemy", "guard", 38, 32, -3, 3],
		["save", 50, 32],
		["clue", 55, 32, "The guard sleeps\nfor no one."],
		["plate", "PitPlate", 66, 36],
		["saw", 61, 35, 12, 0],
		["slime", "p", 70, 36, -4, 4],
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
		["enemy", "archer", 140, 32, -2, 2], ["enemy", "guard", 146, 32, -3, 3], ["enemy", "grunt", 151, 32, -3, 3],
		["tile", 135, 31],
		["clue", 154, 32, "The door forgets\nquickly."],
		["switch", "SwA", 156, 32, {"mode": 1, "active_time": 0.4}],
		["switch", "SwB", 165, 32, {"mode": 1, "active_time": 0.4}],
		["logic", "TLogic", ["SwA", "SwB"], 1],
		["gate", "TGate", 160, 32, 4, "TLogic", 2, {"open_time": 3.0, "warning_time": 1.0}],
		["enemy", "archer", 170, 32, 0, 0],
		["exit", 173, 32],
	]}


## Twin Sanctums: the knights split at the first ladder. The upper knight walks the temple
## roof (saws, a shieldbearer, an archer), the lower one the crypt beneath (orcs, an archer);
## each route's switches open the other's doors in three stages (a held plate below keeps a
## roof door open until the roof latch). The routes join at the far end. Optional: a roof
## ledge above a power tile (coins, green fruit).
static func l11() -> Dictionary:
	return {"id": "l11", "title": "Twin Sanctums", "world": "ruins", "width": 170, "height": 44,
		"difficulty": 6, "minutes": 5.0, "layout": 2, "spawn": [3, 36], "ops": [
		["fill", 0, 0, 0, 43], ["fill", 169, 0, 169, 43], ["ground", 1, 168, 36],
		["fill", 21, 16, 150, 30], ["ladder", 20, 16, 36],
		["fill", 80, 1, 80, 11], ["fill", 110, 1, 110, 11],
		["clear", 86, 16, 90, 17], ["ledge", 66, 69, 12],
		["clue", 6, 36, "Two roads.\nEach opens the other."],
		["switch", "SwitchU1", 40, 16, {"mode": 2}],
		["gate", "GL1", 50, 36, 5, "SwitchU1", 1],
		["switch", "SwitchL1", 70, 36, {"mode": 2}],
		["gate", "GU1", 80, 16, 4, "SwitchL1", 1],
		["spikes", 30, 31, 16], ["enemy", "guard", 55, 16, -4, 4], ["saw", 44, 15, 6, 0],
		["tile", 66, 15], ["coins", 5, 67, 12], ["fruit", "green", 3, 69, 12],
		["spikes", 86, 90, 18],
		["timed", "TA", 87, 16, 2, {"active_time": 2.2, "disabled_time": 1.4}],
		["enemy", "archer", 104, 16, -2, 2],
		["enemy", "grunt", 40, 36, -5, 5], ["slime", "g", 64, 36, -4, 3], ["spikes", 75, 76, 36],
		["tile", 100, 35],
		["plate", "PlateL2", 95, 36],
		["switch", "SwitchU2", 115, 16, {"mode": 2}],
		["logic", "L2", ["PlateL2", "SwitchU2"], 1],
		["gate", "GU2", 110, 16, 4, "L2", 0],
		["gate", "GL2", 125, 36, 5, "SwitchU2", 1],
		["enemy", "guard", 132, 16, -5, 5], ["enemy", "archer", 142, 36, -2, 2],
		["save", 153, 36], ["fruit", "yellow", 2, 157, 36],
		["exit", 164, 36],
	]}


## The Gilded Seal: the World 3 finale. A great chamber whose seal gate needs three locks: twin
## targets struck together, two plates stepped on within moments of each other (a shieldbearer
## guards the pit), three switches in the order the sign tells. Beyond the seal waits the Orc
## Warchief: the hall locks until it falls. Optional: a red jar above the right gallery.
static func l12() -> Dictionary:
	return {"id": "l12", "title": "The Gilded Seal", "world": "ruins", "width": 230, "height": 46,
		"difficulty": 7, "minutes": 7.0, "layout": 2, "spawn": [3, 40], "ops": [
		["fill", 0, 0, 0, 45], ["fill", 229, 0, 229, 45], ["ground", 1, 228, 40],
		["fill", 30, 28, 60, 29], ["ladder", 29, 28, 40],
		["clear", 75, 40, 105, 43], ["ladder", 76, 40, 44], ["ladder", 104, 40, 44],
		["fill", 120, 26, 158, 27], ["clear", 117, 40, 119, 40],
		["ledge", 140, 143, 22], ["fill", 165, 1, 165, 33],
		["clue", 6, 40, "Three locks.\nOne seal."],
		["save", 22, 40],
		["clue", 32, 40, "Strike as one."],
		["target", "TA1", 35, 28], ["target", "TA2", 55, 28],
		["logic", "LockA", ["TA1", "TA2"], 2, {"window": 2.0, "latch": true, "distinct_players": true}],
		["enemy", "grunt", 45, 40, -6, 6], ["enemy", "archer", 66, 40, -2, 2],
		["clue", 72, 40, "Two stones that\ncount together."],
		["plate", "PB1", 78, 44, {"mode": 2, "active_time": 1.5}],
		["plate", "PB2", 101, 44, {"mode": 2, "active_time": 1.5}],
		["logic", "LockB", ["PB1", "PB2"], 0, {"distinct_players": true, "latch": true}],
		["enemy", "guard", 90, 44, -6, 6],
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
		["save", 161, 40],
		["gate", "SealGate", 165, 40, 6, "FinalLock", 1],
		["fill", 166, 1, 224, 30],
		["clue", 170, 40, "The Warchief\nholds the hall."],
		["arena", "WarHall", 170, 31, 220, 39],
		["gate", "HallIn", 168, 40, 9, "WarHall", 0], ["gate", "HallOut", 222, 40, 9, "WarHall", 0],
		["enemy", "warchief", 200, 40, 0, 0],
		["exit", 225, 40],
	]}
