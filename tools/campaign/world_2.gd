extends RefCounted
## World 2, Underground Caves: purple slimes, rock ceilings and tunnels, vertical shafts,
## falling sections with only some safe landing spots, timed platforms, separated vertical
## routes, hidden fruit and jars, and the first optional boss (Brood Mother, level 7).

const WORLD := {"id": "caves", "title": "Underground Caves", "theme": "caves", "music": "caves",
	"dir": "world_02_underground_caves"}


static func levels() -> Array:
	return [l05(), l06(), l07(), l08()]


## Crystal Descent: a long drop down a shaft whose floor is mostly spikes (the ledges lead to
## the bare stone), stepping ledges over the second spike bed, the first purple slime, a
## tunnel with timed platforms over a pit, and a hidden pocket above the tunnel ceiling
## (green fruit, coins) reached by a ladder.
static func l05() -> Dictionary:
	return {"id": "l05", "title": "Crystal Descent", "world": "caves", "width": 124, "height": 50,
		"difficulty": 3, "minutes": 4.0, "spawn": [3, 10], "ops": [
		["fill", 0, 0, 0, 49], ["fill", 123, 0, 123, 49], ["fill", 1, 0, 122, 2],
		["ground", 1, 14, 10],
		["ledge", 15, 20, 15], ["ledge", 26, 31, 20], ["ledge", 17, 22, 25], ["ledge", 28, 33, 30],
		["ledge", 18, 23, 35], ["ledge", 27, 31, 40], ["ledge", 33, 35, 43],
		["ground", 15, 61, 46], ["fill", 41, 3, 122, 38], ["fill", 15, 3, 40, 5],
		["ground", 71, 122, 46],
		["clear", 99, 31, 110, 37], ["clear", 99, 38, 99, 38], ["ladder", 99, 38, 46],
		["clue", 5, 10, "The deep remembers\nfalling stones."],
		["clue", 12, 10, "Land where the\nstone is bare."],
		["spikes", 15, 25, 46], ["spikes", 32, 36, 46],
		["coins", 3, 29, 30],
		["slime", "g", 45, 46, -3, 6], ["slime", "p", 54, 46, -4, 5],
		["save", 59, 46],
		["timed", "StepA", 63, 46, 2, {"active_time": 2.5, "warning_time": 0.8, "disabled_time": 1.6}],
		["timed", "StepB", 67, 46, 2, {"active_time": 2.5, "warning_time": 0.8, "disabled_time": 1.6, "start_offset": 1.4}],
		["tile", 80, 45],
		["slime", "p", 86, 46, -5, 5], ["slime", "g", 93, 46, -4, 3],
		["fruit", "green", 2, 104, 38], ["coins", 4, 108, 38],
		["clue", 96, 46, "Look up\nwhere water drips."],
		["exit", 117, 46],
	]}


## Echoing Shafts: two shafts split by a rock wall. The left shaft climbs by ladders to a plate
## that runs the right shaft's lift; the rider strikes the switch at the top, which opens the
## left knight's gate and keeps the lift running. Then a gallery crossed on three blinking
## bridges over a spike pit (a ladder climbs out of it). Optional: a timed-platform staircase
## to a blue jar.
static func l06() -> Dictionary:
	return {"id": "l06", "title": "Echoing Shafts", "world": "caves", "width": 150, "height": 50,
		"difficulty": 4, "minutes": 4.5, "spawn": [4, 46], "ops": [
		["fill", 0, 0, 0, 49], ["fill", 149, 0, 149, 49], ["fill", 1, 0, 148, 9],
		["ground", 1, 64, 46], ["fill", 41, 22, 45, 45], ["clear", 50, 46, 52, 46],
		["ledge", 22, 32, 38], ["ladder", 25, 38, 46], ["ledge", 26, 39, 30], ["ladder", 30, 30, 38],
		["ledge", 22, 40, 22], ["ladder", 39, 22, 30], ["ledge", 46, 64, 22],
		["ground", 65, 84, 22], ["ground", 96, 148, 22], ["ground", 85, 95, 30],
		["clear", 85, 22, 85, 29], ["ladder", 85, 22, 30],
		["ledge", 112, 115, 17], ["ledge", 117, 120, 14],
		["clue", 7, 46, "One waits.\nOne climbs."],
		["slime", "p", 15, 46, -5, 4],
		["plate", "PlateL", 33, 30],
		["switch", "SwitchR", 62, 22, {"mode": 2}],
		["logic", "LiftLogic", ["PlateL", "SwitchR"], 1],
		["moving", "LiftR", 50, 46, 3, {"travel": Vector2i(0, -24), "speed": 40.0, "auto_start": false}],
		["control", "LiftR", "LiftLogic", 0],
		["gate", "GateL", 37, 30, 3, "SwitchR", 1],
		["save", 74, 22],
		["blink", "BridgeA", 86, 22, 2, {"active_time": 2.2, "disabled_time": 1.4}],
		["blink", "BridgeB", 89, 22, 2, {"active_time": 2.2, "disabled_time": 1.4, "start_offset": 0.8}],
		["blink", "BridgeC", 92, 22, 2, {"active_time": 2.2, "disabled_time": 1.4, "start_offset": 1.6}],
		["spikes", 87, 95, 30],
		["slime", "p", 104, 22, -5, 5], ["slime", "g", 128, 22, -6, 6],
		["timed", "Up1", 108, 19, 2, {"active_time": 2.0, "disabled_time": 1.8}],
		["jar", "blue", 119, 14], ["coins", 3, 113, 17],
		["exit", 143, 22],
	]}


