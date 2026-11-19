class_name TutorialGuidanceOverlay
extends Control
## Non-blocking in-world visual guidance layer owned by GameUI.
##
## Draws pulsating target highlights, animated directional arrows, step markers,
## and short command badges over world or UI targets without intercepting
## pointer clicks, stealing keyboard focus, or mutating gameplay state.

const PULSE_SPEED: float = 4.2
const ARROW_BOB_SPEED: float = 5.5
const ARROW_BOB_PX: float = 3.0
const ARROW_LENGTH: float = 11.0
const ARROW_HALF_WIDTH: float = 5.5
const CALLOUT_GAP_PX: float = 6.0
const CALLOUT_PAD_X: float = 6.0
const CALLOUT_PAD_Y: float = 3.0
const CALLOUT_FONT_SIZE: int = 9
const MARKER_FONT_SIZE: int = 8

var _active: bool = false
var _paused: bool = false
var _target_id: StringName = &""
var _target_rect: Rect2 = Rect2()
var _avoid_rect: Rect2 = Rect2()
var _bounds_rect: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)
var _badge_text: String = ""
var _marker_number: String = ""
var _accent_color: Color = Color(0.32, 0.96, 0.62, 1.0)
var _pulse_time: float = 0.0

var _pointer_side: StringName = &"top"
var _pointer_tip: Vector2 = Vector2.ZERO
var _callout_rect: Rect2 = Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func _process(delta: float) -> void:
	if not _active or not visible or _paused:
		return
	_pulse_time += maxf(0.0, delta)
	queue_redraw()


## Updates the active guidance visual target in canvas coordinates.
func set_guidance(
	target_id: StringName,
	target_rect: Rect2,
	bounds_rect: Rect2,
	badge_text: String,
	marker_number: String,
	accent_color: Color,
	avoid_rect: Rect2 = Rect2(),
	paused: bool = false
) -> void:
	if target_id == &"" or target_rect.size.x <= 0.0 or target_rect.size.y <= 0.0:
		clear_guidance()
		return
	var target_changed := (_target_id != target_id or _badge_text != badge_text)
	_active = true
	_paused = paused
	_target_id = target_id
	_target_rect = target_rect
	_bounds_rect = bounds_rect
	_badge_text = badge_text
	_marker_number = marker_number
	_accent_color = accent_color
	_avoid_rect = avoid_rect
	if target_changed:
		_pulse_time = 0.0
	_recompute_callout_placement()
	visible = true
	queue_redraw()


func clear_guidance() -> void:
	if not _active and not visible:
		return
	_active = false
	_target_id = &""
	_target_rect = Rect2()
	_avoid_rect = Rect2()
	_badge_text = ""
	_marker_number = ""
	_callout_rect = Rect2()
	_pointer_tip = Vector2.ZERO
	visible = false
	queue_redraw()


func is_guidance_active() -> bool:
	return _active and visible


func get_target_id() -> StringName:
	return _target_id if _active else &""


func get_target_rect() -> Rect2:
	return _target_rect if _active else Rect2()


func get_callout_rect() -> Rect2:
	return _callout_rect if _active else Rect2()


func get_pointer_tip() -> Vector2:
	return _pointer_tip if _active else Vector2.ZERO


func get_badge_text() -> String:
	return _badge_text if _active else ""


func get_marker_number() -> String:
	return _marker_number if _active else ""


func get_pointer_side() -> StringName:
	return _pointer_side


func get_accent_color() -> Color:
	return _accent_color


