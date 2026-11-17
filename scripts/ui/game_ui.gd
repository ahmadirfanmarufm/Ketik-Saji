class_name GameUI
extends CanvasLayer
## Presentation and input-forwarding layer for Ketik Saji.
##
## Owns only UI presentation state (active feedback message, invalid-key shake
## timer, and static Indonesian display labels). Never owns or mutates cash,
## phase, service clock, inventory, orders, or day progression directly.

const LOGICAL_VIEWPORT_SIZE: Vector2 = Vector2(640.0, 360.0)
const DIALOGUE_ABOVE_OFFSET: float = 20.0
const DIALOGUE_BELOW_OFFSET: float = 20.0
const DIALOGUE_MARGIN: float = 4.0
const SHAKE_DURATION: float = 0.12
const SHAKE_OFFSET_PX: float = 4.0
const PREFIX_HIGHLIGHT_COLOR: Color = Color(1.0, 0.92, 0.35, 1.0)
const PREFIX_IDLE_COLOR: Color = Color(0.85, 0.90, 1.0, 1.0)

const TARGET_LABELS: Dictionary[StringName, String] = {
	&"storage_box": "Kotak Bahan",
	&"fridge": "Kulkas",
	&"stove": "Kompor",
	&"washer": "Wastafel",
	&"plate_rack": "Rak Piring",
	&"rice_cooker": "Penanak Nasi",
	&"trash": "Tempat Sampah",
	&"work_table": "Meja Kerja",
	&"work_table_stage": "Meja Kerja (Susun)",
	&"work_table_chop": "Talenan (Potong)",
	&"dining_table_01": "Meja Makan 1",
	&"dining_table_02": "Meja Makan 2",
	&"online_station": "Stasiun Online",
}

const PHASE_LABELS: Dictionary[int, String] = {
	SharedTypes.Phase.PLANNING: "Perencanaan",
	SharedTypes.Phase.SERVING: "Layanan",
	SharedTypes.Phase.CLOSING: "Penutupan",
	SharedTypes.Phase.RESULTS: "Hasil",
	SharedTypes.Phase.FINISHED: "Selesai",
}

const FEEDBACK_LABELS: Dictionary[StringName, String] = {
	&"invalid_key": "Huruf tidak cocok",
	&"tile_blocked": "Lantai tidak bisa dilewati",
	&"unknown_target": "Target tidak dikenal",
	&"unreachable_target": "Tidak ada akses di sebelahnya",
	&"start_service_failed": "Tidak bisa mulai layanan",
	&"hand_full": "Tangan penuh",
	&"out_of_stock": "Bahan habis",
	&"wrong_order": "Pesanannya beda!",
	&"invalid_action": "Nggak bisa sekarang",
	&"item_taken": "Bahan diambil",
	&"item_washed": "Bahan dicuci",
	&"plate_washed": "Piring bersih diambil",
	&"item_cooked": "Bahan digoreng",
	&"rice_cooked": "Nasi dimasak",
	&"rice_taken": "Nasi diambil",
	&"item_chopped": "Bahan dipotong",
	&"plate_taken": "Piring diambil",
	&"plate_returned": "Piring dikembalikan",
	&"no_plates": "Piring habis",
	&"item_staged": "Ditaruh di meja",
	&"item_picked_up": "Diambil dari meja",
	&"item_merged": "Ditambahkan ke piring",
	&"dish_ready": "Hidangan siap disajikan!",
	&"invalid_merge": "Tidak bisa digabung",
	&"cooker_full": "Penanak nasi penuh",
	&"cooker_empty": "Belum ada nasi",
	&"item_trashed": "Bahan dibuang",
	&"order_served": "Pesanan disajikan!",
	&"order_expired": "Waktu pesanan habis",
	&"table_cleaned": "Meja dibersihkan",
}

@export var ui_safe_rect: Rect2 = Rect2(0.0, 0.0, 112.0, 360.0)
@export var world_visible_rect: Rect2 = Rect2(112.0, 0.0, 528.0, 360.0)

var _game_root: Node = null
var _world_map: WorldMap = null
var _kitchen_controller: KitchenController = null
var _service_controller: ServiceController = null
var _run_controller: RunController = null

var _feedback_code: StringName = &""
var _feedback_text: String = ""
var _shake_remaining: float = 0.0
var _modal_blocking_active: bool = false

@onready var ui_root: Control = $UIRoot
@onready var left_hud_region: PanelContainer = $UIRoot/LeftHUDRegion
@onready var day_label: Label = $UIRoot/LeftHUDRegion/HUDColumn/DayLabel
@onready var phase_label: Label = $UIRoot/LeftHUDRegion/HUDColumn/PhaseLabel
@onready var cash_label: Label = $UIRoot/LeftHUDRegion/HUDColumn/CashLabel
@onready var goal_label: Label = $UIRoot/LeftHUDRegion/HUDColumn/GoalLabel
@onready var goal_progress_bar: ProgressBar = $UIRoot/LeftHUDRegion/HUDColumn/GoalProgressBar
@onready var planning_box: VBoxContainer = $UIRoot/LeftHUDRegion/HUDColumn/PlanningBox
@onready var forecast_quota_label: Label = (
	$UIRoot/LeftHUDRegion/HUDColumn/PlanningBox/ForecastQuotaLabel
)
@onready var start_service_button: Button = (
	$UIRoot/LeftHUDRegion/HUDColumn/PlanningBox/StartServiceButton
)
@onready var service_box: VBoxContainer = $UIRoot/LeftHUDRegion/HUDColumn/ServiceBox
@onready var service_elapsed_label: Label = (
	$UIRoot/LeftHUDRegion/HUDColumn/ServiceBox/ServiceElapsedLabel
)
@onready var unspawned_quota_label: Label = (
	$UIRoot/LeftHUDRegion/HUDColumn/ServiceBox/UnspawnedQuotaLabel
)

