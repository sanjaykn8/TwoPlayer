extends RefCounted
## World 6, Final Citadel: the hardest combinations of everything taught before, with no new
## rules. Precise platforming on bridges and spires, mixed slime packs, timed gates, several
## hazards at once, multi-stage locks, hidden rewards, the third optional boss (Citadel
## Warden, level 23), and the campaign's end at the Dawn Gate (level 24).

const WORLD := {"id": "citadel", "title": "Final Citadel", "theme": "citadel", "music": "citadel",
	"dir": "world_06_final_citadel"}


static func levels() -> Array:
	return [l21(), l22(), l23(), l24()]


## Frost Causeway: a broken bridge over a spiked chasm with slimes on it (ladders lead out of
## the chasm), a quick timed gate with a switch on each side, crumbling stones over a lava
## moat, and a second chasm crossed on alternating blinking and solid stones. Optional: a high
## ledge above the second chasm (red fruit), a yellow jar.
static func l21() -> Dictionary:
	return {"id": "l21", "title": "Frost Causeway", "world": "citadel", "width": 190, "height": 46,
		"difficulty": 8, "minutes": 5.5, "spawn": [3, 34], "ops": [
		["fill", 0, 0, 0, 45], ["fill", 189, 0, 189, 45],
		["ground", 1, 25, 34], ["ground", 26, 60, 42], ["ground", 61, 119, 34], ["ground", 120, 160, 42], ["ground", 161, 188, 34],
		["ledge", 26, 35, 34], ["ledge", 39, 48, 34], ["ledge", 52, 60, 34],
		["ladder", 27, 34, 42], ["ladder", 59, 34, 42],
		["fill", 80, 1, 80, 29], ["lava", 91, 110, 34, 2],
		["ladder", 120, 34, 42], ["ladder", 160, 34, 42],
		["ledge", 126, 127, 34], ["ledge", 134, 135, 34], ["ledge", 142, 143, 34], ["ledge", 150, 151, 34], ["ledge", 158, 159, 34],
		["ledge", 141, 144, 31],
		["clue", 6, 34, "Cold stone, thin road.\nWalk it together."],
		["spikes", 28, 58, 42],
		["slime", "p", 31, 34, -4, 4], ["slime", "g", 44, 34, -4, 4], ["slime", "p", 56, 34, -3, 3],
		["save", 63, 34], ["jar", "yellow", 66, 34],
		["clue", 68, 34, "Quick feet.\nQuicker friends."],
		["switch", "SwA", 72, 34, {"mode": 1, "active_time": 0.4}],
		["switch", "SwB", 85, 34, {"mode": 1, "active_time": 0.4}],
		["logic", "QuickLogic", ["SwA", "SwB"], 1],
		["gate", "QuickGate", 80, 34, 5, "QuickLogic", 2, {"open_time": 2.4, "warning_time": 0.8}],
		["collapse", "C1", 92, 33, 2], ["collapse", "C2", 96, 33, 2], ["collapse", "C3", 100, 33, 2],
		["collapse", "C4", 104, 33, 2], ["collapse", "C5", 107, 33, 2],
		["save", 113, 34],
		["spikes", 121, 159, 42],
		["blink", "B1", 122, 34, 2, {"active_time": 2.2, "disabled_time": 1.3}],
		["blink", "B2", 130, 34, 2, {"active_time": 2.2, "disabled_time": 1.3, "start_offset": 0.7}],
		["blink", "B3", 138, 34, 2, {"active_time": 2.2, "disabled_time": 1.3, "start_offset": 1.4}],
		["blink", "B4", 146, 34, 2, {"active_time": 2.2, "disabled_time": 1.3}],
		["blink", "B5", 154, 34, 2, {"active_time": 2.2, "disabled_time": 1.3, "start_offset": 0.7}],
		["fruit", "red", 3, 141, 31], ["coins", 4, 144, 31],
		["slime", "p", 170, 34, -5, 5], ["slime", "p", 178, 34, -3, 3],
		["exit", 184, 34],
	]}


