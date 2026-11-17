class_name PlayerVisual
extends Node2D
## Visual-only presentation for the Player scene.
##
## Owns no gameplay state. The Player's tile and position are owned by
## KitchenController; whoever places this node (see PROGRESS.md notes) just
## sets its position. This script only plays optional visual animations.

@onready var _animation_player: AnimationPlayer = $Visual/AnimationPlayer
@onready var _held_item_visual: Node2D = $VisualAnchor/HeldItemVisual


## Plays a visual animation by name. Returns false (no error) when the
## animation is not authored yet, so the scene works without final art.
func play_visual_animation(animation_name: StringName) -> bool:
	if not _animation_player.has_animation(animation_name):
		return false

	_animation_player.play(animation_name)
	return true


## Updates the held-item visual above the player from read-only controller state.
func sync_held_item_visual(
	has_item: bool,
	is_plated: bool,
	part_textures: Array[Texture2D]
) -> void:
	if _held_item_visual == null:
		return
	WorldMap.sync_food_item_visual(_held_item_visual, has_item, is_plated, part_textures)
