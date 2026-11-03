class_name PlatformController
extends Node
## Lets a puzzle drive an existing Phase 6 platform; the platform's own physics (riders
## carried by AnimatableBody2D) is untouched. `platform` is a MovingPlatform or TimedPlatform,
## `controller` any PuzzleSource.
##   RUN_WHILE_ACTIVE     MovingPlatform: ping-pongs only while active, freezes in place otherwise
##   EXTEND_WHILE_ACTIVE  MovingPlatform: travels to its far end while active, back when not
##   TRIGGER              TimedPlatform: each activation calls activate() (one solid cycle);
##                        MovingPlatform: each activation sends it to the other end

enum Mode { RUN_WHILE_ACTIVE, EXTEND_WHILE_ACTIVE, TRIGGER }

@export var platform: NodePath
@export var controller: NodePath
@export var mode := Mode.RUN_WHILE_ACTIVE

var _platform: PlatformBody
var _source: PuzzleSource
var triggers := 0


func _ready() -> void:
	_platform = get_node_or_null(platform) as PlatformBody
	_source = get_node_or_null(controller) as PuzzleSource
	if _platform == null or _source == null:
		if owner != null:  # placed in a level but not wired up (standalone instancing is fine)
			push_error("%s: needs a PlatformBody `platform` and a PuzzleSource `controller`" % get_path())
		return
	_source.changed.connect(_apply)
	_source.pulsed.connect(_on_pulsed.unbind(1))
	# Deferred: the platform (and a restored lock) must finish _ready() first.
	_apply.call_deferred(_source.is_active(), true)


func target() -> PlatformBody:
	return _platform


func _apply(active: bool, initial := false) -> void:
	var moving := _platform as MovingPlatform
	match mode:
		Mode.RUN_WHILE_ACTIVE:
			if moving != null:
				moving.set_running(active)
		Mode.EXTEND_WHILE_ACTIVE:
			if moving != null:
				if initial:
					moving.snap_to(1.0 if active else 0.0)
				else:
					moving.move_to(1.0 if active else 0.0)


func _on_pulsed() -> void:
	if mode != Mode.TRIGGER:
		return
	triggers += 1
	if _platform is TimedPlatform:
		(_platform as TimedPlatform).activate()
	elif _platform is MovingPlatform:
		var moving := _platform as MovingPlatform
		moving.move_to(0.0 if moving.target_progress >= 0.5 or (moving.target_progress < 0.0 and moving.progress >= 0.5) else 1.0)