## Spire of Silence: a tall climb. Crumbling stones from a power tile; a lift run by a plate
## on the first landing (latched at the second); a blinking staircase; at the top a door that
## only opens when one knight strikes the summit target and the other the target far below,
## together. Falls land on the spire floor (partly spiked) to climb again. Optional: a side
## climb to a green jar.
static func l22() -> Dictionary:
	return {"id": "l22", "title": "Spire of Silence", "world": "citadel", "width": 120, "height": 70,
		"difficulty": 9, "minutes": 5.5, "spawn": [4, 66], "ops": [
		["fill", 0, 0, 0, 69], ["fill", 119, 0, 119, 69], ["ground", 1, 118, 66],
		["ledge", 30, 36, 62], ["ledge", 47, 55, 50],
		["ledge", 59, 75, 34], ["ledge", 55, 62, 19], ["ledge", 38, 54, 10], ["ladder", 55, 10, 19],
		["fill", 50, 1, 50, 6], ["ledge", 77, 81, 31], ["ledge", 82, 86, 28],
		["clue", 8, 66, "The silent road\nis the longer road."],
		["tile", 28, 65], ["spikes", 38, 46, 66],
		["collapse", "C1", 38, 59, 2], ["collapse", "C2", 41, 56, 2], ["collapse", "C3", 44, 53, 2],
		["slime", "g", 52, 50, -4, 3],
		["plate", "LandingPlate", 48, 50],
		["moving", "SpireLift", 56, 50, 3, {"travel": Vector2i(0, -16), "speed": 38.0, "auto_start": false}],
		["switch", "LiftLatch", 62, 34, {"mode": 2}],
		["logic", "LiftLogic", ["LandingPlate", "LiftLatch"], 1],
		["control", "SpireLift", "LiftLogic", 0],
		["slime", "p", 68, 34, -4, 4],
		["save", 60, 34],
		["blink", "S1", 73, 31, 2, {"active_time": 2.4, "disabled_time": 1.2}],
		["blink", "S2", 70, 28, 2, {"active_time": 2.4, "disabled_time": 1.2, "start_offset": 0.6}],
		["blink", "S3", 67, 25, 2, {"active_time": 2.4, "disabled_time": 1.2, "start_offset": 1.2}],
		["blink", "S4", 64, 22, 2, {"active_time": 2.4, "disabled_time": 1.2, "start_offset": 1.8}],
		["jar", "green", 85, 28], ["coins", 4, 79, 31],
		["clue", 47, 10, "One above, one below.\nStrike as one."],
		["target", "TopTarget", 52, 10], ["target", "LowTarget", 72, 34],
		["logic", "SpireSync", ["TopTarget", "LowTarget"], 2, {"window": 2.0, "latch": true, "distinct_players": true}],
		["gate", "SummitGate", 50, 10, 3, "SpireSync", 1],
		["slime", "p", 46, 10, -5, 2],
		["exit", 41, 10],
	]}


## Warden's Vault: a gauntlet of mixed slimes and burning floor, a plate-held door latched
## beyond it, three switches on high galleries struck low, low, then high; a crumbling crossing
## over lava. Optional: the Citadel Warden in the vault below (drop through the cracked floor;
## its armour yields only to strikes from both knights together); its niche holds a blue jar.
static func l23() -> Dictionary:
	return {"id": "l23", "title": "Warden's Vault", "world": "citadel", "width": 200, "height": 50,
		"difficulty": 9, "minutes": 6.0, "spawn": [3, 36], "ops": [
		["fill", 0, 0, 0, 49], ["fill", 199, 0, 199, 49], ["ground", 1, 198, 36],
		["hot", 32, 34, 36], ["fill", 54, 1, 54, 30], ["fill", 100, 1, 100, 29],
		["ledge", 62, 72, 30], ["ladder", 62, 30, 36], ["ledge", 72, 82, 26], ["ladder", 72, 26, 30], ["ledge", 86, 94, 30],
		["clear", 105, 37, 150, 47], ["clear", 110, 36, 113, 36], ["ledge", 110, 113, 36],
		["clear", 148, 36, 148, 36], ["ladder", 148, 36, 48],
		["lava", 160, 175, 36, 2],
		["clue", 6, 36, "The warden counts\nevery blow."],
		["slime", "g", 18, 36, -5, 5], ["slime", "p", 26, 36, -4, 4], ["save", 40, 36],
		["plate", "DoorPlate", 46, 36],
		["switch", "DoorLatch", 60, 36, {"mode": 2}],
		["logic", "DoorLogic", ["DoorPlate", "DoorLatch"], 1],
		["gate", "VaultDoor", 54, 36, 6, "DoorLogic", 0],
		["clue", 64, 36, "Low, low,\nthen high."],
		["switch", "Q1", 66, 30, {"mode": 1, "active_time": 0.4}],
		["switch", "Q2", 78, 26, {"mode": 1, "active_time": 0.4}],
		["switch", "Q3", 90, 30, {"mode": 1, "active_time": 0.4}],
		["logic", "Gallery", ["Q1", "Q3", "Q2"], 3, {"latch": true, "window": 6.0}],
		["gate", "GalleryGate", 100, 36, 7, "Gallery", 1],
		["slime", "p", 80, 36, -6, 6],
		["save", 103, 36],
		["clue", 108, 36, "Beneath, the warden.\nOnly two hands as one\nbreak his armour."],
		["seal", "WardenSeal"],
		["boss", "boss_citadel_warden", 128, 48, -18, 18, "WardenSeal"],
		["gate", "RewardGate", 108, 48, 3, "WardenSeal", 1],
		["jar", "blue", 106, 48], ["coins", 8, 105, 48],
		["slime", "p", 120, 36, -6, 6], ["slime", "g", 140, 36, -5, 5],
		["save", 156, 36],
		["collapse", "C1", 161, 35, 2], ["collapse", "C2", 165, 35, 2], ["collapse", "C3", 169, 35, 2], ["collapse", "C4", 173, 35, 2],
		["slime", "p", 182, 36, -4, 4], ["slime", "g", 188, 36, -3, 3],
		["exit", 194, 36],
	]}


