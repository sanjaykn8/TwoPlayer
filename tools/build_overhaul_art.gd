extends SceneTree
## Generates the overhaul's character art from the Tiny RPG pack (assets/tiny_rpg/, by Zerie).
## Run from the project root, in two passes (new PNGs must be imported before use):
##   godot --headless --path . --script res://tools/build_overhaul_art.gd -- art
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/build_overhaul_art.gd -- content
## Outputs:
##   art:     res://assets/created/knight_p2.png       soldier, cloth recoloured royal blue
##            res://assets/created/hollow_soldier.png  soldier, violet-black cloth, dark steel
##            res://assets/created/orc_brute.png       orc, red-brown skin
##            res://assets/created/orc_guard.png       orc, slate-grey skin
##   content: res://resources/players/knight_frames_p1.tres / _p2.tres
##            res://resources/enemies/frames/*.tres (orc grunt / brute / guard, hollow soldier)
## Frame rectangles were measured from the sheets (docs/NEW_ASSET_CATALOG.md): 100x100 cells,
## soldier feet on y = 57 and centre x = 48, orc feet on y = 57.

const SOLDIER := "res://assets/tiny_rpg/soldier.png"
const ORC := "res://assets/tiny_rpg/orc.png"
const KNIGHT_P2 := "res://assets/created/knight_p2.png"
const HOLLOW := "res://assets/created/hollow_soldier.png"
const BRUTE := "res://assets/created/orc_brute.png"
const GUARD := "res://assets/created/orc_guard.png"
const FRAMES_DIR := "res://resources/enemies/frames/"

## Soldier crop inside a cell: 56x40, feet on the bottom edge (cell y 57), centre x 48.
const SOLDIER_CROP := Rect2(20, 17, 56, 40)
## Orc crop: 72x54 (the smash arc reaches below the feet), feet at crop y 43, centre x 50.
const ORC_CROP := Rect2(14, 14, 72, 54)


func _init() -> void:
	var step := "content"
	if not OS.get_cmdline_user_args().is_empty():
		step = OS.get_cmdline_user_args()[0]
	match step:
		"art":
			_build_recolours()
		"content":
			_build_frames()
		_:
			push_error("Unknown step %s (use art or content)" % step)
	quit()


# --- Recolours --------------------------------------------------------------------------

func _build_recolours() -> void:
	var soldier := Image.load_from_file(ProjectSettings.globalize_path(SOLDIER))
	var orc := Image.load_from_file(ProjectSettings.globalize_path(ORC))
	DirAccess.make_dir_recursive_absolute("res://assets/created")
	_save(_recolour(soldier, _p2_cloth), KNIGHT_P2)
	_save(_recolour(soldier, _hollow), HOLLOW)
	_save(_recolour(orc, _brute_skin), BRUTE)
	_save(_recolour(orc, _guard_skin), GUARD)


func _recolour(source: Image, mapper: Callable) -> Image:
	var img := source.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(x, y, mapper.call(c))
	return img


## Red cloth (pure red hues, saturated, not bright: skin, boots, belt and the hurt-flash red are
## left alone) becomes royal blue with the same shading, and the steel helmet turns brass, so
## the two knights differ in both colour and silhouette.
func _p2_cloth(c: Color) -> Color:
	if _is_red_cloth(c):
		return Color.from_hsv(0.62, clampf(c.s * 0.95, 0.0, 1.0), clampf(c.v * 1.25 + 0.06, 0.0, 1.0), c.a)
	if _is_steel(c):
		return Color.from_hsv(0.11, clampf(0.35 + c.s * 0.8, 0.0, 1.0), clampf(c.v * 1.08, 0.0, 1.0), c.a)
	return c


func _hollow(c: Color) -> Color:
	if _is_red_cloth(c):
		return Color.from_hsv(0.78, clampf(c.s * 0.8, 0.0, 1.0), c.v * 0.85, c.a)
	if _is_steel(c):
		# Steel: darker and colder.
		return Color.from_hsv(0.72, clampf(c.s + 0.12, 0.0, 1.0), c.v * 0.62, c.a)
	if c.s > 0.08 and c.s < 0.25 and c.v > 0.7 and (c.h < 0.12 or c.h > 0.9):
		# Skin: pale, lifeless grey-green.
		return Color.from_hsv(0.28, 0.12, c.v * 0.85, c.a)
	return c


func _brute_skin(c: Color) -> Color:
	if _is_orc_skin(c):
		return Color.from_hsv(0.03, clampf(c.s * 0.95, 0.0, 1.0), c.v * 0.95, c.a)
	return c


func _guard_skin(c: Color) -> Color:
	if _is_orc_skin(c):
		return Color.from_hsv(0.58, c.s * 0.35, c.v * 0.92, c.a)
	return c


func _is_red_cloth(c: Color) -> bool:
	return (c.h < 0.025 or c.h > 0.95) and c.s > 0.35 and c.v < 0.75 and c.v > 0.08


## Helmet and armour greys. The near-white slash arc (saturation under 0.08) is excluded.
func _is_steel(c: Color) -> bool:
	return c.s > 0.08 and c.s < 0.4 and c.h > 0.45 and c.h < 0.7 and c.v > 0.15


func _is_orc_skin(c: Color) -> bool:
	return c.h > 0.17 and c.h < 0.32 and c.s > 0.25


