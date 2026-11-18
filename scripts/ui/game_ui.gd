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
	&"hand_empty": "Ambil bahan dulu",
	&"out_of_stock": "Bahan habis",
	&"delivery_pending": "Bahan masih dikirim",
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
	&"online_accepted": "Pesanan online diterima!",
	&"driver_not_at_pickup": "Pengantar belum mendapatkan tempat pickup.",
	&"fixture_purchased": "Alat berhasil dipasang!",
}

const EDIT_MENU_SELECTED_BG: Color = Color(0.18, 0.42, 0.28, 1.0)
const EDIT_MENU_SELECTED_BORDER: Color = Color(0.55, 0.92, 0.62, 1.0)
const EDIT_MENU_UNSELECTED_BG: Color = Color(0.16, 0.18, 0.23, 1.0)
const EDIT_MENU_UNSELECTED_BORDER: Color = Color(0.36, 0.40, 0.48, 1.0)
const SHOP_INGREDIENT_ORDER: Array[StringName] = [
	&"beras",
	&"telur",
	&"ayam",
	&"sapi",
	&"sayur",
	&"tempe",
]
const FIXTURE_SHOP_ORDER: Array[StringName] = [
	&"stove",
	&"rice_cooker",
	&"fridge",
	&"box",
	&"washer",
	&"plate_rack",
	&"dining_table",
]
const FIXTURE_CATEGORY_LABELS: Dictionary[int, String] = {
	SharedTypes.FixtureKind.BOX: "Penyimpanan",
	SharedTypes.FixtureKind.FRIDGE: "Penyimpanan Dingin",
	SharedTypes.FixtureKind.STOVE: "Alat Masak",
	SharedTypes.FixtureKind.WASHER: "Kebersihan",
	SharedTypes.FixtureKind.PLATE_RACK: "Peralatan Saji",
	SharedTypes.FixtureKind.RICE_COOKER: "Alat Masak",
	SharedTypes.FixtureKind.DINING_TABLE: "Ruang Makan",
}
const FIXTURE_BENEFIT_LABELS: Dictionary[StringName, String] = {
	&"box": "+3 slot bahan kering (kapasitas 5/slot)",
	&"fridge": "+2 slot dingin (kapasitas 3/slot, stok tahan ke esok hari)",
	&"stove": "+1 kompor untuk menggoreng paralel",
	&"washer": "+1 wastafel cuci beras & piring kotor",
	&"plate_rack": "+4 kapasitas piring bersih",
	&"rice_cooker": "+1 penanak nasi tambahan",
	&"dining_table": "+1 meja pelanggan makan di tempat",
}
const SLOT_DISPLAY_LABELS: Dictionary[StringName, String] = {
	&"slot_utility_01": "Slot Dapur 1",
	&"slot_utility_02": "Slot Dapur 2",
	&"slot_table_01": "Slot Meja 1",
	&"slot_table_02": "Slot Meja 2",
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
var _pending_menu_selection: Array[StringName] = []
var _edit_menu_buttons: Dictionary[StringName, Button] = {}
var _edit_menu_submitting: bool = false
var _shop_storage_unit_id: StringName = &""
var _pending_shop_basket: Dictionary[StringName, int] = {}
var _shop_ingredient_rows: Dictionary[StringName, Dictionary] = {}
var _shop_submitting: bool = false
var _selected_fixture_slot_id: StringName = &""
var _selected_fixture_utility_id: StringName = &""
var _fixture_slot_buttons: Dictionary[StringName, Button] = {}
var _fixture_shop_rows: Dictionary[StringName, Dictionary] = {}
var _fixture_shop_submitting: bool = false

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
@onready var edit_menu_button: Button = (
	$UIRoot/LeftHUDRegion/HUDColumn/PlanningBox/EditMenuButton
)
@onready var fixture_shop_button: Button = (
	$UIRoot/LeftHUDRegion/HUDColumn/PlanningBox/FixtureShopButton
)
@onready var start_hint_label: Label = (
	$UIRoot/LeftHUDRegion/HUDColumn/PlanningBox/StartHintLabel
)
@onready var menu_stub_button: Button = (
	$UIRoot/LeftHUDRegion/HUDColumn/PlanningBox/StubActionsRow/MenuStubButton
)
@onready var exit_stub_button: Button = (
	$UIRoot/LeftHUDRegion/HUDColumn/PlanningBox/StubActionsRow/ExitStubButton
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
@onready var target_status_label: Label = (
	$UIRoot/InteractionDialogue/DialogueColumn/TargetStatusLabel
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
	$UIRoot/DayResultSidePanel/ResultColumn/ResultSummaryScroll/SettlementSummaryLabel
)
@onready var continue_button: Button = (
	$UIRoot/DayResultSidePanel/ResultColumn/ResultFooter/ContinueButton
)
@onready var extra_mode_button: Button = (
	$UIRoot/DayResultSidePanel/ResultColumn/ResultFooter/ExtraModeButton
)

@onready var edit_menu_overlay: Control = $UIRoot/EditMenuOverlay
@onready var edit_menu_popup: PanelContainer = $UIRoot/EditMenuOverlay/EditMenuPopup
@onready var edit_menu_recipe_list: VBoxContainer = (
	$UIRoot/EditMenuOverlay/EditMenuPopup/PopupColumn/RecipeScroll/RecipeList
)
@onready var edit_menu_error_label: Label = (
	$UIRoot/EditMenuOverlay/EditMenuPopup/PopupColumn/EditMenuErrorLabel
)
@onready var edit_menu_cancel_button: Button = (
	$UIRoot/EditMenuOverlay/EditMenuPopup/PopupColumn/PopupButtonsRow/EditMenuCancelButton
)
@onready var edit_menu_confirm_button: Button = (
	$UIRoot/EditMenuOverlay/EditMenuPopup/PopupColumn/PopupButtonsRow/EditMenuConfirmButton
)

@onready var ingredient_shop_overlay: Control = $UIRoot/IngredientShopOverlay
@onready var ingredient_shop_popup: PanelContainer = (
	$UIRoot/IngredientShopOverlay/IngredientShopPopup
)
@onready var shop_target_label: Label = (
	$UIRoot/IngredientShopOverlay/IngredientShopPopup/ShopColumn/ShopHeaderRow/ShopTargetLabel
)
@onready var shop_cash_label: Label = (
	$UIRoot/IngredientShopOverlay/IngredientShopPopup/ShopColumn/ShopHeaderRow/ShopCashLabel
)
@onready var shop_capacity_label: Label = (
	$UIRoot/IngredientShopOverlay/IngredientShopPopup/ShopColumn/ShopStatusRow/ShopCapacityLabel
)
@onready var shop_delivery_hint_label: Label = (
	$UIRoot/IngredientShopOverlay/IngredientShopPopup/ShopColumn/ShopStatusRow/ShopDeliveryHintLabel
)
@onready var shop_slots_row: HBoxContainer = (
	$UIRoot/IngredientShopOverlay/IngredientShopPopup/ShopColumn/ShopSlotsRow
)
@onready var shop_pending_label: Label = (
	$UIRoot/IngredientShopOverlay/IngredientShopPopup/ShopColumn/ShopPendingLabel
)
@onready var shop_ingredient_list: VBoxContainer = (
	$UIRoot/IngredientShopOverlay/IngredientShopPopup/ShopColumn/ShopScroll/ShopIngredientList
)
@onready var shop_error_label: Label = (
	$UIRoot/IngredientShopOverlay/IngredientShopPopup/ShopColumn/ShopErrorLabel
)
@onready var shop_total_label: Label = (
	$UIRoot/IngredientShopOverlay/IngredientShopPopup/ShopColumn/ShopFooterRow/ShopTotalLabel
)
@onready var shop_retrieve_button: Button = (
	$UIRoot/IngredientShopOverlay/IngredientShopPopup/ShopColumn/ShopFooterRow/ShopRetrieveButton
)
@onready var shop_cancel_button: Button = (
	$UIRoot/IngredientShopOverlay/IngredientShopPopup/ShopColumn/ShopFooterRow/ShopCancelButton
)
@onready var shop_checkout_button: Button = (
	$UIRoot/IngredientShopOverlay/IngredientShopPopup/ShopColumn/ShopFooterRow/ShopCheckoutButton
)

@onready var fixture_shop_overlay: Control = $UIRoot/FixtureShopOverlay
@onready var fixture_shop_popup: PanelContainer = (
	$UIRoot/FixtureShopOverlay/FixtureShopPopup
)
@onready var fixture_cash_label: Label = (
	$UIRoot/FixtureShopOverlay/FixtureShopPopup/FixtureColumn/FixtureHeaderRow/FixtureCashLabel
)
@onready var fixture_power_label: Label = (
	$UIRoot/FixtureShopOverlay/FixtureShopPopup/FixtureColumn/FixtureHeaderRow/FixturePowerLabel
)
@onready var fixture_slots_row: HBoxContainer = (
	$UIRoot/FixtureShopOverlay/FixtureShopPopup/FixtureColumn/FixtureSlotsRow
)
@onready var fixture_list: VBoxContainer = (
	$UIRoot/FixtureShopOverlay/FixtureShopPopup/FixtureColumn/FixtureScroll/FixtureList
)
@onready var fixture_error_label: Label = (
	$UIRoot/FixtureShopOverlay/FixtureShopPopup/FixtureColumn/FixtureErrorLabel
)
@onready var fixture_selection_label: Label = (
	$UIRoot/FixtureShopOverlay/FixtureShopPopup/FixtureColumn/FixtureFooterRow/FixtureSelectionLabel
)
@onready var fixture_cancel_button: Button = (
	$UIRoot/FixtureShopOverlay/FixtureShopPopup/FixtureColumn/FixtureFooterRow/FixtureCancelButton
)
@onready var fixture_confirm_button: Button = (
	$UIRoot/FixtureShopOverlay/FixtureShopPopup/FixtureColumn/FixtureFooterRow/FixtureConfirmButton
)


func _ready() -> void:
	_apply_fallback_styles()
	_connect_ui_buttons()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(
		_on_viewport_size_changed
	):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	_layout_fixture_shop_overlay()
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
			_refresh_driver_visuals()
			_refresh_storage_delivery_visuals()
			if is_ingredient_shop_open():
				_refresh_shop_pending_deliveries()
			if _feedback_text.is_empty() and _is_selected_target_dining_table():
				_refresh_dialogue()
			elif _is_selected_target_driver():
				_refresh_dialogue()
			elif not is_ingredient_shop_open() and _is_selected_target_storage_unit():
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
	if is_edit_menu_open():
		return true
	if is_ingredient_shop_open():
		return true
	if is_fixture_shop_open():
		return true
	if day_result_side_panel != null and day_result_side_panel.visible:
		return true
	return false


func is_ingredient_shop_open() -> bool:
	return ingredient_shop_overlay != null and ingredient_shop_overlay.visible


func open_ingredient_shop(storage_unit_id: StringName) -> bool:
	if not _is_world_click_phase() or ingredient_shop_overlay == null:
		return false
	if (
		_kitchen_controller == null
		or not is_instance_valid(_kitchen_controller)
		or _run_controller == null
		or not is_instance_valid(_run_controller)
	):
		return false
	if not _kitchen_controller.has_storage_unit(storage_unit_id):
		return false
	if is_edit_menu_open():
		close_edit_menu()
	if is_fixture_shop_open():
		close_fixture_shop()

	_clear_feedback_state()
	_kitchen_controller.clear_command_prefix()
	_shop_storage_unit_id = storage_unit_id
	_shop_submitting = false
	if shop_checkout_button != null:
		shop_checkout_button.disabled = false
	_pending_shop_basket.clear()
	_clear_shop_error()
	_build_ingredient_shop_rows()
	ingredient_shop_overlay.visible = true
	if ingredient_shop_popup != null:
		ingredient_shop_popup.size = Vector2(456.0, 324.0)
	_refresh_ingredient_shop_view()
	_refresh_dialogue()
	return true


func close_ingredient_shop() -> void:
	if ingredient_shop_overlay != null:
		ingredient_shop_overlay.visible = false
	_shop_storage_unit_id = &""
	_pending_shop_basket.clear()
	_shop_submitting = false
	if shop_checkout_button != null:
		shop_checkout_button.disabled = false
	_clear_shop_error()
	_release_button_focus_if_any()
	_refresh_dialogue()


func adjust_shop_quantity(ingredient_id: StringName, delta: int) -> bool:
	if not is_ingredient_shop_open() or ingredient_id == &"" or delta == 0:
		return false
	if _kitchen_controller == null or _run_controller == null:
		return false
	if _kitchen_controller.get_ingredient_def(ingredient_id) == null:
		_show_shop_error("Bahan tidak terdaftar.")
		return false
	var unit_price := _get_ingredient_unit_price(ingredient_id)
	if unit_price <= 0:
		_show_shop_error("Harga bahan tidak tersedia.")
		return false

	var cur_qty := int(_pending_shop_basket.get(ingredient_id, 0))
	var next_qty := cur_qty + delta
	if next_qty < 0:
		_show_shop_error("Jumlah tidak boleh negatif.")
		return false

	_clear_shop_error()
	if next_qty == 0:
		_pending_shop_basket.erase(ingredient_id)
		_refresh_ingredient_shop_view()
		return true

	var candidate: Dictionary[StringName, int] = {}
	for k: StringName in _pending_shop_basket:
		var q: int = int(_pending_shop_basket[k])
		if q > 0:
			candidate[k] = q
	candidate[ingredient_id] = next_qty

	if delta > 0:
		if not _kitchen_controller.can_receive_stock_basket(candidate, _shop_storage_unit_id):
			_show_shop_error("Kapasitas penyimpanan penuh.")
			return false
		var cash := int(_run_controller.get_run_view().get("cash", 0))
		if _compute_basket_total(candidate) > cash:
			_show_shop_error("Uang tidak cukup.")
			return false

	_pending_shop_basket[ingredient_id] = next_qty
	_refresh_ingredient_shop_view()
	return true


func get_shop_basket() -> Dictionary:
	return _pending_shop_basket.duplicate(true)


func get_shop_subtotal(ingredient_id: StringName) -> int:
	var qty := int(_pending_shop_basket.get(ingredient_id, 0))
	if qty <= 0:
		return 0
	return _get_ingredient_unit_price(ingredient_id) * qty


func get_shop_total() -> int:
	return _compute_basket_total(_pending_shop_basket)


func get_shop_remaining_capacity() -> int:
	if (
		not is_ingredient_shop_open()
		or _kitchen_controller == null
		or not is_instance_valid(_kitchen_controller)
	):
		return 0
	return _kitchen_controller.get_storage_remaining_capacity(
		_shop_storage_unit_id,
		_pending_shop_basket
	)


func get_shop_ingredient_controls(ingredient_id: StringName) -> Dictionary:
	return _shop_ingredient_rows.get(ingredient_id, {})


func submit_ingredient_shop(override_basket: Dictionary = {}) -> bool:
	if not is_ingredient_shop_open() or _shop_submitting:
		return false
	if not _is_world_click_phase():
		_show_shop_error("Belanja hanya bisa saat Perencanaan atau Layanan.")
		return false
	if (
		_run_controller == null
		or not is_instance_valid(_run_controller)
		or _kitchen_controller == null
		or not is_instance_valid(_kitchen_controller)
	):
		_show_shop_error("Sistem belanja tidak tersedia.")
		return false

	var basket: Dictionary = (
		override_basket.duplicate(true)
		if not override_basket.is_empty()
		else _pending_shop_basket.duplicate(true)
	)
	if basket.is_empty():
		_show_shop_error("Pilih minimal 1 bahan terlebih dahulu.")
		return false

	var pre_err := _validate_shop_basket(basket)
	if not pre_err.is_empty():
		_show_shop_error(pre_err)
		return false

	_shop_submitting = true
	if shop_checkout_button != null:
		shop_checkout_button.disabled = true

	var ok := _run_controller.request_ingredient_basket_purchase(basket, _shop_storage_unit_id)
	_shop_submitting = false
	if shop_checkout_button != null:
		shop_checkout_button.disabled = false

	if not ok:
		_show_shop_error("Pembelian ditolak: periksa kas atau kapasitas.")
		_refresh_ingredient_shop_view()
		return false

	close_ingredient_shop()
	_refresh_hud()
	return true


func is_edit_menu_open() -> bool:
	return edit_menu_overlay != null and edit_menu_overlay.visible


func open_edit_menu() -> bool:
	if not _is_planning_phase() or edit_menu_overlay == null:
		return false
	if _run_controller == null or not is_instance_valid(_run_controller):
		return false
	if is_ingredient_shop_open():
		close_ingredient_shop()
	if is_fixture_shop_open():
		close_fixture_shop()

	_clear_feedback_state()
	if _kitchen_controller != null and is_instance_valid(_kitchen_controller):
		_kitchen_controller.clear_command_prefix()

	_edit_menu_submitting = false
	if edit_menu_confirm_button != null:
		edit_menu_confirm_button.disabled = false
	if edit_menu_error_label != null:
		edit_menu_error_label.visible = false
		edit_menu_error_label.text = ""

	var run_view := _run_controller.get_run_view()
	_pending_menu_selection.clear()
	for raw_id: Variant in run_view.get("selected_recipe_ids", []):
		var id := StringName(raw_id)
		if id != &"" and not _pending_menu_selection.has(id):
			_pending_menu_selection.append(id)

	_rebuild_edit_menu_list(run_view)
	edit_menu_overlay.visible = true
	if edit_menu_popup != null:
		edit_menu_popup.size = Vector2(336.0, 280.0)
	_refresh_dialogue()
	return true


func close_edit_menu() -> void:
	if edit_menu_overlay != null:
		edit_menu_overlay.visible = false
	_pending_menu_selection.clear()
	_edit_menu_submitting = false
	if edit_menu_confirm_button != null:
		edit_menu_confirm_button.disabled = false
	if edit_menu_error_label != null:
		edit_menu_error_label.visible = false
		edit_menu_error_label.text = ""
	_release_button_focus_if_any()
	_refresh_dialogue()


func toggle_edit_menu_recipe(recipe_id: StringName) -> bool:
	if not is_edit_menu_open() or recipe_id == &"":
		return false
	var idx := _pending_menu_selection.find(recipe_id)
	if idx >= 0:
		_pending_menu_selection.remove_at(idx)
	else:
		_pending_menu_selection.append(recipe_id)

	if _edit_menu_buttons.has(recipe_id):
		var btn := _edit_menu_buttons[recipe_id]
		if btn != null and is_instance_valid(btn):
			var selected := _pending_menu_selection.has(recipe_id)
			if btn.button_pressed != selected:
				btn.set_pressed_no_signal(selected)
			_update_recipe_button_visual(btn, recipe_id, selected)

	if edit_menu_error_label != null:
		edit_menu_error_label.visible = false
		edit_menu_error_label.text = ""
	return true


func get_pending_menu_selection() -> Array[StringName]:
	return _pending_menu_selection.duplicate()


func get_edit_menu_recipe_button(recipe_id: StringName) -> Button:
	return _edit_menu_buttons.get(recipe_id, null) as Button


func submit_edit_menu(recipe_ids: Array[StringName]) -> bool:
	if not is_edit_menu_open() or _edit_menu_submitting:
		return false
	if _run_controller == null or not is_instance_valid(_run_controller):
		_show_edit_menu_error("Pengendali menu tidak tersedia.")
		return false

	_edit_menu_submitting = true
	if edit_menu_confirm_button != null:
		edit_menu_confirm_button.disabled = true

	var accepted := _run_controller.select_daily_menu(recipe_ids)
	_edit_menu_submitting = false
	if edit_menu_confirm_button != null:
		edit_menu_confirm_button.disabled = false

	if not accepted:
		_show_edit_menu_error(_describe_menu_rejection(recipe_ids))
		return false

	close_edit_menu()
	_refresh_hud()
	return true


func is_fixture_shop_open() -> bool:
	return fixture_shop_overlay != null and fixture_shop_overlay.visible


func open_fixture_shop(slot_id: StringName = &"") -> bool:
	if not _is_planning_phase() or fixture_shop_overlay == null:
		return false
	if _run_controller == null or not is_instance_valid(_run_controller):
		return false
	if is_edit_menu_open():
		close_edit_menu()
	if is_ingredient_shop_open():
		close_ingredient_shop()

	_clear_feedback_state()
	if _kitchen_controller != null and is_instance_valid(_kitchen_controller):
		_kitchen_controller.clear_command_prefix()

	_fixture_shop_submitting = false
	if fixture_confirm_button != null:
		fixture_confirm_button.disabled = false
	_clear_fixture_error()

	if slot_id != &"":
		_selected_fixture_slot_id = slot_id
	elif _selected_fixture_slot_id == &"":
		_selected_fixture_slot_id = _pick_default_fixture_slot()

	if _selected_fixture_utility_id == &"":
		_selected_fixture_utility_id = _pick_default_fixture_utility(_selected_fixture_slot_id)

	_build_fixture_shop_ui()
	fixture_shop_overlay.visible = true
	_layout_fixture_shop_overlay()
	_refresh_fixture_shop_view()
	_refresh_dialogue()
	return true


func close_fixture_shop() -> void:
	if fixture_shop_overlay != null:
		fixture_shop_overlay.visible = false
	_fixture_shop_submitting = false
	if fixture_confirm_button != null:
		fixture_confirm_button.disabled = false
	_clear_fixture_error()
	_release_button_focus_if_any()
	_refresh_dialogue()


func select_fixture_shop_slot(slot_id: StringName) -> bool:
	if not is_fixture_shop_open() or slot_id == &"":
		return false
	if _world_map == null or not is_instance_valid(_world_map):
		return false
	if not _world_map.get_placement_slot_ids().has(slot_id):
		return false
	_selected_fixture_slot_id = slot_id
	_clear_fixture_error()
	_refresh_fixture_shop_view()
	return true


func select_fixture_shop_utility(utility_id: StringName) -> bool:
	if not is_fixture_shop_open() or utility_id == &"":
		return false
	if _run_controller == null or not is_instance_valid(_run_controller):
		return false
	if _run_controller.get_utility_def(utility_id) == null:
		return false
	_selected_fixture_utility_id = utility_id
	_clear_fixture_error()
	_refresh_fixture_shop_view()
	return true


func get_selected_fixture_slot_id() -> StringName:
	return _selected_fixture_slot_id


func get_selected_fixture_utility_id() -> StringName:
	return _selected_fixture_utility_id


func get_fixture_shop_row(utility_id: StringName) -> Dictionary:
	return _fixture_shop_rows.get(utility_id, {})


func submit_fixture_shop(
	override_utility_id: StringName = &"",
	override_slot_id: StringName = &""
) -> bool:
	if not is_fixture_shop_open() or _fixture_shop_submitting:
		return false
	if _run_controller == null or not is_instance_valid(_run_controller):
		_show_fixture_error("Pengendali peralatan tidak tersedia.")
		return false

	var utility_id := (
		override_utility_id
		if override_utility_id != &""
		else _selected_fixture_utility_id
	)
	var slot_id := (
		override_slot_id
		if override_slot_id != &""
		else _selected_fixture_slot_id
	)
	var check := _run_controller.can_purchase_fixture(utility_id, slot_id)
	if not bool(check.get("ok", false)):
		var reason := StringName(check.get("reason", &"invalid"))
		_show_fixture_error(_describe_fixture_purchase_rejection(reason))
		_refresh_fixture_shop_view()
		return false

	_fixture_shop_submitting = true
	if fixture_confirm_button != null:
		fixture_confirm_button.disabled = true

	var ok := _run_controller.request_fixture_purchase(utility_id, slot_id)
	_fixture_shop_submitting = false
	if fixture_confirm_button != null:
		fixture_confirm_button.disabled = false

	if not ok:
		_show_fixture_error("Pembelian alat gagal: periksa kas atau slot.")
		_refresh_fixture_shop_view()
		return false

	close_fixture_shop()
	_show_feedback(&"fixture_purchased")
	_refresh_hud()
	_refresh_kitchen_visuals()
	_refresh_dine_in_visuals()
	return true


func get_target_display_title(target_id: StringName) -> String:
	if target_id == &"":
		return ""
	if (
		_service_controller != null
		and is_instance_valid(_service_controller)
		and _service_controller.has_driver(target_id)
	):
		var view := _service_controller.get_driver_view(target_id)
		if int(view.get("state", -1)) == SharedTypes.DriverState.AT_PICKUP_SPOT:
			var spot_id := String(view.get("spot_id_or_empty", &""))
			if spot_id.begins_with("pickup_spot_"):
				return "Pengantar Spot %d" % int(spot_id.trim_prefix("pickup_spot_"))
			return "Pengantar Pickup"
		return "Pengantar Antrean"
	if TARGET_LABELS.has(target_id):
		return TARGET_LABELS[target_id]
	if _run_controller != null and is_instance_valid(_run_controller):
		var inst := _run_controller.get_fixture_instance(target_id)
		if not inst.is_empty():
			var util_id := StringName(inst.get("utility_id", &""))
			var def := _run_controller.get_utility_def(util_id)
			if def != null and not def.display_name.is_empty():
				return def.display_name
	return String(target_id)


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
		var interacted := _kitchen_controller.on_interactable_clicked(hit_target_id)
		if interacted and _kitchen_controller.has_storage_unit(hit_target_id):
			open_ingredient_shop(hit_target_id)
	else:
		var overflow_driver_id := _world_map.hit_test_overflow_driver(world_global_pos)
		if overflow_driver_id != &"":
			_kitchen_controller.on_overflow_driver_clicked(overflow_driver_id)
		elif (
			_is_planning_phase()
			and _world_map.has_method(&"hit_test_placement_slot")
		):
			var slot_id := _world_map.hit_test_placement_slot(world_global_pos)
			if slot_id != &"":
				open_fixture_shop(slot_id)
			else:
				var cell := _world_map.global_to_cell(world_global_pos)
				_kitchen_controller.on_floor_clicked(cell)
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
	if not _is_serving_phase() and not _is_planning_phase():
		return
	if key_event.keycode == KEY_ESCAPE:
		if is_ingredient_shop_open():
			close_ingredient_shop()
			if is_inside_tree() and get_viewport() != null:
				get_viewport().set_input_as_handled()
			return
		if is_fixture_shop_open():
			close_fixture_shop()
			if is_inside_tree() and get_viewport() != null:
				get_viewport().set_input_as_handled()
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
	if edit_menu_button != null:
		if not edit_menu_button.pressed.is_connected(_on_edit_menu_pressed):
			edit_menu_button.pressed.connect(_on_edit_menu_pressed)
	if fixture_shop_button != null:
		if not fixture_shop_button.pressed.is_connected(_on_fixture_shop_pressed):
			fixture_shop_button.pressed.connect(_on_fixture_shop_pressed)
	if menu_stub_button != null:
		if not menu_stub_button.pressed.is_connected(_on_stub_button_pressed):
			menu_stub_button.pressed.connect(_on_stub_button_pressed)
	if exit_stub_button != null:
		if not exit_stub_button.pressed.is_connected(_on_stub_button_pressed):
			exit_stub_button.pressed.connect(_on_stub_button_pressed)
	if edit_menu_cancel_button != null:
		if not edit_menu_cancel_button.pressed.is_connected(_on_edit_menu_cancel_pressed):
			edit_menu_cancel_button.pressed.connect(_on_edit_menu_cancel_pressed)
	if edit_menu_confirm_button != null:
		if not edit_menu_confirm_button.pressed.is_connected(_on_edit_menu_confirm_pressed):
			edit_menu_confirm_button.pressed.connect(_on_edit_menu_confirm_pressed)
	if shop_retrieve_button != null:
		if not shop_retrieve_button.pressed.is_connected(_on_shop_retrieve_pressed):
			shop_retrieve_button.pressed.connect(_on_shop_retrieve_pressed)
	if shop_cancel_button != null:
		if not shop_cancel_button.pressed.is_connected(_on_shop_cancel_pressed):
			shop_cancel_button.pressed.connect(_on_shop_cancel_pressed)
	if shop_checkout_button != null:
		if not shop_checkout_button.pressed.is_connected(_on_shop_checkout_pressed):
			shop_checkout_button.pressed.connect(_on_shop_checkout_pressed)
	if fixture_cancel_button != null:
		if not fixture_cancel_button.pressed.is_connected(_on_fixture_cancel_pressed):
			fixture_cancel_button.pressed.connect(_on_fixture_cancel_pressed)
	if fixture_confirm_button != null:
		if not fixture_confirm_button.pressed.is_connected(_on_fixture_confirm_pressed):
			fixture_confirm_button.pressed.connect(_on_fixture_confirm_pressed)
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
		if (
			_service_controller.has_signal(&"online_offer_changed")
			and not _service_controller.is_connected(
				&"online_offer_changed",
				_on_online_offer_changed
			)
		):
			_service_controller.connect(&"online_offer_changed", _on_online_offer_changed)

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
		if (
			_service_controller.has_signal(&"online_offer_changed")
			and _service_controller.is_connected(
				&"online_offer_changed",
				_on_online_offer_changed
			)
		):
			_service_controller.disconnect(&"online_offer_changed", _on_online_offer_changed)

	if _run_controller != null and is_instance_valid(_run_controller):
		if _run_controller.run_state_changed.is_connected(_on_run_state_changed):
			_run_controller.run_state_changed.disconnect(_on_run_state_changed)


func _on_edit_menu_pressed() -> void:
	open_edit_menu()


func _on_edit_menu_cancel_pressed() -> void:
	close_edit_menu()


func _on_edit_menu_confirm_pressed() -> void:
	submit_edit_menu(_pending_menu_selection)


func _on_stub_button_pressed() -> void:
	# Stub Menu/Exit buttons stay non-navigating in M4-A while keeping UI input blocking.
	pass


func _on_shop_retrieve_pressed() -> void:
	close_ingredient_shop()


func _on_shop_cancel_pressed() -> void:
	close_ingredient_shop()


func _on_shop_checkout_pressed() -> void:
	submit_ingredient_shop()


func _on_fixture_shop_pressed() -> void:
	open_fixture_shop()


func _on_fixture_cancel_pressed() -> void:
	close_fixture_shop()


func _on_fixture_confirm_pressed() -> void:
	submit_fixture_shop()


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


func _on_phase_changed(phase: int, _day_index: int) -> void:
	_clear_feedback_state()
	if phase != SharedTypes.Phase.PLANNING and is_edit_menu_open():
		close_edit_menu()
	if phase != SharedTypes.Phase.PLANNING and is_fixture_shop_open():
		close_fixture_shop()
	if (
		phase != SharedTypes.Phase.PLANNING
		and phase != SharedTypes.Phase.SERVING
		and is_ingredient_shop_open()
	):
		close_ingredient_shop()
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
	if is_ingredient_shop_open():
		_refresh_ingredient_shop_view()
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
	if (
		_feedback_code == &"driver_not_at_pickup"
		and _kitchen_controller != null
		and is_instance_valid(_kitchen_controller)
		and _service_controller != null
		and is_instance_valid(_service_controller)
	):
		var selected_id := _kitchen_controller.get_selected_target_id()
		if selected_id != &"" and _service_controller.has_driver(selected_id):
			var view := _service_controller.get_driver_view(selected_id)
			if int(view.get("state", -1)) == SharedTypes.DriverState.AT_PICKUP_SPOT:
				_clear_feedback_state()
	if _is_selected_target_driver():
		_refresh_dialogue()


func _on_online_offer_changed() -> void:
	_refresh_online_station_visual()
	if _is_selected_target_online_station():
		_refresh_dialogue()


func _on_run_state_changed() -> void:
	_refresh_hud()
	_refresh_kitchen_visuals()
	if is_ingredient_shop_open():
		_refresh_ingredient_shop_view()
	if is_fixture_shop_open():
		_refresh_fixture_shop_view()
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
	_refresh_online_station_visual()
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
	if _world_map.has_method(&"sync_extra_kitchen_visuals"):
		var extra_cookers: Dictionary[StringName, Dictionary] = {}
		for cooker_id in _kitchen_controller.get_cooker_ids():
			if cooker_id == &"rice_cooker":
				continue
			var c_view := _kitchen_controller.get_cooker_output_view(cooker_id)
			var c_has := not c_view.is_empty()
			var c_textures := _resolve_item_textures(c_view)
			var c_tex: Texture2D = c_textures[0] if not c_textures.is_empty() else null
			extra_cookers[cooker_id] = {
				"has_output": c_has,
				"texture": c_tex,
			}
		var extra_racks: Dictionary[StringName, Dictionary] = {}
		for rack_id in _kitchen_controller.get_plate_rack_ids():
			if rack_id == &"plate_rack":
				continue
			extra_racks[rack_id] = _kitchen_controller.get_plate_rack_view(rack_id)
		_world_map.sync_extra_kitchen_visuals(extra_cookers, extra_racks)

	if _world_map.has_method(&"sync_placement_slot_visuals"):
		var occupied_slots: Array[StringName] = []
		if _run_controller != null and is_instance_valid(_run_controller):
			var installed: Variant = (
				_run_controller.get_run_view().get("installed_fixtures", {})
			)
			if installed is Dictionary:
				for inst_id: Variant in installed:
					var raw_inst: Variant = installed[inst_id]
					if raw_inst is Dictionary:
						var s_id := StringName((raw_inst as Dictionary).get("slot_id", &""))
						if s_id != &"" and not occupied_slots.has(s_id):
							occupied_slots.append(s_id)
		_world_map.sync_placement_slot_visuals(_is_planning_phase(), occupied_slots)

	_refresh_storage_delivery_visuals()


func _refresh_storage_delivery_visuals() -> void:
	if _world_map == null or not is_instance_valid(_world_map):
		return
	if _kitchen_controller == null or not is_instance_valid(_kitchen_controller):
		return
	if not _world_map.has_method(&"sync_storage_delivery_visuals"):
		return
	var now := 0.0
	if (
		_game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_method(&"get_service_elapsed")
	):
		now = float(_game_root.get_service_elapsed())
	var pending_by_unit: Dictionary[StringName, float] = {}
	for deliv: Dictionary in _kitchen_controller.get_pending_delivery_views():
		var unit_id := StringName(deliv.get("storage_unit_id", &""))
		if unit_id == &"":
			continue
		var rem := maxf(0.0, float(deliv.get("due_at", 0.0)) - now)
		if not pending_by_unit.has(unit_id):
			pending_by_unit[unit_id] = rem
		else:
			pending_by_unit[unit_id] = minf(float(pending_by_unit[unit_id]), rem)
	_world_map.sync_storage_delivery_visuals(pending_by_unit)


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
	var driver_views := _service_controller.get_driver_views()
	var recipe_names: Dictionary = {}
	for view: Dictionary in driver_views:
		var recipe_id := StringName(view.get("recipe_id", &""))
		if recipe_id == &"" or recipe_names.has(recipe_id):
			continue
		recipe_names[recipe_id] = _get_recipe_display_name(recipe_id)
	_world_map.sync_driver_visuals(driver_views, recipe_names)


func _refresh_online_station_visual() -> void:
	if _world_map == null or not is_instance_valid(_world_map):
		return
	if _service_controller == null or not is_instance_valid(_service_controller):
		return
	var offer_view: Dictionary = _service_controller.get_online_offer_view()
	var preview_id := StringName(offer_view.get("preview_recipe_id", &""))
	var enabled := bool(offer_view.get("acceptance_enabled", false))
	var recipe_label := _get_recipe_display_name(preview_id) if preview_id != &"" else ""
	var part_textures := _resolve_recipe_part_textures(preview_id)
	_world_map.sync_online_station_visual(preview_id, enabled, recipe_label, part_textures)


func _get_recipe_display_name(recipe_id: StringName) -> String:
	if recipe_id == &"":
		return ""
	if _kitchen_controller != null and is_instance_valid(_kitchen_controller):
		var def := _kitchen_controller.get_recipe_def(recipe_id)
		if def != null and not def.display_name.is_empty():
			return def.display_name
	return String(recipe_id)


func _resolve_recipe_part_textures(recipe_id: StringName) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	if recipe_id == &"" or _kitchen_controller == null or not is_instance_valid(_kitchen_controller):
		return result
	var def := _kitchen_controller.get_recipe_def(recipe_id)
	if def == null:
		return result
	for part: RecipePartDef in def.required_parts:
		if part == null:
			continue
		var ing_def := _kitchen_controller.get_ingredient_def(part.ingredient_id)
		result.append(ing_def.get_texture_for_state(part.required_state) if ing_def != null else null)
	return result


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


func _is_selected_target_driver() -> bool:
	if (
		_kitchen_controller == null
		or not is_instance_valid(_kitchen_controller)
		or _service_controller == null
		or not is_instance_valid(_service_controller)
	):
		return false
	var target_id := _kitchen_controller.get_selected_target_id()
	return target_id != &"" and _service_controller.has_driver(target_id)


func _is_selected_target_online_station() -> bool:
	if _kitchen_controller == null or not is_instance_valid(_kitchen_controller):
		return false
	return _kitchen_controller.get_selected_target_id() == &"online_station"


func _is_selected_target_storage_unit() -> bool:
	if _kitchen_controller == null or not is_instance_valid(_kitchen_controller):
		return false
	var target_id := _kitchen_controller.get_selected_target_id()
	return target_id != &"" and _kitchen_controller.has_storage_unit(target_id)


func _format_online_station_status() -> String:
	if _service_controller == null or not is_instance_valid(_service_controller):
		return ""
	var offer_view: Dictionary = _service_controller.get_online_offer_view()
	var preview_id := StringName(offer_view.get("preview_recipe_id", &""))
	var dish_label := _get_recipe_display_name(preview_id)
	if bool(offer_view.get("acceptance_enabled", false)):
		return "Tawaran: %s (Siap diterima)" % dish_label

	var reason := StringName(offer_view.get("disabled_reason", &""))
	match reason:
		&"cutoff_reached":
			return "Tawaran: %s (Tutup: kuota <= 2)" % dish_label
		&"concurrent_cap_reached":
			var cap := int(offer_view.get("concurrent_limit", 0))
			return "Tawaran: %s (Penuh: maks %d)" % [dish_label, cap]
		&"not_serving":
			return "Tawaran: %s (Belum layanan)" % dish_label if preview_id != &"" else ""
		&"empty_menu":
			return "Tawaran tutup (Menu kosong)"
		&"invalid_price":
			return "Tawaran: %s (Harga tidak valid)" % dish_label
	return "Tawaran: %s (Tidak tersedia)" % dish_label if preview_id != &"" else ""


func _format_driver_status(driver_id: StringName) -> String:
	if _service_controller == null or not is_instance_valid(_service_controller):
		return ""
	if driver_id == &"" or not _service_controller.has_driver(driver_id):
		return ""
	var view: Dictionary = _service_controller.get_driver_view(driver_id)
	var recipe_id := StringName(view.get("recipe_id", &""))
	var dish_label := _get_recipe_display_name(recipe_id)
	var secs := maxi(0, ceili(float(view.get("seconds_remaining", 0.0))))
	if int(view.get("state", -1)) == SharedTypes.DriverState.AT_PICKUP_SPOT:
		return "Pesanan: %s (%d dtk) — Di tempat pickup" % [dish_label, secs]
	return "Pesanan: %s (%d dtk) — Di antrean luar" % [dish_label, secs]


func _format_storage_unit_status(storage_unit_id: StringName) -> String:
	if _kitchen_controller == null or not is_instance_valid(_kitchen_controller):
		return ""
	if not _kitchen_controller.has_storage_unit(storage_unit_id):
		return ""
	var view: Dictionary = _kitchen_controller.get_storage_unit_view(storage_unit_id)
	var stock_by_id: Dictionary[StringName, int] = {}
	var raw_slots: Variant = view.get("slots", [])
	if raw_slots is Array:
		for raw_slot: Variant in raw_slots:
			if not (raw_slot is Dictionary):
				continue
			var slot: Dictionary = raw_slot
			var ing_id := StringName(slot.get("ingredient_id", &""))
			var qty := int(slot.get("quantity", 0))
			if ing_id != &"" and qty > 0:
				stock_by_id[ing_id] = int(stock_by_id.get(ing_id, 0)) + qty
	var stock_parts: PackedStringArray = []
	for ing_id in SHOP_INGREDIENT_ORDER:
		if stock_by_id.has(ing_id):
			stock_parts.append("%s %d" % [_get_ingredient_display_name(ing_id), stock_by_id[ing_id]])
	for ing_id: StringName in stock_by_id:
		if not SHOP_INGREDIENT_ORDER.has(ing_id):
			stock_parts.append("%s %d" % [_get_ingredient_display_name(ing_id), stock_by_id[ing_id]])
	var lines: PackedStringArray = [
		"Stok: %s" % (", ".join(stock_parts) if not stock_parts.is_empty() else "Kosong")
	]
	var now := 0.0
	if (
		_game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_method(&"get_service_elapsed")
	):
		now = float(_game_root.get_service_elapsed())
	var pending_parts: PackedStringArray = []
	for deliv: Dictionary in _kitchen_controller.get_pending_delivery_views():
		if deliv.get("storage_unit_id", &"") != storage_unit_id:
			continue
		var ing_id := StringName(deliv.get("ingredient_id", &""))
		var qty := int(deliv.get("quantity", 0))
		var secs := maxi(0, ceili(float(deliv.get("due_at", 0.0)) - now))
		pending_parts.append("%s x%d (%d dtk)" % [_get_ingredient_display_name(ing_id), qty, secs])
	if not pending_parts.is_empty():
		lines.append("Kiriman: %s" % ", ".join(pending_parts))
	return "\n".join(lines)


func _format_selected_target_live_status(target_id: StringName) -> String:
	if target_id == &"online_station":
		return _format_online_station_status()
	if (
		_service_controller != null
		and is_instance_valid(_service_controller)
		and _service_controller.has_driver(target_id)
	):
		return _format_driver_status(target_id)
	if (
		_kitchen_controller != null
		and is_instance_valid(_kitchen_controller)
		and _kitchen_controller.has_storage_unit(target_id)
	):
		return _format_storage_unit_status(target_id)
	return ""


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

	var vp_size := _get_viewport_logical_size()
	var hud_w := clampf(ui_safe_rect.size.x, 0.0, maxf(0.0, vp_size.x - 200.0))
	if left_hud_region != null:
		left_hud_region.position = ui_safe_rect.position
		left_hud_region.size = Vector2(hud_w, vp_size.y)
	_layout_fixture_shop_overlay()

	day_label.text = "Hari %d/7" % day_index if day_index <= 7 else "Hari %d" % day_index
	var is_planning := (phase == SharedTypes.Phase.PLANNING)
	phase_label.text = (
		"persiapan sebelum buka"
		if is_planning
		else PHASE_LABELS.get(phase, "Perencanaan")
	)
	cash_label.text = "Kas: Rp%d" % cash

	var target_ratio := (
		clampf(float(cash) / float(target), 0.0, 1.0)
		if target > 0
		else 0.0
	)
	var target_pct := int(round(target_ratio * 100.0))
	goal_label.text = "Target Hari 7: %d%%" % target_pct

	goal_progress_bar.min_value = 0.0
	goal_progress_bar.max_value = 1.0
	goal_progress_bar.step = 0.0
	goal_progress_bar.value = target_ratio

	planning_box.visible = is_planning
	if edit_menu_button != null:
		edit_menu_button.disabled = not is_planning
		if not is_planning and edit_menu_button.has_focus():
			edit_menu_button.release_focus()
	if fixture_shop_button != null:
		fixture_shop_button.disabled = not is_planning
		if not is_planning and fixture_shop_button.has_focus():
			fixture_shop_button.release_focus()
	if menu_stub_button != null:
		menu_stub_button.disabled = not is_planning
		if not is_planning and menu_stub_button.has_focus():
			menu_stub_button.release_focus()
	if exit_stub_button != null:
		exit_stub_button.disabled = not is_planning
		if not is_planning and exit_stub_button.has_focus():
			exit_stub_button.release_focus()
	forecast_quota_label.text = "Target Tamu: %d" % planned_quota
	if start_hint_label != null:
		start_hint_label.text = "Ketik: buka"

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

	var show_planning_typing := (
		phase == SharedTypes.Phase.PLANNING
		and selected_id == &""
		and not prefix.is_empty()
	)
	if selected_id == &"" and _feedback_text.is_empty() and not show_planning_typing:
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
	var show_commands := is_serving or show_planning_typing
	if target_status_label != null:
		var live_status := (
			_format_selected_target_live_status(selected_id)
			if is_serving and selected_id != &""
			else ""
		)
		target_status_label.visible = not live_status.is_empty()
		target_status_label.text = live_status

	if show_commands and not allowed.is_empty():
		allowed_commands_label.visible = true
		allowed_commands_label.text = _format_allowed_commands(prefix, allowed)
	else:
		allowed_commands_label.visible = false
		allowed_commands_label.text = ""

	if show_commands and (not allowed.is_empty() or not prefix.is_empty()):
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
		if show_commands and not remaining_text.is_empty():
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
		if (
			anchor_node == null
			and selected_id != &""
			and _world_map.has_method(&"get_driver_visual_node")
		):
			anchor_node = _world_map.get_driver_visual_node(selected_id)

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
	if show_panel:
		day_result_side_panel.position = Vector2(384.0, 12.0)
		day_result_side_panel.size = Vector2(244.0, 336.0)
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
		if WorldMap.point_hits_area_shapes(area, world_global_pos) and not candidates.has(object_id):
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


func _is_point_blocked_by_ui(canvas_pos: Vector2) -> bool:
	if is_modal_blocking():
		return true
	if ui_safe_rect.has_point(canvas_pos):
		return true
	if left_hud_region != null and left_hud_region.visible:
		if left_hud_region.get_global_rect().has_point(canvas_pos):
			return true
	if day_result_side_panel != null and day_result_side_panel.visible:
		if day_result_side_panel.get_global_rect().has_point(canvas_pos):
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


func _is_planning_phase() -> bool:
	return _get_current_phase() == SharedTypes.Phase.PLANNING


func _is_serving_phase() -> bool:
	return _get_current_phase() == SharedTypes.Phase.SERVING


func _apply_fallback_styles() -> void:
	if left_hud_region != null:
		var hud_style := _make_panel_style(
			Color(0.11, 0.13, 0.18, 0.95),
			Color(0.32, 0.37, 0.48, 1.0),
			6
		)
		left_hud_region.add_theme_stylebox_override("panel", hud_style)
	if edit_menu_popup != null:
		var popup_style := _make_panel_style(
			Color(0.12, 0.14, 0.20, 0.98),
			Color(0.45, 0.52, 0.66, 1.0),
			10
		)
		edit_menu_popup.add_theme_stylebox_override("panel", popup_style)
	if ingredient_shop_popup != null:
		var shop_style := _make_panel_style(
			Color(0.12, 0.14, 0.20, 0.98),
			Color(0.45, 0.52, 0.66, 1.0),
			10
		)
		ingredient_shop_popup.add_theme_stylebox_override("panel", shop_style)
	if fixture_shop_popup != null:
		var fixture_style := _make_panel_style(
			Color(0.12, 0.14, 0.20, 0.98),
			Color(0.45, 0.52, 0.66, 1.0),
			10
		)
		fixture_shop_popup.add_theme_stylebox_override("panel", fixture_style)
	if day_result_side_panel != null:
		var result_style := _make_panel_style(
			Color(0.11, 0.13, 0.19, 0.96),
			Color(0.42, 0.49, 0.63, 1.0),
			8
		)
		day_result_side_panel.add_theme_stylebox_override("panel", result_style)


func _make_panel_style(bg: Color, border: Color, margin_px: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(margin_px)
	return box


func _rebuild_edit_menu_list(run_view: Dictionary) -> void:
	_edit_menu_buttons.clear()
	if edit_menu_recipe_list == null:
		return
	for child in edit_menu_recipe_list.get_children():
		edit_menu_recipe_list.remove_child(child)
		child.free()

	var unlocked_raw: Variant = run_view.get("unlocked_recipe_ids", [])
	if not (unlocked_raw is Array):
		return
	for raw_id: Variant in unlocked_raw:
		var recipe_id := StringName(raw_id)
		if recipe_id == &"":
			continue

		var row := HBoxContainer.new()
		row.name = "RecipeRow_%s" % recipe_id
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit_menu_recipe_list.add_child(row)

		var icons_box := HBoxContainer.new()
		icons_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icons_box)
		var textures := _resolve_recipe_part_textures(recipe_id)
		if textures.is_empty():
			var fallback_rect := ColorRect.new()
			fallback_rect.custom_minimum_size = Vector2(16, 16)
			fallback_rect.color = Color(0.65, 0.58, 0.42, 1.0)
			fallback_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icons_box.add_child(fallback_rect)
		else:
			for tex in textures:
				if tex != null:
					var tex_rect := TextureRect.new()
					tex_rect.texture = tex
					tex_rect.custom_minimum_size = Vector2(16, 16)
					tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
					icons_box.add_child(tex_rect)
				else:
					var part_fallback := ColorRect.new()
					part_fallback.custom_minimum_size = Vector2(16, 16)
					part_fallback.color = Color(0.55, 0.62, 0.72, 1.0)
					part_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
					icons_box.add_child(part_fallback)

		var btn := Button.new()
		btn.name = "RecipeButton_%s" % recipe_id
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_ALL
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.clip_text = true
		var selected := _pending_menu_selection.has(recipe_id)
		btn.set_pressed_no_signal(selected)
		_update_recipe_button_visual(btn, recipe_id, selected)
		btn.toggled.connect(
			func(pressed: bool) -> void:
				_on_recipe_button_toggled(recipe_id, pressed)
		)
		row.add_child(btn)
		_edit_menu_buttons[recipe_id] = btn


func _on_recipe_button_toggled(recipe_id: StringName, pressed: bool) -> void:
	if not is_edit_menu_open() or recipe_id == &"":
		return
	var idx := _pending_menu_selection.find(recipe_id)
	if pressed and idx < 0:
		_pending_menu_selection.append(recipe_id)
	elif not pressed and idx >= 0:
		_pending_menu_selection.remove_at(idx)

	if _edit_menu_buttons.has(recipe_id):
		var btn := _edit_menu_buttons[recipe_id]
		if btn != null and is_instance_valid(btn):
			_update_recipe_button_visual(btn, recipe_id, pressed)

	if edit_menu_error_label != null:
		edit_menu_error_label.visible = false
		edit_menu_error_label.text = ""


func _update_recipe_button_visual(
	btn: Button,
	recipe_id: StringName,
	selected: bool
) -> void:
	var display := _get_recipe_display_name(recipe_id)
	var price := _get_recipe_dine_in_price(recipe_id)
	var marker := "[Aktif]" if selected else "[ ]"
	if price > 0:
		btn.text = "%s %s — Rp%d" % [marker, display, price]
	else:
		btn.text = "%s %s" % [marker, display]

	var style := _make_panel_style(
		EDIT_MENU_SELECTED_BG if selected else EDIT_MENU_UNSELECTED_BG,
		EDIT_MENU_SELECTED_BORDER if selected else EDIT_MENU_UNSELECTED_BORDER,
		4
	)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)


func _get_recipe_dine_in_price(recipe_id: StringName) -> int:
	if _run_controller == null or not is_instance_valid(_run_controller):
		return 0
	if _run_controller.economy_config == null:
		return 0
	var entry := _run_controller.economy_config.get_recipe_entry(recipe_id)
	if entry == null:
		return 0
	return entry.dine_in_price


func _show_edit_menu_error(msg: String) -> void:
	if edit_menu_error_label != null:
		edit_menu_error_label.text = msg
		edit_menu_error_label.modulate = Color(1.0, 0.48, 0.48, 1.0)
		edit_menu_error_label.visible = true


func _describe_menu_rejection(recipe_ids: Array[StringName]) -> String:
	if not _is_planning_phase():
		return "Edit Menu hanya tersedia saat persiapan sebelum buka."
	if recipe_ids.is_empty():
		return "Pilih minimal 1 menu sebelum menyimpan."
	var unlocked: Array[StringName] = []
	if _run_controller != null and is_instance_valid(_run_controller):
		var raw_unlocked: Variant = _run_controller.get_run_view().get("unlocked_recipe_ids", [])
		if raw_unlocked is Array:
			for item: Variant in raw_unlocked:
				unlocked.append(StringName(item))
	var seen: Dictionary[StringName, bool] = {}
	for id in recipe_ids:
		if id == &"" or seen.has(id):
			return "Pilihan menu mengandung duplikat atau ID kosong."
		seen[id] = true
		if not unlocked.has(id):
			return "Menu '%s' belum terbuka." % _get_recipe_display_name(id)
	return "Pilihan menu tidak valid."


func _get_ordered_shop_ingredient_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	if _kitchen_controller == null or not is_instance_valid(_kitchen_controller):
		return result
	var registered: Array[StringName] = _kitchen_controller.get_ingredient_ids()
	for id in SHOP_INGREDIENT_ORDER:
		if registered.has(id) and _get_ingredient_unit_price(id) > 0:
			result.append(id)
	for id in registered:
		if not result.has(id) and _get_ingredient_unit_price(id) > 0:
			result.append(id)
	return result


func _get_ingredient_unit_price(ingredient_id: StringName) -> int:
	if _run_controller == null or not is_instance_valid(_run_controller):
		return 0
	if _run_controller.economy_config == null:
		return 0
	return _run_controller.economy_config.get_ingredient_price(ingredient_id)


func _get_ingredient_display_name(ingredient_id: StringName) -> String:
	if _kitchen_controller != null and is_instance_valid(_kitchen_controller):
		var def := _kitchen_controller.get_ingredient_def(ingredient_id)
		if def != null and not def.display_name.is_empty():
			return def.display_name
	return String(ingredient_id).capitalize()


func _compute_basket_total(basket: Dictionary) -> int:
	var total := 0
	for raw_id: Variant in basket.keys():
		var ing_id := StringName(raw_id)
		var qty: int = int(basket[raw_id])
		if qty <= 0:
			continue
		var price := _get_ingredient_unit_price(ing_id)
		if price > 0:
			total += price * qty
	return total


func _validate_shop_basket(basket: Dictionary) -> String:
	if basket.is_empty():
		return "Pilih minimal 1 bahan terlebih dahulu."
	var cash := int(_run_controller.get_run_view().get("cash", 0))
	var total := 0
	var clean_items: Dictionary[StringName, int] = {}
	for raw_id: Variant in basket.keys():
		var ing_id := StringName(raw_id)
		var raw_qty: Variant = basket[raw_id]
		if not (raw_qty is int):
			return "Jumlah bahan tidak valid."
		var qty := int(raw_qty)
		if ing_id == &"" or qty <= 0:
			return "Jumlah bahan harus lebih dari nol."
		if _kitchen_controller.get_ingredient_def(ing_id) == null:
			return "Bahan '%s' tidak terdaftar." % ing_id
		var price := _get_ingredient_unit_price(ing_id)
		if price <= 0:
			return "Harga '%s' tidak valid." % _get_ingredient_display_name(ing_id)
		clean_items[ing_id] = qty
		total += price * qty
	if total > cash:
		return "Uang tidak cukup (Total Rp%d, Kas Rp%d)." % [total, cash]
	if not _kitchen_controller.can_receive_stock_basket(clean_items, _shop_storage_unit_id):
		return "Kapasitas penyimpanan penuh."
	return ""


func _build_ingredient_shop_rows() -> void:
	_shop_ingredient_rows.clear()
	if shop_ingredient_list == null:
		return
	for child in shop_ingredient_list.get_children():
		shop_ingredient_list.remove_child(child)
		child.free()

	for ing_id in _get_ordered_shop_ingredient_ids():
		var row := HBoxContainer.new()
		row.name = "ShopRow_%s" % ing_id
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shop_ingredient_list.add_child(row)

		var def := _kitchen_controller.get_ingredient_def(ing_id)
		var raw_tex: Texture2D = (
			def.get_texture_for_state(SharedTypes.PrepState.RAW) if def != null else null
		)
		if raw_tex != null:
			var icon_rect := TextureRect.new()
			icon_rect.texture = raw_tex
			icon_rect.custom_minimum_size = Vector2(18, 18)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon_rect)
		else:
			var fallback_icon := ColorRect.new()
			fallback_icon.custom_minimum_size = Vector2(18, 18)
			fallback_icon.color = Color(0.62, 0.36, 0.36, 1.0)
			fallback_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(fallback_icon)

		var name_label := Label.new()
		name_label.text = _get_ingredient_display_name(ing_id)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_label)

		var price_label := Label.new()
		price_label.text = "Rp%d" % _get_ingredient_unit_price(ing_id)
		price_label.custom_minimum_size = Vector2(64, 0)
		price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(price_label)

		var stock_label := Label.new()
		stock_label.text = "Stok: 0"
		stock_label.custom_minimum_size = Vector2(54, 0)
		stock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(stock_label)

		var minus_btn := Button.new()
		minus_btn.name = "Minus_%s" % ing_id
		minus_btn.text = "-"
		minus_btn.custom_minimum_size = Vector2(26, 0)
		minus_btn.focus_mode = Control.FOCUS_ALL
		minus_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		minus_btn.pressed.connect(func() -> void: adjust_shop_quantity(ing_id, -1))
		row.add_child(minus_btn)

		var qty_label := Label.new()
		qty_label.text = "0"
		qty_label.custom_minimum_size = Vector2(24, 0)
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(qty_label)

		var plus_btn := Button.new()
		plus_btn.name = "Plus_%s" % ing_id
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(26, 0)
		plus_btn.focus_mode = Control.FOCUS_ALL
		plus_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		plus_btn.pressed.connect(func() -> void: adjust_shop_quantity(ing_id, 1))
		row.add_child(plus_btn)

		var subtotal_label := Label.new()
		subtotal_label.text = "Rp0"
		subtotal_label.custom_minimum_size = Vector2(64, 0)
		subtotal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		subtotal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(subtotal_label)

		_shop_ingredient_rows[ing_id] = {
			"minus_button": minus_btn,
			"plus_button": plus_btn,
			"qty_label": qty_label,
			"stock_label": stock_label,
			"subtotal_label": subtotal_label,
			"price_label": price_label,
		}


