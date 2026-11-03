extends RefCounted
## World 1, Ancient Forest: teaches the game through its levels. Walking, jumping, pits,
## green slimes, spikes, ladders, one-way platforms, the first moving platforms and the first
## pressure plates; the last level combines them with simple cooperation.
## Op format: tools/campaign/campaign_builder.gd. Rows grow downwards; floor row = surface.

const WORLD := {"id": "forest", "title": "Ancient Forest", "theme": "forest", "music": "forest",
	"dir": "world_01_ancient_forest"}


static func levels() -> Array:
	return [l01(), l02(), l03(), l04()]


## The Mossy Path: walking, small steps, a pit, the first slimes, spikes, a ladder dip, a
## plate that opens a gate, a power tile. Optional: tree-top ledges (red fruit, coins), a
## ledge above the last power tile (coins).
static func l01() -> Dictionary:
	return {"id": "l01", "title": "The Mossy Path", "world": "forest", "width": 150, "height": 30,
		"difficulty": 1, "minutes": 3.5, "spawn": [3, 26], "ops": [
		["fill", 0, 0, 0, 29], ["fill", 149, 0, 149, 29],
		["ground", 1, 24, 26], ["ground", 25, 28, 25], ["ground", 29, 40, 24],
		["ground", 44, 70, 24],
		["ledge", 47, 50, 21], ["ledge", 52, 55, 18], ["ledge", 57, 60, 15],
		["ground", 71, 81, 28], ["ladder", 81, 24, 28], ["ground", 82, 148, 24],
		["spikes", 88, 89, 24],
		["clue", 6, 26, "Two knights walk one road."],
		["slime", "g", 34, 24, -4, 5],
		["fruit", "red", 1, 58, 15], ["coins", 3, 60, 15],
		["fruit", "green", 1, 76, 28], ["coins", 2, 73, 28],
		["slime", "g", 95, 24, -5, 4],
		["save", 103, 24],
		["slime", "g", 109, 24, -5, 5], ["slime", "g", 118, 24, -5, 4],
		["clue", 121, 24, "Stone hears\nthe knight."],
		["plate", "Plate", 123, 24, {"mode": 1}],
		["gate", "Gate", 128, 24, 3, "Plate", 1],
		["tile", 134, 23],
		["ledge", 136, 139, 20], ["coins", 4, 138, 20],
		["exit", 145, 24],
	]}


## Rootway Hollows: down ladders from a cliff, the first moving platform over a pit, the first
## two-knight lock (two plates, latched gate), slimes and spikes in the hollow, a ladder back
## up to the high road. Optional: a ledge above the pit's far side (coins), yellow fruit.
static func l02() -> Dictionary:
	return {"id": "l02", "title": "Rootway Hollows", "world": "forest", "width": 160, "height": 36,
		"difficulty": 2, "minutes": 4.0, "spawn": [3, 14], "ops": [
		["fill", 0, 0, 0, 35], ["fill", 159, 0, 159, 35],
		["ground", 1, 20, 14], ["ladder", 21, 14, 22], ["ground", 21, 40, 22],
		["moving", "Lift", 42, 22, 3, {"travel": Vector2i(12, 0), "speed": 36.0}],
		["ground", 58, 75, 22], ["tile", 62, 21], ["ledge", 64, 67, 18],
		["ledge", 76, 79, 25], ["ground", 80, 123, 28], ["fill", 124, 18, 124, 35],
		["ladder", 123, 18, 28], ["ground", 125, 158, 18],
		["clue", 5, 14, "The roots run deep."],
		["slime", "g", 30, 22, -6, 6],
		["coins", 5, 66, 18], ["fruit", "yellow", 1, 72, 22],
		["save", 82, 28],
		["clue", 84, 28, "Two stones.\nTwo knights."],
		["plate", "PlateA", 86, 28], ["plate", "PlateB", 92, 28],
		["logic", "Lock", ["PlateA", "PlateB"], 0, {"distinct_players": true, "latch": true}],
		["gate", "Gate", 97, 28, 4, "Lock", 1],
		["slime", "g", 104, 28, -4, 4], ["spikes", 108, 109, 28],
		["slime", "g", 114, 28, -3, 5], ["tile", 118, 27],
		["fruit", "green", 1, 121, 28],
		["slime", "g", 136, 18, -6, 6], ["save", 128, 18],
		["exit", 154, 18],
	]}


