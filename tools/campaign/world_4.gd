extends RefCounted
## World 4, Lava Kingdom: lava kills instantly (and so ends the run), so every lava crossing
## has a fair, readable way over it. Ember slimes light their fuse near a knight and explode
## (lure them into brutes and cracked walls), fire jets breathe on a rhythm (watch the
## sputter), hot ground, collapsing and blinking stones, orc brutes, hot-air vents that lift
## knights, and the second optional boss (Magma Heart, level 15).

const WORLD := {"id": "lava", "title": "Lava Kingdom", "theme": "lava", "music": "lava",
	"dir": "world_04_lava_kingdom"}


static func levels() -> Array:
	return [l13(), l14(), l15(), l16()]


## Ashen Steps: two-tile lava pits, a hot-ground strip, crumbling stones over a lava pool, a
## plate beside burning ground that holds a gate until the runner latches it, and two moving
## platforms over a lava river. Optional: a ledge above the crumbling stones (green jar).
static func l13() -> Dictionary:
	return {"id": "l13", "layout": 2, "title": "Ashen Steps", "world": "lava", "width": 170, "height": 36,
		"difficulty": 6, "minutes": 4.5, "spawn": [3, 30], "ops": [
		["fill", 0, 0, 0, 35], ["fill", 169, 0, 169, 35], ["ground", 1, 168, 30],
		["lava", 20, 21, 30], ["hot", 30, 32, 30],
		["lava", 60, 71, 30, 2], ["ledge", 63, 66, 26],
		["fill", 90, 1, 90, 26], ["hot", 86, 88, 30],
		["lava", 100, 111, 30, 2], ["ground", 112, 113, 29], ["lava", 114, 125, 30, 2],
		["clue", 6, 30, "Red stone sleeps.\nRed water does not."],
		["fire", 26, 30, 3], ["fire", 36, 30, 3, {"start_offset": 1.2}],
		["enemy", "ember", 44, 30, -4, 4], ["enemy", "grunt", 52, 30, -5, 5],
		["crack", "AshWall", 58, 27, 1, 3], ["fill", 57, 22, 59, 26],
		["clear", 56, 27, 56, 29], ["clue", 54, 30, "Fire opens
what steel cannot."],
		["collapse", "C1", 61, 29, 2], ["collapse", "C2", 65, 29, 2], ["collapse", "C3", 69, 29, 2],
		["jar", "green", 64, 26],
		["save", 75, 30],
		["clue", 80, 30, "What burns below\nalso opens above."],
		["plate", "HoldPlate", 84, 30],
		["switch", "LatchSw", 95, 30, {"mode": 2}],
		["logic", "HoldLogic", ["HoldPlate", "LatchSw"], 1],
		["gate", "HoldGate", 90, 30, 4, "HoldLogic", 0],
		["moving", "M1", 100, 29, 3, {"travel": Vector2i(8, 0), "speed": 34.0}],
		["moving", "M2", 115, 29, 3, {"travel": Vector2i(8, 0), "speed": 34.0, "start_delay": 1.0}],
		["enemy", "ember", 132, 30, -5, 5], ["tile", 137, 29], ["enemy", "brute", 145, 30, -5, 5],
		["fire", 155, 30, 2], ["fire", 158, 30, 2, {"start_offset": 0.9}],
		["fruit", "green", 2, 150, 30],
		["exit", 164, 30],
	]}


## Cinder Bridges: one-way bridges above a lava sea. Slimes and spikes on the bridge; a gate
## held from a rock shelf below (latched past the gate); a long run of blinking stones (a
## ledge above them holds purple fruit); solid ground and the exit beyond.
static func l14() -> Dictionary:
	return {"id": "l14", "layout": 2, "title": "Cinder Bridges", "world": "lava", "width": 180, "height": 44,
		"difficulty": 7, "minutes": 5.0, "spawn": [3, 30], "ops": [
		["fill", 0, 0, 0, 43], ["fill", 179, 0, 179, 43],
		["ground", 1, 19, 30], ["ground", 20, 160, 40], ["lava", 20, 160, 40, 2], ["ground", 161, 178, 30],
		["ledge", 20, 60, 30], ["ledge", 64, 100, 30], ["ground", 70, 80, 36], ["ladder", 72, 30, 36],
		["fill", 90, 1, 90, 26], ["ledge", 113, 116, 25], ["ledge", 131, 160, 30],
		["clue", 6, 30, "Walk the thread.\nDo not look down."],
		["enemy", "ember", 35, 30, -6, 6], ["spikes", 45, 46, 30], ["enemy", "brute", 54, 30, -4, 4],
		["fire", 40, 30, 2],
		["save", 66, 30],
		["clue", 74, 30, "One below holds\nthe way above."],
		["plate", "ShelfPlate", 76, 36],
		["switch", "BridgeLatch", 95, 30, {"mode": 2}],
		["logic", "ShelfLogic", ["ShelfPlate", "BridgeLatch"], 1],
		["gate", "BridgeGate", 90, 30, 4, "ShelfLogic", 0],
		["blink", "B1", 103, 28, 2, {"active_time": 2.4, "disabled_time": 1.2, "start_offset": 1.8}],
		["blink", "B2", 107, 28, 2, {"active_time": 2.4, "disabled_time": 1.2, "start_offset": 1.5}],
		["blink", "B3", 111, 28, 2, {"active_time": 2.4, "disabled_time": 1.2, "start_offset": 1.2}],
		["blink", "B4", 115, 28, 2, {"active_time": 2.4, "disabled_time": 1.2, "start_offset": 0.9}],
		["blink", "B5", 119, 28, 2, {"active_time": 2.4, "disabled_time": 1.2, "start_offset": 0.6}],
		["blink", "B6", 123, 28, 2, {"active_time": 2.4, "disabled_time": 1.2, "start_offset": 0.3}],
		["blink", "B7", 127, 28, 2, {"active_time": 2.4, "disabled_time": 1.2}],
		["fruit", "purple", 3, 114, 25], ["coins", 4, 116, 25],
		["enemy", "guard", 140, 30, -6, 6], ["enemy", "ember", 152, 30, -5, 5],
		["fire", 146, 30, 2, {"start_offset": 0.5}],
		["save", 163, 30], ["enemy", "grunt", 168, 30, -4, 4],
		["exit", 174, 30],
	]}


## Forge of Embers: hot-ground strips, crumbling stones over a lava trench, a forge corridor
## of slimes under the boss hall. Optional: the Magma Heart above (ladder up); defeating it
## opens its reward niche (green jar). Then a lava pool crossed by a platform that only runs
## while a knight stands on the island plate (latched from the far side).
static func l15() -> Dictionary:
	return {"id": "l15", "layout": 2, "title": "Forge of Embers", "world": "lava", "width": 190, "height": 40,
		"difficulty": 7, "minutes": 5.5, "spawn": [3, 34], "ops": [
		["fill", 0, 0, 0, 39], ["fill", 189, 0, 189, 39], ["ground", 1, 188, 34],
		["hot", 15, 17, 34], ["hot", 24, 26, 34], ["hot", 33, 35, 34],
		["lava", 45, 56, 34, 2],
		["fill", 65, 22, 105, 24], ["fill", 63, 10, 63, 21], ["fill", 106, 10, 106, 21], ["ladder", 64, 22, 34],
		["lava", 110, 123, 34, 2], ["ground", 124, 125, 33], ["lava", 126, 140, 34, 2],
		["hot", 150, 152, 34],
		["clue", 6, 34, "The forge-heart\nsleeps above."],
		["enemy", "ember", 20, 34, -3, 3], ["enemy", "grunt", 29, 34, -3, 3],
		["collapse", "C1", 46, 33, 2], ["collapse", "C2", 50, 33, 2], ["collapse", "C3", 54, 33, 2],
		["save", 60, 34],
		["seal", "MagmaSeal"],
		["boss", "boss_magma_heart", 84, 22, -18, 13, "MagmaSeal"],
		["gate", "RewardGate", 100, 22, 3, "MagmaSeal", 1],
		["jar", "green", 103, 22], ["coins", 6, 102, 22],
		["enemy", "brute", 75, 34, -6, 6], ["spikes", 82, 83, 34], ["enemy", "ember", 92, 34, -5, 4], ["tile", 97, 33],
		["fire", 70, 34, 2], ["fire", 87, 34, 2, {"start_offset": 1.0}], ["fire", 100, 34, 2, {"start_offset": 0.4}],
		["moving", "M1", 110, 33, 3, {"travel": Vector2i(10, 0), "speed": 36.0}],
		["clue", 120, 34, "Stand where the\nfire parts."],
		["plate", "IslandPlate", 124, 33],
		["moving", "M2", 126, 33, 3, {"travel": Vector2i(10, 0), "speed": 36.0, "auto_start": false}],
		["switch", "FarLatch", 144, 34, {"mode": 2}],
		["logic", "IslandLogic", ["IslandPlate", "FarLatch"], 1],
		["control", "M2", "IslandLogic", 0],
		["save", 146, 34],
		["enemy", "ember", 158, 34, -5, 5], ["slime", "p", 166, 34, -5, 5],
		["fruit", "yellow", 3, 170, 34],
		["exit", 184, 34],
	]}


## Heart of the Mountain: the World 4 finale. Hot ground and slimes, a lava lake crossed on
## crumbling stones to a rock pillar whose plate runs the ferry (latched on the far shore), a
## forge hall of burning floors, a long blinking-stone crossing with a rest pillar, and a lift
## up to the summit exit. Optional: a ledge above the pillar (red fruit, coins).
static func l16() -> Dictionary:
	return {"id": "l16", "layout": 2, "title": "Heart of the Mountain", "world": "lava", "width": 170, "height": 44,
		"difficulty": 8, "minutes": 6.0, "spawn": [3, 38], "ops": [
		["fill", 0, 0, 0, 43], ["fill", 169, 0, 169, 43], ["ground", 1, 168, 38],
		["hot", 12, 14, 38], ["hot", 25, 27, 38],
		["lava", 41, 53, 38, 2], ["ground", 54, 55, 36], ["lava", 56, 79, 38, 2], ["ledge", 54, 58, 33],
		["hot", 90, 93, 38], ["hot", 100, 103, 38],
		["lava", 121, 136, 38, 2], ["ground", 137, 138, 36], ["lava", 139, 145, 38, 2],
		["ground", 153, 168, 24], ["clear", 149, 38, 151, 38],
		["clue", 5, 38, "The mountain's\nheart beats twice."],
		["enemy", "ember", 20, 38, -4, 4], ["enemy", "grunt", 32, 38, -5, 5],
		["fire", 16, 38, 2], ["fire", 29, 38, 2, {"start_offset": 1.1}],
		["collapse", "C1", 42, 37, 2], ["collapse", "C2", 46, 37, 2], ["collapse", "C3", 50, 37, 2],
		["plate", "RelayA", 54, 36],
		["moving", "Ferry", 57, 37, 3, {"travel": Vector2i(18, 0), "speed": 40.0, "auto_start": false}],
		["switch", "FarA", 83, 38, {"mode": 2}],
		["logic", "RelayLogic", ["RelayA", "FarA"], 1],
		["control", "Ferry", "RelayLogic", 0],
		["fruit", "red", 3, 57, 33], ["coins", 4, 55, 33],
		["save", 82, 38], ["fruit", "yellow", 2, 86, 38],
		["fill", 87, 26, 113, 31],
		["arena", "Forge", 89, 32, 111, 37],
		["gate", "ForgeIn", 87, 38, 6, "Forge", 0], ["gate", "ForgeOut", 113, 38, 6, "Forge", 0],
		["enemy", "brute", 100, 38, -6, 6], ["enemy", "ember", 94, 38, -2, 2], ["enemy", "ember", 106, 38, -2, 2],
		["tile", 96, 37],
		["fruit", "green", 2, 118, 38],
		["blink", "B1", 122, 37, 2, {"active_time": 2.4, "disabled_time": 1.2, "start_offset": 1.8}],
		["blink", "B2", 126, 37, 2, {"active_time": 2.4, "disabled_time": 1.2, "start_offset": 1.2}],
		["blink", "B3", 130, 37, 2, {"active_time": 2.4, "disabled_time": 1.2, "start_offset": 0.6}],
		["blink", "B4", 134, 37, 2, {"active_time": 2.4, "disabled_time": 1.2}],
		["blink", "B5", 140, 37, 2, {"active_time": 2.4, "disabled_time": 1.2, "start_offset": 0.8}],
		["blink", "B6", 143, 37, 2, {"active_time": 2.4, "disabled_time": 1.2}],
		["save", 147, 38],
		["moving", "SummitLift", 149, 38, 3, {"travel": Vector2i(0, -14), "speed": 36.0}],
		["updraft", 116, 24, 116, 34], ["ledge", 112, 115, 24], ["coins", 5, 113, 24],
		["clue", 115, 38, "Hot air rises."],
		["slime", "p", 160, 24, -5, 5],
		["exit", 164, 24],
	]}