func _refresh_ingredient_shop_view() -> void:
	if not is_ingredient_shop_open():
		return
	if _kitchen_controller == null or _run_controller == null:
		return

	var run_view := _run_controller.get_run_view()
	var cash := int(run_view.get("cash", 0))
	var storage_view := _kitchen_controller.get_storage_unit_view(_shop_storage_unit_id)
	var stock_by_id: Dictionary[StringName, int] = {}
	var raw_slots: Variant = storage_view.get("slots", [])
	if raw_slots is Array:
		for slot: Variant in raw_slots:
			if not (slot is Dictionary):
				continue
			var s_ing := StringName((slot as Dictionary).get("ingredient_id", &""))
			var s_qty := int((slot as Dictionary).get("quantity", 0))
			if s_ing != &"" and s_qty > 0:
				stock_by_id[s_ing] = int(stock_by_id.get(s_ing, 0)) + s_qty

	if shop_target_label != null:
		shop_target_label.text = get_target_display_title(_shop_storage_unit_id)
	if shop_cash_label != null:
		shop_cash_label.text = "Kas: Rp%d" % cash
	if shop_capacity_label != null:
		shop_capacity_label.text = "Sisa kapasitas: %d" % get_shop_remaining_capacity()
	if shop_delivery_hint_label != null:
		shop_delivery_hint_label.text = (
			"Tiba 100 dtk (Esc/Ambil utk ketik)" if _is_serving_phase() else "Tiba langsung"
		)
	if shop_retrieve_button != null:
		var show_retrieve := _is_serving_phase()
		shop_retrieve_button.visible = show_retrieve
		shop_retrieve_button.disabled = not show_retrieve

	_refresh_shop_slots(storage_view)
	_refresh_shop_pending_deliveries()

	for ing_id: StringName in _shop_ingredient_rows:
		var controls: Dictionary = _shop_ingredient_rows[ing_id]
		var qty := int(_pending_shop_basket.get(ing_id, 0))
		var stock_qty := int(stock_by_id.get(ing_id, 0))
		var unit_price := _get_ingredient_unit_price(ing_id)

		(controls["stock_label"] as Label).text = "Stok: %d" % stock_qty
		(controls["qty_label"] as Label).text = "%d" % qty
		(controls["subtotal_label"] as Label).text = "Rp%d" % (unit_price * qty)
		(controls["price_label"] as Label).text = "Rp%d" % unit_price

		var minus_btn := controls["minus_button"] as Button
		minus_btn.disabled = qty <= 0

		var candidate: Dictionary[StringName, int] = {}
		for k: StringName in _pending_shop_basket:
			var q: int = int(_pending_shop_basket[k])
			if q > 0:
				candidate[k] = q
		candidate[ing_id] = qty + 1
		var can_add := (
			unit_price > 0
			and _compute_basket_total(candidate) <= cash
			and _kitchen_controller.can_receive_stock_basket(candidate, _shop_storage_unit_id)
		)
		var plus_btn := controls["plus_button"] as Button
		plus_btn.disabled = not can_add

	if shop_total_label != null:
		shop_total_label.text = "Total: Rp%d" % get_shop_total()


