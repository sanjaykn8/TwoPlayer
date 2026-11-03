extends GameTestCase
## SaveManager and SlotStore without a level: four independent slots, metadata, overwrite
## protection, atomic writes with injected failures, backup recovery, corruption handling,
## schema validation against tampering, invalidation markers and stale requests.
## Folder: user://test_saves/ (cleaned before every test).

const DIR := SaveTestUtil.DIR

var mgr: SaveManager


func before_each() -> void:
	SaveTestUtil.clean()
	SlotStore.fault = ""
	mgr = SaveManager.new(DIR)


func after_each() -> void:
	SlotStore.fault = ""
	SaveTestUtil.clean()


## Starts a campaign in `slot` with `coins` coins and saves it.
func _campaign(slot: int, coins: int) -> String:
	assert_eq(mgr.start_new_run(slot, true), OK, "slot %d created" % slot)
	RunState.current().coins = coins
	assert_eq(mgr.save_active_run({}), OK, "slot %d saved" % slot)
	return RunState.current().campaign.campaign_id


func _file(slot: int, ext := "save") -> String:
	return SaveTestUtil.read(DIR, "slot_%d.%s" % [slot, ext])


# --- Four slots -----------------------------------------------------------------------------

func test_four_slots_are_independent() -> void:
	var ids := {}
	for slot in [1, 2, 3, 4]:
		ids[slot] = _campaign(slot, slot * 10)
	for slot in [1, 2, 3, 4]:
		var result := mgr.load_run(slot)
		assert_true(result.ok, "slot %d loads" % slot)
		assert_eq(RunState.current().coins, slot * 10, "slot %d has its own coins" % slot)
		assert_eq(RunState.current().campaign.campaign_id, ids[slot], "slot %d has its own campaign" % slot)
		assert_eq(mgr.active_slot, slot, "slot %d is now active" % slot)
	assert_eq(DirAccess.get_files_at(DIR).size(), 8, "4 primaries + 4 backups, nothing else")


func test_slot_metadata_without_loading_the_world() -> void:
	_campaign(2, 37)
	RunState.current().player(1).collect_jar(PlayerStats.JarType.GREEN)
	RunState.current().player(2).current_health = 2
	RunState.current().campaign.playtime = 125.5
	mgr.save_active_run({})
	var m := mgr.get_slot_metadata(2)
	assert_true(m.valid, "valid")
	assert_eq(m.status, "VALID", "status")
	assert_eq(m.slot, 2, "slot number")
	assert_eq(m.level_id, LevelCatalog.FIRST_LEVEL, "level")
	assert_eq(m.world_id, LevelCatalog.FIRST_WORLD, "world")
	assert_eq(m.coins, 37, "coins")
	assert_eq([m.p1_health, m.p1_max_health, m.p2_health, m.p2_max_health], [4, 4, 2, 3], "health summary")
	assert_near(m.playtime, 125.5, 0.001, "playtime")
	assert_eq(m.format_version, SaveSchema.FORMAT_VERSION, "format version")
	assert_true(str(m.saved_at) != "" and float(m.saved_at_unix) > 0.0, "timestamp")
	var empty := mgr.get_slot_metadata(3)
	assert_eq(empty.status, "EMPTY", "empty slot")
	assert_false(empty.valid, "empty is not valid")


func test_deleting_one_slot_leaves_the_others_byte_identical() -> void:
	for slot in [1, 2, 3, 4]:
		_campaign(slot, slot)
	var before := [_file(2), _file(3), _file(4), _file(2, "bak")]
	assert_eq(mgr.delete_slot(1), OK, "deleted")
	assert_eq(mgr.slot_status(1), SaveManager.Status.EMPTY, "slot 1 empty")
	assert_eq([_file(2), _file(3), _file(4), _file(2, "bak")], before, "slots 2-4 untouched")


func test_overwrite_needs_explicit_permission() -> void:
	var first := _campaign(1, 5)
	assert_eq(mgr.start_new_run(1), ERR_ALREADY_EXISTS, "refused without overwrite")
	assert_true(mgr.load_run(1).ok and RunState.current().campaign.campaign_id == first, "old campaign intact")
	assert_eq(mgr.start_new_run(1, true), OK, "allowed with overwrite")
	assert_true(RunState.current().campaign.campaign_id != first, "a new campaign")
	assert_false(_file(1, "bak").contains(first), "nothing of the replaced campaign remains")


func test_invalid_slot_numbers_are_rejected() -> void:
	for bad in [0, 5, -1, 99]:
		assert_false(SaveManager.is_valid_slot(bad), "%d invalid" % bad)
		assert_eq(mgr.start_new_run(bad), ERR_INVALID_PARAMETER, "start %d refused" % bad)
		assert_false(mgr.load_run(bad).ok, "load %d refused" % bad)
		assert_eq(mgr.delete_slot(bad), ERR_INVALID_PARAMETER, "delete %d refused" % bad)
		assert_eq(mgr.get_slot_metadata(bad).status, "INVALID_SLOT", "metadata %d" % bad)
		assert_eq(mgr.store.path(bad, SlotStore.Kind.SAVE), "", "no path for %d" % bad)
	assert_eq(DirAccess.get_files_at(DIR).size(), 0, "no file was written")