func _recompute_callout_placement() -> void:
	var font := get_theme_default_font()
	var text_size := (
		font.get_string_size(_badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, CALLOUT_FONT_SIZE)
		if font != null and not _badge_text.is_empty()
		else Vector2(float(_badge_text.length()) * 5.5, 11.0)
	)
	var badge_size := Vector2(
		ceilf(text_size.x + CALLOUT_PAD_X * 2.0),
		ceilf(maxf(text_size.y, 11.0) + CALLOUT_PAD_Y * 2.0)
	)

	var best_side := _pick_pointer_side(badge_size)
	_pointer_side = best_side
	var center := _target_rect.get_center()
	var raw_pos := Vector2.ZERO
	var gap := ARROW_LENGTH + CALLOUT_GAP_PX

	match best_side:
		&"top":
			_pointer_tip = Vector2(center.x, _target_rect.position.y - 2.0)
			raw_pos = Vector2(
				center.x - badge_size.x * 0.5,
				_target_rect.position.y - gap - badge_size.y
			)
		&"bottom":
			_pointer_tip = Vector2(center.x, _target_rect.end.y + 2.0)
			raw_pos = Vector2(
				center.x - badge_size.x * 0.5,
				_target_rect.end.y + gap
			)
		&"left":
			_pointer_tip = Vector2(_target_rect.position.x - 2.0, center.y)
			raw_pos = Vector2(
				_target_rect.position.x - gap - badge_size.x,
				center.y - badge_size.y * 0.5
			)
		_:
			_pointer_tip = Vector2(_target_rect.end.x + 2.0, center.y)
			raw_pos = Vector2(
				_target_rect.end.x + gap,
				center.y - badge_size.y * 0.5
			)

	var min_x := _bounds_rect.position.x + 3.0
	var max_x := maxf(min_x, _bounds_rect.end.x - badge_size.x - 3.0)
	var min_y := _bounds_rect.position.y + 3.0
	var max_y := maxf(min_y, _bounds_rect.end.y - badge_size.y - 3.0)
	var clamped_pos := Vector2(clampf(raw_pos.x, min_x, max_x), clampf(raw_pos.y, min_y, max_y))
	_callout_rect = Rect2(clamped_pos, badge_size)
	if _avoid_rect.size.x > 0.0 and _avoid_rect.size.y > 0.0 and _callout_rect.intersects(_avoid_rect):
		var above_y := _avoid_rect.position.y - badge_size.y - 6.0
		if above_y >= min_y:
			clamped_pos.y = above_y
			_callout_rect = Rect2(clamped_pos, badge_size)
			if best_side == &"left" or best_side == &"right":
				_pointer_tip.y = clamped_pos.y + badge_size.y * 0.5


func _pick_pointer_side(badge_size: Vector2) -> StringName:
	var gap := ARROW_LENGTH + CALLOUT_GAP_PX
	var has_avoid := _avoid_rect.size.x > 0.0 and _avoid_rect.size.y > 0.0
	var candidates: Array[StringName] = [&"top", &"bottom", &"left", &"right"]
	for side in candidates:
		var cand_rect := _estimate_side_rect(side, badge_size, gap)
		if (
			cand_rect.position.x >= _bounds_rect.position.x + 2.0
			and cand_rect.position.y >= _bounds_rect.position.y + 2.0
			and cand_rect.end.x <= _bounds_rect.end.x - 2.0
			and cand_rect.end.y <= _bounds_rect.end.y - 2.0
		):
			if not has_avoid or not cand_rect.intersects(_avoid_rect):
				return side

	for side in candidates:
		var cand_rect := _estimate_side_rect(side, badge_size, gap)
		if (
			cand_rect.position.y >= _bounds_rect.position.y + 2.0
			and cand_rect.end.y <= _bounds_rect.end.y - 2.0
		):
			if not has_avoid or not cand_rect.intersects(_avoid_rect):
				return side
	return &"bottom" if _target_rect.position.y < _bounds_rect.position.y + 44.0 else &"top"


func _estimate_side_rect(side: StringName, badge_size: Vector2, gap: float) -> Rect2:
	var c := _target_rect.get_center()
	match side:
		&"top":
			return Rect2(
				c.x - badge_size.x * 0.5,
				_target_rect.position.y - gap - badge_size.y,
				badge_size.x,
				badge_size.y
			)
		&"bottom":
			return Rect2(
				c.x - badge_size.x * 0.5,
				_target_rect.end.y + gap,
				badge_size.x,
				badge_size.y
			)
		&"left":
			return Rect2(
				_target_rect.position.x - gap - badge_size.x,
				c.y - badge_size.y * 0.5,
				badge_size.x,
				badge_size.y
			)
		_:
			return Rect2(
				_target_rect.end.x + gap,
				c.y - badge_size.y * 0.5,
				badge_size.x,
				badge_size.y
			)