func _refresh_shop_slots(storage_view: Dictionary) -> void:
	if shop_slots_row == null:
		return
	for child in shop_slots_row.get_children():
		shop_slots_row.remove_child(child)
		child.free()

	var raw_slots: Variant = storage_view.get("slots", [])
	if not (raw_slots is Array):
		return
	var idx := 0
	for raw_slot: Variant in raw_slots:
		if not (raw_slot is Dictionary):
			continue
		idx += 1
		var slot: Dictionary = raw_slot
		var ing_id := StringName(slot.get("ingredient_id", &""))
		var qty := int(slot.get("quantity", 0))
		var cap := int(slot.get("capacity", 0))
		var slot_box := PanelContainer.new()
		slot_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_box.add_theme_stylebox_override(
			"panel",
			_make_panel_style(EDIT_MENU_UNSELECTED_BG, EDIT_MENU_UNSELECTED_BORDER, 3)
		)
		var lbl := Label.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ing_id == &"" or qty <= 0:
			lbl.text = "S%d: Kosong (0/%d)" % [idx, cap]
		else:
			lbl.text = "S%d: %s %d/%d" % [idx, _get_ingredient_display_name(ing_id), qty, cap]
		slot_box.add_child(lbl)
		shop_slots_row.add_child(slot_box)


