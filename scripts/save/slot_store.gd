class_name SlotStore
extends RefCounted
## File operations for the four save slots. The ONLY code that touches slot files.
## Every path is built from a validated slot number (1-4) and a fixed kind, never from data
## read out of a file:
##   slot_N.save     primary save
##   slot_N.bak      the previous good save (backup)
##   slot_N.tmp      a save being written
##   slot_N.dead     team-wipe invalidation marker (holds the dead campaign's id)
##   slot_N.corrupt  copy of the last damaged primary (diagnostics only, never loaded)
##
## write_atomic(): write .tmp -> flush/close -> re-read and verify -> move the current primary
## to .bak (only if it is itself valid) -> rename .tmp onto the primary (Godot's rename
## replaces an existing file on Windows; verified in Phase 8) -> re-read and verify the
## primary. Any failure rolls back to the previous primary and reports the error; the last
## good save is never destroyed by a failed write.

enum Kind { SAVE, BACKUP, TEMP, DEAD, CORRUPT }

const EXTENSIONS := {Kind.SAVE: "save", Kind.BACKUP: "bak", Kind.TEMP: "tmp", Kind.DEAD: "dead", Kind.CORRUPT: "corrupt"}
const SLOT_COUNT := 4

## Test-only fault injection: "tmp_write", "tmp_verify", "replace", "primary_verify",
## "marker". Empty in normal use.
static var fault := ""

var dir := SavePaths.SAVE_DIR
var last_error := ""


func _init(save_dir := SavePaths.SAVE_DIR) -> void:
	dir = save_dir if save_dir.ends_with("/") else save_dir + "/"


static func is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT


func path(slot: int, kind: Kind) -> String:
	if not is_valid_slot(slot):
		return ""
	return "%sslot_%d.%s" % [dir, slot, EXTENSIONS[kind]]


func exists(slot: int, kind: Kind) -> bool:
	var p := path(slot, kind)
	return p != "" and FileAccess.file_exists(p)


func read_text(slot: int, kind: Kind) -> String:
	if not exists(slot, kind):
		return ""
	return FileAccess.get_file_as_string(path(slot, kind))


func remove(slot: int, kind: Kind) -> Error:
	if not exists(slot, kind):
		return OK
	return DirAccess.remove_absolute(path(slot, kind))


func ensure_dir() -> Error:
	if DirAccess.dir_exists_absolute(dir):
		return OK
	return DirAccess.make_dir_recursive_absolute(dir)


## Writes `text` as the slot's primary save. `is_valid(text) -> bool` checks a file's content
## (the SaveManager passes the full schema decode). Returns OK only when the new primary has
## been re-read and verified.
func write_atomic(slot: int, text: String, is_valid: Callable) -> Error:
	last_error = ""
	if not is_valid_slot(slot):
		return _err(ERR_INVALID_PARAMETER, "invalid slot %d" % slot)
	var err := ensure_dir()
	if err != OK:
		return _err(err, "cannot create %s" % dir)
	var tmp := path(slot, Kind.TEMP)
	var primary := path(slot, Kind.SAVE)
	var backup := path(slot, Kind.BACKUP)
	err = _write_file(tmp, text)
	if err != OK or fault == "tmp_write":
		remove(slot, Kind.TEMP)
		return _err(err if err != OK else FAILED, "writing the temporary file failed")
	var written := FileAccess.get_file_as_string(tmp)
	if written != text or not is_valid.call(written) or fault == "tmp_verify":
		remove(slot, Kind.TEMP)
		return _err(ERR_FILE_CORRUPT, "the temporary file did not verify")
	# Keep the previous good primary as the backup (a damaged primary is not kept as backup).
	var moved_primary := false
	if FileAccess.file_exists(primary):
		if is_valid.call(FileAccess.get_file_as_string(primary)):
			err = DirAccess.rename_absolute(primary, backup)
			if err != OK:
				remove(slot, Kind.TEMP)
				return _err(err, "could not keep the previous save as backup")
			moved_primary = true
		else:
			_keep_corrupt_copy(slot)
			DirAccess.remove_absolute(primary)
	err = DirAccess.rename_absolute(tmp, primary) if fault != "replace" else FAILED
	if err != OK:
		if moved_primary:
			DirAccess.rename_absolute(backup, primary)  # roll back: the previous save is primary again
		remove(slot, Kind.TEMP)
		return _err(err, "replacing the save failed; the previous save was kept")
	var check := FileAccess.get_file_as_string(primary)
	if check != text or not is_valid.call(check) or fault == "primary_verify":
		DirAccess.remove_absolute(primary)
		if moved_primary:
			DirAccess.rename_absolute(backup, primary)
		return _err(ERR_FILE_CORRUPT, "the new save did not verify; the previous save was kept")
	return OK


## Writes the team-wipe marker (holding the dead campaign id) and verifies it.
func write_marker(slot: int, dead_campaign_id: String) -> Error:
	last_error = ""
	if not is_valid_slot(slot):
		return _err(ERR_INVALID_PARAMETER, "invalid slot %d" % slot)
	var err := ensure_dir()
	if err != OK or fault == "marker":
		return _err(err if err != OK else FAILED, "cannot write the invalidation marker")
	var p := path(slot, Kind.DEAD)
	err = _write_file(p, dead_campaign_id)
	if err != OK or FileAccess.get_file_as_string(p) != dead_campaign_id:
		return _err(err if err != OK else ERR_FILE_CORRUPT, "the invalidation marker did not verify")
	return OK


func read_marker(slot: int) -> String:
	return read_text(slot, Kind.DEAD).strip_edges()


## Copies the current primary to slot_N.corrupt for diagnosis (best effort).
func _keep_corrupt_copy(slot: int) -> void:
	var text := read_text(slot, Kind.SAVE)
	if text != "" or exists(slot, Kind.SAVE):
		_write_file(path(slot, Kind.CORRUPT), text)


func keep_corrupt_copy(slot: int) -> void:
	_keep_corrupt_copy(slot)


static func _write_file(file_path: String, text: String) -> Error:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	var err := file.get_error()
	file.close()
	return err


## Records the failure for the caller (SaveManager reports it); returns `code`.
func _err(code: Error, message: String) -> Error:
	last_error = "%s (%s)" % [message, error_string(code)]
	return code
