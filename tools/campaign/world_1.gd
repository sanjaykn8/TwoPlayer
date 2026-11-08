extends RefCounted
## World 1, Ancient Forest: teaches the game through its levels. Walking and jumping, green
## slimes, the first orc grunts (read the wind-up, step back, punish), spring mushrooms up to
## the canopy, cracked blocks that only a charged slash breaks, the co-op lift and plates, and
## an arena ambush at the end. Secrets reward the charged slash and the stack boost.
## Op format: tools/campaign/campaign_builder.gd. Rows grow downwards; floor row = surface.

const WORLD := {"id": "forest", "title": "Ancient Forest", "theme": "forest", "music": "forest",
	"dir": "world_01_ancient_forest"}


static func levels() -> Array:
	return [l01(), l02(), l03(), l04()]


## The Mossy Path: steps and a pit, the first slimes, a spring mushroom up to the canopy
## (red fruit, coins), a cracked wall that teaches the charged slash (a secret room above it
## needs a charged up-strike and a partner's boost), a plate gate, and the first orc grunt.
static func l01() -> Dictionary:
	return {"id": "l01", "title": "The Mossy Path", "world": "forest", "width": 120, "height": 36,
		"difficulty": 1, "minutes": 3.5, "layout": 2, "spawn": [3, 30], "ops": [
		["fill", 0, 0, 0, 35], ["fill", 119, 0, 119, 35],
		["ground", 1, 18, 30], ["ground", 19, 22, 29], ["ground", 23, 34, 28],
		["clue", 6, 30, "Two knights walk one road."],
		["slime", "g", 28, 28, -3, 3],
		["ground", 37, 52, 28],
		["spring", 40, 28],
		["ledge", 38, 44, 22], ["ledge", 47, 52, 20], ["ledge", 55, 59, 21],
		["coins", 3, 49, 20], ["fruit", "red", 1, 51, 20],
		["ground", 53, 84, 26],
		["slime", "g", 45, 28, -3, 4],
		["fill", 61, 10, 76, 22],
		["clue", 58, 26, "Hold the blade.\nLet it ring."],
		["crack", "CrackWall", 68, 24, 1, 2],
		["clear", 70, 18, 75, 21], ["crack", "CrackRoof", 72, 22, 2, 1],
		["coins", 5, 71, 22], ["fruit", "green", 1, 75, 22],
		["save", 80, 26],
		["ground", 85, 118, 24],
		["slime", "g", 89, 24, -3, 3],
		["clue", 92, 24, "Stone hears\nthe knight."],
		["plate", "Plate", 94, 24, {"mode": 1}],
		["fill", 99, 0, 99, 20],
		["gate", "Gate", 99, 24, 3, "Plate", 1],
		["enemy", "grunt", 106, 24, -4, 4],
		["tile", 110, 23], ["ledge", 108, 112, 20], ["coins", 3, 110, 20],
		["exit", 115, 24],
	]}


## Rootway Hollows: a ladder down from the cliff, a spring back up to a root ledge (coins), a
## lift over a pit, orc grunts, the hollow with the first two-knight lock, a cracked root wall
## hiding a cave of coins, and a ladder up to the high road.
static func l02() -> Dictionary:
	return {"id": "l02", "title": "Rootway Hollows", "world": "forest", "width": 130, "height": 44,
		"difficulty": 2, "minutes": 4.0, "layout": 2, "spawn": [3, 14], "ops": [
		["fill", 0, 0, 0, 43], ["fill", 129, 0, 129, 43],
		["ground", 1, 18, 14], ["ladder", 19, 14, 24], ["ground", 19, 36, 24],
		["clue", 5, 14, "The roots run deep."],
		["slime", "g", 27, 24, -5, 5],
		["spring", 33, 24], ["ledge", 30, 36, 18], ["coins", 4, 34, 18],
		["moving", "Lift", 37, 24, 3, {"travel": Vector2i(9, 0), "speed": 36.0}],
		["ground", 49, 64, 24],
		["enemy", "grunt", 56, 24, -5, 4],
		["ground", 65, 105, 32],
		["clue", 68, 32, "Two stones.\nTwo knights."],
		["plate", "PlateA", 72, 32], ["plate", "PlateB", 78, 32],
		["logic", "Lock", ["PlateA", "PlateB"], 0, {"distinct_players": true, "latch": true}],
		["fill", 84, 0, 84, 27],
		["gate", "Gate", 84, 32, 4, "Lock", 1],
		["slime", "g", 91, 32, -4, 4], ["spikes", 95, 96, 32],
		["enemy", "grunt", 100, 32, -3, 3],
		["ground", 106, 128, 22], ["ladder", 105, 22, 32],
		["crack", "RootWall", 106, 30, 1, 2], ["clear", 107, 29, 112, 31],
		["coins", 5, 110, 32], ["fruit", "purple", 1, 112, 32],
		["save", 108, 22],
		["fruit", "yellow", 1, 112, 22],
		["enemy", "grunt", 117, 22, -4, 4], ["slime", "g", 122, 22, -3, 2],
		["exit", 125, 22],
	]}