func _refresh_shop_pending_deliveries() -> void:
	if shop_pending_label == null or _kitchen_controller == null:
		return
	var now := 0.0
	if (
		_game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_method(&"get_service_elapsed")
	):
		now = float(_game_root.get_service_elapsed())

	var parts: PackedStringArray = []
	for deliv: Dictionary in _kitchen_controller.get_pending_delivery_views():
		if deliv.get("storage_unit_id", &"") != _shop_storage_unit_id:
			continue
		var ing_id := StringName(deliv.get("ingredient_id", &""))
		var qty := int(deliv.get("quantity", 0))
		var rem := maxi(0, ceili(float(deliv.get("due_at", 0.0)) - now))
		parts.append("%s x%d (%d dtk)" % [_get_ingredient_display_name(ing_id), qty, rem])

	if parts.is_empty():
		shop_pending_label.text = "Kiriman tertunda: tidak ada"
	else:
		shop_pending_label.text = "Kiriman tertunda: %s" % ", ".join(parts)


func _show_shop_error(msg: String) -> void:
	if shop_error_label != null:
		shop_error_label.text = msg
		shop_error_label.modulate = Color(1.0, 0.48, 0.48, 1.0)
		shop_error_label.visible = true


func _clear_shop_error() -> void:
	if shop_error_label != null:
		shop_error_label.visible = false
		shop_error_label.text = ""