@onready var interaction_dialogue: PanelContainer = $UIRoot/InteractionDialogue
@onready var target_title_label: Label = (
	$UIRoot/InteractionDialogue/DialogueColumn/TargetTitleLabel
)
@onready var allowed_commands_label: Label = (
	$UIRoot/InteractionDialogue/DialogueColumn/AllowedCommandsLabel
)
@onready var prefix_prompt_label: Label = (
	$UIRoot/InteractionDialogue/DialogueColumn/PrefixPromptLabel
)
@onready var remaining_prompt_label: Label = (
	$UIRoot/InteractionDialogue/DialogueColumn/RemainingPromptLabel
)
@onready var context_message_label: Label = (
	$UIRoot/InteractionDialogue/DialogueColumn/ContextMessage
)

@onready var day_result_side_panel: PanelContainer = $UIRoot/DayResultSidePanel
@onready var result_title_label: Label = (
	$UIRoot/DayResultSidePanel/ResultColumn/ResultTitleLabel
)
@onready var settlement_summary_label: Label = (
	$UIRoot/DayResultSidePanel/ResultColumn/SettlementSummaryLabel
)
@onready var continue_button: Button = $UIRoot/DayResultSidePanel/ResultColumn/ContinueButton
@onready var extra_mode_button: Button = $UIRoot/DayResultSidePanel/ResultColumn/ExtraModeButton


func _ready() -> void:
	_connect_ui_buttons()
	_refresh_all()


func _process(delta: float) -> void:
	if (
		_game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_method(&"is_serving")
	):
		if _game_root.is_serving():
			if service_elapsed_label != null:
				var elapsed := float(_game_root.get_service_elapsed())
				service_elapsed_label.text = "Waktu: %.1f dtk" % elapsed
			_refresh_dine_in_visuals()
			if _feedback_text.is_empty() and _is_selected_target_dining_table():
				_refresh_dialogue()

	if _shake_remaining > 0.0:
		_shake_remaining = maxf(0.0, _shake_remaining - maxf(0.0, delta))
		_update_dialogue_position()


## Binds GameRoot, WorldMap, and controller references once per wiring pass,
## disconnecting any prior references so signals are never duplicated.
func bind_context(
	game_root: Node,
	world_map: WorldMap,
	kitchen: KitchenController,
	service: ServiceController,
	run: RunController
) -> void:
	_disconnect_context_signals()
	_game_root = game_root
	_world_map = world_map
	_kitchen_controller = kitchen
	_service_controller = service
	_run_controller = run
	_connect_context_signals()
	if is_node_ready():
		_refresh_all()


## Sets explicit modal blocking state (for overlays/tests that block world/typing input).
func set_modal_blocking(active: bool) -> void:
	_modal_blocking_active = active


func is_modal_blocking() -> bool:
	if _modal_blocking_active:
		return true
	if day_result_side_panel != null and day_result_side_panel.visible:
		return true
	return false


func get_target_display_title(target_id: StringName) -> String:
	if target_id == &"":
		return ""
	return TARGET_LABELS.get(target_id, String(target_id))


func get_feedback_code() -> StringName:
	return _feedback_code


func is_shaking() -> bool:
	return _shake_remaining > 0.0


func _unhandled_input(event: InputEvent) -> void:
	var mouse_btn := event as InputEventMouseButton
	if mouse_btn == null or not mouse_btn.pressed:
		return
	if mouse_btn.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _is_world_click_phase():
		return

	var canvas_pos: Vector2 = mouse_btn.position
	if _is_point_blocked_by_ui(canvas_pos):
		return
	if _world_map == null or _world_map.grid == null or _world_map.registry == null:
		return
	if _kitchen_controller == null:
		return

	var world_global_pos: Vector2 = (
		_world_map.get_canvas_transform().affine_inverse() * canvas_pos
	)
	_release_button_focus_if_any()
	_clear_feedback_state()
	var hit_target_id := _hit_test_interactable(world_global_pos)
	if hit_target_id != &"":
		_kitchen_controller.on_interactable_clicked(hit_target_id)
	else:
		var cell := _world_map.global_to_cell(world_global_pos)
		_kitchen_controller.on_floor_clicked(cell)
	_refresh_dialogue()

	if is_inside_tree() and get_viewport() != null:
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed:
		return
	if not _is_serving_phase():
		return
	if _is_keyboard_blocked_by_focus_or_modal():
		return
	if _kitchen_controller == null:
		return

	if key_event.keycode == KEY_ESCAPE:
		_clear_feedback_state()
		_kitchen_controller.clear_command_prefix()
		_refresh_dialogue()
		if is_inside_tree() and get_viewport() != null:
			get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_BACKSPACE:
		_clear_feedback_state()
		_kitchen_controller.backspace_command_prefix()
		_refresh_dialogue()
		if is_inside_tree() and get_viewport() != null:
			get_viewport().set_input_as_handled()
		return

	var ch := _extract_typed_character(key_event)
	if not ch.is_empty():
		_kitchen_controller.accept_typed_character(ch)
		if is_inside_tree() and get_viewport() != null:
			get_viewport().set_input_as_handled()


