class_name UiConfig
extends Resource
## Presentation settings (resources/config/ui_config.tres). The game has no final title yet,
## so the displayed title is configured here and defaults to a placeholder.

## Shown on the main menu and as the window title. Placeholder until a title is chosen.
@export var game_title := "UNTITLED"
@export var subtitle := "A cooperative adventure for two knights"
## Shown small in a corner of the main menu.
@export var version_label := "development build (overhaul)"
## Seconds of the fade between the menu and gameplay.
@export_range(0.0, 2.0) var fade_seconds := 0.25