func _pick_default_fixture_slot() -> StringName:
	if _world_map == null or not is_instance_valid(_world_map):
		return &"slot_utility_01"
	var slot_ids := _world_map.get_placement_slot_ids()
	if slot_ids.is_empty():
		return &"slot_utility_01"
	var occupied := _get_occupied_slot_map()
	for s_id in slot_ids:
		if not occupied.has(s_id):
			return s_id
	return slot_ids[0]


func _pick_default_fixture_utility(slot_id: StringName) -> StringName:
	if _run_controller == null or not is_instance_valid(_run_controller):
		return &"stove"
	var ordered := _get_ordered_utility_ids()
	if slot_id != &"" and _world_map != null and is_instance_valid(_world_map):
		var slot_view := _world_map.get_placement_slot_view(slot_id)
		var allowed_raw: Variant = slot_view.get("allowed_kinds", [])
		if allowed_raw is Array:
			for u_id in ordered:
				var def := _run_controller.get_utility_def(u_id)
				if def != null and (allowed_raw as Array).has(int(def.fixture_kind)):
					return u_id
	return ordered[0] if not ordered.is_empty() else &"stove"


func _get_ordered_utility_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	if _run_controller == null or not is_instance_valid(_run_controller):
		return result
	var available := _run_controller.get_utility_ids()
	for u_id in FIXTURE_SHOP_ORDER:
		if available.has(u_id):
			result.append(u_id)
	for u_id in available:
		if not result.has(u_id):
			result.append(u_id)
	return result


