class_name WorldDefinition
extends Resource
## One world: an ordered list of four main levels and its presentation.

@export var id := ""
@export var title := ""
@export var theme := ""
## AudioConfig track id for every level of this world (a level may override it).
@export var music_track := ""
@export var levels: Array[LevelDefinition] = []