## Old Watchtrees: a lift that only runs while a plate is held. One knight holds, the other
## rides up and strikes the switch on the trunk, which keeps the lift running for the holder.
## Then the canopy: branches, a gliding platform over a spike floor, a second trunk, stairs to
## the high exit. Optional: the forest floor (green fruit, coins, ladder back), a high branch
## with purple fruit.
static func l03() -> Dictionary:
	return {"id": "l03", "title": "Old Watchtrees", "world": "forest", "width": 150, "height": 40,
		"difficulty": 2, "minutes": 4.5, "spawn": [3, 34], "ops": [
		["fill", 0, 0, 0, 39], ["fill", 149, 0, 149, 39],
		["ground", 1, 40, 34], ["clear", 37, 34, 39, 34], ["fill", 41, 22, 44, 39],
		["ledge", 45, 60, 22], ["ground", 45, 100, 34], ["ledge", 61, 72, 22], ["ladder", 62, 22, 34],
		["ledge", 87, 100, 22], ["ladder", 99, 22, 34], ["fill", 101, 22, 104, 39],
		["ledge", 106, 110, 19], ["ledge", 112, 116, 16], ["ground", 117, 148, 16],
		["ledge", 128, 131, 12],
		["clue", 5, 34, "One waits.\nOne climbs."],
		["slime", "g", 18, 34, -6, 6], ["spikes", 26, 27, 34],
		["plate", "PlateLift", 31, 34],
		["switch", "SwitchTop", 43, 22, {"mode": 2}],
		["logic", "LiftLogic", ["PlateLift", "SwitchTop"], 1],
		["moving", "Lift", 37, 34, 3, {"travel": Vector2i(0, -12), "speed": 34.0, "auto_start": false}],
		["control", "Lift", "LiftLogic", 0],
		["slime", "g", 52, 22, -5, 5],
		["moving", "Glide", 73, 22, 2, {"travel": Vector2i(11, 0), "speed": 40.0}],
		["spikes", 74, 86, 34],
		["fruit", "green", 2, 92, 34], ["coins", 4, 96, 34], ["slime", "g", 55, 34, -6, 6],
		["save", 90, 22],
		["slime", "g", 125, 16, -6, 6], ["tile", 130, 15], ["fruit", "purple", 1, 129, 12],
		["slime", "g", 138, 16, -5, 5],
		["exit", 145, 16],
	]}


## Heart of the Grove: a slime-guarded clearing (a hidden cave under its one-way floor holds
## a green jar), a two-platform crossing, the first split: one knight holds the plate on the
## upper walkway while the other passes the lower gate and strikes the switch that keeps it
## open. Spikes, a power tile, and a two-plate gate before the exit.
static func l04() -> Dictionary:
	return {"id": "l04", "title": "Heart of the Grove", "world": "forest", "width": 170, "height": 34,
		"difficulty": 3, "minutes": 5.0, "spawn": [3, 28], "ops": [
		["fill", 0, 0, 0, 33], ["fill", 169, 0, 169, 33],
		["ground", 1, 60, 28], ["clear", 44, 28, 52, 31], ["ledge", 45, 48, 28],
		["fill", 44, 28, 44, 28], ["fill", 49, 28, 51, 28], ["ladder", 52, 28, 32],
		["moving", "Raft1", 61, 28, 2, {"travel": Vector2i(11, 0), "speed": 38.0}],
		["ground", 75, 77, 27],
		["moving", "Raft2", 78, 27, 2, {"travel": Vector2i(10, 0), "speed": 38.0}],
		["ground", 91, 168, 27], ["clear", 99, 25, 113, 26], ["fill", 99, 23, 113, 24],
		["clear", 98, 23, 98, 26], ["ladder", 98, 23, 27], ["fill", 113, 15, 113, 22],
		["clue", 5, 28, "The grove remembers\nevery step."],
		["fruit", "yellow", 1, 16, 28],
		["slime", "g", 28, 28, -5, 5], ["slime", "g", 38, 28, -5, 4], ["slime", "g", 56, 28, -3, 3],
		["jar", "green", 50, 32], ["coins", 3, 46, 32],
		["save", 93, 27],
		["clue", 96, 27, "Above holds.\nBelow runs."],
		["plate", "PlateUp", 104, 23],
		["switch", "SwitchFar", 116, 27, {"mode": 2}],
		["logic", "Split", ["PlateUp", "SwitchFar"], 1],
		["gate", "GateLow", 110, 27, 2, "Split", 0],
		["coins", 3, 108, 23],
		["slime", "g", 124, 27, -5, 5], ["spikes", 131, 132, 27], ["spikes", 137, 138, 27],
		["tile", 142, 26],
		["clue", 145, 27, "Two shadows\nwake the gate."],
		["plate", "PlateL", 148, 27], ["plate", "PlateR", 154, 27],
		["logic", "Final", ["PlateL", "PlateR"], 0, {"distinct_players": true, "latch": true}],
		["gate", "GateEnd", 160, 27, 3, "Final", 1],
		["exit", 164, 27],
	]}