## Old Watchtrees: one knight holds the plate while the other rides the lift and strikes the
## switch that keeps it running. Then up the trees on branches and a spring, an orc on the
## high branch, a gliding platform between trunks, and down to the exit. Optional: a chain of
## spirit lanterns (strike down to bounce) to a ledge with the green jar.
static func l03() -> Dictionary:
	return {"id": "l03", "title": "Old Watchtrees", "world": "forest", "width": 112, "height": 56,
		"difficulty": 2, "minutes": 4.5, "layout": 2, "spawn": [3, 50], "ops": [
		["fill", 0, 0, 0, 55], ["fill", 111, 0, 111, 55],
		["ground", 1, 24, 50], ["clear", 21, 50, 23, 50],
		["clue", 5, 50, "One waits.\nOne climbs."],
		["slime", "g", 12, 50, -2, 2],
		["plate", "PlateLift", 15, 50],
		["fill", 25, 36, 28, 55],
		["switch", "SwitchTop", 26, 36, {"mode": 2}],
		["logic", "LiftLogic", ["PlateLift", "SwitchTop"], 1],
		["moving", "Lift", 21, 50, 3, {"travel": Vector2i(0, -14), "speed": 34.0, "auto_start": false}],
		["control", "Lift", "LiftLogic", 0],
		["ledge", 30, 35, 33], ["ledge", 37, 42, 30], ["spring", 41, 30],
		["ledge", 38, 46, 24], ["enemy", "grunt", 43, 24, -4, 3],
		["ledge", 49, 53, 22],
		["fill", 55, 22, 58, 55], ["save", 56, 22],
		["moving", "Glide", 59, 22, 2, {"travel": Vector2i(10, 0), "speed": 40.0}],
		["fill", 71, 20, 74, 55], ["coins", 3, 71, 20],
		["lantern", 76, 17], ["lantern", 80, 16], ["lantern", 84, 15],
		["ledge", 87, 90, 15], ["jar", "green", 89, 15],
		["clue", 73, 20, "Strike down\non the lights."],
		["ledge", 77, 81, 22], ["ledge", 84, 88, 24],
		["ground", 90, 110, 28],
		["enemy", "grunt", 96, 28, -4, 4], ["slime", "g", 101, 28, -3, 3],
		["tile", 99, 27],
		["exit", 106, 28],
	]}


## Heart of the Grove: the World 1 finale. An ambush in the clearing (the gates shut until the
## grunts and slime are beaten), a coin cave under a cracked floor (strike the earth from
## above; a ladder leads out), rafts over a pit, the split (one holds above, one runs below),
## more orcs and spikes, and the two-plate gate.
static func l04() -> Dictionary:
	return {"id": "l04", "title": "Heart of the Grove", "world": "forest", "width": 150, "height": 40,
		"difficulty": 3, "minutes": 5.0, "layout": 2, "spawn": [3, 32], "ops": [
		["fill", 0, 0, 0, 39], ["fill", 149, 0, 149, 39],
		["ground", 1, 60, 32],
		["clue", 6, 32, "The grove remembers\nevery step."],
		["fruit", "yellow", 1, 11, 32],
		["fill", 17, 0, 45, 24],
		["arena", "Clearing", 19, 25, 43, 31],
		["gate", "GateIn", 17, 32, 7, "Clearing", 0], ["gate", "GateOut", 45, 32, 7, "Clearing", 0],
		["enemy", "grunt", 29, 32, -4, 4], ["enemy", "grunt", 39, 32, -4, 3], ["slime", "g", 34, 32, -3, 3],
		["save", 49, 32],
		["clue", 53, 32, "Strike the earth\nfrom above."],
		["clear", 52, 33, 58, 35], ["crack", "Floor", 55, 32, 1, 1],
		["clear", 52, 32, 52, 32], ["ladder", 52, 32, 36],
		["coins", 5, 56, 36], ["fruit", "green", 2, 58, 36],
		["moving", "Raft1", 61, 32, 2, {"travel": Vector2i(11, 0), "speed": 38.0}],
		["ground", 75, 77, 31],
		["moving", "Raft2", 78, 31, 2, {"travel": Vector2i(10, 0), "speed": 38.0}],
		["ground", 91, 148, 31],
		["clear", 99, 29, 113, 30], ["fill", 99, 27, 113, 28],
		["clear", 98, 27, 98, 30], ["ladder", 98, 27, 31], ["fill", 113, 19, 113, 26],
		["clue", 95, 31, "Above holds.\nBelow runs."],
		["plate", "PlateUp", 104, 27],
		["switch", "SwitchFar", 116, 31, {"mode": 2}],
		["logic", "Split", ["PlateUp", "SwitchFar"], 1],
		["gate", "GateLow", 110, 31, 2, "Split", 0],
		["coins", 3, 108, 27],
		["enemy", "grunt", 122, 31, -4, 4], ["spikes", 127, 128, 31], ["tile", 125, 30],
		["slime", "g", 131, 31, -3, 2],
		["clue", 134, 31, "Two shadows\nwake the gate."],
		["plate", "PlateL", 137, 31], ["plate", "PlateR", 141, 31],
		["logic", "Final", ["PlateL", "PlateR"], 0, {"distinct_players": true, "latch": true}],
		["fill", 145, 0, 145, 27],
		["gate", "GateEnd", 145, 31, 3, "Final", 1],
		["exit", 146, 31],
	]}