func _get_occupied_slot_map() -> Dictionary[StringName, StringName]:
	var result: Dictionary[StringName, StringName] = {}
	if _run_controller == null or not is_instance_valid(_run_controller):
		return result
	var installed: Variant = (
		_run_controller.get_run_view().get("installed_fixtures", {})
	)
	if not (installed is Dictionary):
		return result
	for inst_id: Variant in installed:
		var raw_inst: Variant = installed[inst_id]
		if not (raw_inst is Dictionary):
			continue
		var inst := raw_inst as Dictionary
		var s_id := StringName(inst.get("slot_id", &""))
		if s_id != &"":
			result[s_id] = StringName(inst_id)
	return result


func _build_fixture_shop_ui() -> void:
	_fixture_slot_buttons.clear()
	_fixture_shop_rows.clear()
	if fixture_slots_row != null:
		for child in fixture_slots_row.get_children():
			fixture_slots_row.remove_child(child)
			child.free()
	if fixture_list != null:
		for child in fixture_list.get_children():
			fixture_list.remove_child(child)
			child.free()

	if _world_map != null and is_instance_valid(_world_map) and fixture_slots_row != null:
		for slot_id in _world_map.get_placement_slot_ids():
			var btn := Button.new()
			btn.name = "SlotBtn_%s" % slot_id
			btn.toggle_mode = true
			btn.focus_mode = Control.FOCUS_ALL
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(40, 22)
			btn.add_theme_font_size_override("font_size", 10)
			btn.clip_text = true
			var captured_slot := slot_id
			btn.pressed.connect(
				func() -> void:
					select_fixture_shop_slot(captured_slot)
			)
			fixture_slots_row.add_child(btn)
			_fixture_slot_buttons[slot_id] = btn

	if _run_controller == null or fixture_list == null:
		return

	for u_id in _get_ordered_utility_ids():
		var def := _run_controller.get_utility_def(u_id)
		if def == null:
			continue

		var row_panel := PanelContainer.new()
		row_panel.name = "FixtureRow_%s" % u_id
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fixture_list.add_child(row_panel)

		var row_box := HBoxContainer.new()
		row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_box.add_theme_constant_override("separation", 6)
		row_panel.add_child(row_box)

		var info_col := VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_col.add_theme_constant_override("separation", 1)
		row_box.add_child(info_col)

		var title_lbl := Label.new()
		title_lbl.name = "TitleLabel"
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_lbl.add_theme_font_size_override("font_size", 11)
		var cat_label: String = FIXTURE_CATEGORY_LABELS.get(int(def.fixture_kind), "Peralatan")
		title_lbl.text = "%s [%s] — Rp%d" % [def.display_name, cat_label, def.purchase_price]
		info_col.add_child(title_lbl)

		var benefit_lbl := Label.new()
		benefit_lbl.name = "BenefitLabel"
		benefit_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		benefit_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		benefit_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		benefit_lbl.add_theme_font_size_override("font_size", 10)
		benefit_lbl.modulate = Color(0.75, 0.95, 0.80, 1.0)
		benefit_lbl.text = "Manfaat: %s" % FIXTURE_BENEFIT_LABELS.get(
			u_id,
			"Meningkatkan kapasitas operasional"
		)
		info_col.add_child(benefit_lbl)

		var downside_lbl := Label.new()
		downside_lbl.name = "DownsideLabel"
		downside_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		downside_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		downside_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		downside_lbl.add_theme_font_size_override("font_size", 10)
		downside_lbl.modulate = Color(1.0, 0.82, 0.55, 1.0)
		downside_lbl.text = _describe_fixture_downside(u_id, def)
		info_col.add_child(downside_lbl)

		var avail_lbl := Label.new()
		avail_lbl.name = "AvailabilityLabel"
		avail_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		avail_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		avail_lbl.add_theme_font_size_override("font_size", 10)
		info_col.add_child(avail_lbl)

		var select_btn := Button.new()
		select_btn.name = "SelectButton"
		select_btn.toggle_mode = true
		select_btn.focus_mode = Control.FOCUS_ALL
		select_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		select_btn.custom_minimum_size = Vector2(56, 26)
		select_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		select_btn.add_theme_font_size_override("font_size", 11)
		select_btn.text = "Pilih"
		var captured_id := u_id
		select_btn.pressed.connect(
			func() -> void:
				select_fixture_shop_utility(captured_id)
		)
		row_box.add_child(select_btn)

		_fixture_shop_rows[u_id] = {
			"panel": row_panel,
			"title_label": title_lbl,
			"benefit_label": benefit_lbl,
			"downside_label": downside_lbl,
			"availability_label": avail_lbl,
			"select_button": select_btn,
		}


