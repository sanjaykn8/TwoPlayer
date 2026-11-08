extends RefCounted
## World 5, Dark Fortress: earlier mechanics combined into longer, harder sequences. Hollow
## archers on the walks and towers, shieldbearers holding doorways, saw blades over spike
## trenches and along the halls, fire jets, wind over the broken towers, locks with several
## keys and two objectives in separate places, and the Hollow Captain guarding the last door.
## Difficulty comes from combinations and positioning, never from tougher numbers.

const WORLD := {"id": "fortress", "title": "Dark Fortress", "theme": "fortress", "music": "fortress",
	"dir": "world_05_dark_fortress"}


static func levels() -> Array:
	return [l17(), l18(), l19(), l20()]


## Iron Gate Keep: a three-key gate (a held plate, a timed plate and a latch struck in time);
## a guard hall full of slimes with a catwalk above as the quiet way through, and a vault
## under a cracked floor tile (red jar past a spike bed); platforms over a spiked pit; twin
## targets before the exit.
static func l17() -> Dictionary:
	return {"id": "l17", "layout": 2, "title": "Iron Gate Keep", "world": "fortress", "width": 180, "height": 40,
		"difficulty": 7, "minutes": 5.5, "spawn": [3, 34], "ops": [
		["fill", 0, 0, 0, 39], ["fill", 179, 0, 179, 39], ["ground", 1, 178, 34],
		["fill", 50, 1, 50, 29], ["ledge", 56, 104, 28], ["ladder", 54, 28, 34],
		["clear", 82, 35, 92, 38], ["clear", 84, 34, 86, 34], ["ledge", 84, 86, 34],
		["clear", 92, 34, 92, 34], ["ladder", 92, 34, 39],
		["clear", 115, 34, 145, 36], ["clear", 145, 34, 145, 34], ["ladder", 145, 34, 37],
		["fill", 170, 1, 170, 29],
		["clue", 6, 34, "The keep has\nthree keys."],
		["enemy", "guard", 18, 34, -4, 4], ["spikes", 26, 27, 34],
		["clue", 31, 34, "Three keys.\nTwo hands."],
		["plate", "PlateA", 34, 34],
		["plate", "PlateB", 40, 34, {"mode": 2, "active_time": 3.0}],
		["switch", "SwitchC", 46, 34, {"mode": 2}],
		["logic", "KeepLock", ["PlateA", "PlateB", "SwitchC"], 0, {"latch": true}],
		["gate", "KeepGate", 50, 34, 5, "KeepLock", 1],
		["jar", "yellow", 52, 34],
		["clue", 57, 34, "The quiet road\nruns high."],
		["enemy", "grunt", 62, 34, -4, 4], ["enemy", "guard", 70, 34, -4, 4], ["slime", "p", 78, 34, -3, 3],
		["enemy", "archer", 100, 34, -2, 2], ["enemy", "archer", 98, 28, -2, 2],
		["fire", 66, 34, 2], ["fire", 74, 34, 2, {"start_offset": 0.8}],
		["fruit", "green", 2, 78, 28], ["coins", 3, 100, 28],
		["spikes", 87, 89, 39], ["jar", "red", 90, 39], ["coins", 4, 83, 39],
		["save", 110, 34],
		["spikes", 115, 144, 37],
		["moving", "M1", 115, 34, 3, {"travel": Vector2i(12, 0), "speed": 38.0}],
		["moving", "M2", 131, 34, 3, {"travel": Vector2i(11, 0), "speed": 38.0, "start_delay": 1.5}],
		["saw", 118, 30, 9, 0, {"speed": 50.0}], ["saw", 134, 30, 9, 0, {"speed": 50.0, "start_phase": 0.5}],
		["enemy", "guard", 160, 34, -3, 3],
		["clue", 150, 34, "Strike as one."],
		["target", "TargetL", 154, 34], ["target", "TargetR", 166, 34],
		["logic", "Sync", ["TargetL", "TargetR"], 2, {"window": 2.0, "latch": true, "distinct_players": true}],
		["gate", "SyncGate", 170, 34, 5, "Sync", 1],
		["exit", 175, 34],
	]}


