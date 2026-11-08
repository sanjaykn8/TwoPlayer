class_name LevelDefinition
extends Resource
## One main campaign level (resources/campaign/*.tres, written by the campaign builder).
## The scene path lives here, in the trusted registry; save files only ever hold `id`.

@export var id := ""
@export var title := ""
@export var world_id := ""
## 1-based position in the whole campaign.
@export var order := 0
@export_file("*.tscn") var scene_path := ""
## 1 (gentle) to 10 (hardest).
@export_range(1, 10) var difficulty := 1
## Planned successful first-play minutes for two players (a design estimate, not a measurement).
@export var estimated_minutes := 4.0
## AudioConfig track id; "" uses the world's track.
@export var music_track := ""
@export var theme := ""
@export var spawn_p1 := Vector2.ZERO
@export var spawn_p2 := Vector2.ZERO
@export var camera_bounds := Rect2()
## How the level is completed. Only "exit" exists: either living knight reaching the exit.
@export var completion := "exit"
## Collectible / boss ids that are optional (never needed to finish the level).
@export var optional_content: PackedStringArray = []
## Optional boss id in this level ("" = none).
@export var boss_id := ""
## Version of the level's layout. Saves record it; a mid-level save made with another layout
## version starts the level from its spawn instead (run progress is kept).
@export var layout_version := 1
