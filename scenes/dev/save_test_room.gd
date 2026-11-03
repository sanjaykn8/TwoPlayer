extends "res://scenes/campaign/campaign_game.gd"
## Phase 8 save-system test harness: the real CampaignGame with development keys. It uses its
## OWN save folder (user://saves_dev/ = %APPDATA%\TwoKnightCoop\saves_dev\), so it can never
## touch a player's campaigns in user://saves/. Keys exist only in this room:
##   1-4      save this slot, then switch to slot 1-4 (continue it, or start it if empty)
##   F1 / F2  hurt P1 / P2 (CONTACT)          F3  kill P1 (team wipe)
##   F4       start a NEW campaign in this slot (explicit overwrite)
##   F5       save now                         F6  delete this slot's files and start fresh
##   F7       damage this slot's primary file, then reload it (backup recovery)
##   F8       damage primary AND backup, then try to reload (corrupted slot)
##   F9       overlay on/off                   F10 close the window (save-on-exit path)
##   F11      next level (as if the exit was reached)

const DEV_SAVE_DIR := "user://saves_dev/"


func _init() -> void:
	save_dir = DEV_SAVE_DIR
	LevelCatalog.use_development()  # this harness exercises the two Phase 8 levels


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			switch_slot(key.physical_keycode - KEY_0)
		KEY_F1:
			_hurt(0)
		KEY_F2:
			_hurt(1)
		KEY_F3:
			if not knights.is_empty():
				knights[0].health.take_damage(DamageEvent.create(99, DamageEvent.Category.CONTACT, self))
		KEY_F4:
			_restart(SaveManager.Status.VALID)
		KEY_F5:
			save_now("manual (dev)")
		KEY_F6:
			saves.delete_slot(slot)
			_restart(SaveManager.Status.EMPTY)
		KEY_F7:
			_damage(SlotStore.Kind.SAVE)
			_reload_from_disk()
		KEY_F8:
			_damage(SlotStore.Kind.SAVE)
			_damage(SlotStore.Kind.BACKUP)
			_reload_from_disk()
		KEY_F9:
			var hud := get_node_or_null("SaveDebugHud") as CanvasLayer
			if hud != null:
				hud.visible = not hud.visible
		KEY_F10:
			handle_close_request()
		KEY_F11:
			complete_level()
		_:
			return
	get_viewport().set_input_as_handled()


func switch_slot(next: int) -> void:
	if phase == Phase.PLAYING:
		save_now("switch slot")
	slot = next
	start_mode = StartMode.CONTINUE
	begin()


func _hurt(index: int) -> void:
	if index < knights.size():
		knights[index].health.take_damage(DamageEvent.create(1, DamageEvent.Category.CONTACT, self))


func _restart(_expected: SaveManager.Status) -> void:
	start_mode = StartMode.NEW
	overwrite = true
	begin()
	overwrite = false


func _damage(kind: SlotStore.Kind) -> void:
	var path := saves.store.path(slot, kind)
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ_WRITE)
		file.seek(file.get_length() / 2)
		file.store_string("#DAMAGED#")
		file.close()
		_notice("Damaged %s (dev)" % path.get_file())


func _reload_from_disk() -> void:
	start_mode = StartMode.LOAD
	if begin() != OK:
		_notice("Slot %d is %s: F4 starts a new campaign." % [slot, SaveManager.status_name(saves.slot_status(slot))])
