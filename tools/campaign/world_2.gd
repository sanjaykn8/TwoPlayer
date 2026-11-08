extends RefCounted
## World 2, Underground Caves: darkness (each knight carries a light; torches mark the way),
## cave bats that swoop from the ceiling, loose rocks that shake before they fall, updrafts
## that carry knights up shafts, purple slimes, the first orc brutes and their shockwaves,
## hidden crystal rooms, and the first optional boss (Brood Mother, level 7).

const WORLD := {"id": "caves", "title": "Underground Caves", "theme": "caves", "music": "caves",
	"dir": "world_02_underground_caves"}


static func levels() -> Array:
	return [l05(), l06(), l07(), l08()]


## Crystal Descent: a dark descent down shelves. A bat over the first steps, rocks over a
## spike gap, a cracked crystal wall hiding a room (purple fruit, coins), a drop shaft into the
## lowest chamber, and an updraft chimney above it (jump into the wind) to a crystal room with
## the yellow jar; a side shaft leads back down.
static func l05() -> Dictionary:
	return {"id": "l05", "title": "Crystal Descent", "world": "caves", "width": 110, "height": 50,
		"difficulty": 3, "minutes": 4.5, "layout": 2, "spawn": [3, 10], "ops": [
		["fill", 0, 0, 0, 49], ["fill", 109, 0, 109, 49], ["fill", 1, 0, 108, 3],
		["dark"],
		["ground", 1, 16, 10], ["torch", 9, 7],
		["clue", 5, 10, "Light is short.\nThe dark is long."],
		["ground", 17, 26, 14], ["ground", 27, 36, 18],
		["enemy", "bat", 22, 4, 0, 0], ["slime", "p", 31, 18, -3, 4], ["torch", 28, 15],
		["ground", 37, 60, 24], ["torch", 40, 21],
		["fill", 46, 4, 56, 16], ["rock", 49, 17], ["rock", 53, 17],
		["spikes", 43, 44, 24],
		["enemy", "grunt", 57, 24, -3, 2],
		["ground", 61, 80, 32],
		["crack", "CrystalWall", 60, 30, 1, 2], ["clear", 54, 29, 59, 31],
		["coins", 5, 56, 32], ["fruit", "purple", 2, 58, 32],
		["fill", 64, 4, 80, 25],
		["enemy", "bat", 70, 26, 0, 0], ["slime", "p", 66, 32, -3, 4], ["torch", 63, 29],
		["ground", 81, 108, 44], ["fill", 84, 4, 108, 36],
		["save", 83, 44], ["torch", 86, 41],
		["spikes", 89, 89, 44],
		["enemy", "grunt", 93, 44, -2, 4],
		["clear", 100, 30, 101, 36], ["updraft", 100, 30, 101, 40],
		["clear", 95, 26, 103, 29], ["clear", 96, 30, 96, 36],
		["jar", "yellow", 102, 30], ["coins", 4, 98, 30], ["torch", 99, 26],
		["slime", "p", 104, 44, -1, 1],
		["exit", 106, 44],
	]}


## Echoing Shafts: up through the caves on the wind. An updraft to the first shelf (a bat
## under its roof), the blinking bridge (stones vanish behind you), a second updraft to the
## high shelf under loose rocks and an orc, timed stones to the plateau. Optional: a spring
## at the end of the middle shelf up to a pocket (power tile, coins).
static func l06() -> Dictionary:
	return {"id": "l06", "title": "Echoing Shafts", "world": "caves", "width": 100, "height": 64,
		"difficulty": 4, "minutes": 4.5, "layout": 2, "spawn": [3, 58], "ops": [
		["fill", 0, 0, 0, 63], ["fill", 99, 0, 99, 63], ["fill", 1, 0, 98, 3],
		["ground", 1, 36, 58],
		["clue", 5, 58, "The wind remembers\nthe way up."],
		["slime", "p", 12, 58, -2, 3],
		["updraft", 16, 40, 17, 55],
		["fill", 19, 42, 30, 43], ["fill", 18, 28, 32, 29],
		["enemy", "bat", 25, 30, 0, 0], ["slime", "p", 27, 42, -3, 3],
		["blink", "BridgeA", 31, 42, 2, {"active_time": 2.2, "disabled_time": 1.4, "start_offset": 1.2}],
		["blink", "BridgeB", 34, 42, 2, {"active_time": 2.2, "disabled_time": 1.4, "start_offset": 0.6}],
		["blink", "BridgeC", 37, 42, 2, {"active_time": 2.2, "disabled_time": 1.4}],
		["fill", 40, 42, 55, 43],
		["updraft", 50, 24, 51, 39],
		["spring", 55, 42], ["ledge", 53, 58, 36], ["coins", 4, 54, 36], ["tile", 57, 35],
		["fill", 53, 24, 66, 25], ["fill", 45, 4, 75, 14],
		["rock", 58, 15], ["rock", 62, 15],
		["enemy", "grunt", 60, 24, -4, 4],
		["timed", "StepA", 68, 22, 2, {"active_time": 2.5, "warning_time": 0.8, "disabled_time": 1.6, "start_offset": 1.4}],
		["timed", "StepB", 72, 20, 2, {"active_time": 2.5, "warning_time": 0.8, "disabled_time": 1.6}],
		["ground", 76, 98, 18], ["fill", 76, 4, 98, 9],
		["save", 78, 18],
		["slime", "p", 86, 18, -4, 4],
		["enemy", "bat", 90, 10, 0, 0, {"detection_radius_override": 130.0}],
		["fruit", "green", 2, 92, 18],
		["exit", 95, 18],
	]}


