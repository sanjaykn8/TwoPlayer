extends SceneTree
## Generates Phase 9 pixel art that the asset bundle does not contain.
## Run from the project root, then import:
##   godot --headless --path . --script res://tools/build_phase9_content.gd
##   godot --headless --path . --import
## Output: res://assets/created/ui_icons.png, a 32x8 strip of 8x8 cells:
##   0 heart (full)   1 heart (empty)   2 slider grabber   3 menu pointer arrow
## Colours follow the knight/slime palettes of the bundle (dark outline, saturated fill).

const OUT := "res://assets/created/ui_icons.png"

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"K": Color("1a1220"),  # outline
	"R": Color("d23a3a"),  # heart red
	"W": Color("ffb0a0"),  # heart highlight
	"D": Color("3b3046"),  # empty heart fill
	"G": Color("e3b450"),  # gold
	"g": Color("8a6a2a"),  # dark gold
}

const CELLS := [
	[
		".KK.KK..",
		"KRRKRRK.",
		"KRWRRRK.",
		"KRRRRRK.",
		".KRRRK..",
		"..KRK...",
		"...K....",
		"........",
	],
	[
		".KK.KK..",
		"KDDKDDK.",
		"KDDDDDK.",
		"KDDDDDK.",
		".KDDDK..",
		"..KDK...",
		"...K....",
		"........",
	],
	[
		"..KKKK..",
		"..KGGK..",
		"..KGGK..",
		"..KGgK..",
		"..KGgK..",
		"..KggK..",
		"..KKKK..",
		"........",
	],
	[
		"..K.....",
		"..KK....",
		"..KGK...",
		"..KGGK..",
		"..KGK...",
		"..KK....",
		"..K.....",
		"........",
	],
]


func _init() -> void:
	var img := Image.create(8 * CELLS.size(), 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in CELLS.size():
		var rows: Array = CELLS[i]
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				img.set_pixel(i * 8 + x, y, PALETTE[row[x]])
	DirAccess.make_dir_recursive_absolute("res://assets/created")
	var err := img.save_png(OUT)
	print("%s %s" % [OUT, "written" if err == OK else "FAILED: %s" % error_string(err)])
	quit(0 if err == OK else 1)