func _extract_typed_character(key_event: InputEventKey) -> String:
	if key_event == null:
		return ""
	if (
		key_event.keycode == KEY_ENTER
		or key_event.keycode == KEY_KP_ENTER
		or key_event.keycode == KEY_TAB
		or key_event.keycode == KEY_SPACE
		or key_event.keycode == KEY_DELETE
	):
		return ""
	if key_event.unicode > 32 and key_event.unicode != 127:
		return String.chr(key_event.unicode).to_lower()
	var kc: int = key_event.keycode
	if kc == KEY_NONE:
		kc = key_event.physical_keycode
	if kc >= KEY_A and kc <= KEY_Z:
		return String.chr(kc).to_lower()
	return ""


func _clear_feedback_state() -> void:
	_feedback_code = &""
	_feedback_text = ""
	_shake_remaining = 0.0


func _connect_ui_buttons() -> void:
	if start_service_button != null:
		if not start_service_button.pressed.is_connected(_on_start_service_pressed):
			start_service_button.pressed.connect(_on_start_service_pressed)
	if continue_button != null:
		if not continue_button.pressed.is_connected(_on_continue_pressed):
			continue_button.pressed.connect(_on_continue_pressed)
	if extra_mode_button != null:
		if not extra_mode_button.pressed.is_connected(_on_extra_mode_pressed):
			extra_mode_button.pressed.connect(_on_extra_mode_pressed)


func _connect_context_signals() -> void:
	if _game_root != null and is_instance_valid(_game_root):
		if _game_root.has_signal(&"phase_changed"):
			if not _game_root.is_connected(&"phase_changed", _on_phase_changed):
				_game_root.connect(&"phase_changed", _on_phase_changed)

	if _kitchen_controller != null and is_instance_valid(_kitchen_controller):
		if not _kitchen_controller.player_tile_changed.is_connected(_on_player_tile_changed):
			_kitchen_controller.player_tile_changed.connect(_on_player_tile_changed)
		if not _kitchen_controller.selected_interactable_changed.is_connected(
			_on_selected_interactable_changed
		):
			_kitchen_controller.selected_interactable_changed.connect(
				_on_selected_interactable_changed
			)
		if not _kitchen_controller.command_prefix_changed.is_connected(_on_command_prefix_changed):
			_kitchen_controller.command_prefix_changed.connect(_on_command_prefix_changed)
		if not _kitchen_controller.action_feedback.is_connected(_on_action_feedback):
			_kitchen_controller.action_feedback.connect(_on_action_feedback)
		if not _kitchen_controller.kitchen_state_changed.is_connected(_on_kitchen_state_changed):
			_kitchen_controller.kitchen_state_changed.connect(_on_kitchen_state_changed)

	if _service_controller != null and is_instance_valid(_service_controller):
		if not _service_controller.orders_changed.is_connected(_on_orders_changed):
			_service_controller.orders_changed.connect(_on_orders_changed)
		if not _service_controller.queues_changed.is_connected(_on_queues_changed):
			_service_controller.queues_changed.connect(_on_queues_changed)
		if not _service_controller.tables_changed.is_connected(_on_tables_changed):
			_service_controller.tables_changed.connect(_on_tables_changed)
		if not _service_controller.drivers_changed.is_connected(_on_drivers_changed):
			_service_controller.drivers_changed.connect(_on_drivers_changed)

	if _run_controller != null and is_instance_valid(_run_controller):
		if not _run_controller.run_state_changed.is_connected(_on_run_state_changed):
			_run_controller.run_state_changed.connect(_on_run_state_changed)


