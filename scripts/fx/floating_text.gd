class_name FloatingText
extends Label
## A short pixel-font message that rises and fades, then frees itself.

const RISE := 12.0
const DURATION := 0.8


## Shows `text` at `offset` relative to `anchor` (added to the anchor's parent so it stays
## where it appeared when the anchor moves or is removed).
static func spawn(anchor: Node2D, offset: Vector2, text: String, colour: Color) -> void:
	if anchor == null or not anchor.is_inside_tree() or anchor.get_parent() == null:
		return
	var label := FloatingText.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 8)
	label.add_theme_color_override(&"font_color", colour)
	label.add_theme_color_override(&"font_outline_color", Color(0.05, 0.05, 0.07))
	label.add_theme_constant_override(&"outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(80, 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 20
	anchor.get_parent().add_child(label)
	label.global_position = (anchor.global_position + offset - Vector2(40, 4)).round()
	var tween := label.create_tween()
	tween.tween_property(label, ^"position:y", label.position.y - RISE, DURATION)
	tween.parallel().tween_property(label, ^"modulate:a", 0.0, DURATION)
	tween.tween_callback(label.queue_free)