func _get_viewport_logical_size() -> Vector2:
	if is_inside_tree() and get_viewport() != null:
		var vis := get_viewport().get_visible_rect().size
		if vis.x > 0.0 and vis.y > 0.0:
			return vis
	return LOGICAL_VIEWPORT_SIZE


func _on_viewport_size_changed() -> void:
	_layout_fixture_shop_overlay()
	_refresh_hud()


func _layout_fixture_shop_overlay() -> void:
	var vp_size := _get_viewport_logical_size()
	var hud_w := clampf(ui_safe_rect.size.x, 0.0, maxf(0.0, vp_size.x - 200.0))
	var world_rect := Rect2(
		hud_w,
		0.0,
		maxf(160.0, vp_size.x - hud_w),
		maxf(120.0, vp_size.y)
	)
	world_visible_rect = world_rect
	if fixture_shop_overlay == null or fixture_shop_popup == null:
		return
	var dimmer := fixture_shop_overlay.get_node_or_null("WorldDimmer") as ColorRect
	if dimmer != null:
		dimmer.position = world_rect.position
		dimmer.size = world_rect.size
	var margin_x := clampf(roundf(world_rect.size.x * 0.035), 8.0, 20.0)
	var margin_y := clampf(roundf(world_rect.size.y * 0.04), 8.0, 14.0)
	var avail_w := maxf(180.0, world_rect.size.x - margin_x * 2.0)
	var avail_h := maxf(140.0, world_rect.size.y - margin_y * 2.0)
	var popup_w := minf(488.0, avail_w)
	var popup_h := minf(332.0, avail_h)
	var popup_x := world_rect.position.x + floorf((world_rect.size.x - popup_w) * 0.5)
	var popup_y := world_rect.position.y + floorf((world_rect.size.y - popup_h) * 0.5)
	fixture_shop_popup.custom_minimum_size = Vector2.ZERO
	fixture_shop_popup.position = Vector2(popup_x, popup_y)
	fixture_shop_popup.size = Vector2(popup_w, popup_h)