func _disconnect_context_signals() -> void:
	if _game_root != null and is_instance_valid(_game_root):
		if _game_root.has_signal(&"phase_changed"):
			if _game_root.is_connected(&"phase_changed", _on_phase_changed):
				_game_root.disconnect(&"phase_changed", _on_phase_changed)

	if _kitchen_controller != null and is_instance_valid(_kitchen_controller):
		if _kitchen_controller.player_tile_changed.is_connected(_on_player_tile_changed):
			_kitchen_controller.player_tile_changed.disconnect(_on_player_tile_changed)
		if _kitchen_controller.selected_interactable_changed.is_connected(
			_on_selected_interactable_changed
		):
			_kitchen_controller.selected_interactable_changed.disconnect(
				_on_selected_interactable_changed
			)
		if _kitchen_controller.command_prefix_changed.is_connected(_on_command_prefix_changed):
			_kitchen_controller.command_prefix_changed.disconnect(_on_command_prefix_changed)
		if _kitchen_controller.action_feedback.is_connected(_on_action_feedback):
			_kitchen_controller.action_feedback.disconnect(_on_action_feedback)
		if _kitchen_controller.kitchen_state_changed.is_connected(_on_kitchen_state_changed):
			_kitchen_controller.kitchen_state_changed.disconnect(_on_kitchen_state_changed)

	if _service_controller != null and is_instance_valid(_service_controller):
		if _service_controller.orders_changed.is_connected(_on_orders_changed):
			_service_controller.orders_changed.disconnect(_on_orders_changed)
		if _service_controller.queues_changed.is_connected(_on_queues_changed):
			_service_controller.queues_changed.disconnect(_on_queues_changed)
		if _service_controller.tables_changed.is_connected(_on_tables_changed):
			_service_controller.tables_changed.disconnect(_on_tables_changed)
		if _service_controller.drivers_changed.is_connected(_on_drivers_changed):
			_service_controller.drivers_changed.disconnect(_on_drivers_changed)

	if _run_controller != null and is_instance_valid(_run_controller):
		if _run_controller.run_state_changed.is_connected(_on_run_state_changed):
			_run_controller.run_state_changed.disconnect(_on_run_state_changed)


func _on_start_service_pressed() -> void:
	if _game_root == null or not is_instance_valid(_game_root):
		return
	if not _game_root.has_method(&"start_service_requested"):
		return
	if not _game_root.start_service_requested():
		_show_feedback(&"start_service_failed")


func _on_continue_pressed() -> void:
	if _game_root == null or not is_instance_valid(_game_root):
		return
	if _game_root.has_method(&"request_continue_from_results"):
		_game_root.request_continue_from_results()


func _on_extra_mode_pressed() -> void:
	if _game_root == null or not is_instance_valid(_game_root):
		return
	if _game_root.has_method(&"request_extra_mode"):
		_game_root.request_extra_mode()


func _on_phase_changed(_phase: int, _day_index: int) -> void:
	_clear_feedback_state()
	_refresh_all()


func _on_player_tile_changed(_tile: Vector2i) -> void:
	_update_dialogue_position()


func _on_selected_interactable_changed(_target_id: StringName) -> void:
	_clear_feedback_state()
	_refresh_dialogue()


func _on_command_prefix_changed(_prefix: String) -> void:
	_clear_feedback_state()
	_refresh_dialogue()


func _on_action_feedback(code: StringName) -> void:
	_show_feedback(code)


func _on_kitchen_state_changed() -> void:
	_refresh_kitchen_visuals()
	_refresh_dialogue()


func _on_queues_changed() -> void:
	_refresh_hud()
	_refresh_dine_in_visuals()


func _on_orders_changed() -> void:
	_refresh_dine_in_visuals()
	if _is_selected_target_dining_table():
		_refresh_dialogue()


func _on_tables_changed() -> void:
	_refresh_dine_in_visuals()
	if _is_selected_target_dining_table():
		_refresh_dialogue()


func _on_drivers_changed() -> void:
	_refresh_driver_visuals()


func _on_run_state_changed() -> void:
	_refresh_hud()
	_refresh_kitchen_visuals()
	_refresh_results_panel()


func _show_feedback(code: StringName) -> void:
	_feedback_code = code
	_feedback_text = FEEDBACK_LABELS.get(code, String(code))
	if code == &"invalid_key":
		_shake_remaining = SHAKE_DURATION
	_refresh_dialogue()


func _refresh_all() -> void:
	if not is_node_ready():
		return
	_refresh_hud()
	_refresh_kitchen_visuals()
	_refresh_dine_in_visuals()
	_refresh_driver_visuals()
	_refresh_dialogue()
	_refresh_results_panel()


func _refresh_kitchen_visuals() -> void:
	if _world_map == null or not is_instance_valid(_world_map):
		return
	if _kitchen_controller == null or not is_instance_valid(_kitchen_controller):
		return

	var held_view := _kitchen_controller.get_held_item_view()
	var held_has := not held_view.is_empty()
	var held_plated: bool = held_has and held_view.get("plate_id", &"") != &""
	var held_textures := _resolve_item_textures(held_view)
	var player_visual := _world_map.player as PlayerVisual
	if player_visual != null:
		player_visual.sync_held_item_visual(held_has, held_plated, held_textures)

	var table_view := _kitchen_controller.get_work_table_view(&"work_table")
	var table_has := not table_view.is_empty()
	var table_plated: bool = table_has and table_view.get("plate_id", &"") != &""
	var table_textures := _resolve_item_textures(table_view)

	var cooker_view := _kitchen_controller.get_cooker_output_view(&"rice_cooker")
	var cooker_has := not cooker_view.is_empty()
	var cooker_textures := _resolve_item_textures(cooker_view)
	var cooker_tex: Texture2D = cooker_textures[0] if not cooker_textures.is_empty() else null

	var rack_view := _kitchen_controller.get_plate_rack_view(&"plate_rack")
	var clean_plates := int(rack_view.get("clean_count", 0))
	var washer_view := _kitchen_controller.get_washer_view()
	var dirty_plates := int(washer_view.get("dirty_plate_count", 0))

	_world_map.sync_kitchen_visuals(
		table_has,
		table_plated,
		table_textures,
		cooker_has,
		cooker_tex,
		clean_plates,
		dirty_plates
	)