## Clockwork Halls: the knights work two machines at once. Left hall: a switch triggers a
## timed bridge that one knight must cross; right hall (up a ladder): a plate that only counts
## while held and a crumbling catwalk. Both machines must be finished (latched) to open the
## clock door. Then a pen of slimes around a plate that holds the last gate (latched past it).
static func l18() -> Dictionary:
	return {"id": "l18", "layout": 2, "title": "Clockwork Halls", "world": "fortress", "width": 180, "height": 46,
		"difficulty": 8, "minutes": 5.5, "spawn": [3, 40], "ops": [
		["fill", 0, 0, 0, 45], ["fill", 179, 0, 179, 45], ["ground", 1, 178, 40],
		["fill", 25, 24, 95, 26], ["ladder", 24, 24, 40],
		["clear", 40, 40, 52, 42], ["spikes", 40, 52, 43],
		["clear", 60, 24, 70, 25], ["spikes", 60, 70, 26],
		["fill", 100, 1, 100, 34],
		["clear", 120, 40, 140, 42], ["ground", 120, 140, 43], ["ladder", 120, 40, 43], ["ladder", 140, 40, 43],
		["fill", 150, 1, 150, 34],
		["clue", 6, 40, "Two machines.\nOne door."],
		["save", 14, 40],
		["switch", "BridgeSwitch", 36, 40, {"mode": 1, "active_time": 0.4}],
		["timed", "BridgeA", 41, 40, 3, {"mode": 1, "active_time": 4.0, "warning_time": 1.0, "start_active": false}],
		["timed", "BridgeB", 47, 40, 3, {"mode": 1, "active_time": 4.0, "warning_time": 1.0, "start_active": false}],
		["control", "BridgeA", "BridgeSwitch", 2], ["control", "BridgeB", "BridgeSwitch", 2],
		["switch", "LowLatch", 58, 40, {"mode": 2}],
		["enemy", "grunt", 72, 40, -5, 5], ["enemy", "archer", 88, 40, -2, 2],
		["saw", 63, 39, 12, 0, {"speed": 55.0}],
		["plate", "HighPlate", 30, 24],
		["collapse", "Cat1", 60, 24, 2], ["collapse", "Cat2", 63, 24, 2], ["collapse", "Cat3", 66, 24, 2], ["collapse", "Cat4", 69, 24, 2],
		["switch", "HighLatch", 90, 24, {"mode": 2}],
		["logic", "HighMachine", ["HighPlate", "HighLatch"], 1, {"latch": true}],
		["enemy", "guard", 80, 24, -5, 5], ["fire", 75, 24, 2, {"start_offset": 0.6}],
		["logic", "ClockLock", ["LowLatch", "HighMachine"], 0, {"latch": true}],
		["gate", "ClockGate", 100, 40, 6, "ClockLock", 1],
		["fruit", "green", 3, 93, 24],
		["save", 104, 40],
		["clue", 112, 40, "The pen keeps\nits own key."],
		["plate", "PenPlate", 129, 43],
		["slime", "p", 124, 43, -3, 7], ["slime", "g", 135, 43, -6, 4],
		["switch", "PenLatch", 155, 40, {"mode": 2}],
		["logic", "PenLogic", ["PenPlate", "PenLatch"], 1],
		["gate", "PenGate", 150, 40, 6, "PenLogic", 0],
		["tile", 146, 39],
		["enemy", "archer", 166, 40, -2, 2], ["enemy", "guard", 160, 40, -3, 3],
		["exit", 172, 40],
	]}


## Broken Towers: four ruined towers above a spiked courtyard. Ladders inside the towers,
## crumbling bridges and a moving platform between them, slimes on the tower tops. A switch
## on the last tower latches the courtyard gate. Ladders let a knight who falls into the spiked
## courtyard climb back to the tower it fell from. Optional: a precise climb above the last
## tower to a blue jar.
static func l19() -> Dictionary:
	return {"id": "l19", "layout": 2, "title": "Broken Towers", "world": "fortress", "width": 160, "height": 50,
		"difficulty": 8, "minutes": 5.5, "spawn": [3, 44], "ops": [
		["fill", 0, 0, 0, 49], ["fill", 159, 0, 159, 49], ["ground", 1, 158, 44],
		["fill", 20, 22, 28, 43], ["clear", 22, 23, 26, 43], ["clear", 24, 22, 24, 22], ["ladder", 24, 22, 44],
		["clear", 20, 41, 21, 43],
		["fill", 50, 18, 58, 43], ["fill", 82, 20, 90, 43], ["fill", 112, 16, 120, 43],
		["spikes", 30, 49, 44], ["spikes", 60, 81, 44], ["spikes", 92, 111, 44],
		["ladder", 29, 22, 44], ["ladder", 59, 18, 44], ["ladder", 91, 20, 44],
		["ladder", 121, 16, 44],
		["fill", 140, 1, 140, 38],
		["ledge", 117, 120, 13], ["ledge", 112, 115, 10],
		["clue", 6, 44, "Climb the broken\nteeth of the keep."],
		["enemy", "grunt", 13, 44, -4, 4],
		["collapse", "Br1", 30, 21, 2], ["collapse", "Br2", 34, 20, 2], ["collapse", "Br3", 38, 19, 2],
		["collapse", "Br4", 42, 19, 2], ["collapse", "Br5", 46, 18, 2],
		["enemy", "guard", 54, 18, -3, 3],
		["moving", "Span", 59, 18, 3, {"travel": Vector2i(20, 0), "speed": 40.0}],
		["enemy", "archer", 88, 20, -2, 1],
		["wind", 60, 10, 80, 17, {"direction": -1, "strength": 30.0}],
		["save", 84, 20],
		["timed", "Hop1", 92, 19, 2, {"active_time": 2.2, "disabled_time": 1.3}],
		["timed", "Hop2", 96, 18, 2, {"active_time": 2.2, "disabled_time": 1.3, "start_offset": 0.7}],
		["timed", "Hop3", 100, 17, 2, {"active_time": 2.2, "disabled_time": 1.3, "start_offset": 1.4}],
		["timed", "Hop4", 104, 16, 2, {"active_time": 2.2, "disabled_time": 1.3}],
		["timed", "Hop5", 108, 16, 2, {"active_time": 2.2, "disabled_time": 1.3, "start_offset": 0.7}],
		["switch", "TowerSwitch", 118, 16, {"mode": 2}],
		["enemy", "guard", 115, 16, -2, 3],
		["jar", "blue", 113, 10], ["coins", 4, 118, 13],
		["gate", "CourtGate", 140, 44, 6, "TowerSwitch", 1],
		["fruit", "green", 2, 130, 44], ["enemy", "grunt", 133, 44, -4, 4], ["enemy", "archer", 148, 44, -2, 2],
		["exit", 152, 44],
	]}