func test_empty_slot_is_handled() -> void:
	assert_false(mgr.has_valid_save(1), "no save")
	var result := mgr.load_run(1)
	assert_false(result.ok, "nothing to load")
	assert_eq(result.status, "EMPTY", "reported as empty")


# --- Atomic writing --------------------------------------------------------------------------

func test_normal_write_keeps_a_backup_and_no_temp_file() -> void:
	_campaign(1, 1)
	RunState.current().coins = 2
	assert_eq(mgr.save_active_run({}), OK, "second save")
	assert_eq(mgr.validate_slot_file(1, SlotStore.Kind.SAVE), "", "primary valid")
	assert_eq(mgr.validate_slot_file(1, SlotStore.Kind.BACKUP), "", "backup valid")
	assert_true(_file(1).contains("\"coins\": 2"), "primary is the new save")
	assert_true(_file(1, "bak").contains("\"coins\": 1"), "backup is the previous save")
	assert_false(FileAccess.file_exists(DIR + "slot_1.tmp"), "no temporary file left")


func test_failed_writes_never_destroy_the_last_good_save() -> void:
	_campaign(1, 11)
	var good := _file(1)
	for fault in ["tmp_write", "tmp_verify", "replace", "primary_verify"]:
		SlotStore.fault = fault
		RunState.current().coins = 99
		assert_true(mgr.save_active_run({}) != OK, "%s: reported as failed" % fault)
		SlotStore.fault = ""
		assert_eq(_file(1), good, "%s: the previous save is intact" % fault)
		assert_false(FileAccess.file_exists(DIR + "slot_1.tmp"), "%s: no temp file left" % fault)
		assert_true(mgr.load_run(1).ok and RunState.current().coins == 11, "%s: still loads" % fault)


# --- Corruption and recovery -----------------------------------------------------------------

func test_damaged_primary_is_recovered_from_backup() -> void:
	_campaign(1, 3)
	RunState.current().coins = 4
	mgr.save_active_run({})
	var damaged := _file(1).replace("\"coins\": 4", "\"coins\": 9")
	SaveTestUtil.write(DIR, "slot_1.save", damaged)
	assert_eq(mgr.slot_status(1), SaveManager.Status.RECOVERED, "detected, backup usable")
	var warnings: Array = mgr.get_slot_metadata(1).warnings
	assert_true(str(warnings).contains("checksum"), "the problem is reported (%s)" % str(warnings))
	var result := mgr.load_run(1)
	assert_true(result.ok, "loads")
	assert_eq(result.status, "RECOVERED", "reported as recovered")
	assert_eq(RunState.current().coins, 3, "the backup's campaign")
	assert_eq(mgr.validate_slot_file(1), "", "primary repaired from the backup")
	assert_eq(SaveTestUtil.read(DIR, "slot_1.corrupt"), damaged, "damaged file kept for diagnosis")


func test_damaged_backup_alone_is_detected() -> void:
	_campaign(1, 3)
	mgr.save_active_run({})
	SaveTestUtil.write(DIR, "slot_1.bak", "garbage")
	assert_eq(mgr.slot_status(1), SaveManager.Status.VALID, "primary still fine")
	assert_true(mgr.validate_slot_file(1, SlotStore.Kind.BACKUP) != "", "backup reported invalid")


func test_both_damaged_is_reported_and_never_replaced_silently() -> void:
	_campaign(1, 3)
	mgr.save_active_run({})
	SaveTestUtil.write(DIR, "slot_1.save", "TKCSAVE 1 00\n{")
	SaveTestUtil.write(DIR, "slot_1.bak", "")
	assert_eq(mgr.slot_status(1), SaveManager.Status.CORRUPTED, "corrupted")
	var result := mgr.load_run(1)
	assert_false(result.ok, "not loaded")
	assert_eq(result.status, "CORRUPTED", "reported")
	assert_true(FileAccess.file_exists(DIR + "slot_1.save"), "nothing was replaced automatically")
	assert_eq(mgr.start_new_run(1), OK, "an explicit new game is allowed")
	assert_true(FileAccess.file_exists(DIR + "slot_1.corrupt"), "the damaged file was kept")


func test_only_a_temp_file_is_reported() -> void:
	SaveTestUtil.write(DIR, "slot_4.tmp", "partial")
	assert_eq(mgr.slot_status(4), SaveManager.Status.CORRUPTED, "not empty, not loadable")
	assert_true(str(mgr.get_slot_metadata(4).warnings).contains("temporary"), "explained")


# --- Validation against bad or hostile data --------------------------------------------------