func _resolve_item_textures(item_view: Dictionary) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	if item_view.is_empty() or _kitchen_controller == null:
		return result
	var raw_parts: Variant = item_view.get("parts", [])
	if not (raw_parts is Array):
		return result
	for raw_part: Variant in raw_parts:
		if not (raw_part is Dictionary):
			continue
		var part: Dictionary = raw_part
		var ing_id := StringName(part.get("ingredient_id", &""))
		var prep_state := int(part.get("state", 0)) as SharedTypes.PrepState
		var def := _kitchen_controller.get_ingredient_def(ing_id)
		result.append(def.get_texture_for_state(prep_state) if def != null else null)
	return result


func _refresh_driver_visuals() -> void:
	if _world_map == null or not is_instance_valid(_world_map):
		return
	if _service_controller == null or not is_instance_valid(_service_controller):
		return
	_world_map.sync_driver_visuals(_service_controller.get_driver_views())


func _refresh_dine_in_visuals() -> void:
	if _world_map == null or not is_instance_valid(_world_map):
		return
	if _service_controller == null or not is_instance_valid(_service_controller):
		return

	var customer_views := _service_controller.get_customer_views()
	var table_views: Array[Dictionary] = []
	for table_id in _service_controller.get_registered_table_ids():
		table_views.append(_service_controller.get_table_view(table_id))

	var recipe_names: Dictionary = {}
	if _kitchen_controller != null and is_instance_valid(_kitchen_controller):
		for view: Dictionary in customer_views:
			var recipe_id := StringName(view.get("recipe_id", &""))
			if recipe_id == &"" or recipe_names.has(recipe_id):
				continue
			var def := _kitchen_controller.get_recipe_def(recipe_id)
			if def != null and not def.display_name.is_empty():
				recipe_names[recipe_id] = def.display_name

	_world_map.sync_dine_in_visuals(customer_views, table_views, recipe_names)


func _is_selected_target_dining_table() -> bool:
	if (
		_kitchen_controller == null
		or not is_instance_valid(_kitchen_controller)
		or _service_controller == null
		or not is_instance_valid(_service_controller)
	):
		return false
	var target_id := _kitchen_controller.get_selected_target_id()
	return target_id != &"" and _service_controller.has_table(target_id)


func _format_dining_table_status(table_id: StringName) -> String:
	if _service_controller == null or not is_instance_valid(_service_controller):
		return ""
	if table_id == &"" or not _service_controller.has_table(table_id):
		return ""

	var table_view := _service_controller.get_table_view(table_id)
	var state: int = int(table_view.get("state", -1))
	match state:
		SharedTypes.TableState.CLEAN_VACANT:
			return "Meja kosong bersih"
		SharedTypes.TableState.DIRTY:
			return "Meja kotor"
		SharedTypes.TableState.OCCUPIED_WAITING:
			var order_id := StringName(table_view.get("order_id_or_empty", &""))
			var order_view := _service_controller.get_order_view(order_id)
			var recipe_id := StringName(order_view.get("recipe_id", &""))
			var dish_label: String = String(recipe_id)
			if _kitchen_controller != null and is_instance_valid(_kitchen_controller):
				var def := _kitchen_controller.get_recipe_def(recipe_id)
				if def != null and not def.display_name.is_empty():
					dish_label = def.display_name
			var secs: int = ceili(float(order_view.get("seconds_remaining", 0.0)))
			return "Pesanan: %s (%d dtk)" % [dish_label, secs]
		SharedTypes.TableState.OCCUPIED_EATING:
			var cust_id := StringName(table_view.get("customer_id_or_empty", &""))
			for cview: Dictionary in _service_controller.get_customer_views():
				if StringName(cview.get("customer_id", &"")) == cust_id:
					var secs: int = ceili(float(cview.get("eat_seconds_remaining", 0.0)))
					return "Sedang makan (%d dtk)" % secs
			return "Sedang makan"
	return ""


