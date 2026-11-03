class_name SaveManager
extends RefCounted
## The single interface for saving and loading campaigns (four independent slots).
## Owns no gameplay: the campaign scene (CampaignGame) asks it to save/load, and it reads and
## writes RunState plus a WorldSnapshot dictionary through SaveSchema and SlotStore.
##
## Slots are always 1-4 (anything else is rejected). Each slot is its own set of files, so
## deleting, corrupting or wiping one never touches another.
##
## Stale-save protection: every save names the campaign it belongs to (`token`, the run's
## campaign_id). A save for a campaign that is no longer the current run, a save while a team
## wipe holds `wipe_lock`, and a save of a campaign the slot has marked dead are all refused.

signal saved(slot: int)
signal save_failed(slot: int, reason: String)
## A damaged primary was replaced by the valid backup.
signal recovered(slot: int, reason: String)

enum Status { EMPTY, VALID, RECOVERED, CORRUPTED, INVALIDATED }

var store: SlotStore
## The slot of the campaign being played (0 = none).
var active_slot := 0
## True from the moment a team wipe starts until the fresh campaign has been saved; every
## ordinary save request is refused meanwhile.
var wipe_lock := false
var last_error := ""
var save_count := 0


func _init(save_dir := SavePaths.SAVE_DIR) -> void:
	store = SlotStore.new(save_dir)


static func is_valid_slot(slot: int) -> bool:
	return SlotStore.is_valid_slot(slot)


static func status_name(status: Status) -> String:
	return Status.keys()[status]


# --- Slot information ----------------------------------------------------------------------

## Everything a save-slot screen needs, read from the file header without building the world.
func get_slot_metadata(slot: int) -> Dictionary:
	if not is_valid_slot(slot):
		return {"slot": slot, "status": "INVALID_SLOT", "valid": false, "warnings": ["invalid slot number"]}
	var resolved := _resolve(slot)
	var meta := {
		"slot": slot, "status": status_name(resolved.status), "valid": false,
		"campaign_id": "", "world_id": "", "level_id": "", "saved_at": "", "saved_at_unix": 0.0,
		"coins": 0, "p1_health": 0, "p1_max_health": 0, "p2_health": 0, "p2_max_health": 0,
		"playtime": 0.0, "format_version": SaveSchema.FORMAT_VERSION, "warnings": resolved.warnings,
	}
	if resolved.doc.is_empty():
		return meta
	var h: Dictionary = resolved.doc.header
	meta.valid = true
	meta.campaign_id = str(h.campaign_id)
	meta.world_id = str(h.world_id)
	meta.level_id = str(h.level_id)
	meta.saved_at = str(h.get("saved_at", ""))
	meta.saved_at_unix = float(h.saved_at_unix)
	meta.coins = int(h.coins)
	meta.playtime = float(h.playtime)
	meta.p1_health = int(h.players["1"].health)
	meta.p1_max_health = int(h.players["1"].max_health)
	meta.p2_health = int(h.players["2"].health)
	meta.p2_max_health = int(h.players["2"].max_health)
	return meta


func has_valid_save(slot: int) -> bool:
	if not is_valid_slot(slot):
		return false
	var status: Status = _resolve(slot).status
	return status == Status.VALID or status == Status.RECOVERED


func slot_status(slot: int) -> Status:
	return _resolve(slot).status if is_valid_slot(slot) else Status.CORRUPTED


# --- Campaign operations -------------------------------------------------------------------

## Starts a fresh campaign (new RunState) in `slot` and writes its starting save.
## An existing valid campaign is only replaced with `overwrite = true`.
func start_new_run(slot: int, overwrite := false) -> Error:
	last_error = ""
	if not is_valid_slot(slot):
		return _fail(slot, ERR_INVALID_PARAMETER, "invalid slot %d" % slot)
	var status: Status = _resolve(slot).status
	if (status == Status.VALID or status == Status.RECOVERED) and not overwrite:
		return _fail(slot, ERR_ALREADY_EXISTS, "slot %d holds a campaign; overwrite not confirmed" % slot)
	if status == Status.CORRUPTED:
		store.keep_corrupt_copy(slot)
	RunState.reset()
	active_slot = slot
	var err := save_active_run({}, RunState.current().campaign.campaign_id, true)
	if err == OK:
		store.remove(slot, SlotStore.Kind.BACKUP)  # nothing of the replaced campaign remains
		store.remove(slot, SlotStore.Kind.DEAD)
	return err