func _save(img: Image, path: String) -> void:
	var err := img.save_png(ProjectSettings.globalize_path(path))
	print("%s %s" % ["wrote" if err == OK else "FAILED", path])


# --- Sprite frames ------------------------------------------------------------------------

func _build_frames() -> void:
	DirAccess.make_dir_recursive_absolute(FRAMES_DIR)
	_save_res(_knight_frames(load(SOLDIER)), "res://resources/players/knight_frames_p1.tres")
	_save_res(_knight_frames(load(KNIGHT_P2)), "res://resources/players/knight_frames_p2.tres")
	_save_res(_hollow_frames(load(HOLLOW)), FRAMES_DIR + "hollow_soldier_frames.tres")
	_save_res(_orc_frames(load(ORC)), FRAMES_DIR + "orc_grunt_frames.tres")
	_save_res(_orc_frames(load(BRUTE)), FRAMES_DIR + "orc_brute_frames.tres")
	_save_res(_orc_frames(load(GUARD)), FRAMES_DIR + "orc_guard_frames.tres")


## Rows: 0 idle 6, 1 walk 8, 2 slash 6, 3 chop 6, 4 bow 9, 5 hurt 4, 6 death 4.
## Attack animations are stepped by the combat timeline in code (fps unused).
func _knight_frames(sheet: Texture2D) -> SpriteFrames:
	var f := _new_frames()
	_anim(f, sheet, SOLDIER_CROP, &"idle", 0, [0, 1, 2, 3, 4, 5], 8.0, true)
	_anim(f, sheet, SOLDIER_CROP, &"run", 1, [0, 1, 2, 3, 4, 5, 6, 7], 14.0, true)
	_anim(f, sheet, SOLDIER_CROP, &"jump", 1, [1], 1.0, true)
	_anim(f, sheet, SOLDIER_CROP, &"fall", 1, [5], 1.0, true)
	_anim(f, sheet, SOLDIER_CROP, &"crouch", 6, [1], 1.0, true)
	_anim(f, sheet, SOLDIER_CROP, &"climb", 1, [1, 3], 6.0, true)
	_anim(f, sheet, SOLDIER_CROP, &"hurt", 5, [0, 1, 2, 3], 12.0, false)
	_anim(f, sheet, SOLDIER_CROP, &"death", 6, [0, 1, 2, 3], 8.0, false)
	_anim(f, sheet, SOLDIER_CROP, &"attack_side", 2, [0, 1, 2, 3, 4, 5], 0.0, false)
	_anim(f, sheet, SOLDIER_CROP, &"attack_chop", 3, [0, 1, 2, 3, 4, 5], 0.0, false)
	return f


func _hollow_frames(sheet: Texture2D) -> SpriteFrames:
	var f := _new_frames()
	_anim(f, sheet, SOLDIER_CROP, &"idle", 0, [0, 1, 2, 3, 4, 5], 7.0, true)
	_anim(f, sheet, SOLDIER_CROP, &"walk", 1, [0, 1, 2, 3, 4, 5, 6, 7], 10.0, true)
	_anim(f, sheet, SOLDIER_CROP, &"draw", 4, [0, 1, 2, 3, 4, 5, 6], 0.0, false)
	_anim(f, sheet, SOLDIER_CROP, &"release", 4, [7, 8], 10.0, false)
	_anim(f, sheet, SOLDIER_CROP, &"slash", 2, [0, 1, 2, 3, 4, 5], 0.0, false)
	_anim(f, sheet, SOLDIER_CROP, &"chop", 3, [0, 1, 2, 3, 4, 5], 0.0, false)
	_anim(f, sheet, SOLDIER_CROP, &"hurt", 5, [0, 1, 2, 3], 12.0, false)
	_anim(f, sheet, SOLDIER_CROP, &"death", 6, [0, 1, 2, 3], 8.0, false)
	return f


## Rows: 0 idle 6, 1 walk 8, 2 sweep 6, 3 smash 6, 4 hurt 4, 5 death 4.
func _orc_frames(sheet: Texture2D) -> SpriteFrames:
	var f := _new_frames()
	_anim(f, sheet, ORC_CROP, &"idle", 0, [0, 1, 2, 3, 4, 5], 7.0, true)
	_anim(f, sheet, ORC_CROP, &"walk", 1, [0, 1, 2, 3, 4, 5, 6, 7], 10.0, true)
	_anim(f, sheet, ORC_CROP, &"sweep", 2, [0, 1, 2, 3, 4, 5], 0.0, false)
	_anim(f, sheet, ORC_CROP, &"smash", 3, [0, 1, 2, 3, 4, 5], 0.0, false)
	_anim(f, sheet, ORC_CROP, &"hurt", 4, [0, 1, 2, 3], 12.0, false)
	_anim(f, sheet, ORC_CROP, &"death", 5, [0, 1, 2, 3], 8.0, false)
	return f


func _new_frames() -> SpriteFrames:
	var f := SpriteFrames.new()
	f.remove_animation(&"default")
	return f


func _anim(frames: SpriteFrames, sheet: Texture2D, crop: Rect2, anim: StringName, row: int,
		cols: Array, fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for col: int in cols:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(col * 100 + crop.position.x, row * 100 + crop.position.y, crop.size.x, crop.size.y)
		atlas.filter_clip = true
		frames.add_frame(anim, atlas)


func _save_res(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	print("%s %s" % ["wrote" if err == OK else "FAILED", path])
