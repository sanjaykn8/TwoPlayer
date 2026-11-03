class_name RunState
extends RefCounted
## The current campaign run: the single authority for shared progression (coins, collected
## item ids) and the owner of each player's PlayerStats record.
##
## Held in a static variable, so it survives level and scene changes without an autoload
## (and works the same in the headless test runner). RunState.reset() starts a fresh run:
## used by tests now, and by new game / team wipe in Phase 8.
## Puzzle progress lives in `puzzles` (PuzzleRegistry), so it shares the run's lifetime.
## snapshot() / restore() produce and accept plain JSON-compatible dictionaries for the
## Phase 8 four-slot SaveManager. This class performs no disk I/O.

signal coins_changed(total: int)
## A coin was collected; `healed` is true when its 10 % roll healed both players.
signal coin_collected(collector_id: int, healed: bool)
## A unique collectible (fruit, jar, ...) was collected.
signal item_collected(id: String, player_id: int, kind: String)
## restore() replaced the state; bound knights resynchronise.
signal restored

## 2: adds "puzzles" (a version-1 snapshot without it restores with no puzzle progress).
## 3: adds "campaign" (older snapshots keep the current campaign position).
const VERSION := 3
const PROGRESSION_CONFIG := "res://resources/config/progression_config.tres"
const KNIGHT_CONFIG := "res://resources/config/knight_config.tres"
const COMBAT_CONFIG := "res://resources/config/combat_config.tres"
const PLAYER_IDS: Array[int] = [1, 2]

static var _current: RunState

var config: ProgressionConfig
var coins := 0
## id -> {"player": int, "kind": String}
var collected := {}
## Rolls the coin healing chance. Seed it for deterministic tests.
var coin_rng := RandomNumberGenerator.new()
## Saved puzzle states and live puzzle registration for this run.
var puzzles := PuzzleRegistry.new()
## Campaign position, completed levels, play time and the run's unique id.
var campaign := CampaignState.new()

var _players := {}


static func current() -> RunState:
	if _current == null:
		_current = RunState.new()
	return _current


## Replaces the current run with a fresh one and returns it.
static func reset() -> RunState:
	_current = RunState.new()
	return _current


## Drops the current run (application exit), so nothing is held by a static at shutdown.
static func clear() -> void:
	_current = null


func _init() -> void:
	config = load(PROGRESSION_CONFIG)
	coin_rng.randomize()
	var knight: KnightConfig = load(KNIGHT_CONFIG)
	var combat: CombatConfig = load(COMBAT_CONFIG)
	for id in PLAYER_IDS:
		_players[id] = PlayerStats.new(id, config, knight.base_max_health, combat.base_attack_power, combat.base_range_multiplier)


func player(id: int) -> PlayerStats:
	return _players.get(id)


# --- Coins --------------------------------------------------------------------------

## One coin collected by `collector_id`: +1 shared coin, then one independent heal roll.
## Returns true when the roll healed both living players.
func collect_coin(collector_id: int) -> bool:
	coins += 1
	coins_changed.emit(coins)
	var healed := PlayerEffects.roll_percent(coin_rng, config.coin_heal_chance_percent)
	if healed:
		for id in PLAYER_IDS:
			_players[id].heal(config.coin_heal_amount)
	coin_collected.emit(collector_id, healed)
	return healed


# --- Unique collectibles --------------------------------------------------------------

func is_collected(id: String) -> bool:
	return collected.has(id)


## Records a unique collectible. Returns false if the id was already collected this run.
func mark_collected(id: String, player_id: int, kind: String) -> bool:
	if id == "" or collected.has(id):
		return false
	collected[id] = {"player": player_id, "kind": kind}
	item_collected.emit(id, player_id, kind)
	return true


# --- Snapshot -----------------------------------------------------------------------

func snapshot() -> Dictionary:
	var ids := collected.keys()
	ids.sort()
	var items := []
	for id: String in ids:
		items.append({"id": id, "player": collected[id].player, "kind": collected[id].kind})
	var players := {}
	for id in PLAYER_IDS:
		players[str(id)] = _players[id].snapshot()
	return {"version": VERSION, "coins": coins, "collected": items, "players": players,
		"puzzles": puzzles.snapshot(), "campaign": campaign.snapshot()}


## Restores a snapshot. Everything is validated before anything changes; returns false
## (and keeps the current state) for missing, malformed or newer-version data.
func restore(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("version") or int(data.version) > VERSION:
		return false
	if not (data.has("coins") and data.has("collected") and data.has("players")):
		return false
	var coin_total := int(data.coins)
	if coin_total < 0 or typeof(data.collected) != TYPE_ARRAY or typeof(data.players) != TYPE_DICTIONARY:
		return false
	var items := {}
	for entry: Variant in data.collected:
		if typeof(entry) != TYPE_DICTIONARY or not (entry.has("id") and entry.has("player") and entry.has("kind")):
			return false
		items[str(entry.id)] = {"player": int(entry.player), "kind": str(entry.kind)}
	var knight: KnightConfig = load(KNIGHT_CONFIG)
	var combat: CombatConfig = load(COMBAT_CONFIG)
	for id in PLAYER_IDS:
		var probe := PlayerStats.new(id, config, knight.base_max_health, combat.base_attack_power, combat.base_range_multiplier)
		if not data.players.has(str(id)) or not probe.restore(data.players[str(id)]):
			return false
	var puzzle_data: Variant = data.get("puzzles", {"version": PuzzleRegistry.VERSION, "states": {}})
	if int(data.version) >= 2 and not data.has("puzzles"):
		return false
	if not PuzzleRegistry.is_valid_snapshot(puzzle_data):
		return false
	if int(data.version) >= 3 and not CampaignState.is_valid_snapshot(data.get("campaign")):
		return false
	for id in PLAYER_IDS:
		_players[id].restore(data.players[str(id)])
	coins = coin_total
	collected = items
	puzzles.restore(puzzle_data)
	if int(data.version) >= 3:
		campaign.restore(data.campaign)
	coins_changed.emit(coins)
	restored.emit()
	return true
