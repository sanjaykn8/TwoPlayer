class_name CampaignDefinition
extends Resource
## A whole campaign: worlds in order, each with its levels in order. The registry behind
## LevelCatalog. `development` marks the two-level test campaign used by Phase 8-9 tests.

@export var id := ""
@export var title := ""
@export var development := false
@export var worlds: Array[WorldDefinition] = []
