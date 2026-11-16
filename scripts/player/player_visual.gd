class_name PlayerVisual
extends Node2D
## Visual-only presentation for the Player scene.
##
## Owns no gameplay state. The Player's tile and position are owned by
## KitchenController; whoever places this node (see PROGRESS.md notes) just
## sets its position. This script only plays optional visual animations.

@onready var _animation_player: AnimationPlayer = $Visual/AnimationPlayer


## Plays a visual animation by name. Returns false (no error) when the
## animation is not authored yet, so the scene works without final art.
func play_visual_animation(animation_name: StringName) -> bool:
	if not _animation_player.has_animation(animation_name):
		return false

	_animation_player.play(animation_name)
	return true