func _refresh_hud() -> void:
	if not is_node_ready():
		return

	var phase: int = _get_current_phase()
	var day_index: int = _get_current_day_index()
	var cash: int = 0
	var target: int = 0
	var planned_quota: int = 0

	if _run_controller != null and is_instance_valid(_run_controller):
		var run_view: Dictionary = _run_controller.get_run_view()
		day_index = int(run_view.get("day_index", day_index))
		cash = int(run_view.get("cash", 0))
		target = int(run_view.get("day_7_target", 0))
		planned_quota = int(run_view.get("planned_dinein_quota", 0))

	var unspawned_quota: int = 0
	if _service_controller != null and is_instance_valid(_service_controller):
		var queue_view: Dictionary = _service_controller.get_customer_queue_view()
		unspawned_quota = int(queue_view.get("day_queue_remaining", 0))

	var elapsed: float = 0.0
	if _game_root != null and is_instance_valid(_game_root):
		if _game_root.has_method(&"get_service_elapsed"):
			elapsed = float(_game_root.get_service_elapsed())

	if left_hud_region != null:
		left_hud_region.position = ui_safe_rect.position
		left_hud_region.size = ui_safe_rect.size

	day_label.text = "Hari %d" % day_index
	phase_label.text = PHASE_LABELS.get(phase, "Perencanaan")
	cash_label.text = "Kas: Rp%d" % cash
	goal_label.text = "Target Hari 7: Rp%d" % target

	goal_progress_bar.min_value = 0.0
	goal_progress_bar.max_value = 1.0
	goal_progress_bar.step = 0.0
	if target > 0:
		goal_progress_bar.value = clampf(float(cash) / float(target), 0.0, 1.0)
	else:
		goal_progress_bar.value = 0.0

	var is_planning := (phase == SharedTypes.Phase.PLANNING)
	planning_box.visible = is_planning
	start_service_button.disabled = not is_planning
	if not is_planning and start_service_button.has_focus():
		start_service_button.release_focus()
	forecast_quota_label.text = "Target Tamu: %d" % planned_quota

	service_box.visible = (
		phase == SharedTypes.Phase.SERVING
		or phase == SharedTypes.Phase.CLOSING
	)
	service_elapsed_label.text = "Waktu: %.1f dtk" % elapsed
	unspawned_quota_label.text = "Antrean Datang: %d" % unspawned_quota


func _refresh_dialogue() -> void:
	if not is_node_ready() or interaction_dialogue == null:
		return

	var phase: int = _get_current_phase()
	var in_active_world_phase := (
		phase == SharedTypes.Phase.PLANNING
		or phase == SharedTypes.Phase.SERVING
	)
	if not in_active_world_phase:
		interaction_dialogue.visible = false
		return

	var selected_id: StringName = &""
	var allowed: Array[String] = []
	var prefix: String = ""
	if _kitchen_controller != null and is_instance_valid(_kitchen_controller):
		selected_id = _kitchen_controller.get_selected_target_id()
		allowed = _kitchen_controller.get_allowed_commands_for_selected_target()
		prefix = _kitchen_controller.get_command_prefix()

	if selected_id == &"" and _feedback_text.is_empty():
		interaction_dialogue.visible = false
		return

	interaction_dialogue.visible = true
	if selected_id != &"":
		target_title_label.visible = true
		target_title_label.text = get_target_display_title(selected_id)
	else:
		target_title_label.visible = false
		target_title_label.text = ""

	var is_serving := (phase == SharedTypes.Phase.SERVING)
	if is_serving and not allowed.is_empty():
		allowed_commands_label.visible = true
		allowed_commands_label.text = _format_allowed_commands(prefix, allowed)
	else:
		allowed_commands_label.visible = false
		allowed_commands_label.text = ""

	if is_serving and (not allowed.is_empty() or not prefix.is_empty()):
		prefix_prompt_label.visible = true
		prefix_prompt_label.text = _format_prefix_prompt(prefix, allowed)
		prefix_prompt_label.modulate = (
			PREFIX_HIGHLIGHT_COLOR if not prefix.is_empty() else PREFIX_IDLE_COLOR
		)
	else:
		prefix_prompt_label.visible = false
		prefix_prompt_label.text = ""
		prefix_prompt_label.modulate = PREFIX_IDLE_COLOR

	if remaining_prompt_label != null:
		var remaining_text := _format_remaining_preview(prefix, allowed)
		if is_serving and not remaining_text.is_empty():
			remaining_prompt_label.visible = true
			remaining_prompt_label.text = remaining_text
		else:
			remaining_prompt_label.visible = false
			remaining_prompt_label.text = ""

	if not _feedback_text.is_empty():
		context_message_label.visible = true
		context_message_label.text = _feedback_text
	elif is_serving and selected_id != &"":
		var table_status := _format_dining_table_status(selected_id)
		context_message_label.visible = not table_status.is_empty()
		context_message_label.text = table_status
	else:
		context_message_label.visible = false
		context_message_label.text = ""

	_update_dialogue_position()


func _format_allowed_commands(prefix: String, allowed: Array[String]) -> String:
	if prefix.is_empty():
		return ", ".join(allowed)

	var norm_prefix := prefix.to_lower()
	var formatted: PackedStringArray = []
	for cmd in allowed:
		var norm_cmd := cmd.strip_edges().to_lower()
		if norm_cmd.begins_with(norm_prefix):
			var typed_part := norm_cmd.left(norm_prefix.length())
			var rest_part := norm_cmd.substr(norm_prefix.length())
			formatted.append("[%s]%s" % [typed_part, rest_part])
		else:
			formatted.append(norm_cmd)
	return ", ".join(formatted)


func _format_prefix_prompt(prefix: String, allowed: Array[String]) -> String:
	if prefix.is_empty():
		if allowed.size() == 1:
			return "Ketik: %s" % allowed[0].strip_edges().to_lower()
		return "Ketik perintah"
	return "Ketik: [%s]" % prefix.to_lower()