## Crown of Dawn: the end of the campaign. A gauntlet of spikes, burning floor and slimes; a
## lava river crossed on crumbling stones and a ferry run from a pillar plate (latched on the
## far bank); the battlements and the vaults beneath, each opening the other's doors in two
## stages; and the Dawn Gate, sealed three ways: twin targets, two stones stepped together and
## three switches in order. Beyond it, the exit on the dais. Optional: a ledge above the
## battlements (green fruit, coins).
static func l24() -> Dictionary:
	return {"id": "l24", "title": "Crown of Dawn", "world": "citadel", "width": 230, "height": 50,
		"difficulty": 10, "minutes": 7.0, "spawn": [3, 44], "ops": [
		["fill", 0, 0, 0, 49], ["fill", 229, 0, 229, 49], ["ground", 1, 228, 44],
		["hot", 26, 28, 44],
		["lava", 46, 57, 44, 2], ["ground", 58, 59, 43], ["lava", 60, 80, 44, 2],
		["fill", 95, 26, 165, 38], ["ladder", 94, 26, 44], ["ledge", 100, 103, 23],
		["fill", 120, 1, 120, 21], ["fill", 150, 1, 150, 21],
		["clear", 130, 26, 136, 27],
		["fill", 206, 1, 206, 36], ["ground", 210, 228, 42],
		["clue", 6, 44, "Here the long road ends.\nWalk it as two."],
		["spikes", 14, 15, 44], ["slime", "p", 20, 44, -4, 4], ["slime", "g", 34, 44, -5, 5],
		["save", 40, 44],
		["collapse", "C1", 47, 43, 2], ["collapse", "C2", 51, 43, 2], ["collapse", "C3", 55, 43, 2],
		["plate", "RelayP", 58, 43],
		["moving", "Ferry", 61, 43, 3, {"travel": Vector2i(16, 0), "speed": 40.0, "auto_start": false}],
		["switch", "FerryLatch", 86, 44, {"mode": 2}],
		["logic", "FerryLogic", ["RelayP", "FerryLatch"], 1],
		["control", "Ferry", "FerryLogic", 0],
		["save", 88, 44],
		["clue", 91, 44, "Two roads.\nEach opens the other."],
		["switch", "SwU1", 105, 26, {"mode": 2}],
		["gate", "GL1", 110, 44, 5, "SwU1", 1],
		["switch", "SwL1", 115, 44, {"mode": 2}],
		["gate", "GU1", 120, 26, 4, "SwL1", 1],
		["fruit", "green", 3, 101, 23], ["coins", 5, 103, 23],
		["slime", "p", 112, 26, -4, 4],
		["spikes", 130, 136, 28],
		["blink", "U1", 131, 26, 2, {"active_time": 2.2, "disabled_time": 1.3}],
		["blink", "U2", 134, 26, 2, {"active_time": 2.2, "disabled_time": 1.3, "start_offset": 1.0}],
		["plate", "PL2", 125, 44],
		["switch", "SwU2", 155, 26, {"mode": 2}],
		["logic", "L2", ["PL2", "SwU2"], 1],
		["gate", "GU2", 150, 26, 4, "L2", 0],
		["gate", "GL2", 140, 44, 5, "SwU2", 1],
		["slime", "g", 160, 26, -4, 4],
		["slime", "p", 102, 44, -5, 5], ["slime", "p", 132, 44, -5, 5], ["spikes", 136, 137, 44], ["tile", 146, 43],
		["save", 168, 44],
		["clue", 170, 44, "Strike as one. Step as one.\nThen low to high."],
		["target", "TA", 172, 44], ["target", "TB", 186, 44],
		["logic", "SyncLock", ["TA", "TB"], 2, {"window": 2.0, "latch": true, "distinct_players": true}],
		["plate", "StepA", 176, 44, {"mode": 2, "active_time": 1.2}],
		["plate", "StepB", 180, 44, {"mode": 2, "active_time": 1.2}],
		["logic", "StepLock", ["StepA", "StepB"], 0, {"latch": true, "distinct_players": true}],
		["switch", "Q1", 190, 44, {"mode": 1, "active_time": 0.4}],
		["switch", "Q2", 196, 44, {"mode": 1, "active_time": 0.4}],
		["switch", "Q3", 202, 44, {"mode": 1, "active_time": 0.4}],
		["logic", "SeqLock", ["Q1", "Q2", "Q3"], 3, {"latch": true, "window": 5.0}],
		["logic", "DawnSeal", ["SyncLock", "StepLock", "SeqLock"], 0, {"latch": true}],
		["gate", "DawnGate", 206, 44, 7, "DawnSeal", 1],
		["clue", 213, 42, "Dawn waits\nfor two."],
		["exit", 221, 42],
	]}
