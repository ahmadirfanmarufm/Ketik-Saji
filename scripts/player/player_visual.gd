class_name PlayerVisual
extends Node2D
## Visual-only presentation for the Player scene.
##
## Owns no gameplay state. KitchenController remains authoritative for the
## logical player tile; this node animates only child visual offsets cleanly
## toward the authoritative destination without introducing position drift.

const BASE_MOVE_DURATION: float = 0.08
const PIXELS_PER_SECOND: float = 420.0
const MIN_MOVE_DURATION: float = 0.10
const MAX_MOVE_DURATION: float = 0.24

@onready var _visual: Node2D = $Visual
@onready var _animation_player: AnimationPlayer = $Visual/AnimationPlayer
@onready var _visual_anchor: Marker2D = $VisualAnchor
@onready var _held_item_visual: Node2D = $VisualAnchor/HeldItemVisual

var _base_anchor_pos: Vector2 = Vector2(0, -22)
var _move_tween: Tween = null


func _ready() -> void:
	if _visual_anchor != null:
		_base_anchor_pos = _visual_anchor.position


func _exit_tree() -> void:
	_kill_move_tween()


## Moves `Player` immediately to `target_global_pos` while smoothly
## interpolating child visuals from their previous screen position.
func move_to_global(target_global_pos: Vector2, animate: bool = true) -> void:
	var prev_visual_global := get_visual_global_position()
	_kill_move_tween()
	global_position = target_global_pos

	if not animate or not is_inside_tree() or _visual == null:
		snap_to_destination()
		return

	var offset := prev_visual_global - target_global_pos
	if offset.length() < 1.0:
		snap_to_destination()
		return

	_visual.position = offset
	if _visual_anchor != null:
		_visual_anchor.position = _base_anchor_pos + offset

	var duration := clampf(
		BASE_MOVE_DURATION + offset.length() / PIXELS_PER_SECOND,
		MIN_MOVE_DURATION,
		MAX_MOVE_DURATION
	)
	_move_tween = create_tween()
	_move_tween.set_parallel(true)
	_move_tween.set_trans(Tween.TRANS_CUBIC)
	_move_tween.set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(_visual, "position", Vector2.ZERO, duration)
	if _visual_anchor != null:
		_move_tween.tween_property(_visual_anchor, "position", _base_anchor_pos, duration)


func snap_to_destination() -> void:
	_kill_move_tween()
	if _visual != null:
		_visual.position = Vector2.ZERO
	if _visual_anchor != null:
		_visual_anchor.position = _base_anchor_pos


func is_moving_visually() -> bool:
	return _move_tween != null and _move_tween.is_valid() and _move_tween.is_running()


func get_visual_global_position() -> Vector2:
	if _visual != null and is_instance_valid(_visual):
		return _visual.global_position
	return global_position


func _kill_move_tween() -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null


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