func test_tampered_or_mismatched_files_are_rejected() -> void:
	_campaign(1, 5)
	var text := _file(1)
	var body := SaveTestUtil.body_of(text)
	var cases := {
		"truncated": text.left(text.length() / 2),
		"edited without checksum": text.replace("\"coins\": 5", "\"coins\": 6"),
		"wrong slot": text,
		"newer format": text.replace("TKCSAVE 1 ", "TKCSAVE 2 "),
		"older format": text.replace("TKCSAVE 1 ", "TKCSAVE 0 "),
		"unknown level": SaveTestUtil.resign(body.replace("\"level_id\": \"w1_l1\"", "\"level_id\": \"w9_l9\"")),
		"scene path injected": SaveTestUtil.resign(body.replace("\"level_id\": \"w1_l1\"", "\"level_id\": \"res://scenes/dev/puzzle_test_room.tscn\"")),
		"negative coins": SaveTestUtil.resign(body.replace("\"coins\": 5", "\"coins\": -5")),
		"dead player": SaveTestUtil.resign(body.replace("\"current_health\": 3", "\"current_health\": 0")),
		"not json": "TKCSAVE 1 %s\n<xml/>" % "<xml/>".sha256_text(),
	}
	for name: String in cases:
		var slot := 2 if name == "wrong slot" else 1
		var result := SaveSchema.decode(cases[name], slot)
		assert_false(result.ok, "%s rejected" % name)
	assert_true(SaveSchema.decode(text, 1).ok, "the original is valid")


func test_world_section_validation() -> void:
	var good := {"level_id": "w1_l1", "players": {"1": _p(), "2": _p()}, "enemies": {}, "coins": [], "puzzles": {}, "platforms": {}}
	assert_eq(WorldSnapshot.validate(good, "w1_l1"), "", "valid world")
	assert_eq(WorldSnapshot.validate({}, "w1_l1"), "", "an empty world is a fresh level")
	var bad := good.duplicate(true)
	bad.players["1"].x = 1.0e9
	assert_true(WorldSnapshot.validate(bad, "w1_l1") != "", "position out of range")
	bad = good.duplicate(true)
	bad.coins = [_coin("a"), _coin("a")]
	assert_true(WorldSnapshot.validate(bad, "w1_l1") != "", "duplicate coin id")
	bad = good.duplicate(true)
	bad.enemies = {"e1": {"type": "dragon", "x": 0, "y": 0}}
	assert_true(WorldSnapshot.validate(bad, "w1_l1") != "", "unknown enemy type")
	assert_true(WorldSnapshot.validate(good, "w1_l2") != "", "world of another level")


func _p() -> Dictionary:
	return {"x": 10.0, "y": 20.0, "facing": 1, "safe_x": 10.0, "safe_y": 20.0, "has_safe": true}


func _coin(id: String) -> Dictionary:
	return {"id": id, "x": 1.0, "y": 2.0, "vx": 0.0, "vy": 0.0, "resting": true, "delay": 0.0}


# --- Invalidation, locks and stale requests --------------------------------------------------

func test_invalidation_makes_every_old_file_unloadable() -> void:
	var dead := _campaign(1, 8)
	RunState.current().coins = 9
	mgr.save_active_run({})
	var old_primary := _file(1)
	var old_backup := _file(1, "bak")
	assert_eq(mgr.invalidate_run_after_death(1, dead), OK, "invalidated")
	assert_eq(mgr.slot_status(1), SaveManager.Status.INVALIDATED, "slot needs a new campaign")
	assert_false(mgr.load_run(1).ok, "nothing loads")
	# Even if old files reappear (an interrupted delete, a stray copy), they stay dead.
	SaveTestUtil.write(DIR, "slot_1.save", old_primary)
	SaveTestUtil.write(DIR, "slot_1.bak", old_backup)
	assert_eq(mgr.slot_status(1), SaveManager.Status.INVALIDATED, "old primary and backup refused")
	assert_eq(mgr.save_active_run({}), ERR_LOCKED, "wipe lock refuses ordinary saves")
	assert_eq(mgr.save_active_run({}, "", true), ERR_INVALID_DATA, "the dead campaign itself can never be saved again")
	assert_eq(mgr.clear_invalidation(1), ERR_UNAVAILABLE, "marker kept until a fresh campaign is verified")


func test_marker_failure_is_fail_closed() -> void:
	var id := _campaign(1, 8)
	SlotStore.fault = "marker"
	assert_true(mgr.invalidate_run_after_death(1, id) != OK, "reported")
	assert_true(mgr.wipe_lock, "the lock stays on")
	assert_eq(mgr.save_active_run({}), ERR_LOCKED, "nothing can be saved as if the wipe succeeded")


func test_stale_save_requests_are_refused() -> void:
	var old_id := _campaign(1, 4)
	RunState.reset()
	assert_eq(mgr.save_active_run({}, old_id), ERR_INVALID_DATA, "a request for an older campaign is refused")
	assert_true(_file(1).contains(old_id), "the slot still holds what it held")


func test_other_slots_untouched_by_an_invalidation() -> void:
	for slot in [1, 2, 3, 4]:
		_campaign(slot, slot)
	var before := [_file(1), _file(2), _file(4)]
	var victim := SaveSchema.decode(_file(3), 3).doc.header.campaign_id as String
	mgr.invalidate_run_after_death(3, victim)
	assert_eq([_file(1), _file(2), _file(4)], before, "slots 1, 2, 4 unchanged")
	assert_eq(mgr.slot_status(3), SaveManager.Status.INVALIDATED, "only slot 3 invalidated")