func _format_remaining_preview(prefix: String, allowed: Array[String]) -> String:
	if prefix.is_empty():
		return ""

	var norm_prefix := prefix.to_lower()
	var remainders: PackedStringArray = []
	for cmd in allowed:
		var norm_cmd := cmd.strip_edges().to_lower()
		if norm_cmd.begins_with(norm_prefix):
			var rem := norm_cmd.substr(norm_prefix.length())
			if not rem.is_empty():
				remainders.append(rem)

	if remainders.is_empty():
		return ""
	return "Ketik berikutnya: %s" % " / ".join(remainders)


func _update_dialogue_position() -> void:
	if not is_node_ready() or interaction_dialogue == null or not interaction_dialogue.visible:
		return
	if _world_map == null or not is_instance_valid(_world_map):
		return

	var anchor_node: Node2D = null
	if _kitchen_controller != null and is_instance_valid(_kitchen_controller):
		var selected_id := _kitchen_controller.get_selected_target_id()
		if selected_id != &"" and _world_map.registry != null:
			anchor_node = _world_map.registry.get_object(selected_id)

	if anchor_node == null:
		anchor_node = _world_map.player
	if anchor_node == null or not is_instance_valid(anchor_node):
		return

	var target_canvas_pos: Vector2 = anchor_node.get_global_transform_with_canvas().origin
	interaction_dialogue.reset_size()
	var dlg_size: Vector2 = interaction_dialogue.get_combined_minimum_size()
	interaction_dialogue.size = dlg_size

	var desired_x := target_canvas_pos.x - dlg_size.x * 0.5
	if _shake_remaining > 0.0:
		desired_x += SHAKE_OFFSET_PX

	var desired_y := target_canvas_pos.y - DIALOGUE_ABOVE_OFFSET - dlg_size.y
	var min_y := world_visible_rect.position.y + DIALOGUE_MARGIN
	if desired_y < min_y:
		desired_y = target_canvas_pos.y + DIALOGUE_BELOW_OFFSET

	var min_x := world_visible_rect.position.x + DIALOGUE_MARGIN
	var max_x := maxf(min_x, world_visible_rect.end.x - dlg_size.x - DIALOGUE_MARGIN)
	var max_y := maxf(min_y, world_visible_rect.end.y - dlg_size.y - DIALOGUE_MARGIN)

	interaction_dialogue.position = Vector2(
		clampf(desired_x, min_x, max_x),
		clampf(desired_y, min_y, max_y)
	)


func _refresh_results_panel() -> void:
	if not is_node_ready() or day_result_side_panel == null:
		return

	var phase: int = _get_current_phase()
	var show_panel := (
		phase == SharedTypes.Phase.RESULTS
		or phase == SharedTypes.Phase.FINISHED
	)
	day_result_side_panel.visible = show_panel
	if not show_panel:
		continue_button.disabled = true
		extra_mode_button.disabled = true
		if continue_button.has_focus():
			continue_button.release_focus()
		if extra_mode_button.has_focus():
			extra_mode_button.release_focus()
		return

	var day_index: int = _get_current_day_index()
	var settlement: Dictionary = {}
	var goal_outcome: int = SharedTypes.DayOutcome.UNDECIDED
	if _run_controller != null and is_instance_valid(_run_controller):
		settlement = _run_controller.get_day_settlement_view(day_index)
		var run_view := _run_controller.get_run_view()
		goal_outcome = int(
			settlement.get("day7_outcome", run_view.get("goal_outcome", goal_outcome))
		)

	if phase == SharedTypes.Phase.FINISHED:
		if goal_outcome == SharedTypes.DayOutcome.WON:
			result_title_label.text = "Hari %d — Berhasil!" % day_index
		else:
			result_title_label.text = "Hari %d — Belum cukup uang" % day_index
	else:
		result_title_label.text = "Hasil Hari %d" % day_index

	var lines: PackedStringArray = [
		"Kas Awal: Rp%d" % int(settlement.get("begin_cash", 0)),
		"Belanja Bahan: -Rp%d" % int(settlement.get("ingredient_purchase_total", 0)),
		"Beli Alat: -Rp%d" % int(settlement.get("fixture_purchase_total", 0)),
		"Jual Alat: +Rp%d" % int(settlement.get("fixture_sale_total", 0)),
		"Pendapatan Makan: +Rp%d" % int(settlement.get("order_revenue_dinein", 0)),
		"Pendapatan Online: +Rp%d" % int(settlement.get("order_revenue_online", 0)),
		"Refund Kiriman: +Rp%d" % int(settlement.get("refund_total", 0)),
		"Listrik Harian: -Rp%d" % int(settlement.get("electricity_charge", 0)),
		"Kas Akhir: Rp%d" % int(settlement.get("end_cash", 0)),
		"Selesai (Makan/Online): %d / %d" % [
			int(settlement.get("completed_dinein_count", 0)),
			int(settlement.get("completed_online_count", 0)),
		],
		"Gagal (Makan/Online): %d / %d" % [
			int(settlement.get("failed_dinein_count", 0)),
			int(settlement.get("failed_online_count", 0)),
		],
		"Penalti Permintaan: %d -> %d" % [
			int(settlement.get("penalty_debt_before", 0)),
			int(settlement.get("penalty_debt_after", 0)),
		],
		"Perkiraan Besok: %d" % int(settlement.get("forecast_next_day", 0)),
	]
	settlement_summary_label.text = "\n".join(lines)

	var can_continue := (phase == SharedTypes.Phase.RESULTS and day_index != 7)
	var can_extra := (
		phase == SharedTypes.Phase.FINISHED
		and day_index == 7
		and goal_outcome == SharedTypes.DayOutcome.WON
	)
	continue_button.visible = can_continue
	continue_button.disabled = not can_continue
	if not can_continue and continue_button.has_focus():
		continue_button.release_focus()

	extra_mode_button.visible = can_extra
	extra_mode_button.disabled = not can_extra
	if not can_extra and extra_mode_button.has_focus():
		extra_mode_button.release_focus()