## Saves the current RunState plus `world` to the active slot. `token` must be the campaign
## id the request was made for (stale requests are refused); `during_wipe` is only used by
## the team-wipe flow for the fresh campaign's first save.
func save_active_run(world: Dictionary, token := "", during_wipe := false) -> Error:
	last_error = ""
	var run := RunState.current()
	if not is_valid_slot(active_slot):
		return _fail(active_slot, ERR_UNCONFIGURED, "no active slot")
	if wipe_lock and not during_wipe:
		return _fail(active_slot, ERR_LOCKED, "team wipe in progress: save refused")
	if token != "" and token != run.campaign.campaign_id:
		return _fail(active_slot, ERR_INVALID_DATA, "stale save request for an older campaign: refused")
	if store.read_marker(active_slot) == run.campaign.campaign_id:
		return _fail(active_slot, ERR_INVALID_DATA, "this campaign was invalidated by a team wipe: refused")
	var text := SaveSchema.encode(SaveSchema.build(active_slot, run, world))
	var slot := active_slot
	var check := SaveSchema.decode(text, slot)
	if not check.ok:
		return _fail(slot, ERR_INVALID_DATA, "snapshot failed validation: " + check.error)
	var err := store.write_atomic(slot, text, func(t: String) -> bool: return SaveSchema.decode(t, slot).ok)
	if err != OK:
		return _fail(slot, err, store.last_error)
	save_count += 1
	saved.emit(slot)
	return OK


## Loads a slot into the current RunState. Returns {"ok", "status", "world", "warnings", "error"};
## on failure nothing changes. A damaged primary with a valid backup is recovered (reported).
func load_run(slot: int) -> Dictionary:
	last_error = ""
	if not is_valid_slot(slot):
		_fail(slot, ERR_INVALID_PARAMETER, "invalid slot %d" % slot)
		return {"ok": false, "status": "INVALID_SLOT", "world": {}, "warnings": [], "error": last_error}
	var resolved := _resolve(slot)
	var status: Status = resolved.status
	if status != Status.VALID and status != Status.RECOVERED:
		last_error = "slot %d cannot be loaded (%s)" % [slot, status_name(status)]
		return {"ok": false, "status": status_name(status), "world": {}, "warnings": resolved.warnings, "error": last_error}
	var fresh := RunState.new()
	if not fresh.restore(resolved.doc.run):
		last_error = "slot %d: run data refused" % slot
		return {"ok": false, "status": "CORRUPTED", "world": {}, "warnings": resolved.warnings, "error": last_error}
	if status == Status.RECOVERED:
		var err := recover_backup(slot)
		if err != OK:
			resolved.warnings.append("backup loaded but the primary could not be repaired: " + store.last_error)
	RunState.reset().restore(resolved.doc.run)
	active_slot = slot
	return {"ok": true, "status": status_name(status), "world": resolved.doc.world, "warnings": resolved.warnings, "error": ""}


## Replaces a damaged primary with the slot's valid backup (the damaged file is kept as
## slot_N.corrupt for diagnosis).
func recover_backup(slot: int) -> Error:
	var backup := SaveSchema.decode(store.read_text(slot, SlotStore.Kind.BACKUP), slot)
	if not backup.ok:
		return _fail(slot, ERR_FILE_CORRUPT, "no valid backup: " + backup.error)
	var dead := store.read_marker(slot)
	if dead != "" and str(backup.doc.header.campaign_id) == dead:
		return _fail(slot, ERR_FILE_CORRUPT, "the backup belongs to an invalidated campaign")
	store.keep_corrupt_copy(slot)
	var text := store.read_text(slot, SlotStore.Kind.BACKUP)
	var err := store.write_atomic(slot, text, func(t: String) -> bool: return SaveSchema.decode(t, slot).ok)
	if err != OK:
		return _fail(slot, err, store.last_error)
	recovered.emit(slot, "primary save damaged; restored from backup")
	return OK


## Removes every file of one slot. Other slots are never touched.
func delete_slot(slot: int) -> Error:
	if not is_valid_slot(slot):
		return _fail(slot, ERR_INVALID_PARAMETER, "invalid slot %d" % slot)
	for kind in SlotStore.EXTENSIONS:
		store.remove(slot, kind)
	if active_slot == slot:
		active_slot = 0
	for kind in SlotStore.EXTENSIONS:
		if store.exists(slot, kind):
			return _fail(slot, ERR_CANT_OPEN, "slot %d could not be fully deleted" % slot)
	return OK