func _refresh_fixture_shop_view() -> void:
	if not is_node_ready() or _run_controller == null:
		return

	var run_view := _run_controller.get_run_view()
	var cash := int(run_view.get("cash", 0))
	var daily_power := _run_controller.get_daily_electricity_estimate()
	if fixture_cash_label != null:
		fixture_cash_label.text = "Kas: Rp%d" % cash
	if fixture_power_label != null:
		fixture_power_label.text = "Listrik: Rp%d/hari" % daily_power

	var occupied := _get_occupied_slot_map()
	for slot_id: StringName in _fixture_slot_buttons:
		var btn := _fixture_slot_buttons[slot_id]
		if btn == null or not is_instance_valid(btn):
			continue
		var selected := (slot_id == _selected_fixture_slot_id)
		btn.set_pressed_no_signal(selected)
		var slot_title: String = SLOT_DISPLAY_LABELS.get(slot_id, String(slot_id))
		if occupied.has(slot_id):
			var inst_id := occupied[slot_id]
			var inst_title := get_target_display_title(inst_id)
			btn.text = "%s (%s)" % [slot_title, inst_title]
		else:
			btn.text = "%s (Kosong)" % slot_title

	for u_id: StringName in _fixture_shop_rows:
		var controls: Dictionary = _fixture_shop_rows[u_id]
		var def := _run_controller.get_utility_def(u_id)
		if def == null:
			continue
		var selected := (u_id == _selected_fixture_utility_id)
		var panel := controls["panel"] as PanelContainer
		panel.add_theme_stylebox_override(
			"panel",
			_make_panel_style(
				EDIT_MENU_SELECTED_BG if selected else EDIT_MENU_UNSELECTED_BG,
				EDIT_MENU_SELECTED_BORDER if selected else EDIT_MENU_UNSELECTED_BORDER,
				5
			)
		)
		var select_btn := controls["select_button"] as Button
		select_btn.set_pressed_no_signal(selected)
		select_btn.text = "Terpilih" if selected else "Pilih"

		var compat_slots := _run_controller.get_compatible_empty_slots(u_id)
		var check := _run_controller.can_purchase_fixture(u_id, _selected_fixture_slot_id)
		var avail_lbl := controls["availability_label"] as Label
		if bool(check.get("ok", false)):
			avail_lbl.text = "Siap dipasang di %s (slot kompatibel: %d)" % [
				SLOT_DISPLAY_LABELS.get(_selected_fixture_slot_id, String(_selected_fixture_slot_id)),
				compat_slots.size(),
			]
			avail_lbl.modulate = Color(0.65, 0.95, 0.72, 1.0)
		else:
			var reason := StringName(check.get("reason", &"invalid"))
			avail_lbl.text = "%s (slot kosong kompatibel: %d)" % [
				_describe_fixture_purchase_rejection(reason),
				compat_slots.size(),
			]
			avail_lbl.modulate = Color(0.95, 0.65, 0.65, 1.0)

	if fixture_selection_label != null:
		var sel_def := _run_controller.get_utility_def(_selected_fixture_utility_id)
		var slot_label: String = SLOT_DISPLAY_LABELS.get(
			_selected_fixture_slot_id,
			String(_selected_fixture_slot_id)
		)
		if sel_def != null:
			fixture_selection_label.text = "%s -> %s (Rp%d)" % [
				sel_def.display_name,
				slot_label,
				sel_def.purchase_price,
			]
		else:
			fixture_selection_label.text = "Pilih slot & alat"


func _describe_fixture_downside(utility_id: StringName, def: UtilityDef) -> String:
	var power := 0
	if _run_controller != null and is_instance_valid(_run_controller):
		power = _run_controller.get_fixture_daily_electricity_cost(utility_id)
	if power > 0:
		return "Beban (Complexity Debt): Listrik +Rp%d/hari & pakai 1 slot permanen" % power
	if def != null and def.fixture_kind == SharedTypes.FixtureKind.DINING_TABLE:
		return "Beban (Complexity Debt): Tambah meja meningkatkan tekanan antrean & piring"
	return "Beban (Complexity Debt): Listrik Rp0/hari, pakai 1 slot dapur permanen"


func _describe_fixture_purchase_rejection(reason: StringName) -> String:
	match reason:
		&"insufficient_cash":
			return "Kas tidak cukup untuk membeli alat ini."
		&"slot_occupied", &"footprint_blocked":
			return "Slot sudah terisi."
		&"incompatible_slot", &"slot_incompatible":
			return "Alat tidak cocok dengan slot ini."
		&"not_planning":
			return "Pembelian alat hanya saat perencanaan."
		&"no_cardinal_access":
			return "Slot tidak memiliki akses jalan di sebelahnya."
		_:
			return "Pilihan alat atau slot tidak valid."


func _show_fixture_error(msg: String) -> void:
	if fixture_error_label != null:
		fixture_error_label.text = msg
		fixture_error_label.modulate = Color(1.0, 0.48, 0.48, 1.0)
		fixture_error_label.visible = true


func _clear_fixture_error() -> void:
	if fixture_error_label != null:
		fixture_error_label.visible = false
		fixture_error_label.text = ""