func _hit_test_interactable(world_global_pos: Vector2) -> StringName:
	if _world_map == null or _world_map.registry == null:
		return &""

	var candidates: Array[StringName] = []
	var world_2d := _world_map.get_world_2d()
	if world_2d != null and world_2d.direct_space_state != null:
		var params := PhysicsPointQueryParameters2D.new()
		params.position = world_global_pos
		params.collide_with_areas = true
		params.collide_with_bodies = false
		var hits := world_2d.direct_space_state.intersect_point(params)
		for hit: Dictionary in hits:
			var collider: Variant = hit.get("collider")
			if collider is Area2D and is_instance_valid(collider):
				var area := collider as Area2D
				var hit_id := _world_map.registry.find_id(area)
				if hit_id != &"" and not candidates.has(hit_id):
					candidates.append(hit_id)

	for object_id in _world_map.registry.get_ids():
		var node := _world_map.registry.get_object(object_id)
		if node == null or not is_instance_valid(node) or not (node is Area2D):
			continue
		var area := node as Area2D
		if not area.is_visible_in_tree() or not area.input_pickable:
			continue
		if _point_hits_area_shapes(area, world_global_pos) and not candidates.has(object_id):
			candidates.append(object_id)

	if candidates.is_empty():
		return &""

	candidates.sort_custom(_compare_hit_candidates)
	return candidates[0]


func _compare_hit_candidates(a: StringName, b: StringName) -> bool:
	var node_a := _world_map.registry.get_object(a)
	var node_b := _world_map.registry.get_object(b)
	var a_is_child := node_a != null and node_a.has_meta(WorldMap.PARENT_WORLD_ID_META)
	var b_is_child := node_b != null and node_b.has_meta(WorldMap.PARENT_WORLD_ID_META)
	if a_is_child != b_is_child:
		return a_is_child
	return String(a) < String(b)


func _point_hits_area_shapes(area: Area2D, world_global_pos: Vector2) -> bool:
	for child in area.get_children():
		if not (child is CollisionShape2D):
			continue
		var shape_node := child as CollisionShape2D
		if not is_instance_valid(shape_node) or shape_node.disabled or shape_node.shape == null:
			continue
		var xform := shape_node.get_global_transform()
		if is_zero_approx(xform.determinant()):
			continue
		var local_pt := xform.affine_inverse() * world_global_pos
		if shape_node.shape is RectangleShape2D:
			var rect_shape := shape_node.shape as RectangleShape2D
			if rect_shape.get_rect().has_point(local_pt):
				return true
		elif shape_node.shape is CircleShape2D:
			var circle_shape := shape_node.shape as CircleShape2D
			if local_pt.length_squared() <= circle_shape.radius * circle_shape.radius:
				return true
	return false


func _is_point_blocked_by_ui(canvas_pos: Vector2) -> bool:
	if ui_safe_rect.has_point(canvas_pos):
		return true
	if left_hud_region != null and left_hud_region.visible:
		if left_hud_region.get_global_rect().has_point(canvas_pos):
			return true
	if day_result_side_panel != null and day_result_side_panel.visible:
		if day_result_side_panel.get_global_rect().has_point(canvas_pos):
			return true
	if _modal_blocking_active:
		return true
	return false


func _is_keyboard_blocked_by_focus_or_modal() -> bool:
	if is_modal_blocking():
		return true
	if is_inside_tree() and get_viewport() != null:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and is_instance_valid(focused):
			if focused is LineEdit or focused is TextEdit or focused is SpinBox:
				return true
			if focused is BaseButton and focused.is_visible_in_tree():
				return true
			if bool(focused.get_meta(&"blocks_gameplay_keys", false)):
				return true
	return false


func _release_button_focus_if_any() -> void:
	if not is_inside_tree() or get_viewport() == null:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is BaseButton and is_instance_valid(focused):
		focused.release_focus()


func _get_current_phase() -> int:
	if (
		_game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_method(&"get_phase")
	):
		return int(_game_root.get_phase())
	return SharedTypes.Phase.PLANNING


func _get_current_day_index() -> int:
	if (
		_game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_method(&"get_day_index")
	):
		return int(_game_root.get_day_index())
	return 1


func _is_world_click_phase() -> bool:
	var phase := _get_current_phase()
	return (
		phase == SharedTypes.Phase.PLANNING
		or phase == SharedTypes.Phase.SERVING
	)


func _is_serving_phase() -> bool:
	return _get_current_phase() == SharedTypes.Phase.SERVING