func _draw() -> void:
	if not _active:
		return

	var pulse := 0.5 + 0.5 * sin(_pulse_time * PULSE_SPEED)
	var bob := (0.5 + 0.5 * sin(_pulse_time * ARROW_BOB_SPEED)) * ARROW_BOB_PX

	# 1. Soft glow wash and crisp inner + pulsating outer highlight rings.
	var fill_col := Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.12 + 0.08 * pulse)
	var inner_rect := _target_rect.grow(1.0)
	var outer_rect := _target_rect.grow(2.0 + 2.5 * pulse)
	draw_rect(inner_rect, fill_col, true)
	draw_rect(inner_rect, Color(0.04, 0.06, 0.09, 0.85), false, 3.0)
	draw_rect(inner_rect, _accent_color, false, 1.5)
	var outer_col := Color(
		_accent_color.r, _accent_color.g, _accent_color.b, 0.35 + 0.55 * (1.0 - pulse)
	)
	draw_rect(outer_rect, outer_col, false, 1.2)

	# 2. Small numbered step marker on the top-left corner of the highlight.
	var font := get_theme_default_font()
	if not _marker_number.is_empty() and font != null:
		var marker_size := Vector2(maxf(14.0, float(_marker_number.length()) * 6.0 + 6.0), 13.0)
		var marker_pos := Vector2(
			clampf(inner_rect.position.x - 4.0, _bounds_rect.position.x + 2.0, _bounds_rect.end.x - marker_size.x - 2.0),
			clampf(inner_rect.position.y - 6.0, _bounds_rect.position.y + 2.0, _bounds_rect.end.y - marker_size.y - 2.0)
		)
		var marker_rect := Rect2(marker_pos, marker_size)
		draw_rect(marker_rect, Color(0.06, 0.09, 0.14, 0.96), true)
		draw_rect(marker_rect, _accent_color, false, 1.2)
		draw_string(
			font,
			marker_pos + Vector2(3.0, 10.0),
			_marker_number,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			MARKER_FONT_SIZE,
			_accent_color
		)

	# 3. Animated directional arrow pointing straight at target_rect.
	var dir := _get_pointer_direction(_pointer_side)
	var tip := _pointer_tip - dir * bob
	var base := tip - dir * ARROW_LENGTH
	var perp := Vector2(-dir.y, dir.x) * ARROW_HALF_WIDTH
	var tri := PackedVector2Array([tip, base + perp, base - perp])
	draw_colored_polygon(tri, Color(0.05, 0.07, 0.11, 0.95))
	var inset_tri := PackedVector2Array([
		tip - dir * 1.5,
		base + perp * 0.72 + dir * 1.0,
		base - perp * 0.72 + dir * 1.0,
	])
	draw_colored_polygon(inset_tri, _accent_color)

	# 4. Short contextual command badge near the arrow tail.
	if not _badge_text.is_empty() and _callout_rect.size.x > 0.0:
		draw_rect(_callout_rect, Color(0.06, 0.08, 0.13, 0.95), true)
		draw_rect(_callout_rect, _accent_color, false, 1.2)
		if font != null:
			draw_string(
				font,
				_callout_rect.position + Vector2(CALLOUT_PAD_X, _callout_rect.size.y - CALLOUT_PAD_Y - 1.0),
				_badge_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				CALLOUT_FONT_SIZE,
				Color(0.96, 0.98, 1.0, 1.0)
			)


func _get_pointer_direction(side: StringName) -> Vector2:
	match side:
		&"top":
			return Vector2.DOWN
		&"bottom":
			return Vector2.UP
		&"left":
			return Vector2.RIGHT
		_:
			return Vector2.LEFT
