extends "res://scenes/app/game_app.gd"
## Phase 9 UI test harness: the real GameApp (menus, HUD, pause, settings, audio) with its
## OWN save folder (user://saves_ui_dev/) and settings file (user://settings_ui_dev.cfg), so it
## can never touch the player's campaigns in user://saves/ or their settings.cfg.
## Development keys (this room only):
##   F1  menu: fill the four slots with controlled states (ACTIVE progress, INVALIDATED,
##       CORRUPTED, RECOVERED)          F2  menu: empty all four slots
##   F3  game: P1 +1 max health (green jar effect; repeat for more than 3 hearts)
##   F4  game: timed effects on both knights (yellow fruit, yellow jar, power-tile effects)
##   F5  game: +1 coin (shared counter)  F6  game: kill P1 (team wipe -> game-over screen)
##   F7  game: victory screen (development preview, current run)
##   F8  game: hold the knights apart sideways (side-by-side split)
##   F9  game: hold the knights apart vertically (stacked split)
##   F10 game: release the knights (shared camera again)

const DEV_SAVE_DIR := "user://saves_ui_dev/"
const DEV_SETTINGS := "user://settings_ui_dev.cfg"

var _held: Array[Knight] = []


func _init() -> void:
	save_dir = DEV_SAVE_DIR
	settings_path = DEV_SETTINGS


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and _dev_key(key.physical_keycode):
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _dev_key(code: Key) -> bool:
	if mode == Mode.MENU:
		match code:
			KEY_F1:
				seed_slots(saves)
			KEY_F2:
				for slot in range(1, 5):
					saves.delete_slot(slot)
			_:
				return false
		show_main_menu()
		return true
	if campaign == null or mode != Mode.PLAYING:
		return false
	var run := RunState.current()
	match code:
		KEY_F3:
			run.player(1).collect_jar(PlayerStats.JarType.GREEN)
		KEY_F4:
			run.player(1).collect_fruit(PlayerStats.FruitType.YELLOW, 3)
			run.player(1).effects.add_tile_effect(PlayerEffects.ATTACK_SPEED)
			run.player(2).collect_jar(PlayerStats.JarType.YELLOW)
			run.player(2).effects.add_tile_effect(PlayerEffects.TILE_SHIELD)
			run.player(2).effects.add_tile_effect(PlayerEffects.SPEED_BOOST)
		KEY_F5:
			run.collect_coin(1)
		KEY_F6:
			campaign.knights[0].health.apply_damage(99)
		KEY_F7:
			show_victory(true)
		KEY_F8:
			_hold(Vector2(80, 448), Vector2(1100, 448))
		KEY_F9:
			_hold(Vector2(200, 448), Vector2(200, 120))
		KEY_F10:
			for k in _held:
				if is_instance_valid(k):
					k.set_physics_process(true)
			_held.clear()
		_:
			return false
	return true


func _hold(p1: Vector2, p2: Vector2) -> void:
	_held = [campaign.knights[0], campaign.knights[1]]
	for i in 2:
		_held[i].set_physics_process(false)
		_held[i].global_position = [p1, p2][i]


## Writes four controlled slot states with the real SaveManager (never the player's folder:
## `manager` must point at a development or test directory).
static func seed_slots(manager: SaveManager) -> void:
	assert(manager.store.dir != SavePaths.SAVE_DIR, "seed_slots must not run on the real save folder")
	if manager.store.dir == SavePaths.SAVE_DIR:
		return
	for slot in range(1, 5):
		manager.delete_slot(slot)
	# 1: ACTIVE, with progress in level 2.
	manager.start_new_run(1, true)
	var run := RunState.current()
	run.campaign.complete_level(LevelCatalog.first_level())
	run.campaign.enter_level(LevelCatalog.next_level(LevelCatalog.first_level()))
	run.coins = 23
	run.campaign.playtime = 1312.0
	run.player(1).collect_jar(PlayerStats.JarType.GREEN)
	run.player(2).current_health = 2
	manager.save_active_run({}, run.campaign.campaign_id)
	# 2: INVALIDATED (lost in a team wipe, no fresh run saved).
	manager.start_new_run(2, true)
	manager.invalidate_run_after_death(2, RunState.current().campaign.campaign_id)
	manager.wipe_lock = false
	# 3: CORRUPTED (damaged file, no backup).
	var f := FileAccess.open(manager.store.path(3, SlotStore.Kind.SAVE), FileAccess.WRITE)
	f.store_string("TKCSAVE 1 0000\n{ damaged")
	f.close()
	# 4: RECOVERED (damaged primary, valid backup).
	manager.start_new_run(4, true)
	RunState.current().coins = 5
	manager.save_active_run({}, RunState.current().campaign.campaign_id)
	var p := FileAccess.open(manager.store.path(4, SlotStore.Kind.SAVE), FileAccess.WRITE)
	p.store_string("TKCSAVE 1 0000\n{ damaged")
	p.close()
	manager.active_slot = 0
	RunState.reset()