## Brood Caverns: a dark cavern of slimes, orcs and bats under hanging rock, a ferry over the
## gap, loose rock, timed steps to a ledge of coins, and the brood below: an optional fight
## with the Brood Mother (her treasure: the red jar). The way out is an arena: the first orc
## brute and its shockwaves, with a grunt and a purple slime, before the gates open.
static func l07() -> Dictionary:
	return {"id": "l07", "title": "Brood Caverns", "world": "caves", "width": 180, "height": 44,
		"difficulty": 4, "minutes": 5.0, "layout": 2, "spawn": [3, 24], "ops": [
		["fill", 0, 0, 0, 43], ["fill", 179, 0, 179, 43], ["fill", 1, 0, 178, 6],
		["dark"],
		["fill", 20, 7, 23, 13], ["fill", 48, 7, 52, 15], ["fill", 96, 7, 99, 14], ["fill", 140, 7, 143, 12],
		["ground", 1, 60, 24],
		["moving", "Ferry", 61, 24, 3, {"travel": Vector2i(13, 0), "speed": 36.0}],
		["fill", 61, 7, 78, 19],
		["ground", 78, 178, 24],
		["clear", 92, 25, 140, 35], ["clear", 100, 24, 104, 24], ["ledge", 100, 104, 24],
		["clear", 138, 24, 138, 24], ["ladder", 138, 24, 36],
		["ledge", 120, 124, 18],
		["clue", 6, 24, "Many small mouths.\nOne great hunger."],
		["torch", 8, 21], ["torch", 34, 21], ["torch", 57, 21], ["torch", 84, 21], ["torch", 110, 21],
		["torch", 134, 21], ["torch", 116, 32], ["torch", 95, 32],
		["enemy", "grunt", 16, 24, -5, 5], ["slime", "p", 30, 24, -5, 5], ["slime", "g", 40, 24, -4, 6],
		["enemy", "bat", 21, 14, 0, 0, {"detection_radius_override": 170.0}],
		["enemy", "bat", 50, 16, 0, 0, {"detection_radius_override": 170.0}],
		["fruit", "yellow", 2, 56, 24],
		["save", 82, 24],
		["slime", "p", 90, 24, -4, 4], ["spikes", 112, 113, 24], ["rock", 97, 15],
		["timed", "StepA", 118, 21, 2, {"active_time": 2.6, "disabled_time": 1.5}],
		["coins", 4, 122, 18],
		["enemy", "grunt", 130, 24, -5, 5],
		["clue", 96, 24, "Below, the mother\nkeeps her treasure."],
		["seal", "BroodSeal"],
		["boss", "boss_brood_mother", 116, 36, -14, 18, "BroodSeal"],
		["gate", "RewardGate", 96, 36, 3, "BroodSeal", 1],
		["jar", "red", 94, 36], ["coins", 6, 93, 36],
		["fruit", "green", 2, 134, 36],
		["fill", 149, 7, 171, 17], ["torch", 147, 21], ["torch", 173, 21],
		["arena", "BroodGate", 151, 18, 169, 23],
		["gate", "ArenaIn", 149, 24, 6, "BroodGate", 0], ["gate", "ArenaOut", 171, 24, 6, "BroodGate", 0],
		["enemy", "brute", 160, 24, -6, 6], ["enemy", "grunt", 166, 24, -3, 2], ["slime", "p", 155, 24, -3, 3],
		["exit", 174, 24],
	]}


## The Sunless Lift: the World 2 finale in the dark. One knight holds the floor plate so the
## other can ride to the middle shelf; the middle plate runs both lifts, so the first can ride
## to the top and latch the switch that keeps both running. Loose rock overhead, timed hops to
## high ledges (coins, red fruit), a treasure room down a crack, and at the top an arena: a
## brute, a grunt and a purple slime before the exit.
static func l08() -> Dictionary:
	return {"id": "l08", "title": "The Sunless Lift", "world": "caves", "width": 120, "height": 60,
		"difficulty": 5, "minutes": 5.5, "layout": 2, "spawn": [3, 56], "ops": [
		["fill", 0, 0, 0, 59], ["fill", 119, 0, 119, 59], ["fill", 1, 0, 118, 3],
		["dark"],
		["ground", 1, 30, 56], ["clear", 28, 56, 30, 56],
		["ground", 31, 50, 38], ["clear", 47, 38, 49, 38],
		["ground", 50, 118, 22],
		["clear", 55, 45, 68, 55], ["clear", 58, 22, 58, 44], ["ladder", 58, 22, 56],
		["ledge", 73, 77, 16], ["ledge", 79, 83, 13],
		["clue", 6, 56, "The lift remembers\nwho holds the stone."],
		["torch", 8, 53], ["torch", 24, 53], ["torch", 34, 35], ["torch", 44, 35], ["torch", 52, 19],
		["torch", 70, 19], ["torch", 62, 52],
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
		["enemy", "grunt", 40, 38, -5, 4],
		["save", 54, 22],
		["rock", 64, 4, {"drop_range": 300.0}], ["rock", 80, 4, {"drop_range": 300.0}],
		["timed", "Hop1", 70, 19, 2, {"active_time": 2.4, "disabled_time": 1.6}],
		["coins", 4, 75, 16], ["fruit", "red", 2, 81, 13],
		["fruit", "green", 2, 62, 56], ["coins", 5, 66, 56],
		["fill", 86, 4, 118, 15], ["torch", 85, 19], ["torch", 115, 19],
		["arena", "TopHall", 88, 16, 112, 21],
		["gate", "HallIn", 87, 22, 6, "TopHall", 0], ["gate", "HallOut", 113, 22, 6, "TopHall", 0],
		["enemy", "brute", 100, 22, -6, 6], ["enemy", "grunt", 94, 22, -3, 3], ["slime", "p", 107, 22, -3, 3],
		["exit", 115, 22],
	]}