## The Black Bastion: the World 5 finale. A guarded plate pit and a timed gate open the outer
## wall; on the ramparts, two knights split at a tower: one rides a lift held by the other's
## plate, the rider latches it; a crumbling rampart over spikes; the inner seal needs twin
## targets and a two-plate step struck together. Optional: a coin vault under a cracked
## floor tile (a ladder leads back out) and purple fruit.
static func l20() -> Dictionary:
	return {"id": "l20", "layout": 2, "title": "The Black Bastion", "world": "fortress", "width": 200, "height": 48,
		"difficulty": 9, "minutes": 6.5, "spawn": [3, 42], "ops": [
		["fill", 0, 0, 0, 47], ["fill", 199, 0, 199, 47], ["ground", 1, 198, 42],
		["clear", 20, 42, 34, 44], ["ladder", 34, 42, 45], ["ledge", 20, 22, 42],
		["fill", 50, 1, 50, 36],
		["fill", 70, 26, 74, 41], ["clear", 66, 42, 68, 42],
		["ground", 75, 120, 26], ["clear", 90, 26, 104, 27], ["spikes", 90, 104, 28],
		["clear", 124, 42, 126, 42], ["ladder", 121, 26, 42],
		["fill", 160, 1, 160, 36],
		["ledge", 80, 83, 23], ["clear", 135, 43, 145, 46], ["clear", 140, 42, 141, 42], ["ledge", 140, 141, 42],
		["clear", 135, 42, 135, 42], ["ladder", 135, 42, 47],
		["clue", 6, 42, "The bastion\nnever sleeps."],
		["plate", "PitPlate", 27, 45],
		["slime", "p", 24, 45, -3, 8], ["enemy", "guard", 31, 45, -6, 2],
		["switch", "OuterLatch", 54, 42, {"mode": 2}],
		["logic", "OuterLogic", ["PitPlate", "OuterLatch"], 1],
		["gate", "OuterGate", 50, 42, 6, "OuterLogic", 0],
		["save", 56, 42],
		["enemy", "grunt", 59, 42, -2, 2],
		["plate", "LiftPlate", 62, 42],
		["moving", "TowerLift", 66, 42, 3, {"travel": Vector2i(0, -16), "speed": 40.0, "auto_start": false}],
		["switch", "LiftLatch", 77, 26, {"mode": 2}],
		["logic", "LiftLogic", ["LiftPlate", "LiftLatch"], 1],
		["control", "TowerLift", "LiftLogic", 0],
		["coins", 4, 82, 23], ["fruit", "purple", 3, 81, 23],
		["collapse", "R1", 91, 26, 2], ["collapse", "R2", 95, 26, 2], ["collapse", "R3", 99, 26, 2], ["collapse", "R4", 102, 26, 2],
		["enemy", "archer", 114, 26, -4, 4], ["enemy", "guard", 108, 26, -4, 4],
		["moving", "Drop", 124, 42, 3, {"travel": Vector2i(0, -16), "speed": 40.0}],
		["save", 130, 42],
		["coins", 6, 143, 46], ["fruit", "green", 2, 137, 46],
		["clue", 150, 42, "Strike as one.\nStep as one."],
		["target", "TA", 147, 42], ["target", "TB", 157, 42],
		["logic", "Targets", ["TA", "TB"], 2, {"window": 2.0, "latch": true, "distinct_players": true}],
		["plate", "StepA", 151, 42, {"mode": 2, "active_time": 1.2}],
		["plate", "StepB", 154, 42, {"mode": 2, "active_time": 1.2}],
		["logic", "Steps", ["StepA", "StepB"], 0, {"latch": true, "distinct_players": true}],
		["logic", "InnerSeal", ["Targets", "Steps"], 0, {"latch": true}],
		["gate", "InnerGate", 160, 42, 6, "InnerSeal", 1],
		["save", 163, 42],
		["fill", 166, 1, 194, 33],
		["clue", 168, 42, "The captain
keeps the last door."],
		["arena", "Keep", 168, 34, 192, 41],
		["gate", "KeepIn", 165, 42, 8, "Keep", 0], ["gate", "KeepOut", 194, 42, 8, "Keep", 0],
		["enemy", "captain", 186, 42, 0, 0],
		["exit", 196, 42],
	]}
