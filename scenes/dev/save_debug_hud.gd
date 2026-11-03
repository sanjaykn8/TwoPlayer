extends CanvasLayer
## Development overlay for Phase 8: the active slot and campaign, all four slots' metadata,
## the last save, phase and notices. (The real save-slot screen is Phase 9.)

var _label: Label
var _timer := 0.0
var _slots_text := ""


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.72)
	style.set_content_margin_all(3)
	panel.add_theme_stylebox_override(&"panel", style)
	panel.position = Vector2(4, 4)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 8)
	panel.add_child(_label)
	add_child(panel)


func _process(delta: float) -> void:
	var game := get_parent() as CampaignGame
	if game == null or game.saves == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 1.0  # slot files are read at most once a second
		var rows := PackedStringArray()
		for s in 4:
			var m := game.saves.get_slot_metadata(s + 1)
			rows.append("%d:%s %s c%d %.0fs" % [s + 1, m.status, m.level_id, m.coins, m.playtime] if m.valid else "%d:%s" % [s + 1, m.status])
		_slots_text = "  ".join(rows)
	var run := RunState.current()
	var lines := PackedStringArray()
	lines.append("SLOT %d  %s  level %s  run %s  time %.1fs  coins %d" % [game.slot, game.phase_name(),
		run.campaign.level_id, run.campaign.campaign_id.left(6), run.campaign.playtime, run.coins])
	for knight in game.knights:
		if is_instance_valid(knight):
			var s := run.player(knight.player_id())
			lines.append("P%d HP %d/%d pow %d x%d %s" % [knight.player_id(), knight.health.current_health,
				knight.health.max_health, s.attack_power(), knight.global_position.x, ", ".join(s.effects.active_ids())])
	lines.append("last save: %s %s   wipes %d%s" % [game.last_save_reason, "OK" if game.last_save_ok else "-",
		game.wipes, "   FRESH RUN UNSAVED" if game.fresh_run_unsaved else ""])
	lines.append("slots  " + _slots_text)
	if game.last_notice != "":
		lines.append("> " + game.last_notice)
	lines.append("DEV 1-4 slot F1/F2 hurt F3 kill P1 F4 new F5 save F6 delete F7 dmg primary F8 dmg both F9 hud F10 close F11 next lvl")
	_label.text = "\n".join(lines)