## Brood Caverns: stalactite halls with slime packs, a ferry under a low ceiling, timed steps
## to a coin ledge. A cave below the main hall (drop through the cracked floor) holds the
## optional Brood Mother; defeating her opens the reward niche (red jar). A ladder leads back.
static func l07() -> Dictionary:
	return {"id": "l07", "title": "Brood Caverns", "world": "caves", "width": 180, "height": 44,
		"difficulty": 4, "minutes": 5.0, "spawn": [3, 24], "ops": [
		["fill", 0, 0, 0, 43], ["fill", 179, 0, 179, 43], ["fill", 1, 0, 178, 6],
		["fill", 20, 7, 23, 13], ["fill", 48, 7, 52, 15], ["fill", 96, 7, 99, 14], ["fill", 140, 7, 143, 12],
		["ground", 1, 60, 24],
		["moving", "Ferry", 61, 24, 3, {"travel": Vector2i(13, 0), "speed": 36.0}],
		["fill", 61, 7, 78, 19],
		["ground", 78, 178, 24],
		["clear", 92, 25, 140, 35], ["clear", 100, 24, 104, 24], ["ledge", 100, 104, 24],
		["clear", 138, 24, 138, 24], ["ladder", 138, 24, 36],
		["ledge", 120, 124, 18],
		["clue", 6, 24, "Many small mouths.\nOne great hunger."],
		["slime", "g", 16, 24, -6, 6], ["slime", "p", 30, 24, -5, 5], ["slime", "g", 40, 24, -4, 6],
		["fruit", "yellow", 2, 56, 24],
		["save", 82, 24],
		["slime", "p", 90, 24, -4, 4], ["spikes", 112, 113, 24],
		["timed", "StepA", 118, 21, 2, {"active_time": 2.6, "disabled_time": 1.5}],
		["coins", 4, 122, 18],
		["slime", "p", 132, 24, -5, 5], ["slime", "g", 150, 24, -6, 6], ["slime", "p", 160, 24, -6, 6],
		["clue", 96, 24, "Below, the mother\nkeeps her treasure."],
		["seal", "BroodSeal"],
		["boss", "boss_brood_mother", 116, 36, -14, 18, "BroodSeal"],
		["gate", "RewardGate", 96, 36, 3, "BroodSeal", 1],
		["jar", "red", 94, 36], ["coins", 6, 93, 36],
		["fruit", "green", 2, 134, 36],
		["exit", 173, 24],
	]}


## The Sunless Lift: the World 2 finale, a tall cavern climbed by two lifts. One knight holds
## the floor plate so the other can ride to the middle shelf; the middle plate runs both
## lifts, so the first knight can ride all the way up and latch the top switch, which keeps
## both lifts running for the partner. Purple slimes above; timed hops to high ledges (coins,
## red fruit); a ladder down a crack to a sealed treasure room (green fruit, coins).
static func l08() -> Dictionary:
	return {"id": "l08", "title": "The Sunless Lift", "world": "caves", "width": 120, "height": 60,
		"difficulty": 5, "minutes": 5.0, "spawn": [3, 56], "ops": [
		["fill", 0, 0, 0, 59], ["fill", 119, 0, 119, 59], ["fill", 1, 0, 118, 3],
		["ground", 1, 30, 56], ["clear", 28, 56, 30, 56],
		["ground", 31, 50, 38], ["clear", 47, 38, 49, 38],
		["ground", 50, 118, 22],
		["clear", 55, 45, 68, 55], ["clear", 58, 22, 58, 44], ["ladder", 58, 22, 56],
		["ledge", 73, 77, 16], ["ledge", 79, 83, 13],
		["clue", 6, 56, "The lift remembers\nwho holds the stone."],
		["slime", "p", 12, 56, -6, 6],
		["plate", "PlateLow", 20, 56],
		["plate", "PlateMid", 33, 38],
		["switch", "TopSwitch", 52, 22, {"mode": 2}],
		["logic", "LowLogic", ["PlateLow", "PlateMid", "TopSwitch"], 1],
		["logic", "HighLogic", ["PlateMid", "TopSwitch"], 1],
		["moving", "LiftLow", 28, 56, 3, {"travel": Vector2i(0, -18), "speed": 40.0, "auto_start": false}],
		["control", "LiftLow", "LowLogic", 0],
		["moving", "LiftHigh", 47, 38, 3, {"travel": Vector2i(0, -16), "speed": 40.0, "auto_start": false}],
		["control", "LiftHigh", "HighLogic", 0],
		["slime", "g", 40, 38, -6, 5],
		["save", 54, 22],
		["timed", "Hop1", 70, 19, 2, {"active_time": 2.4, "disabled_time": 1.6}],
		["coins", 4, 75, 16], ["fruit", "red", 2, 81, 13],
		["fruit", "green", 2, 62, 56], ["coins", 5, 66, 56],
		["slime", "p", 92, 22, -6, 6], ["slime", "p", 104, 22, -4, 6],
		["exit", 113, 22],
	]}