## Team wipe, step 2: makes the dead campaign permanently unloadable. Sets `wipe_lock`, writes
## and verifies the slot's marker (the dead campaign id), then deletes the slot's primary,
## backup and temporary files. Fail-closed: if the marker cannot be written, nothing is
## deleted, the lock stays on and the error is returned.
func invalidate_run_after_death(slot: int, dead_campaign_id: String) -> Error:
	wipe_lock = true
	if not is_valid_slot(slot):
		return _fail(slot, ERR_INVALID_PARAMETER, "invalid slot %d" % slot)
	var err := store.write_marker(slot, dead_campaign_id)
	if err != OK:
		return _fail(slot, err, "team wipe could not invalidate the old campaign: " + store.last_error)
	for kind in [SlotStore.Kind.SAVE, SlotStore.Kind.BACKUP, SlotStore.Kind.TEMP]:
		store.remove(slot, kind)
	if store.exists(slot, SlotStore.Kind.SAVE) or store.exists(slot, SlotStore.Kind.BACKUP):
		# The marker still makes these files unloadable; report the incomplete clean-up.
		last_error = "old save files could not be deleted (still invalidated by the marker)"
	return OK


## Team wipe, last step: once the fresh campaign's save has been verified, the marker can go.
func clear_invalidation(slot: int) -> Error:
	var check := SaveSchema.decode(store.read_text(slot, SlotStore.Kind.SAVE), slot)
	if not check.ok or str(check.doc.header.campaign_id) == store.read_marker(slot):
		return _fail(slot, ERR_UNAVAILABLE, "no verified fresh campaign yet; marker kept")
	return store.remove(slot, SlotStore.Kind.DEAD)


func export_snapshot() -> Dictionary:
	return RunState.current().snapshot()


func restore_snapshot(data: Variant) -> bool:
	return RunState.current().restore(data)


## Validates one slot file ("" when valid, else the problem).
func validate_slot_file(slot: int, kind: SlotStore.Kind = SlotStore.Kind.SAVE) -> String:
	if not store.exists(slot, kind):
		return "missing"
	var result := SaveSchema.decode(store.read_text(slot, kind), slot)
	return "" if result.ok else str(result.error)


# --- Internals -----------------------------------------------------------------------------

## Works out what a slot holds: {"status", "doc", "warnings"}.
func _resolve(slot: int) -> Dictionary:
	var warnings: Array = []
	var dead := store.read_marker(slot)
	if store.exists(slot, SlotStore.Kind.SAVE):
		var primary := SaveSchema.decode(store.read_text(slot, SlotStore.Kind.SAVE), slot)
		if primary.ok and str(primary.doc.header.campaign_id) != dead:
			if dead != "":
				warnings.append("an interrupted team wipe was completed earlier")
			return {"status": Status.VALID, "doc": primary.doc, "warnings": warnings}
		warnings.append("primary save rejected: " + (str(primary.error) if not primary.ok else "campaign was lost in a team wipe"))
	if store.exists(slot, SlotStore.Kind.BACKUP):
		var backup := SaveSchema.decode(store.read_text(slot, SlotStore.Kind.BACKUP), slot)
		if backup.ok and str(backup.doc.header.campaign_id) != dead:
			warnings.append("recovered from backup")
			return {"status": Status.RECOVERED, "doc": backup.doc, "warnings": warnings}
		warnings.append("backup rejected: " + (str(backup.error) if not backup.ok else "campaign was lost in a team wipe"))
	if dead != "":
		warnings.append("the campaign in this slot was lost in a team wipe; start a new campaign")
		return {"status": Status.INVALIDATED, "doc": {}, "warnings": warnings}
	if store.exists(slot, SlotStore.Kind.SAVE) or store.exists(slot, SlotStore.Kind.BACKUP) or store.exists(slot, SlotStore.Kind.TEMP):
		if store.exists(slot, SlotStore.Kind.TEMP) and warnings.is_empty():
			warnings.append("only an unfinished temporary file exists")
		return {"status": Status.CORRUPTED, "doc": {}, "warnings": warnings}
	return {"status": Status.EMPTY, "doc": {}, "warnings": warnings}


func _fail(slot: int, code: Error, reason: String) -> Error:
	last_error = reason
	save_failed.emit(slot, reason)
	return code
