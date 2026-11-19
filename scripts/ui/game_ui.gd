class_name GameUI
extends CanvasLayer
## Presentation and input-forwarding layer for Ketik Saji.
##
## Owns only UI presentation state (active feedback message, invalid-key shake
## timer, and static Indonesian display labels). Never owns or mutates cash,
## phase, service clock, inventory, orders, or day progression directly.

signal exit_game_requested()

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
const SILENT_VISUAL_FEEDBACK_CODES: Array[StringName] = [
	&"invalid_key",
	&"tile_blocked",
]

const EDIT_MENU_SELECTED_BG: Color = Color(0.18, 0.42, 0.28, 1.0)
const EDIT_MENU_SELECTED_BORDER: Color = Color(0.55, 0.92, 0.62, 1.0)
const EDIT_MENU_UNSELECTED_BG: Color = Color(0.16, 0.18, 0.23, 1.0)
const EDIT_MENU_UNSELECTED_BORDER: Color = Color(0.36, 0.40, 0.48, 1.0)
const EDIT_MENU_PREVIEW_BORDER: Color = Color(0.45, 0.72, 0.98, 1.0)
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
const FIXTURE_PURPOSE_LABELS: Dictionary[StringName, String] = {
	&"box": "Buat nyimpen stok bahan harian",
	&"fridge": "Buat nyimpen bahan sampai beberapa hari",
	&"stove": "Untuk memasak",
	&"washer": "Buat nyuci beras & piring kotor",
	&"plate_rack": "Nambah stok piring bersih",
	&"rice_cooker": "Untuk menanak nasi",
	&"dining_table": "Nambah meja & kursi untuk pelanggan",
}
const WARUNG_TILESET_PATH: String = "res://assets/art/tiles/Warung-Tileset.png"
const SLOT_DISPLAY_LABELS: Dictionary[StringName, String] = {
	&"slot_utility_01": "Slot Dapur 1",
	&"slot_utility_02": "Slot Dapur 2",
	&"slot_utility_03": "Slot Dapur 3",
	&"slot_utility_04": "Slot Dapur 4",
	&"slot_utility_05": "Slot Dapur 5",
	&"slot_table_01": "Slot Meja 1",
	&"slot_table_02": "Slot Meja 2",
	&"slot_table_03": "Slot Meja 3",
	&"slot_table_04": "Slot Meja 4",
	&"slot_table_05": "Slot Meja 5",
	&"slot_table_06": "Slot Meja 6",
}

@export var ui_safe_rect: Rect2 = Rect2(0.0, 0.0, 136.0, 360.0)
@export var world_visible_rect: Rect2 = Rect2(136.0, 0.0, 504.0, 360.0)

var _game_root: Node = null
var _world_map: WorldMap = null
var _kitchen_controller: KitchenController = null
var _service_controller: ServiceController = null
var _run_controller: RunController = null

var _feedback_code: StringName = &""
var _feedback_text: String = ""
var _shake_remaining: float = 0.0
var _modal_blocking_active: bool = false
var _exit_quit_disabled: bool = false
var _pending_menu_selection: Array[StringName] = []
var _edit_menu_buttons: Dictionary[StringName, Button] = {}
var _edit_menu_preview_buttons: Dictionary[StringName, Button] = {}
var _edit_menu_rows: Dictionary[StringName, Dictionary] = {}
var _previewed_recipe_id: StringName = &""
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

var _onboarding_enabled: bool = false
var _onboarding_explicitly_set: bool = false
var _onboarding_boot_checked: bool = false
var _shown_day_stories: Dictionary[int, bool] = {}
var _shown_day7_epilogue: bool = false
var _active_story_id: StringName = &""
var _active_story_title: String = ""
var _active_story_lines: Array[Dictionary] = []
var _active_story_line_index: int = 0
var _tutorial_active: bool = false
var _tutorial_completed: bool = false
var _tutorial_skipped: bool = false
var _tutorial_step_index: int = 0
var _tutorial_started_day: int = 1
var _tutorial_flags: Dictionary[StringName, bool] = {}
var _tutorial_hint_text: String = ""
var _last_shop_storage_unit_id: StringName = &"storage_box"
var _shown_feature_tips: Dictionary[StringName, bool] = {}
var _pending_feature_tips: Array[StringName] = []
var _active_feature_tip_id: StringName = &""
var _last_seen_unlocked_count: int = 1
var _portrait_texture_cache: Dictionary[String, Texture2D] = {}

@onready var ui_root: Control = $UIRoot
@onready var left_hud_region: PanelContainer = $UIRoot/LeftHUDRegion
@onready var day_label: Label = $UIRoot/LeftHUDRegion/HUDColumn/DayLabel
@onready var phase_label: Label = $UIRoot/LeftHUDRegion/HUDColumn/PhaseLabel
@onready var cash_label: Label = $UIRoot/LeftHUDRegion/HUDColumn/CashLabel
@onready var goal_target_label: Label = $UIRoot/LeftHUDRegion/HUDColumn/GoalTargetLabel
@onready var goal_label: Label = $UIRoot/LeftHUDRegion/HUDColumn/GoalLabel
@onready var goal_progress_bar: ProgressBar = $UIRoot/LeftHUDRegion/HUDColumn/GoalProgressBar
@onready var planning_box: VBoxContainer = $UIRoot/LeftHUDRegion/HUDColumn/PlanningBox
@onready var potential_demand_label: Label = (
	$UIRoot/LeftHUDRegion/HUDColumn/PlanningBox/PotentialDemandLabel
)
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
@onready var pause_button: Button = $UIRoot/LeftHUDRegion/HUDColumn/PauseButton

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
@onready var result_narrative_label: Label = (
	$UIRoot/DayResultSidePanel/ResultColumn/ResultNarrativeLabel
)
@onready var continue_button: Button = (
	$UIRoot/DayResultSidePanel/ResultColumn/ResultFooter/ContinueButton
)
@onready var extra_mode_button: Button = (
	$UIRoot/DayResultSidePanel/ResultColumn/ResultFooter/ExtraModeButton
)

@onready var edit_menu_overlay: Control = $UIRoot/EditMenuOverlay
@onready var edit_menu_popup: PanelContainer = $UIRoot/EditMenuOverlay/EditMenuPopup
@onready var edit_menu_forecast_label: Label = (
	$UIRoot/EditMenuOverlay/EditMenuPopup/PopupColumn/EditMenuForecastLabel
)
@onready var edit_menu_recipe_list: VBoxContainer = (
	$UIRoot/EditMenuOverlay/EditMenuPopup/PopupColumn/EditMenuBodyRow/RecipeScroll/RecipeList
)
@onready var recipe_detail_panel: PanelContainer = (
	$UIRoot/EditMenuOverlay/EditMenuPopup/PopupColumn/EditMenuBodyRow/RecipeDetailPanel
)
@onready var recipe_detail_title_label: Label = (
	$UIRoot/EditMenuOverlay/EditMenuPopup/PopupColumn/EditMenuBodyRow/RecipeDetailPanel/DetailColumn/RecipeDetailTitleLabel
)
@onready var recipe_detail_list: VBoxContainer = (
	$UIRoot/EditMenuOverlay/EditMenuPopup/PopupColumn/EditMenuBodyRow/RecipeDetailPanel/DetailColumn/DetailScroll/RecipeDetailList
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
@onready var shop_status_row: HBoxContainer = (
	$UIRoot/IngredientShopOverlay/IngredientShopPopup/ShopColumn/ShopStatusRow
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
@onready var pause_overlay: Control = $UIRoot/PauseOverlay
@onready var pause_popup: PanelContainer = $UIRoot/PauseOverlay/PausePopup
@onready var pause_resume_button: Button = (
	$UIRoot/PauseOverlay/PausePopup/PauseColumn/PauseResumeButton
)
@onready var pause_exit_button: Button = (
	$UIRoot/PauseOverlay/PausePopup/PauseColumn/PauseExitButton
)
@onready var tutorial_guidance_overlay: TutorialGuidanceOverlay = (
	$UIRoot/TutorialGuidanceOverlay
)
@onready var tutorial_help_button: Button = $UIRoot/TutorialHelpButton
@onready var tutorial_banner: PanelContainer = $UIRoot/TutorialBanner
@onready var tutorial_title_label: Label = $UIRoot/TutorialBanner/TutorialColumn/TutorialTitleLabel
@onready var tutorial_body_label: Label = (
	$UIRoot/TutorialBanner/TutorialColumn/TutorialScroll/TutorialBodyLabel
)
@onready var tutorial_skip_button: Button = (
	$UIRoot/TutorialBanner/TutorialColumn/TutorialButtonsRow/TutorialSkipButton
)
@onready var tutorial_next_button: Button = (
	$UIRoot/TutorialBanner/TutorialColumn/TutorialButtonsRow/TutorialNextButton
)
@onready var feature_tip_panel: PanelContainer = $UIRoot/FeatureTipPanel
@onready var tip_title_label: Label = $UIRoot/FeatureTipPanel/TipColumn/TipTitleLabel
@onready var tip_body_label: Label = (
	$UIRoot/FeatureTipPanel/TipColumn/TipScroll/TipBodyLabel
)
@onready var tip_dismiss_button: Button = $UIRoot/FeatureTipPanel/TipColumn/TipDismissButton
@onready var tutorial_reference_overlay: Control = $UIRoot/TutorialReferenceOverlay
@onready var reference_popup: PanelContainer = $UIRoot/TutorialReferenceOverlay/ReferencePopup
@onready var reference_body_label: Label = (
	$UIRoot/TutorialReferenceOverlay/ReferencePopup/RefColumn/RefScroll/RefBodyLabel
)
@onready var reference_restart_button: Button = (
	$UIRoot/TutorialReferenceOverlay/ReferencePopup/RefColumn/RefFooterRow/RefRestartTutorialButton
)
@onready var reference_close_button: Button = (
	$UIRoot/TutorialReferenceOverlay/ReferencePopup/RefColumn/RefFooterRow/RefCloseButton
)
@onready var story_dialogue_overlay: Control = $UIRoot/StoryDialogueOverlay
@onready var story_popup: PanelContainer = $UIRoot/StoryDialogueOverlay/StoryPopup
@onready var story_title_label: Label = (
	$UIRoot/StoryDialogueOverlay/StoryPopup/StoryColumn/StoryTitleLabel
)
@onready var story_portrait_frame: PanelContainer = (
	$UIRoot/StoryDialogueOverlay/StoryPopup/StoryColumn/StoryContentRow/StoryPortraitFrame
)
@onready var story_portrait_rect: TextureRect = (
	$UIRoot/StoryDialogueOverlay/StoryPopup/StoryColumn/StoryContentRow/StoryPortraitFrame/StoryPortraitRect
)
@onready var story_speaker_label: Label = (
	$UIRoot/StoryDialogueOverlay/StoryPopup/StoryColumn/StoryContentRow/StoryTextColumn/StorySpeakerLabel
)
@onready var story_body_label: Label = (
	$UIRoot/StoryDialogueOverlay/StoryPopup/StoryColumn/StoryContentRow/StoryTextColumn/StoryScroll/StoryBodyLabel
)
@onready var story_progress_label: Label = (
	$UIRoot/StoryDialogueOverlay/StoryPopup/StoryColumn/StoryFooterRow/StoryProgressLabel
)
@onready var story_skip_button: Button = (
	$UIRoot/StoryDialogueOverlay/StoryPopup/StoryColumn/StoryFooterRow/StorySkipButton
)
@onready var story_continue_button: Button = (
	$UIRoot/StoryDialogueOverlay/StoryPopup/StoryColumn/StoryFooterRow/StoryContinueButton
)


static func format_rupiah(amount: int) -> String:
	if amount < 0:
		return "-%s" % format_rupiah(-amount)
	if amount < 1000:
		return "Rp %d" % amount
	var rounded_tenths: int = roundi(float(amount) / 100.0)
	if rounded_tenths % 10 == 0:
		return "Rp %dk" % (rounded_tenths / 10)
	return "Rp %d.%dk" % [rounded_tenths / 10, rounded_tenths % 10]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_fallback_styles()
	_connect_ui_buttons()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(
		_on_viewport_size_changed
	):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	if reference_body_label != null:
		reference_body_label.text = NarrativeTutorialCatalog.get_reference_summary_text()
	_layout_fixture_shop_overlay()
	_refresh_all()
	call_deferred(&"_check_auto_onboarding_start")


func _process(delta: float) -> void:
	if _is_gameplay_paused():
		return
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
			elif _feedback_text.is_empty() and _is_selected_target_online_station():
				_refresh_dialogue()
			elif not is_ingredient_shop_open() and _is_selected_target_storage_unit():
				_refresh_dialogue()
			if _onboarding_enabled:
				_refresh_visual_guidance()

	if _shake_remaining > 0.0:
		_shake_remaining = maxf(0.0, _shake_remaining - maxf(0.0, delta))
		_update_dialogue_position()
		if _onboarding_enabled:
			_refresh_visual_guidance()


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
		call_deferred(&"_check_auto_onboarding_start")


## Sets explicit modal blocking state (for overlays/tests that block world/typing input).
func set_modal_blocking(active: bool) -> void:
	_modal_blocking_active = active


func is_modal_blocking() -> bool:
	if _modal_blocking_active:
		return true
	if is_pause_open() or _is_gameplay_paused():
		return true
	if is_story_open():
		return true
	if is_reference_open():
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


func is_pause_open() -> bool:
	return pause_overlay != null and pause_overlay.visible


func open_pause() -> bool:
	if pause_overlay == null:
		return false
	if not _is_world_click_phase():
		return false
	if _game_root == null or not is_instance_valid(_game_root):
		return false
	if _game_root.has_method(&"set_paused"):
		if not bool(_game_root.set_paused(true)):
			return false
	_release_button_focus_if_any()
	pause_overlay.visible = true
	_layout_fixture_shop_overlay()
	return true


func close_pause() -> void:
	if pause_overlay != null:
		pause_overlay.visible = false
	if (
		_game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_method(&"set_paused")
	):
		_game_root.set_paused(false)
	_release_button_focus_if_any()
	_refresh_hud()
	_refresh_dialogue()


func request_exit_game() -> void:
	if pause_overlay != null:
		pause_overlay.visible = false
	if (
		_game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_method(&"set_paused")
	):
		_game_root.set_paused(false)
	exit_game_requested.emit()
	if not _exit_quit_disabled and is_inside_tree() and get_tree() != null:
		get_tree().quit()


func set_exit_quit_disabled_for_test(disabled: bool) -> void:
	_exit_quit_disabled = disabled


func is_ingredient_shop_open() -> bool:
	return ingredient_shop_overlay != null and ingredient_shop_overlay.visible


func open_ingredient_shop(storage_unit_id: StringName) -> bool:
	if (
		not _is_world_click_phase()
		or _is_gameplay_paused()
		or is_story_open()
		or is_reference_open()
		or ingredient_shop_overlay == null
	):
		return false
	if (
		_kitchen_controller == null
		or not is_instance_valid(_kitchen_controller)
		or _run_controller == null
		or not is_instance_valid(_run_controller)
	):
		return false
	if (
		not _kitchen_controller.has_storage_unit(storage_unit_id)
		or (
			_run_controller.has_method(&"can_purchase_ingredients_for_storage")
			and not _run_controller.can_purchase_ingredients_for_storage(storage_unit_id)
		)
	):
		return false
	if is_edit_menu_open():
		close_edit_menu()
	if is_fixture_shop_open():
		close_fixture_shop()

	_clear_feedback_state()
	_kitchen_controller.clear_command_prefix()
	_shop_storage_unit_id = storage_unit_id
	_last_shop_storage_unit_id = storage_unit_id
	_shop_submitting = false
	if shop_checkout_button != null:
		shop_checkout_button.disabled = false
	_pending_shop_basket.clear()
	_clear_shop_error()
	_build_ingredient_shop_rows()
	ingredient_shop_overlay.visible = true
	if _onboarding_enabled and _is_serving_phase():
		_queue_feature_tip(&"serving_belanja")
	_layout_fixture_shop_overlay()
	_refresh_ingredient_shop_view()
	_refresh_dialogue()
	_evaluate_onboarding_progress()
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
	_evaluate_onboarding_progress()


func adjust_shop_quantity(ingredient_id: StringName, delta: int) -> bool:
	if not is_ingredient_shop_open() or _is_gameplay_paused() or ingredient_id == &"" or delta == 0:
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
	if not is_ingredient_shop_open() or _is_gameplay_paused() or _shop_submitting:
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
	if (
		not _is_planning_phase()
		or _is_gameplay_paused()
		or is_story_open()
		or is_reference_open()
		or edit_menu_overlay == null
	):
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
	_previewed_recipe_id = &""
	for raw_id: Variant in run_view.get("selected_recipe_ids", []):
		var id := StringName(raw_id)
		if id != &"" and not _pending_menu_selection.has(id):
			_pending_menu_selection.append(id)

	_rebuild_edit_menu_list(run_view)
	edit_menu_overlay.visible = true
	_layout_fixture_shop_overlay()
	_refresh_edit_menu_demand_preview()
	_refresh_recipe_detail_panel()
	_refresh_dialogue()
	_evaluate_onboarding_progress()
	return true


func close_edit_menu() -> void:
	if edit_menu_overlay != null:
		edit_menu_overlay.visible = false
	_pending_menu_selection.clear()
	_previewed_recipe_id = &""
	_edit_menu_submitting = false
	if edit_menu_confirm_button != null:
		edit_menu_confirm_button.disabled = false
	if edit_menu_error_label != null:
		edit_menu_error_label.visible = false
		edit_menu_error_label.text = ""
	_refresh_recipe_detail_panel()
	_release_button_focus_if_any()
	_refresh_dialogue()
	_evaluate_onboarding_progress()


func toggle_edit_menu_recipe(recipe_id: StringName) -> bool:
	if not is_edit_menu_open() or _is_gameplay_paused() or recipe_id == &"":
		return false
	if not _edit_menu_buttons.has(recipe_id):
		return false
	var idx := _pending_menu_selection.find(recipe_id)
	if idx >= 0:
		_pending_menu_selection.remove_at(idx)
	else:
		_pending_menu_selection.append(recipe_id)

	var btn := _edit_menu_buttons[recipe_id]
	if btn != null and is_instance_valid(btn):
		var selected := _pending_menu_selection.has(recipe_id)
		if btn.button_pressed != selected:
			btn.set_pressed_no_signal(selected)
		_update_recipe_button_visual(btn, recipe_id, selected)

	if edit_menu_error_label != null:
		edit_menu_error_label.visible = false
		edit_menu_error_label.text = ""
	_refresh_edit_menu_demand_preview()
	return true


func preview_edit_menu_recipe(recipe_id: StringName) -> bool:
	if not is_edit_menu_open() or _is_gameplay_paused():
		return false
	if recipe_id != &"" and not _edit_menu_preview_buttons.has(recipe_id):
		return false
	_previewed_recipe_id = recipe_id
	for id: StringName in _edit_menu_buttons:
		var btn := _edit_menu_buttons[id]
		if btn != null and is_instance_valid(btn):
			_update_recipe_button_visual(btn, id, _pending_menu_selection.has(id))
	_refresh_recipe_detail_panel()
	return true


func get_previewed_edit_menu_recipe_id() -> StringName:
	return _previewed_recipe_id


func get_pending_menu_selection() -> Array[StringName]:
	return _pending_menu_selection.duplicate()


func get_edit_menu_recipe_button(recipe_id: StringName) -> Button:
	return _edit_menu_buttons.get(recipe_id, null) as Button


func get_edit_menu_preview_button(recipe_id: StringName) -> Button:
	return _edit_menu_preview_buttons.get(recipe_id, null) as Button


func get_edit_menu_recipe_row(recipe_id: StringName) -> Dictionary:
	return _edit_menu_rows.get(recipe_id, {})


func get_edit_menu_detail_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if recipe_detail_list == null:
		return lines
	for child in recipe_detail_list.get_children():
		var lbl := child as Label
		if lbl != null and lbl.visible:
			lines.append(lbl.text)
	return lines


func submit_edit_menu(recipe_ids: Array[StringName]) -> bool:
	if not is_edit_menu_open() or _is_gameplay_paused() or _edit_menu_submitting:
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
	if (
		not _is_planning_phase()
		or _is_gameplay_paused()
		or is_story_open()
		or is_reference_open()
		or fixture_shop_overlay == null
	):
		return false
	if _run_controller == null or not is_instance_valid(_run_controller):
		return false
	if _world_map == null or not is_instance_valid(_world_map):
		return false
	if slot_id == &"" or not _world_map.get_placement_slot_ids().has(slot_id):
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

	_selected_fixture_slot_id = slot_id
	_selected_fixture_utility_id = _pick_default_fixture_utility(_selected_fixture_slot_id)

	_build_fixture_shop_ui()
	fixture_shop_overlay.visible = true
	if _onboarding_enabled:
		_queue_feature_tip(&"fridge_and_power")
	_layout_fixture_shop_overlay()
	_refresh_fixture_shop_view()
	_refresh_dialogue()
	_evaluate_onboarding_progress()
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
	_evaluate_onboarding_progress()


func select_fixture_shop_slot(slot_id: StringName) -> bool:
	# Chosen world slot remains fixed under M5-D slot-first flow.
	return is_fixture_shop_open() and slot_id == _selected_fixture_slot_id


func select_fixture_shop_utility(utility_id: StringName) -> bool:
	if not is_fixture_shop_open() or _is_gameplay_paused() or utility_id == &"":
		return false
	if _run_controller == null or not is_instance_valid(_run_controller):
		return false
	if not _fixture_shop_rows.has(utility_id):
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
	if not is_fixture_shop_open() or _is_gameplay_paused() or _fixture_shop_submitting:
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
	if _is_gameplay_paused() or not _is_world_click_phase():
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
		if _handle_escape_key():
			if is_inside_tree() and get_viewport() != null:
				get_viewport().set_input_as_handled()
		return
	if _is_keyboard_blocked_by_focus_or_modal():
		return
	if _kitchen_controller == null:
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


func _handle_escape_key() -> bool:
	if is_pause_open():
		close_pause()
		return true
	if _is_gameplay_paused():
		return false
	if is_story_open():
		return open_pause()
	if is_reference_open():
		close_reference()
		return true
	if is_ingredient_shop_open():
		close_ingredient_shop()
		return true
	if is_fixture_shop_open():
		close_fixture_shop()
		return true
	if is_edit_menu_open():
		close_edit_menu()
		return true
	if _modal_blocking_active or _has_focused_text_input():
		return false

	var has_target := false
	var has_prefix := false
	if _kitchen_controller != null and is_instance_valid(_kitchen_controller):
		has_target = _kitchen_controller.get_selected_target_id() != &""
		has_prefix = not _kitchen_controller.get_command_prefix().is_empty()
	if has_target or has_prefix or not _feedback_text.is_empty():
		_clear_feedback_state()
		if _kitchen_controller != null and is_instance_valid(_kitchen_controller):
			_kitchen_controller.clear_selected_target()
		_release_button_focus_if_any()
		_refresh_dialogue()
		return true

	return open_pause()


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
	if interaction_dialogue != null:
		if not interaction_dialogue.gui_input.is_connected(_on_interaction_dialogue_gui_input):
			interaction_dialogue.gui_input.connect(_on_interaction_dialogue_gui_input)
	if allowed_commands_label != null:
		if not allowed_commands_label.gui_input.is_connected(_on_allowed_commands_gui_input):
			allowed_commands_label.gui_input.connect(_on_allowed_commands_gui_input)
	if pause_button != null:
		if not pause_button.pressed.is_connected(_on_pause_pressed):
			pause_button.pressed.connect(_on_pause_pressed)
	if pause_resume_button != null:
		if not pause_resume_button.pressed.is_connected(_on_pause_resume_pressed):
			pause_resume_button.pressed.connect(_on_pause_resume_pressed)
	if pause_exit_button != null:
		if not pause_exit_button.pressed.is_connected(_on_pause_exit_pressed):
			pause_exit_button.pressed.connect(_on_pause_exit_pressed)
	if story_continue_button != null:
		if not story_continue_button.pressed.is_connected(_on_story_continue_pressed):
			story_continue_button.pressed.connect(_on_story_continue_pressed)
	if story_skip_button != null:
		if not story_skip_button.pressed.is_connected(_on_story_skip_pressed):
			story_skip_button.pressed.connect(_on_story_skip_pressed)
	if tutorial_skip_button != null:
		if not tutorial_skip_button.pressed.is_connected(_on_tutorial_skip_pressed):
			tutorial_skip_button.pressed.connect(_on_tutorial_skip_pressed)
	if tutorial_next_button != null:
		if not tutorial_next_button.pressed.is_connected(_on_tutorial_next_pressed):
			tutorial_next_button.pressed.connect(_on_tutorial_next_pressed)
	if tip_dismiss_button != null:
		if not tip_dismiss_button.pressed.is_connected(_on_tip_dismiss_pressed):
			tip_dismiss_button.pressed.connect(_on_tip_dismiss_pressed)
	if tutorial_help_button != null:
		if not tutorial_help_button.pressed.is_connected(_on_tutorial_help_pressed):
			tutorial_help_button.pressed.connect(_on_tutorial_help_pressed)
	if reference_restart_button != null:
		if not reference_restart_button.pressed.is_connected(_on_reference_restart_pressed):
			reference_restart_button.pressed.connect(_on_reference_restart_pressed)
	if reference_close_button != null:
		if not reference_close_button.pressed.is_connected(_on_reference_close_pressed):
			reference_close_button.pressed.connect(_on_reference_close_pressed)


func _connect_context_signals() -> void:
	if _game_root != null and is_instance_valid(_game_root):
		if _game_root.has_signal(&"phase_changed"):
			if not _game_root.is_connected(&"phase_changed", _on_phase_changed):
				_game_root.connect(&"phase_changed", _on_phase_changed)
		if _game_root.has_signal(&"pause_changed"):
			if not _game_root.is_connected(&"pause_changed", _on_pause_changed):
				_game_root.connect(&"pause_changed", _on_pause_changed)

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
		if (
			_kitchen_controller.has_signal(&"ingredient_shop_requested")
			and not _kitchen_controller.is_connected(
				&"ingredient_shop_requested",
				_on_ingredient_shop_requested
			)
		):
			_kitchen_controller.connect(
				&"ingredient_shop_requested",
				_on_ingredient_shop_requested
			)

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
		if _game_root.has_signal(&"pause_changed"):
			if _game_root.is_connected(&"pause_changed", _on_pause_changed):
				_game_root.disconnect(&"pause_changed", _on_pause_changed)

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
		if (
			_kitchen_controller.has_signal(&"ingredient_shop_requested")
			and _kitchen_controller.is_connected(
				&"ingredient_shop_requested",
				_on_ingredient_shop_requested
			)
		):
			_kitchen_controller.disconnect(
				&"ingredient_shop_requested",
				_on_ingredient_shop_requested
			)

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


func _on_pause_pressed() -> void:
	open_pause()


func _on_pause_resume_pressed() -> void:
	close_pause()


func _on_pause_exit_pressed() -> void:
	request_exit_game()


func _on_pause_changed(paused: bool) -> void:
	if pause_overlay != null:
		pause_overlay.visible = paused
	if paused:
		_release_button_focus_if_any()
		_layout_fixture_shop_overlay()
	else:
		_refresh_hud()
		_refresh_dialogue()
	_refresh_onboarding_visibility()


func _on_phase_changed(phase: int, day_index: int) -> void:
	_clear_feedback_state()
	if (
		phase != SharedTypes.Phase.PLANNING
		and phase != SharedTypes.Phase.SERVING
		and is_pause_open()
	):
		close_pause()
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
	if (
		phase != SharedTypes.Phase.PLANNING
		and phase != SharedTypes.Phase.SERVING
		and is_reference_open()
	):
		close_reference()
	_on_onboarding_phase_changed(phase, day_index)
	_refresh_all()


func _on_player_tile_changed(_tile: Vector2i) -> void:
	_update_dialogue_position()
	_refresh_visual_guidance()


func _on_selected_interactable_changed(_target_id: StringName) -> void:
	_clear_feedback_state()
	_refresh_dialogue()
	_evaluate_onboarding_progress()


func _on_command_prefix_changed(_prefix: String) -> void:
	_clear_feedback_state()
	_refresh_dialogue()


func _on_action_feedback(code: StringName) -> void:
	_show_feedback(code)
	_record_onboarding_feedback(code)
	_evaluate_onboarding_progress()


func _on_kitchen_state_changed() -> void:
	_refresh_kitchen_visuals()
	if is_ingredient_shop_open():
		_refresh_ingredient_shop_view()
	_refresh_dialogue()
	_evaluate_onboarding_progress()


func _on_ingredient_shop_requested(storage_unit_id: StringName) -> void:
	open_ingredient_shop(storage_unit_id)


func _on_queues_changed() -> void:
	_refresh_hud()
	_refresh_dine_in_visuals()
	_evaluate_onboarding_progress()


func _on_orders_changed() -> void:
	_refresh_dine_in_visuals()
	if _is_selected_target_dining_table():
		_refresh_dialogue()
	_evaluate_onboarding_progress()


func _on_tables_changed() -> void:
	_refresh_dine_in_visuals()
	if _is_selected_target_dining_table():
		_refresh_dialogue()
	_evaluate_onboarding_progress()


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
	_evaluate_onboarding_progress()


func _on_online_offer_changed() -> void:
	_refresh_online_station_visual()
	if _is_selected_target_online_station():
		_refresh_dialogue()
	_evaluate_onboarding_progress()


func _on_run_state_changed() -> void:
	_refresh_hud()
	_refresh_kitchen_visuals()
	if is_ingredient_shop_open():
		_refresh_ingredient_shop_view()
	if is_fixture_shop_open():
		_refresh_fixture_shop_view()
	_refresh_results_panel()
	_evaluate_onboarding_progress()


func _show_feedback(code: StringName) -> void:
	_feedback_code = code
	if code == &"invalid_key":
		_feedback_text = ""
		_shake_remaining = SHAKE_DURATION
		_refresh_dialogue()
		return
	if SILENT_VISUAL_FEEDBACK_CODES.has(code):
		_feedback_text = ""
		_refresh_dialogue()
		return
	_feedback_text = FEEDBACK_LABELS.get(code, String(code))
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
	_refresh_onboarding_visibility()


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
	var cooker_portions := int(cooker_view.get("portions", 0))
	var cooker_has := not cooker_view.is_empty() and cooker_portions > 0
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
		dirty_plates,
		cooker_portions
	)
	if _world_map.has_method(&"sync_extra_kitchen_visuals"):
		var extra_cookers: Dictionary[StringName, Dictionary] = {}
		for cooker_id in _kitchen_controller.get_cooker_ids():
			if cooker_id == &"rice_cooker":
				continue
			var c_view := _kitchen_controller.get_cooker_output_view(cooker_id)
			var c_portions := int(c_view.get("portions", 0))
			var c_has := not c_view.is_empty() and c_portions > 0
			var c_textures := _resolve_item_textures(c_view)
			var c_tex: Texture2D = c_textures[0] if not c_textures.is_empty() else null
			extra_cookers[cooker_id] = {
				"has_output": c_has,
				"portions": c_portions,
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
		var secs := maxi(0, ceili(float(offer_view.get("offer_seconds_remaining", 0.0))))
		if secs > 0:
			return "Tawaran: %s (Siap diterima, %d dtk)" % [dish_label, secs]
		return "Tawaran: %s (Siap diterima)" % dish_label

	var reason := StringName(offer_view.get("disabled_reason", &""))
	match reason:
		&"offer_waiting":
			var wait_secs := maxi(
				0, ceili(float(offer_view.get("next_offer_in_seconds", 0.0)))
			)
			return "Menunggu tawaran (%d dtk)" % wait_secs
		&"cutoff_reached":
			if preview_id != &"":
				return "Tawaran: %s (Tutup: kuota <= 2)" % dish_label
			return "Tawaran tutup (Kuota <= 2)"
		&"concurrent_cap_reached":
			var cap := int(offer_view.get("concurrent_limit", 0))
			if preview_id != &"":
				return "Tawaran: %s (Penuh: maks %d)" % [dish_label, cap]
			return "Tawaran penuh (Maks %d)" % cap
		&"not_serving":
			return "Tawaran: %s (Belum layanan)" % dish_label if preview_id != &"" else ""
		&"empty_menu":
			return "Tawaran tutup (Menu kosong)"
		&"invalid_price":
			if preview_id != &"":
				return "Tawaran: %s (Harga tidak valid)" % dish_label
			return "Tawaran tidak valid"
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
	var potential_demand: int = 0
	var planned_quota: int = 0

	if _run_controller != null and is_instance_valid(_run_controller):
		var run_view: Dictionary = _run_controller.get_run_view()
		day_index = int(run_view.get("day_index", day_index))
		cash = int(run_view.get("cash", 0))
		target = int(run_view.get("day_7_target", 0))
		potential_demand = int(run_view.get("potential_demand", 0))
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
	var is_serving := (phase == SharedTypes.Phase.SERVING)
	phase_label.text = (
		"persiapan sebelum buka"
		if is_planning
		else PHASE_LABELS.get(phase, "Perencanaan")
	)
	cash_label.text = "Kas: %s" % format_rupiah(cash)

	var target_ratio := (
		clampf(float(cash) / float(target), 0.0, 1.0)
		if target > 0
		else 0.0
	)
	var target_pct := int(round(target_ratio * 100.0))
	if goal_target_label != null:
		goal_target_label.visible = is_planning
		goal_target_label.text = "Target: %s" % format_rupiah(target)
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
		fixture_shop_button.visible = false
		fixture_shop_button.disabled = true
		if fixture_shop_button.has_focus():
			fixture_shop_button.release_focus()
	if menu_stub_button != null:
		menu_stub_button.disabled = not is_planning
		if not is_planning and menu_stub_button.has_focus():
			menu_stub_button.release_focus()
	if exit_stub_button != null:
		exit_stub_button.disabled = not is_planning
		if not is_planning and exit_stub_button.has_focus():
			exit_stub_button.release_focus()
	if potential_demand_label != null:
		potential_demand_label.text = "Potensi Tamu: %d" % potential_demand
	forecast_quota_label.text = "Target Tamu: %d" % planned_quota
	if start_hint_label != null:
		start_hint_label.text = "Ketik: buka"

	service_box.visible = (
		is_serving
		or phase == SharedTypes.Phase.CLOSING
	)
	service_elapsed_label.text = "Waktu: %.1f dtk" % elapsed
	unspawned_quota_label.text = "Antrean Datang: %d" % unspawned_quota
	if pause_button != null:
		var can_pause := is_planning or is_serving
		pause_button.visible = can_pause
		pause_button.disabled = not can_pause
		if not can_pause and pause_button.has_focus():
			pause_button.release_focus()


func _refresh_dialogue() -> void:
	if not is_node_ready() or interaction_dialogue == null:
		return

	var phase: int = _get_current_phase()
	var in_active_world_phase := (
		phase == SharedTypes.Phase.PLANNING
		or phase == SharedTypes.Phase.SERVING
	)
	if not in_active_world_phase or is_ingredient_shop_open():
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
	var show_planning_storage := (
		phase == SharedTypes.Phase.PLANNING
		and selected_id != &""
		and not allowed.is_empty()
	)
	if selected_id == &"" and _feedback_text.is_empty() and not show_planning_typing:
		interaction_dialogue.visible = false
		if target_title_label != null:
			target_title_label.visible = false
			target_title_label.text = ""
		if target_status_label != null:
			target_status_label.visible = false
			target_status_label.text = ""
		if allowed_commands_label != null:
			allowed_commands_label.visible = false
			allowed_commands_label.text = ""
		if prefix_prompt_label != null:
			prefix_prompt_label.visible = false
			prefix_prompt_label.text = ""
		if remaining_prompt_label != null:
			remaining_prompt_label.visible = false
			remaining_prompt_label.text = ""
		if context_message_label != null:
			context_message_label.visible = false
			context_message_label.text = ""
		return

	interaction_dialogue.visible = true
	if selected_id != &"":
		target_title_label.visible = true
		target_title_label.text = get_target_display_title(selected_id)
	else:
		target_title_label.visible = false
		target_title_label.text = ""

	var is_serving := (phase == SharedTypes.Phase.SERVING)
	var show_commands := is_serving or show_planning_typing or show_planning_storage
	if target_status_label != null:
		var is_selected_storage := (
			selected_id != &""
			and _kitchen_controller != null
			and is_instance_valid(_kitchen_controller)
			and _kitchen_controller.has_storage_unit(selected_id)
		)
		var live_status := (
			_format_selected_target_live_status(selected_id)
			if (is_serving or (phase == SharedTypes.Phase.PLANNING and is_selected_storage))
			and selected_id != &""
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
	_refresh_visual_guidance()


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


func get_dialogue_command_rect(command: String) -> Rect2:
	if (
		interaction_dialogue == null
		or not interaction_dialogue.visible
		or allowed_commands_label == null
		or not allowed_commands_label.visible
	):
		return Rect2()
	var norm_target := command.strip_edges().to_lower()
	if norm_target.is_empty():
		return Rect2()
	var label_global := allowed_commands_label.get_global_rect().position
	for entry in _compute_dialogue_command_entries():
		if String(entry.get("command", "")) == norm_target:
			var local_rect: Rect2 = entry.get("rect", Rect2())
			return Rect2(label_global + local_rect.position, local_rect.size)
	return Rect2()


func _compute_dialogue_command_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if (
		allowed_commands_label == null
		or not allowed_commands_label.visible
		or _kitchen_controller == null
		or not is_instance_valid(_kitchen_controller)
	):
		return entries
	if _kitchen_controller.get_selected_target_id() == &"":
		return entries
	var allowed := _kitchen_controller.get_allowed_commands_for_selected_target()
	if allowed.is_empty():
		return entries
	var prefix := _kitchen_controller.get_command_prefix()
	var norm_prefix := prefix.to_lower()
	var formatted: Array[String] = []
	var normalized: Array[String] = []
	for cmd in allowed:
		var norm_cmd := cmd.strip_edges().to_lower()
		normalized.append(norm_cmd)
		if not norm_prefix.is_empty() and norm_cmd.begins_with(norm_prefix):
			formatted.append(
				"[%s]%s" % [
					norm_cmd.left(norm_prefix.length()),
					norm_cmd.substr(norm_prefix.length()),
				]
			)
		else:
			formatted.append(norm_cmd)

	var label_size := allowed_commands_label.size
	var label_h := maxf(1.0, label_size.y)
	var font: Font = allowed_commands_label.get_theme_font("font")
	var font_size: int = allowed_commands_label.get_theme_font_size("font_size")
	var full_rendered := ", ".join(formatted)
	var total_chars := maxi(1, full_rendered.length())
	for i in range(formatted.size()):
		var before_text := "" if i == 0 else ", ".join(formatted.slice(0, i)) + ", "
		var up_to_text := before_text + formatted[i]
		var start_x := 0.0
		var end_x := 0.0
		if font != null and font_size > 0:
			start_x = (
				font.get_string_size(
					before_text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					font_size
				).x
				if not before_text.is_empty()
				else 0.0
			)
			end_x = font.get_string_size(
				up_to_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size
			).x
		else:
			var full_w := maxf(1.0, label_size.x)
			start_x = full_w * (float(before_text.length()) / float(total_chars))
			end_x = full_w * (float(up_to_text.length()) / float(total_chars))
		var width := maxf(1.0, end_x - start_x)
		entries.append({
			"command": normalized[i],
			"rect": Rect2(Vector2(start_x, 0.0), Vector2(width, label_h)),
		})
	return entries


func _on_interaction_dialogue_gui_input(event: InputEvent) -> void:
	if interaction_dialogue == null or not interaction_dialogue.visible:
		return
	var mouse_btn := event as InputEventMouseButton
	if mouse_btn != null and mouse_btn.pressed:
		interaction_dialogue.accept_event()


func _on_allowed_commands_gui_input(event: InputEvent) -> void:
	if (
		interaction_dialogue == null
		or not interaction_dialogue.visible
		or allowed_commands_label == null
		or not allowed_commands_label.visible
	):
		return
	var mouse_btn := event as InputEventMouseButton
	if mouse_btn == null or not mouse_btn.pressed:
		return
	allowed_commands_label.accept_event()
	if mouse_btn.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _is_world_click_phase() or is_modal_blocking():
		return
	if _kitchen_controller == null or not is_instance_valid(_kitchen_controller):
		return
	if _kitchen_controller.get_selected_target_id() == &"":
		return

	var local_pos: Vector2 = mouse_btn.position
	for entry in _compute_dialogue_command_entries():
		var rect: Rect2 = entry.get("rect", Rect2())
		if rect.has_point(local_pos):
			var cmd := StringName(String(entry.get("command", "")))
			_release_button_focus_if_any()
			_clear_feedback_state()
			_kitchen_controller.execute_allowed_command(cmd)
			_refresh_dialogue()
			return


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
		if result_narrative_label != null:
			result_narrative_label.visible = false
			result_narrative_label.text = ""
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
		"Kas Awal: %s" % format_rupiah(int(settlement.get("begin_cash", 0))),
		"Belanja Bahan: -%s" % format_rupiah(int(settlement.get("ingredient_purchase_total", 0))),
		"Beli Alat: -%s" % format_rupiah(int(settlement.get("fixture_purchase_total", 0))),
		"Jual Alat: +%s" % format_rupiah(int(settlement.get("fixture_sale_total", 0))),
		"Pendapatan Makan: +%s" % format_rupiah(int(settlement.get("order_revenue_dinein", 0))),
		"Pendapatan Online: +%s" % format_rupiah(int(settlement.get("order_revenue_online", 0))),
		"Refund Kiriman: +%s" % format_rupiah(int(settlement.get("refund_total", 0))),
		"Listrik Harian: -%s" % format_rupiah(int(settlement.get("electricity_charge", 0))),
		"Kas Akhir: %s" % format_rupiah(int(settlement.get("end_cash", 0))),
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
		"Potensi Besok: %d" % int(settlement.get("forecast_next_day_potential", 0)),
		"Perkiraan Besok: %d" % int(settlement.get("forecast_next_day", 0)),
	]
	settlement_summary_label.text = "\n".join(lines)
	if result_narrative_label != null:
		var caption := (
			NarrativeTutorialCatalog.get_day_closing_caption(day_index, goal_outcome)
			if _onboarding_enabled
			else ""
		)
		result_narrative_label.text = caption
		result_narrative_label.visible = not caption.is_empty()
		result_narrative_label.modulate = Color(0.84, 0.90, 0.98, 1.0)

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
	if interaction_dialogue != null and interaction_dialogue.visible:
		if interaction_dialogue.get_global_rect().has_point(canvas_pos):
			return true
	if tutorial_help_button != null and tutorial_help_button.visible:
		if tutorial_help_button.get_global_rect().has_point(canvas_pos):
			return true
	if tutorial_banner != null and tutorial_banner.visible:
		if tutorial_banner.get_global_rect().has_point(canvas_pos):
			return true
	if feature_tip_panel != null and feature_tip_panel.visible:
		if feature_tip_panel.get_global_rect().has_point(canvas_pos):
			return true
	return false


func _is_keyboard_blocked_by_focus_or_modal() -> bool:
	if is_modal_blocking():
		return true
	if _has_focused_text_input():
		return true
	if is_inside_tree() and get_viewport() != null:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and is_instance_valid(focused):
			if focused is BaseButton and focused.is_visible_in_tree():
				return true
			if bool(focused.get_meta(&"blocks_gameplay_keys", false)):
				return true
	return false


func _has_focused_text_input() -> bool:
	if is_inside_tree() and get_viewport() != null:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and is_instance_valid(focused):
			if focused is LineEdit or focused is TextEdit or focused is SpinBox:
				return true
	return false


func _is_gameplay_paused() -> bool:
	if (
		_game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_method(&"is_paused")
	):
		return bool(_game_root.is_paused())
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
	if recipe_detail_panel != null:
		var detail_style := _make_panel_style(
			Color(0.09, 0.11, 0.16, 0.96),
			Color(0.32, 0.37, 0.48, 1.0),
			6
		)
		recipe_detail_panel.add_theme_stylebox_override("panel", detail_style)
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
	if pause_popup != null:
		var pause_style := _make_panel_style(
			Color(0.12, 0.14, 0.20, 0.98),
			Color(0.45, 0.52, 0.66, 1.0),
			10
		)
		pause_popup.add_theme_stylebox_override("panel", pause_style)
	if tutorial_banner != null:
		tutorial_banner.add_theme_stylebox_override(
			"panel",
			_make_panel_style(Color(0.10, 0.14, 0.19, 0.96), Color(0.42, 0.78, 0.58, 1.0), 6)
		)
	if tutorial_title_label != null:
		tutorial_title_label.modulate = Color(0.55, 0.94, 0.68, 1.0)
	if feature_tip_panel != null:
		feature_tip_panel.add_theme_stylebox_override(
			"panel",
			_make_panel_style(Color(0.12, 0.14, 0.22, 0.96), Color(0.95, 0.78, 0.36, 1.0), 6)
		)
	if tip_title_label != null:
		tip_title_label.modulate = Color(0.98, 0.85, 0.45, 1.0)
	if reference_popup != null:
		reference_popup.add_theme_stylebox_override(
			"panel",
			_make_panel_style(Color(0.11, 0.13, 0.20, 0.98), Color(0.45, 0.55, 0.72, 1.0), 10)
		)
	if story_popup != null:
		story_popup.add_theme_stylebox_override(
			"panel",
			_make_panel_style(Color(0.10, 0.12, 0.19, 0.98), Color(0.58, 0.68, 0.84, 1.0), 8)
		)
	if story_portrait_frame != null:
		story_portrait_frame.add_theme_stylebox_override(
			"panel",
			_make_panel_style(Color(0.08, 0.10, 0.15, 1.0), Color(0.38, 0.46, 0.60, 1.0), 3)
		)
	if story_title_label != null:
		story_title_label.modulate = Color(0.98, 0.85, 0.45, 1.0)
	if story_speaker_label != null:
		story_speaker_label.modulate = Color(0.65, 0.88, 1.0, 1.0)


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
	_edit_menu_preview_buttons.clear()
	_edit_menu_rows.clear()
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
		row.add_theme_constant_override("separation", 3)
		edit_menu_recipe_list.add_child(row)

		var toggle_btn := CheckBox.new()
		toggle_btn.name = "CheckBox_%s" % recipe_id
		toggle_btn.text = ""
		toggle_btn.custom_minimum_size = Vector2(20, 22)
		toggle_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		toggle_btn.focus_mode = Control.FOCUS_ALL
		toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var selected := _pending_menu_selection.has(recipe_id)
		toggle_btn.set_pressed_no_signal(selected)
		toggle_btn.toggled.connect(
			func(pressed: bool) -> void:
				_on_recipe_button_toggled(recipe_id, pressed)
		)
		row.add_child(toggle_btn)

		var icons_box := HBoxContainer.new()
		icons_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icons_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icons_box.add_theme_constant_override("separation", 1)
		row.add_child(icons_box)
		var textures := _resolve_recipe_part_textures(recipe_id)
		if textures.is_empty():
			var fallback_rect := ColorRect.new()
			fallback_rect.custom_minimum_size = Vector2(12, 12)
			fallback_rect.color = Color(0.65, 0.58, 0.42, 1.0)
			fallback_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icons_box.add_child(fallback_rect)
		else:
			for tex in textures:
				if tex != null:
					var tex_rect := TextureRect.new()
					tex_rect.texture = tex
					tex_rect.custom_minimum_size = Vector2(12, 12)
					tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
					icons_box.add_child(tex_rect)
				else:
					var part_fallback := ColorRect.new()
					part_fallback.custom_minimum_size = Vector2(12, 12)
					part_fallback.color = Color(0.55, 0.62, 0.72, 1.0)
					part_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
					icons_box.add_child(part_fallback)

		var preview_btn := Button.new()
		preview_btn.name = "RecipeButton_%s" % recipe_id
		preview_btn.toggle_mode = false
		preview_btn.focus_mode = Control.FOCUS_ALL
		preview_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		preview_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		preview_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		preview_btn.add_theme_font_size_override("font_size", 11)
		preview_btn.pressed.connect(
			func() -> void:
				_on_recipe_preview_pressed(recipe_id)
		)
		row.add_child(preview_btn)

		_edit_menu_buttons[recipe_id] = toggle_btn
		_edit_menu_preview_buttons[recipe_id] = preview_btn
		_edit_menu_rows[recipe_id] = {
			"row": row,
			"toggle_button": toggle_btn,
			"preview_button": preview_btn,
			"icons_box": icons_box,
		}
		_update_recipe_button_visual(toggle_btn, recipe_id, selected)


func _on_recipe_preview_pressed(recipe_id: StringName) -> void:
	if not is_edit_menu_open() or _is_gameplay_paused() or recipe_id == &"":
		return
	if _previewed_recipe_id == recipe_id:
		preview_edit_menu_recipe(&"")
	else:
		preview_edit_menu_recipe(recipe_id)


func _on_recipe_button_toggled(recipe_id: StringName, pressed: bool) -> void:
	if not is_edit_menu_open() or _is_gameplay_paused() or recipe_id == &"":
		return
	if not _edit_menu_buttons.has(recipe_id):
		return
	var idx := _pending_menu_selection.find(recipe_id)
	if pressed and idx < 0:
		_pending_menu_selection.append(recipe_id)
	elif not pressed and idx >= 0:
		_pending_menu_selection.remove_at(idx)

	var btn := _edit_menu_buttons[recipe_id]
	if btn != null and is_instance_valid(btn):
		_update_recipe_button_visual(btn, recipe_id, pressed)

	if edit_menu_error_label != null:
		edit_menu_error_label.visible = false
		edit_menu_error_label.text = ""
	_refresh_edit_menu_demand_preview()


func _refresh_edit_menu_demand_preview() -> void:
	if edit_menu_forecast_label == null:
		return
	if _run_controller == null or not is_instance_valid(_run_controller):
		edit_menu_forecast_label.text = "Potensi Tamu: 0 | Target Tamu: 0"
		return
	if _pending_menu_selection.is_empty():
		edit_menu_forecast_label.text = "Potensi Tamu: 0 | Target Tamu: 0"
		return
	var preview: Dictionary = _run_controller.preview_demand_for_menu(_pending_menu_selection)
	var potential := int(preview.get("potential_demand", 0))
	var quota := int(preview.get("planned_dinein_quota", 0))
	edit_menu_forecast_label.text = "Potensi Tamu: %d | Target Tamu: %d" % [potential, quota]


func _update_recipe_button_visual(
	btn: Button,
	recipe_id: StringName,
	selected: bool
) -> void:
	var preview_btn := _edit_menu_preview_buttons.get(recipe_id, null) as Button
	var display := _get_recipe_display_name(recipe_id)
	var price := _get_recipe_dine_in_price(recipe_id)
	var label_text := "%s: %s" % [display, format_rupiah(price)] if price > 0 else display
	if preview_btn != null and is_instance_valid(preview_btn):
		preview_btn.text = label_text
	if btn != null and is_instance_valid(btn) and not (btn is CheckBox):
		btn.text = label_text

	var is_previewed := (_previewed_recipe_id == recipe_id)
	var bg := EDIT_MENU_SELECTED_BG if selected else EDIT_MENU_UNSELECTED_BG
	var border := (
		EDIT_MENU_PREVIEW_BORDER
		if is_previewed
		else (EDIT_MENU_SELECTED_BORDER if selected else EDIT_MENU_UNSELECTED_BORDER)
	)
	var style := _make_panel_style(bg, border, 4)
	if preview_btn != null and is_instance_valid(preview_btn):
		preview_btn.add_theme_stylebox_override("normal", style)
		preview_btn.add_theme_stylebox_override("hover", style)
		preview_btn.add_theme_stylebox_override("pressed", style)
	if btn != null and is_instance_valid(btn):
		var toggle_style := _make_panel_style(bg, border, 2)
		btn.add_theme_stylebox_override("normal", toggle_style)
		btn.add_theme_stylebox_override("hover", toggle_style)
		btn.add_theme_stylebox_override("pressed", toggle_style)


func _refresh_recipe_detail_panel() -> void:
	if recipe_detail_title_label == null or recipe_detail_list == null:
		return
	for child in recipe_detail_list.get_children():
		recipe_detail_list.remove_child(child)
		child.free()

	if _previewed_recipe_id == &"":
		recipe_detail_title_label.text = "Detail Resep"
		recipe_detail_title_label.remove_theme_font_override("font")
		var hint_lbl := Label.new()
		hint_lbl.name = "DetailEmptyLabel"
		hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_lbl.add_theme_font_size_override("font_size", 10)
		hint_lbl.modulate = Color(0.76, 0.80, 0.88, 1.0)
		hint_lbl.text = "Pilih hidangan untuk lihat bahan."
		recipe_detail_list.add_child(hint_lbl)
		return

	recipe_detail_title_label.text = _get_recipe_display_name(_previewed_recipe_id)
	var base_font := recipe_detail_title_label.get_theme_font("font")
	if base_font != null:
		var bold_font := FontVariation.new()
		bold_font.base_font = base_font
		bold_font.variation_embolden = 0.45
		recipe_detail_title_label.add_theme_font_override("font", bold_font)

	var def: RecipeDef = (
		_kitchen_controller.get_recipe_def(_previewed_recipe_id)
		if _kitchen_controller != null and is_instance_valid(_kitchen_controller)
		else null
	)
	if def == null:
		return

	for i in range(def.required_parts.size()):
		var part := def.required_parts[i]
		if part == null:
			continue
		var line_lbl := Label.new()
		line_lbl.name = "IngredientLine_%d" % i
		line_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line_lbl.add_theme_font_size_override("font_size", 11)
		line_lbl.text = _format_recipe_ingredient_line(part)
		recipe_detail_list.add_child(line_lbl)


func _format_recipe_ingredient_line(part: RecipePartDef) -> String:
	if part == null:
		return ""
	var ing_name := _get_ingredient_display_name(part.ingredient_id)
	match part.required_state:
		SharedTypes.PrepState.COOKED, SharedTypes.PrepState.COOKED_RICE:
			return ing_name
		SharedTypes.PrepState.CHOPPED:
			return "%s (potong)" % ing_name
		SharedTypes.PrepState.CHOPPED_AND_COOKED:
			return "%s (potong & masak)" % ing_name
		SharedTypes.PrepState.WASHED:
			return "%s (cuci)" % ing_name
		SharedTypes.PrepState.RAW:
			return "%s (mentah)" % ing_name
	return ing_name


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
		return "Uang tidak cukup (Total %s, Kas %s)." % [
			format_rupiah(total),
			format_rupiah(cash),
		]
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
		row.add_theme_constant_override("separation", 4)
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
		name_label.clip_text = true
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_label)

		var price_label := Label.new()
		price_label.text = format_rupiah(_get_ingredient_unit_price(ing_id))
		price_label.custom_minimum_size = Vector2(46, 0)
		price_label.add_theme_font_size_override("font_size", 11)
		price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(price_label)

		var minus_btn := Button.new()
		minus_btn.name = "Minus_%s" % ing_id
		minus_btn.text = "-"
		minus_btn.custom_minimum_size = Vector2(22, 22)
		minus_btn.add_theme_font_size_override("font_size", 11)
		minus_btn.focus_mode = Control.FOCUS_ALL
		minus_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		minus_btn.pressed.connect(func() -> void: adjust_shop_quantity(ing_id, -1))
		row.add_child(minus_btn)

		var qty_label := Label.new()
		qty_label.text = "0"
		qty_label.custom_minimum_size = Vector2(20, 0)
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qty_label.add_theme_font_size_override("font_size", 11)
		qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(qty_label)

		var plus_btn := Button.new()
		plus_btn.name = "Plus_%s" % ing_id
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(22, 22)
		plus_btn.add_theme_font_size_override("font_size", 11)
		plus_btn.focus_mode = Control.FOCUS_ALL
		plus_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		plus_btn.pressed.connect(func() -> void: adjust_shop_quantity(ing_id, 1))
		row.add_child(plus_btn)

		var subtotal_label := Label.new()
		subtotal_label.text = format_rupiah(0)
		subtotal_label.custom_minimum_size = Vector2(48, 0)
		subtotal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		subtotal_label.add_theme_font_size_override("font_size", 11)
		subtotal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(subtotal_label)

		_shop_ingredient_rows[ing_id] = {
			"minus_button": minus_btn,
			"plus_button": plus_btn,
			"qty_label": qty_label,
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
	var is_serving := _is_serving_phase()

	if shop_target_label != null:
		shop_target_label.text = get_target_display_title(_shop_storage_unit_id)
	if shop_cash_label != null:
		shop_cash_label.visible = false
	if shop_capacity_label != null:
		shop_capacity_label.visible = false
	if shop_status_row != null:
		shop_status_row.visible = is_serving
	if shop_delivery_hint_label != null:
		shop_delivery_hint_label.visible = is_serving
		shop_delivery_hint_label.text = "Tiba 100 dtk" if is_serving else ""
	if shop_retrieve_button != null:
		shop_retrieve_button.visible = is_serving
		shop_retrieve_button.disabled = not is_serving

	_refresh_shop_slots(storage_view)
	_refresh_shop_pending_deliveries()

	for ing_id: StringName in _shop_ingredient_rows:
		var controls: Dictionary = _shop_ingredient_rows[ing_id]
		var qty := int(_pending_shop_basket.get(ing_id, 0))
		var unit_price := _get_ingredient_unit_price(ing_id)

		(controls["qty_label"] as Label).text = "%d" % qty
		(controls["subtotal_label"] as Label).text = format_rupiah(unit_price * qty)
		(controls["price_label"] as Label).text = format_rupiah(unit_price)

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
		shop_total_label.text = "Total: %s" % format_rupiah(get_shop_total())


func _refresh_shop_slots(storage_view: Dictionary) -> void:
	if shop_slots_row == null:
		return
	for child in shop_slots_row.get_children():
		shop_slots_row.remove_child(child)
		child.free()

	var raw_slots: Variant = storage_view.get("slots", [])
	if not (raw_slots is Array):
		return
	for raw_slot: Variant in raw_slots:
		if not (raw_slot is Dictionary):
			continue
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
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.clip_text = true
		if ing_id == &"" or qty <= 0:
			lbl.text = "Kosong (0/%d)" % cap
		else:
			lbl.text = "%s %d/%d" % [_get_ingredient_display_name(ing_id), qty, cap]
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
		shop_pending_label.visible = false
		shop_pending_label.text = ""
	else:
		shop_pending_label.visible = true
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
		var allowed_raw: Variant = slot_view.get("allowed_fixture_kinds", [])
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


func _get_filtered_utility_ids_for_slot(slot_id: StringName) -> Array[StringName]:
	var ordered := _get_ordered_utility_ids()
	if slot_id == &"" or _world_map == null or not is_instance_valid(_world_map):
		return ordered
	if _run_controller == null or not is_instance_valid(_run_controller):
		return ordered
	var slot_view := _world_map.get_placement_slot_view(slot_id)
	var allowed_raw: Variant = slot_view.get("allowed_fixture_kinds", [])
	if not (allowed_raw is Array):
		return ordered
	var filtered: Array[StringName] = []
	for u_id in ordered:
		var def := _run_controller.get_utility_def(u_id)
		if def != null and (allowed_raw as Array).has(int(def.fixture_kind)):
			filtered.append(u_id)
	return filtered


func _create_fixture_shop_icon(def: UtilityDef) -> Control:
	var box := Control.new()
	box.name = "IconContainer"
	box.custom_minimum_size = Vector2(28, 36)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tileset_tex := load(WARUNG_TILESET_PATH) as Texture2D
	if def != null and def.fixture_kind == SharedTypes.FixtureKind.DINING_TABLE:
		var base := ColorRect.new()
		base.position = Vector2(4, 3)
		base.size = Vector2(20, 16)
		base.color = Color(0.35, 0.21, 0.12, 1.0)
		base.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(base)

		var surface := ColorRect.new()
		surface.position = Vector2(5, 4)
		surface.size = Vector2(18, 12)
		surface.color = Color(0.76, 0.56, 0.34, 1.0)
		surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(surface)

		if tileset_tex != null:
			var chair_atlas := AtlasTexture.new()
			chair_atlas.atlas = tileset_tex
			chair_atlas.region = WorldMap.REGION_DINING_CHAIR
			var chair_rect := TextureRect.new()
			chair_rect.position = Vector2(4, 18)
			chair_rect.size = Vector2(20, 16)
			chair_rect.texture = chair_atlas
			chair_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			chair_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			chair_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			chair_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(chair_rect)
		return box

	var region := (
		_world_map.get_fixture_region_rect(int(def.fixture_kind))
		if def != null and _world_map != null and is_instance_valid(_world_map)
		else Rect2()
	)
	if tileset_tex != null and region.size != Vector2.ZERO:
		var atlas := AtlasTexture.new()
		atlas.atlas = tileset_tex
		atlas.region = region
		var tex_rect := TextureRect.new()
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.texture = atlas
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tex_rect)
	else:
		var fallback := ColorRect.new()
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback.color = Color(0.45, 0.52, 0.64, 1.0)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(fallback)
	return box


func _format_fixture_description(utility_id: StringName, def: UtilityDef) -> String:
	var desc: String = FIXTURE_PURPOSE_LABELS.get(utility_id, "Peralatan restoran")
	var power := 0
	if _run_controller != null and is_instance_valid(_run_controller) and def != null:
		power = _run_controller.get_fixture_daily_electricity_cost(
			utility_id,
			int(def.fixture_kind)
		)
	if power > 0:
		return "%s (listrik: %s/hari)" % [desc, format_rupiah(power)]
	return desc


func _build_fixture_shop_ui() -> void:
	_fixture_slot_buttons.clear()
	_fixture_shop_rows.clear()
	if fixture_slots_row != null:
		fixture_slots_row.visible = false
		for child in fixture_slots_row.get_children():
			fixture_slots_row.remove_child(child)
			child.free()
	if fixture_list != null:
		for child in fixture_list.get_children():
			fixture_list.remove_child(child)
			child.free()

	if _run_controller == null or fixture_list == null:
		return

	for u_id in _get_filtered_utility_ids_for_slot(_selected_fixture_slot_id):
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

		var icon_ctrl := _create_fixture_shop_icon(def)
		row_box.add_child(icon_ctrl)

		var info_col := VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_col.add_theme_constant_override("separation", 2)
		row_box.add_child(info_col)

		var title_lbl := Label.new()
		title_lbl.name = "TitleLabel"
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_lbl.add_theme_font_size_override("font_size", 11)
		var base_font := title_lbl.get_theme_font("font")
		if base_font != null:
			var bold_font := FontVariation.new()
			bold_font.base_font = base_font
			bold_font.variation_embolden = 0.45
			title_lbl.add_theme_font_override("font", bold_font)
		title_lbl.text = "%s: %s" % [def.display_name, format_rupiah(def.purchase_price)]
		info_col.add_child(title_lbl)

		var desc_lbl := Label.new()
		desc_lbl.name = "DescriptionLabel"
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.text = _format_fixture_description(u_id, def)
		info_col.add_child(desc_lbl)

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
			"icon": icon_ctrl,
			"title_label": title_lbl,
			"description_label": desc_lbl,
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
	var margin_x := clampf(roundf(world_rect.size.x * 0.035), 8.0, 20.0)
	var margin_y := clampf(roundf(world_rect.size.y * 0.04), 8.0, 14.0)
	var avail_w := maxf(180.0, world_rect.size.x - margin_x * 2.0)
	var avail_h := maxf(140.0, world_rect.size.y - margin_y * 2.0)
	if fixture_shop_overlay != null and fixture_shop_popup != null:
		var dimmer := fixture_shop_overlay.get_node_or_null("WorldDimmer") as ColorRect
		if dimmer != null:
			dimmer.position = world_rect.position
			dimmer.size = world_rect.size
		var popup_w := minf(488.0, avail_w)
		var popup_h := minf(332.0, avail_h)
		var popup_x := world_rect.position.x + floorf((world_rect.size.x - popup_w) * 0.5)
		var popup_y := world_rect.position.y + floorf((world_rect.size.y - popup_h) * 0.5)
		fixture_shop_popup.custom_minimum_size = Vector2.ZERO
		fixture_shop_popup.position = Vector2(popup_x, popup_y)
		fixture_shop_popup.size = Vector2(popup_w, popup_h)
	if edit_menu_overlay != null:
		var edit_dimmer := edit_menu_overlay.get_node_or_null("WorldDimmer") as ColorRect
		if edit_dimmer != null:
			edit_dimmer.position = world_rect.position
			edit_dimmer.size = world_rect.size
		if edit_menu_popup != null:
			var edit_w := minf(456.0, avail_w)
			var edit_h := minf(280.0, avail_h)
			var edit_x := world_rect.position.x + floorf((world_rect.size.x - edit_w) * 0.5)
			var edit_y := world_rect.position.y + floorf((world_rect.size.y - edit_h) * 0.5)
			edit_menu_popup.custom_minimum_size = Vector2.ZERO
			edit_menu_popup.position = Vector2(edit_x, edit_y)
			edit_menu_popup.size = Vector2(edit_w, edit_h)
	if ingredient_shop_overlay != null:
		var shop_dimmer := ingredient_shop_overlay.get_node_or_null("WorldDimmer") as ColorRect
		if shop_dimmer != null:
			shop_dimmer.position = world_rect.position
			shop_dimmer.size = world_rect.size
		if ingredient_shop_popup != null:
			var shop_w := minf(456.0, avail_w)
			var shop_h := minf(324.0, avail_h)
			var shop_x := world_rect.position.x + floorf((world_rect.size.x - shop_w) * 0.5)
			var shop_y := world_rect.position.y + floorf((world_rect.size.y - shop_h) * 0.5)
			ingredient_shop_popup.custom_minimum_size = Vector2.ZERO
			ingredient_shop_popup.position = Vector2(shop_x, shop_y)
			ingredient_shop_popup.size = Vector2(shop_w, shop_h)
	if pause_popup != null:
		var p_size := pause_popup.get_combined_minimum_size()
		pause_popup.position = Vector2(
			floorf((vp_size.x - p_size.x) * 0.5),
			floorf((vp_size.y - p_size.y) * 0.5)
		)
		pause_popup.size = p_size
	_layout_onboarding_overlays(vp_size, world_rect)


func _refresh_fixture_shop_view() -> void:
	if not is_node_ready() or _run_controller == null:
		return

	if fixture_cash_label != null:
		fixture_cash_label.visible = false
	if fixture_power_label != null:
		fixture_power_label.visible = false
	if fixture_slots_row != null:
		fixture_slots_row.visible = false

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

	if fixture_selection_label != null:
		var sel_def := _run_controller.get_utility_def(_selected_fixture_utility_id)
		if sel_def != null:
			fixture_selection_label.text = "Harga: %s" % format_rupiah(sel_def.purchase_price)
		else:
			fixture_selection_label.text = "Harga: -"


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


func set_onboarding_enabled(enabled: bool) -> void:
	_onboarding_explicitly_set = true
	_onboarding_enabled = enabled
	_ensure_onboarding_connections()
	if not enabled:
		_close_story_internal()
		_tutorial_active = false
		_active_feature_tip_id = &""
		_pending_feature_tips.clear()
		if tutorial_reference_overlay != null:
			tutorial_reference_overlay.visible = false
	else:
		_onboarding_boot_checked = true
		_on_onboarding_phase_changed(_get_current_phase(), _get_current_day_index())
	_refresh_onboarding_visibility()


func is_onboarding_enabled() -> bool:
	return _onboarding_enabled


func _check_auto_onboarding_start() -> void:
	_ensure_onboarding_connections()
	if _onboarding_boot_checked:
		return
	if _game_root == null or _run_controller == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	if not _onboarding_explicitly_set:
		if tree.current_scene != _game_root:
			return
		_onboarding_enabled = true
	_onboarding_boot_checked = true
	if _onboarding_enabled:
		_on_onboarding_phase_changed(_get_current_phase(), _get_current_day_index())
	_refresh_onboarding_visibility()


func _ensure_onboarding_connections() -> void:
	if edit_menu_confirm_button != null:
		var cb := Callable(self, &"_on_onboarding_edit_menu_confirm_pressed")
		if not edit_menu_confirm_button.pressed.is_connected(cb):
			edit_menu_confirm_button.pressed.connect(cb)


func _on_onboarding_edit_menu_confirm_pressed() -> void:
	if not _onboarding_enabled:
		return
	if not is_edit_menu_open() and _has_selected_recipes():
		_tutorial_flags[&"edit_menu_confirmed"] = true
		_evaluate_onboarding_progress()


func is_story_open() -> bool:
	return (
		_active_story_id != &""
		and _active_story_line_index >= 0
		and _active_story_line_index < _active_story_lines.size()
	)


func is_reference_open() -> bool:
	return (
		tutorial_reference_overlay != null
		and tutorial_reference_overlay.visible
	)


func open_reference() -> bool:
	if not _onboarding_enabled or _is_gameplay_paused():
		return false
	if is_story_open() or is_edit_menu_open() or is_ingredient_shop_open() or is_fixture_shop_open():
		return false
	if tutorial_reference_overlay == null:
		return false
	if reference_body_label != null:
		reference_body_label.text = NarrativeTutorialCatalog.get_reference_summary_text()
	tutorial_reference_overlay.visible = true
	_refresh_onboarding_visibility()
	if reference_close_button != null:
		reference_close_button.grab_focus()
	return true


func close_reference() -> void:
	if tutorial_reference_overlay != null:
		tutorial_reference_overlay.visible = false
	_release_button_focus_if_any()
	_refresh_onboarding_visibility()


func open_opening_story() -> bool:
	if not _onboarding_enabled:
		return false
	if _shown_day_stories.get(1, false):
		return false
	_shown_day_stories[1] = true
	return _open_story_payload(NarrativeTutorialCatalog.get_opening_story())


func open_day_narrative(day_index: int) -> bool:
	if not _onboarding_enabled:
		return false
	if day_index <= 1:
		return open_opening_story()
	if _shown_day_stories.get(day_index, false):
		return false
	var payload := NarrativeTutorialCatalog.get_day_intro_story(day_index)
	if payload.is_empty():
		return false
	_shown_day_stories[day_index] = true
	return _open_story_payload(payload)


func open_day_7_epilogue(goal_outcome: int) -> bool:
	if not _onboarding_enabled:
		return false
	if _shown_day7_epilogue:
		return false
	_shown_day7_epilogue = true
	return _open_story_payload(NarrativeTutorialCatalog.get_day_7_epilogue(goal_outcome))


func _open_story_payload(payload: Dictionary) -> bool:
	var raw_lines: Variant = payload.get("lines", [])
	if not (raw_lines is Array) or (raw_lines as Array).is_empty():
		return false
	_active_story_id = StringName(payload.get("id", &""))
	_active_story_title = str(payload.get("title", ""))
	_active_story_lines.clear()
	for entry_v in (raw_lines as Array):
		if entry_v is Dictionary:
			_active_story_lines.append((entry_v as Dictionary).duplicate(true))
	if _active_story_lines.is_empty():
		_active_story_id = &""
		return false
	_active_story_line_index = 0
	if tutorial_reference_overlay != null:
		tutorial_reference_overlay.visible = false
	_update_story_dialogue_view()
	_refresh_onboarding_visibility()
	if story_continue_button != null and not _is_gameplay_paused():
		story_continue_button.grab_focus()
	return true


func advance_story() -> bool:
	if not is_story_open() or _is_gameplay_paused():
		return false
	_active_story_line_index += 1
	if _active_story_line_index >= _active_story_lines.size():
		var finished_id := _active_story_id
		_close_story_internal()
		_on_story_finished(finished_id)
		_refresh_onboarding_visibility()
		_evaluate_onboarding_progress()
		_release_button_focus_if_any()
		return true
	_update_story_dialogue_view()
	_refresh_onboarding_visibility()
	return true


func skip_story() -> void:
	if not is_story_open() or _is_gameplay_paused():
		return
	var finished_id := _active_story_id
	_close_story_internal()
	_on_story_finished(finished_id)
	_refresh_onboarding_visibility()
	_evaluate_onboarding_progress()
	_release_button_focus_if_any()


func get_story_state_view() -> Dictionary:
	var open := is_story_open()
	var line: Dictionary = {}
	if open:
		line = _active_story_lines[_active_story_line_index]
	return {
		"open": open,
		"id": _active_story_id,
		"title": _active_story_title,
		"line_index": _active_story_line_index,
		"line_count": _active_story_lines.size(),
		"speaker": str(line.get("speaker", "")),
		"text": str(line.get("text", "")),
	}


func _close_story_internal() -> void:
	_active_story_id = &""
	_active_story_title = ""
	_active_story_lines.clear()
	_active_story_line_index = 0


func _on_story_finished(finished_id: StringName) -> void:
	if finished_id == NarrativeTutorialCatalog.DAY_1_OPENING_ID:
		if not _tutorial_completed and not _tutorial_skipped:
			_start_tutorial()


func _update_story_dialogue_view() -> void:
	if not is_story_open():
		return
	var line := _active_story_lines[_active_story_line_index]
	if story_title_label != null:
		story_title_label.text = _active_story_title
	if story_speaker_label != null:
		story_speaker_label.text = str(line.get("speaker", "Narasi"))
	if story_body_label != null:
		story_body_label.text = str(line.get("text", ""))
	if story_progress_label != null:
		story_progress_label.text = "%d/%d" % [
			_active_story_line_index + 1,
			_active_story_lines.size(),
		]
	var portrait_path := str(line.get("portrait_path", ""))
	if story_portrait_frame != null and story_portrait_rect != null:
		if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
			var tex := load(portrait_path) as Texture2D
			story_portrait_rect.texture = tex
			story_portrait_frame.visible = tex != null
		else:
			story_portrait_rect.texture = null
			story_portrait_frame.visible = false
	if story_continue_button != null:
		var is_last := _active_story_line_index >= _active_story_lines.size() - 1
		story_continue_button.text = "Selesai" if is_last else "Lanjut"


func _start_tutorial() -> void:
	if not _onboarding_enabled or _tutorial_completed or _tutorial_skipped:
		return
	_tutorial_active = true
	_tutorial_step_index = 0
	_tutorial_started_day = _get_current_day_index()
	_tutorial_flags.clear()
	_tutorial_hint_text = ""
	_evaluate_onboarding_progress()
	_refresh_onboarding_visibility()


func is_tutorial_active() -> bool:
	return (
		_onboarding_enabled
		and _tutorial_active
		and not _tutorial_skipped
		and not _tutorial_completed
	)


func is_tutorial_completed() -> bool:
	return _tutorial_completed


func is_tutorial_skipped() -> bool:
	return _tutorial_skipped


func get_tutorial_step_id() -> StringName:
	if not is_tutorial_active():
		return &""
	var steps := NarrativeTutorialCatalog.get_tutorial_steps()
	if _tutorial_step_index < 0 or _tutorial_step_index >= steps.size():
		return &""
	return StringName(steps[_tutorial_step_index].get("id", &""))


func get_tutorial_guidance_view() -> Dictionary:
	if tutorial_guidance_overlay == null:
		return {
			"active": false,
			"target_id": &"",
			"target_rect": Rect2(),
			"callout_rect": Rect2(),
			"badge_text": "",
			"marker_number": "",
			"pointer_side": &"",
		}
	return {
		"active": tutorial_guidance_overlay.is_guidance_active(),
		"target_id": tutorial_guidance_overlay.get_target_id(),
		"target_rect": tutorial_guidance_overlay.get_target_rect(),
		"callout_rect": tutorial_guidance_overlay.get_callout_rect(),
		"badge_text": tutorial_guidance_overlay.get_badge_text(),
		"marker_number": tutorial_guidance_overlay.get_marker_number(),
		"pointer_side": tutorial_guidance_overlay.get_pointer_side(),
	}


func skip_tutorial() -> void:
	_tutorial_skipped = true
	_tutorial_active = false
	_tutorial_hint_text = ""
	_refresh_onboarding_visibility()
	_release_button_focus_if_any()


func restart_tutorial() -> void:
	_onboarding_explicitly_set = true
	_onboarding_enabled = true
	_onboarding_boot_checked = true
	_tutorial_skipped = false
	_tutorial_completed = false
	_tutorial_active = true
	_tutorial_step_index = 0
	_tutorial_started_day = _get_current_day_index()
	_tutorial_flags.clear()
	_tutorial_hint_text = ""
	if tutorial_reference_overlay != null:
		tutorial_reference_overlay.visible = false
	_evaluate_onboarding_progress()
	_refresh_onboarding_visibility()
	_release_button_focus_if_any()


func get_active_feature_tip_id() -> StringName:
	return _active_feature_tip_id


func has_shown_feature_tip(tip_id: StringName) -> bool:
	return bool(_shown_feature_tips.get(tip_id, false))


func dismiss_feature_tip() -> void:
	if _active_feature_tip_id == &"":
		return
	_active_feature_tip_id = &""
	if not _pending_feature_tips.is_empty():
		var next_id := _pending_feature_tips[0]
		_pending_feature_tips.remove_at(0)
		_activate_feature_tip(next_id)
	_refresh_onboarding_visibility()
	_release_button_focus_if_any()


func _queue_feature_tip(tip_id: StringName) -> void:
	if not _onboarding_enabled or tip_id == &"":
		return
	if _shown_feature_tips.get(tip_id, false):
		return
	if _active_feature_tip_id == tip_id or _pending_feature_tips.has(tip_id):
		return
	if _active_feature_tip_id == &"":
		_activate_feature_tip(tip_id)
	else:
		_pending_feature_tips.append(tip_id)
	_refresh_onboarding_visibility()


func _activate_feature_tip(tip_id: StringName) -> void:
	var tip := NarrativeTutorialCatalog.get_feature_discovery_tip(tip_id)
	if tip.is_empty():
		return
	_shown_feature_tips[tip_id] = true
	_active_feature_tip_id = tip_id
	if tip_title_label != null:
		tip_title_label.text = str(tip.get("title", "Tip"))
	if tip_body_label != null:
		tip_body_label.text = str(tip.get("body", ""))


func _on_story_continue_pressed() -> void:
	advance_story()


func _on_story_skip_pressed() -> void:
	skip_story()


func _on_tutorial_skip_pressed() -> void:
	skip_tutorial()


func _on_tutorial_next_pressed() -> void:
	if not is_tutorial_active() or _is_gameplay_paused():
		return
	var step_id := get_tutorial_step_id()
	if step_id == &"step_01_objective":
		_tutorial_flags[&"step_01_next"] = true
	elif step_id == &"step_09_finish_day":
		_tutorial_flags[&"step_09_done"] = true
	_evaluate_onboarding_progress()
	_refresh_onboarding_visibility()
	_release_button_focus_if_any()


func _on_tip_dismiss_pressed() -> void:
	dismiss_feature_tip()


func _on_tutorial_help_pressed() -> void:
	if is_reference_open():
		close_reference()
	else:
		open_reference()


func _on_reference_restart_pressed() -> void:
	restart_tutorial()


func _on_reference_close_pressed() -> void:
	close_reference()


func _on_onboarding_phase_changed(phase: int, day_index: int) -> void:
	if not _onboarding_enabled:
		return
	if phase == SharedTypes.Phase.SERVING or phase == SharedTypes.Phase.CLOSING:
		if is_story_open():
			_close_story_internal()
		if is_reference_open():
			close_reference()
	if phase == SharedTypes.Phase.RESULTS or phase == SharedTypes.Phase.FINISHED:
		for stale_tip in [&"online_offer", &"first_driver_pickup", &"driver_overflow", &"serving_belanja"]:
			_pending_feature_tips.erase(stale_tip)
		if _active_feature_tip_id in [&"online_offer", &"first_driver_pickup", &"driver_overflow", &"serving_belanja"]:
			dismiss_feature_tip()
	if phase == SharedTypes.Phase.PLANNING:
		if day_index >= 2 and _tutorial_active and _tutorial_started_day < day_index:
			_tutorial_completed = true
			_tutorial_active = false
		if day_index == 1:
			open_opening_story()
		elif day_index >= 2 and day_index <= 7:
			open_day_narrative(day_index)
	elif phase == SharedTypes.Phase.FINISHED:
		var goal_outcome: int = SharedTypes.DayOutcome.UNDECIDED
		if _run_controller != null:
			goal_outcome = int(_run_controller.get_run_view().get("goal_outcome", SharedTypes.DayOutcome.UNDECIDED))
		open_day_7_epilogue(goal_outcome)
	_evaluate_onboarding_progress()
	_refresh_onboarding_visibility()


func _record_onboarding_feedback(code: StringName) -> void:
	if not _onboarding_enabled:
		return
	match code:
		&"item_taken":
			if _held_has_ingredient(&"beras"):
				_tutorial_flags[&"rice_picked"] = true
				_tutorial_hint_text = "Beras diambil! Sekarang cuci di Wastafel."
			if _held_has_ingredient(&"telur"):
				_tutorial_flags[&"telur_picked"] = true
				_tutorial_hint_text = "Telur diambil! Bawa ke Kompor lalu ketik 'goreng'."
		&"item_washed":
			if _held_has_ingredient_state(&"beras", SharedTypes.PrepState.WASHED):
				_tutorial_flags[&"rice_washed"] = true
				_tutorial_hint_text = "Beras sudah dicuci! Lanjut ke Penanak Nasi."
		&"item_cooked":
			if _held_has_ingredient_state(&"telur", SharedTypes.PrepState.COOKED):
				_tutorial_flags[&"telur_cooked"] = true
				_tutorial_hint_text = "Telur matang! Rakit bersama piring & nasi."
		&"rice_cooked":
			_tutorial_flags[&"rice_cooked"] = true
			_tutorial_hint_text = "Nasi matang! 1x masak = 5 porsi nasi."
		&"rice_taken":
			_tutorial_flags[&"rice_cooked"] = true
			_tutorial_flags[&"rice_taken"] = true
		&"dish_ready":
			if _has_valid_nasi_telor_in_hand_or_table():
				_tutorial_flags[&"dish_assembled"] = true
				_tutorial_hint_text = "Nasi Telor siap! Antarkan ke meja pelanggan."
		&"order_served":
			_tutorial_flags[&"order_served"] = true
			_tutorial_hint_text = "Pesanan tersaji!"
		&"wrong_order":
			if is_tutorial_active() and get_tutorial_step_id() == &"step_07_serve_customer":
				_tutorial_hint_text = "Hidangan belum sesuai! Pastikan membawa piring Nasi Telor matang."
		&"invalid_key":
			if (
				is_tutorial_active()
				and get_tutorial_step_id() == &"step_07_serve_customer"
				and _kitchen_controller != null
				and not _has_valid_nasi_telor_in_hand_or_table()
			):
				_tutorial_hint_text = "Hidangan belum sesuai! Pastikan membawa piring Nasi Telor matang."
		&"table_cleaned":
			_tutorial_flags[&"table_cleaned"] = true
			_tutorial_hint_text = "Meja bersih! Cuci piring kotor di Wastafel."
		&"plate_washed":
			_tutorial_flags[&"plate_washed"] = true
			_tutorial_hint_text = "Piring bersih kembali ke tangan!"


func _evaluate_onboarding_progress() -> void:
	if not _onboarding_enabled:
		return
	_evaluate_feature_discovery()
	if not is_tutorial_active():
		_refresh_onboarding_visibility()
		return

	var phase := _get_current_phase()
	var day_index := _get_current_day_index()
	if day_index >= 2 and _tutorial_started_day < day_index:
		_tutorial_completed = true
		_tutorial_active = false
		_refresh_onboarding_visibility()
		return

	var steps := NarrativeTutorialCatalog.get_tutorial_steps()
	var prev_idx := _tutorial_step_index
	var safety: int = 0
	while _tutorial_active and _tutorial_step_index < steps.size() and safety < 12:
		safety += 1
		var step_id := StringName(steps[_tutorial_step_index].get("id", &""))
		if not _is_tutorial_step_satisfied(step_id, phase):
			break
		_tutorial_step_index += 1
		if _tutorial_step_index >= steps.size():
			_tutorial_completed = true
			_tutorial_active = false
			break

	if _tutorial_step_index != prev_idx and get_tutorial_step_id() != &"step_05_cook_egg":
		if _tutorial_step_index >= prev_idx + 2:
			_tutorial_hint_text = ""

	_update_tutorial_banner_view()
	_refresh_onboarding_visibility()


func _is_tutorial_step_satisfied(step_id: StringName, phase: int) -> bool:
	var already_results := (
		phase == SharedTypes.Phase.RESULTS
		or phase == SharedTypes.Phase.FINISHED
	)
	match step_id:
		&"step_01_objective":
			return (
				bool(_tutorial_flags.get(&"step_01_next", false))
				or phase == SharedTypes.Phase.SERVING
				or phase == SharedTypes.Phase.CLOSING
				or already_results
			)
		&"step_02_prepare_ingredients":
			var both_ready := _has_or_used_ingredient(&"beras") and _has_or_used_ingredient(&"telur")
			var rice_retrieved := (
				bool(_tutorial_flags.get(&"rice_picked", false))
				or _held_has_ingredient(&"beras")
				or _held_has_ingredient_state(&"beras", SharedTypes.PrepState.WASHED)
				or bool(_tutorial_flags.get(&"rice_washed", false))
				or _rice_cooker_has_cooked_rice()
				or bool(_tutorial_flags.get(&"rice_cooked", false))
			)
			return already_results or (both_ready and rice_retrieved)
		&"step_03_wash_rice":
			return (
				already_results
				or bool(_tutorial_flags.get(&"rice_washed", false))
				or _held_has_ingredient_state(&"beras", SharedTypes.PrepState.WASHED)
				or bool(_tutorial_flags.get(&"rice_cooked", false))
				or _rice_cooker_has_cooked_rice()
			)
		&"step_04_cook_rice":
			return (
				already_results
				or bool(_tutorial_flags.get(&"rice_cooked", false))
				or _rice_cooker_has_cooked_rice()
				or _has_valid_nasi_telor_in_hand_or_table()
				or bool(_tutorial_flags.get(&"order_served", false))
			)
		&"step_05_cook_egg":
			return (
				already_results
				or bool(_tutorial_flags.get(&"telur_cooked", false))
				or _stove_or_plate_has_cooked_telur()
				or _has_valid_nasi_telor_in_hand_or_table()
				or bool(_tutorial_flags.get(&"order_served", false))
			)
		&"step_06_assemble_dish":
			return (
				already_results
				or _has_valid_nasi_telor_in_hand_or_table()
				or bool(_tutorial_flags.get(&"dish_assembled", false))
				or bool(_tutorial_flags.get(&"order_served", false))
			)
		&"step_07_serve_customer":
			return already_results or bool(_tutorial_flags.get(&"order_served", false))
		&"step_08_clean_and_wash":
			return (
				already_results
				or (
					bool(_tutorial_flags.get(&"table_cleaned", false))
					and bool(_tutorial_flags.get(&"plate_washed", false))
				)
			)
		&"step_09_finish_day":
			return (
				bool(_tutorial_flags.get(&"step_09_done", false))
				or phase == SharedTypes.Phase.FINISHED
			)
		_:
			return false


func _evaluate_feature_discovery() -> void:
	if _service_controller != null:
		var offer_view := _service_controller.get_online_offer_view()
		if (
			bool(offer_view.get("acceptance_enabled", false))
			or StringName(offer_view.get("preview_recipe_id", &"")) != &""
		):
			_queue_feature_tip(&"online_offer")

		var has_driver_at_pickup := false
		var has_driver_overflow := false
		for dv in _service_controller.get_driver_views():
			var drv_state := int(dv.get("state", dv.get("driver_state", -1)))
			if drv_state == SharedTypes.DriverState.AT_PICKUP_SPOT:
				has_driver_at_pickup = true
			elif drv_state == SharedTypes.DriverState.OUTSIDE_DRIVER_QUEUE:
				has_driver_overflow = true
		if has_driver_at_pickup:
			_queue_feature_tip(&"first_driver_pickup")
		if not has_driver_overflow:
			var qv := _service_controller.get_customer_queue_view()
			if int(qv.get("outside_driver_count", 0)) > 0:
				has_driver_overflow = true
		if has_driver_overflow:
			_queue_feature_tip(&"driver_overflow")

	if _run_controller != null:
		var rv := _run_controller.get_run_view()
		var unlocked: Array = rv.get("unlocked_recipe_ids", [])
		if unlocked.size() > 1:
			_queue_feature_tip(&"recipe_unlock")
		var selected: Array = rv.get("selected_recipe_ids", [])
		if _recipes_need_chopped_veggie(selected) or _recipes_need_chopped_veggie(unlocked):
			_queue_feature_tip(&"potong_veggie")
		if _get_current_phase() == SharedTypes.Phase.RESULTS:
			var settlement := _run_controller.get_day_settlement_view(_get_current_day_index())
			if float(settlement.get("penalty_debt_after", 0.0)) > 0.0:
				_queue_feature_tip(&"demand_and_debt")


func _recipes_need_chopped_veggie(recipe_ids: Array) -> bool:
	if _kitchen_controller == null:
		return false
	for r_id_v in recipe_ids:
		var def := _kitchen_controller.get_recipe_def(StringName(r_id_v))
		if def == null:
			continue
		var parts_v: Variant = def.get("required_parts")
		if not (parts_v is Array):
			parts_v = def.get("ingredients")
		if not (parts_v is Array):
			continue
		for part_v in (parts_v as Array):
			var ing_id: StringName = &""
			var req_state: int = -1
			if part_v is Dictionary:
				var d := part_v as Dictionary
				ing_id = StringName(d.get("ingredient_id", &""))
				req_state = int(d.get("state", d.get("required_state", -1)))
			elif part_v is Object:
				var obj := part_v as Object
				var ing_v: Variant = obj.get("ingredient_id")
				if ing_v != null:
					ing_id = StringName(ing_v)
				var st_v: Variant = obj.get("state")
				if st_v == null:
					st_v = obj.get("required_state")
				if st_v != null:
					req_state = int(st_v)
			if (
				req_state == SharedTypes.PrepState.CHOPPED
				or req_state == SharedTypes.PrepState.CHOPPED_AND_COOKED
				or ing_id in [&"sayur", &"kol", &"timun", &"selada", &"tomat"]
			):
				return true
	return false


func _has_selected_recipes() -> bool:
	if _run_controller == null:
		return false
	var selected: Array = _run_controller.get_run_view().get("selected_recipe_ids", [])
	return not selected.is_empty()


func _storage_has_ingredient(ingredient_id: StringName) -> bool:
	if _kitchen_controller == null:
		return false
	for unit_id in [&"storage_box", &"fridge_a", &"fridge_b", &"fridge_c"]:
		if not _kitchen_controller.has_storage_unit(unit_id):
			continue
		var view := _kitchen_controller.get_storage_unit_view(unit_id)
		var slots_v: Variant = view.get("slots", [])
		if not (slots_v is Array):
			continue
		for slot_v in (slots_v as Array):
			if slot_v is Dictionary:
				var d := slot_v as Dictionary
				if (
					StringName(d.get("ingredient_id", &"")) == ingredient_id
					and int(d.get("quantity", 0)) > 0
				):
					return true
	return false


func _held_has_ingredient(ingredient_id: StringName) -> bool:
	if _kitchen_controller == null:
		return false
	return _view_has_ingredient_state(_kitchen_controller.get_held_item_view(), ingredient_id, -1)


func _held_has_ingredient_state(ingredient_id: StringName, req_state: int) -> bool:
	if _kitchen_controller == null:
		return false
	return _view_has_ingredient_state(_kitchen_controller.get_held_item_view(), ingredient_id, req_state)


func _has_or_used_ingredient(ingredient_id: StringName) -> bool:
	if _storage_has_ingredient(ingredient_id) or _held_has_ingredient(ingredient_id):
		return true
	if _kitchen_controller != null:
		for deliv: Dictionary in _kitchen_controller.get_pending_delivery_views():
			if StringName(deliv.get("ingredient_id", &"")) == ingredient_id:
				return true
		var wt := _kitchen_controller.get_work_table_view(&"work_table")
		if _view_has_ingredient_state(wt, ingredient_id, -1):
			return true
		if ingredient_id == &"beras":
			if _rice_cooker_has_rice() or bool(_tutorial_flags.get(&"rice_cooked", false)):
				return true
		if ingredient_id == &"telur":
			if bool(_tutorial_flags.get(&"telur_cooked", false)) or _stove_or_plate_has_cooked_telur():
				return true
	if bool(_tutorial_flags.get(&"order_served", false)):
		return true
	return false


func _find_storage_with_ingredient(ingredient_id: StringName) -> StringName:
	if _kitchen_controller != null:
		for unit_id in [&"storage_box", &"fridge_a", &"fridge_b", &"fridge_c"]:
			if not _kitchen_controller.has_storage_unit(unit_id):
				continue
			var view := _kitchen_controller.get_storage_unit_view(unit_id)
			var slots_v: Variant = view.get("slots", [])
			if not (slots_v is Array):
				continue
			for slot_v in (slots_v as Array):
				if slot_v is Dictionary:
					var d := slot_v as Dictionary
					if (
						StringName(d.get("ingredient_id", &"")) == ingredient_id
						and int(d.get("quantity", 0)) > 0
					):
						return unit_id
	return &"storage_box"


func _rice_cooker_has_rice() -> bool:
	if _kitchen_controller == null:
		return false
	var view := _kitchen_controller.get_cooker_output_view(&"rice_cooker")
	if int(view.get("portions", 0)) > 0:
		return true
	return _view_has_ingredient_state(view, &"beras", -1)


func _rice_cooker_has_cooked_rice() -> bool:
	if _kitchen_controller == null:
		return false
	for cooker_id in _kitchen_controller.get_cooker_ids():
		var view := _kitchen_controller.get_cooker_output_view(cooker_id)
		if int(view.get("portions", 0)) > 0 and _view_has_ingredient_state(
			view, &"beras", SharedTypes.PrepState.COOKED_RICE
		):
			return true
	if _view_has_ingredient_state(
		_kitchen_controller.get_held_item_view(), &"beras", SharedTypes.PrepState.COOKED_RICE
	):
		return true
	return _view_has_ingredient_state(
		_kitchen_controller.get_work_table_view(&"work_table"),
		&"beras",
		SharedTypes.PrepState.COOKED_RICE
	)


func _stove_or_plate_has_cooked_telur() -> bool:
	if _kitchen_controller == null:
		return false
	for cooker_id in _kitchen_controller.get_cooker_ids():
		if cooker_id == &"rice_cooker":
			continue
		var c_view := _kitchen_controller.get_cooker_output_view(cooker_id)
		if _view_has_ingredient_state(c_view, &"telur", SharedTypes.PrepState.COOKED):
			return true
	if _view_has_ingredient_state(
		_kitchen_controller.get_held_item_view(), &"telur", SharedTypes.PrepState.COOKED
	):
		return true
	return _view_has_ingredient_state(
		_kitchen_controller.get_work_table_view(&"work_table"),
		&"telur",
		SharedTypes.PrepState.COOKED
	)


func _has_valid_nasi_telor_in_hand_or_table() -> bool:
	if _kitchen_controller == null:
		return false
	var held := _kitchen_controller.get_held_item_view()
	if StringName(held.get("matched_recipe_id", &"")) == &"nasi_telor":
		return true
	var table := _kitchen_controller.get_work_table_view(&"work_table")
	return StringName(table.get("matched_recipe_id", &"")) == &"nasi_telor"


func _washer_dirty_plate_count() -> int:
	if _kitchen_controller == null:
		return 0
	return int(_kitchen_controller.get_washer_view().get("dirty_plate_count", 0))


func _find_waiting_table_for_tutorial(fallback_to_first: bool = true) -> StringName:
	if _service_controller == null:
		return &"dining_table_01" if fallback_to_first else &""
	var first_waiting := &""
	for table_id in _service_controller.get_registered_table_ids():
		var tview := _service_controller.get_table_view(table_id)
		if int(tview.get("state", -1)) != SharedTypes.TableState.OCCUPIED_WAITING:
			continue
		if first_waiting == &"":
			first_waiting = table_id
		var order_id := StringName(tview.get("order_id_or_empty", &""))
		if order_id != &"":
			var oview := _service_controller.get_order_view(order_id)
			if StringName(oview.get("recipe_id", &"")) == &"nasi_telor":
				return table_id
	if first_waiting != &"":
		return first_waiting
	return &"dining_table_01" if fallback_to_first else &""


func _find_dirty_table_for_tutorial() -> StringName:
	if _service_controller == null:
		return &""
	for table_id in _service_controller.get_registered_table_ids():
		if int(_service_controller.get_table_view(table_id).get("state", -1)) == SharedTypes.TableState.DIRTY:
			return table_id
	return &""


func _find_eating_table_for_tutorial() -> StringName:
	if _service_controller == null:
		return &""
	for table_id in _service_controller.get_registered_table_ids():
		if int(_service_controller.get_table_view(table_id).get("state", -1)) == SharedTypes.TableState.OCCUPIED_EATING:
			return table_id
	return &""


func _view_has_ingredient_state(view: Dictionary, ingredient_id: StringName, req_state: int) -> bool:
	if view.is_empty():
		return false
	var parts_v: Variant = view.get("parts", [])
	if not (parts_v is Array):
		return false
	for part_v in (parts_v as Array):
		var ing := &""
		var st := -1
		if part_v is Dictionary:
			var d := part_v as Dictionary
			ing = StringName(d.get("ingredient_id", &""))
			st = int(d.get("state", -1))
		elif part_v is Object:
			var obj := part_v as Object
			var ing_v: Variant = obj.get("ingredient_id")
			if ing_v != null:
				ing = StringName(ing_v)
			var st_v: Variant = obj.get("state")
			if st_v != null:
				st = int(st_v)
		if ing == ingredient_id and (req_state < 0 or st == req_state):
			return true
	return false


func _resolve_step_guidance_detail() -> Dictionary:
	var steps := NarrativeTutorialCatalog.get_tutorial_steps()
	if _tutorial_step_index < 0 or _tutorial_step_index >= steps.size():
		return {}
	var step := steps[_tutorial_step_index]
	var step_id := StringName(step.get("id", &""))
	var title := str(step.get("title", "Tutorial"))
	var body := str(step.get("body", ""))
	var allow_next := bool(step.get("allow_next", false))
	var next_label := str(step.get("next_label", "Lanjut"))
	var phase := _get_current_phase()

	var target_id: StringName = &""
	var marker := ""
	var badge := ""

	var held := _kitchen_controller.get_held_item_view() if _kitchen_controller != null else {}
	var table := _kitchen_controller.get_work_table_view(&"work_table") if _kitchen_controller != null else {}

	match step_id:
		&"step_01_objective":
			pass
		&"step_02_prepare_ingredients":
			var has_b := _has_or_used_ingredient(&"beras")
			var has_t := _has_or_used_ingredient(&"telur")
			marker = "2"
			if not has_b or not has_t:
				target_id = &"storage_box"
				badge = "[2] Ketik: beli"
				var missing := "beras dan telur" if (not has_b and not has_t) else ("beras" if not has_b else "telur")
				body = "Kita butuh %s. Klik Kotak Bahan lalu ketik 'beli' untuk membeli bahan!" % missing
			elif phase == SharedTypes.Phase.PLANNING:
				target_id = &"ui_start_service"
				badge = "[2] Ketik: buka"
				if _kitchen_controller != null and _kitchen_controller.get_selected_target_id() != &"":
					body = "Stok beras & telur siap! Klik lantai / tekan ESC, lalu ketik 'buka' untuk membuka warung."
				else:
					body = "Stok beras & telur siap! Ketik 'buka' untuk membuka warung agar bahan bisa diambil."
			else:
				target_id = _find_storage_with_ingredient(&"beras")
				badge = "[2] Ketik: beras"
				body = "Klik Kotak Bahan dan ketik 'beras' untuk mengambil beras. (Telur akan diambil dengan 'telur' nanti.)"
		&"step_03_wash_rice":
			marker = "3"
			if _view_has_ingredient_state(held, &"beras", SharedTypes.PrepState.RAW):
				target_id = &"washer"
				badge = "[3] Ketik: cuci"
				body = "Beras harus dicuci terlebih dahulu. Klik Wastafel, lalu ketik 'cuci'."
			elif _view_has_ingredient_state(table, &"beras", SharedTypes.PrepState.RAW):
				target_id = &"work_table_stage"
				badge = "[3] Ambil beras"
				body = "Klik Meja Kerja untuk mengambil kembali beras mentah, lalu cuci di Wastafel."
			else:
				target_id = _find_storage_with_ingredient(&"beras")
				badge = "[3] Ketik: beras"
				body = "Ambil beras dari Kotak Bahan ('beras'), lalu bawa ke Wastafel ('cuci')."
		&"step_04_cook_rice":
			marker = "4"
			if _view_has_ingredient_state(held, &"beras", SharedTypes.PrepState.WASHED):
				target_id = &"rice_cooker"
				badge = "[4] Ketik: masak"
				body = "Masukkan beras yang sudah dicuci ke Penanak Nasi. Klik Penanak Nasi lalu ketik 'masak'."
			elif _view_has_ingredient_state(table, &"beras", SharedTypes.PrepState.WASHED):
				target_id = &"work_table_stage"
				badge = "[4] Ambil beras cuci"
				body = "Ambil beras cuci di Meja Kerja lalu masukkan ke Penanak Nasi ('masak')."
			else:
				target_id = &"rice_cooker"
				badge = "[4] Penanak Nasi"
		&"step_05_cook_egg":
			marker = "5"
			if _view_has_ingredient_state(held, &"telur", SharedTypes.PrepState.RAW):
				target_id = &"stove"
				badge = "[5] Ketik: goreng"
				body = "1x masak menghasilkan 5 porsi nasi! Sekarang bawa telur ke Kompor, klik lalu ketik 'goreng'."
			elif _view_has_ingredient_state(table, &"telur", SharedTypes.PrepState.RAW):
				target_id = &"work_table_stage"
				badge = "[5] Ambil telur"
				body = "Klik Meja Kerja untuk mengambil telur mentah lalu goreng di Kompor ('goreng')."
			elif not held.is_empty():
				if table.is_empty():
					target_id = &"work_table_stage"
					badge = "[5] Taruh sementara"
					body = "1x masak = 5 porsi nasi! Taruh item di tangan ke Meja Kerja sebentar, lalu ambil 'telur' di Kotak Bahan."
				else:
					target_id = _find_storage_with_ingredient(&"telur")
					badge = "[5] Ketik: telur"
			elif _storage_has_ingredient(&"telur"):
				target_id = _find_storage_with_ingredient(&"telur")
				badge = "[5] Ketik: telur"
				body = "Satu kali memasak menghasilkan 5 porsi nasi! Klik Kotak Bahan lalu ketik 'telur'."
			else:
				target_id = &"storage_box"
				badge = "[5] Ketik: beli"
				body = "Stok telur habis! Klik Kotak Bahan -> ketik 'beli' untuk membeli telur."
		&"step_06_assemble_dish":
			marker = "6"
			var held_plate_id := StringName(held.get("plate_id", &""))
			var held_parts: Array = held.get("parts", [])
			var table_plate_id := StringName(table.get("plate_id", &""))
			var held_has_egg := _view_has_ingredient_state(held, &"telur", SharedTypes.PrepState.COOKED)
			var held_has_rice := _view_has_ingredient_state(held, &"beras", SharedTypes.PrepState.COOKED_RICE)
			var table_has_egg := _view_has_ingredient_state(table, &"telur", SharedTypes.PrepState.COOKED)
			var table_has_rice := _view_has_ingredient_state(table, &"beras", SharedTypes.PrepState.COOKED_RICE)
			if held_plate_id == &"" and not held.is_empty():
				if table_plate_id != &"":
					target_id = &"work_table_stage"
					badge = "[6] Klik Meja Kerja"
					body = "Klik Meja Kerja untuk menggabungkan bahan matang di tangan ke piring di meja!"
				else:
					target_id = &"plate_rack"
					badge = "[6] Klik Rak Piring"
					body = "Klik Rak Piring agar bahan matang langsung di piring (atau taruh dulu di Meja Kerja)!"
			elif held_plate_id != &"" and held_parts.is_empty():
				if table_has_egg or table_has_rice:
					target_id = &"work_table_stage"
					badge = "[6] Klik Meja Kerja"
					body = "Piring bersih siap! Klik Meja Kerja untuk memindahkan bahan matang ke piring."
				else:
					target_id = &"rice_cooker"
					badge = "[6] Ketik: nasi"
					body = "Piring bersih siap! Klik Penanak Nasi lalu ketik 'nasi'."
			elif held_plate_id != &"" and held_has_egg and not held_has_rice:
				if table_has_rice:
					target_id = &"work_table_stage"
					badge = "[6] Klik Meja Kerja"
					body = "Klik Meja Kerja untuk menambahkan nasi ke piring telur!"
				else:
					target_id = &"rice_cooker"
					badge = "[6] Ketik: nasi"
					body = "Telur sudah di piring! Klik Penanak Nasi lalu ketik 'nasi' untuk melengkapi Nasi Telor."
			elif held_plate_id != &"" and held_has_rice and not held_has_egg:
				if table_has_egg:
					target_id = &"work_table_stage"
					badge = "[6] Klik Meja Kerja"
					body = "Nasi sudah di piring! Klik Meja Kerja untuk menggabungkan telur goreng."
				else:
					target_id = _find_storage_with_ingredient(&"telur")
					badge = "[6] Siapkan telur"
					body = "Nasi di piring siap — ambil & goreng telur jika belum matang."
			elif not table.is_empty():
				if table_plate_id != &"":
					target_id = &"work_table_stage"
					badge = "[6] Klik Meja Kerja"
					body = "Lanjutkan merakit Nasi Telor di Meja Kerja atau Penanak Nasi ('nasi')."
				else:
					target_id = &"plate_rack"
					badge = "[6] Klik Rak Piring"
					body = "Bahan matang sudah siap di Meja Kerja! Klik Rak Piring untuk ambil piring bersih, lalu gabung."
			else:
				target_id = &"plate_rack"
				badge = "[6] Klik Rak Piring"
		&"step_07_serve_customer":
			marker = "7"
			if StringName(table.get("matched_recipe_id", &"")) == &"nasi_telor" and held.is_empty():
				target_id = &"work_table_stage"
				badge = "[7] Ambil Nasi Telor"
				body = "Nasi Telor sudah jadi di Meja Kerja! Klik Meja Kerja untuk mengambilnya."
			else:
				target_id = _find_waiting_table_for_tutorial()
				badge = "[7] Ketik: saji"
				body = "Pesanan sudah siap! Pilih meja pelanggan yang menunggu, lalu ketik 'saji'."
		&"step_08_clean_and_wash":
			var dirty_tid := _find_dirty_table_for_tutorial()
			if bool(_tutorial_flags.get(&"table_cleaned", false)) or _washer_dirty_plate_count() > 0:
				marker = "8b"
				if not held.is_empty() and table.is_empty():
					target_id = &"work_table_stage"
					badge = "[8b] Taruh dulu"
					body = "Kosongkan tangan (taruh di Meja Kerja) sebelum mencuci piring kotor di Wastafel."
				else:
					target_id = &"washer"
					badge = "[8b] Ketik: cuci"
					body = "Piring kotor masuk Wastafel. Dengan tangan kosong, klik Wastafel lalu ketik 'cuci'."
			elif dirty_tid != &"":
				marker = "8a"
				target_id = dirty_tid
				badge = "[8a] Ketik: bersihkan"
				body = "Pelanggan selesai makan & meja kotor! Klik meja tersebut lalu ketik 'bersihkan'."
			else:
				marker = "8"
				var eat_tid := _find_eating_table_for_tutorial()
				target_id = eat_tid if eat_tid != &"" else &"dining_table_01"
				badge = "[8] Tunggu selesai"
				body = "Pelanggan sedang makan (~20 dtk). Setelah selesai, bersihkan mejanya ('bersihkan') lalu cuci piring di Wastafel."
		&"step_09_finish_day":
			marker = "9"
			if phase == SharedTypes.Phase.RESULTS or phase == SharedTypes.Phase.FINISHED:
				target_id = &"ui_day_result"
				badge = "[9] Hasil Hari 1"
			else:
				allow_next = false
				var wait_tid := _find_waiting_table_for_tutorial(false)
				var dirty_tid := _find_dirty_table_for_tutorial()
				target_id = wait_tid if wait_tid != &"" else dirty_tid
				badge = "[9] Lanjut layani" if target_id != &"" else ""
				body = "Teruskan melayani pelanggan yang tersisa sampai jam warung tutup otomatis, lalu cek laporan hasil hari pertama."

	if not _tutorial_hint_text.is_empty() and step_id != &"step_01_objective" and phase != SharedTypes.Phase.RESULTS:
		body = _tutorial_hint_text + "\n" + body

	return {
		"id": step_id,
		"title": title,
		"body": body,
		"allow_next": allow_next,
		"next_label": next_label,
		"target_id": target_id,
		"marker": marker,
		"badge": badge,
	}


func _update_tutorial_banner_view() -> void:
	if not is_tutorial_active():
		return
	var detail := _resolve_step_guidance_detail()
	if detail.is_empty():
		return
	if tutorial_title_label != null:
		tutorial_title_label.text = str(detail.get("title", "Tutorial"))
	if tutorial_body_label != null:
		tutorial_body_label.text = str(detail.get("body", ""))
	if tutorial_next_button != null:
		tutorial_next_button.visible = bool(detail.get("allow_next", false))
		tutorial_next_button.text = str(detail.get("next_label", "Lanjut"))


func _refresh_onboarding_visibility() -> void:
	var paused := _is_gameplay_paused()
	var story_open := is_story_open()
	var ref_open := is_reference_open()

	if story_dialogue_overlay != null:
		story_dialogue_overlay.visible = _onboarding_enabled and story_open and not paused
		if story_dialogue_overlay.visible:
			_update_story_dialogue_view()

	if tutorial_reference_overlay != null:
		tutorial_reference_overlay.visible = (
			_onboarding_enabled and ref_open and not paused and not story_open
		)

	if tutorial_help_button != null:
		tutorial_help_button.visible = _onboarding_enabled and not paused and not story_open

	var modal_blocking := (
		story_open
		or ref_open
		or is_edit_menu_open()
		or is_ingredient_shop_open()
		or is_fixture_shop_open()
	)
	if tutorial_banner != null:
		tutorial_banner.visible = (
			is_tutorial_active()
			and not paused
			and not story_open
			and not ref_open
		)
		if tutorial_banner.visible:
			_update_tutorial_banner_view()

	if feature_tip_panel != null:
		feature_tip_panel.visible = (
			_onboarding_enabled
			and _active_feature_tip_id != &""
			and not paused
			and not modal_blocking
		)

	var vp := get_viewport()
	if vp != null:
		var vp_size := vp.get_visible_rect().size
		if vp_size.x > 0.0 and vp_size.y > 0.0:
			var hud_w: float = left_hud_region.size.x if left_hud_region != null else 136.0
			var world_rect := Rect2(hud_w, 0.0, maxf(0.0, vp_size.x - hud_w), vp_size.y)
			_layout_onboarding_overlays(vp_size, world_rect)
	_refresh_visual_guidance()


func _refresh_visual_guidance() -> void:
	if tutorial_guidance_overlay == null:
		return
	var paused := _is_gameplay_paused()
	var story_open := is_story_open()
	var ref_open := is_reference_open()
	var modal_blocking := (
		story_open
		or ref_open
		or is_edit_menu_open()
		or is_ingredient_shop_open()
		or is_fixture_shop_open()
	)
	if not _onboarding_enabled or paused or modal_blocking:
		tutorial_guidance_overlay.clear_guidance()
		return

	var target_id: StringName = &""
	var badge := ""
	var marker := ""
	var accent := Color(0.32, 0.96, 0.62, 1.0)

	if is_tutorial_active():
		var detail := _resolve_step_guidance_detail()
		target_id = StringName(detail.get("target_id", &""))
		badge = str(detail.get("badge", ""))
		marker = str(detail.get("marker", ""))

	if target_id == &"" and _active_feature_tip_id != &"":
		var tip_spec := _resolve_tip_guidance_detail(_active_feature_tip_id)
		target_id = StringName(tip_spec.get("target_id", &""))
		badge = str(tip_spec.get("badge", ""))
		marker = str(tip_spec.get("marker", "!"))
		accent = Color(0.98, 0.80, 0.30, 1.0)

	if target_id == &"":
		tutorial_guidance_overlay.clear_guidance()
		return

	var resolved := _resolve_guidance_target_rect(target_id)
	var target_rect: Rect2 = resolved.get("rect", Rect2())
	var bounds_rect: Rect2 = resolved.get("bounds_rect", world_visible_rect)
	if target_rect.size.x <= 0.0 or target_rect.size.y <= 0.0:
		tutorial_guidance_overlay.clear_guidance()
		return

	var avoid_rect := Rect2()
	if interaction_dialogue != null and interaction_dialogue.visible:
		avoid_rect = interaction_dialogue.get_global_rect()
	if target_id == &"ui_day_result" and tutorial_banner != null and tutorial_banner.visible:
		var banner_rect := tutorial_banner.get_global_rect()
		avoid_rect = banner_rect if avoid_rect.size == Vector2.ZERO else avoid_rect.merge(banner_rect)

	tutorial_guidance_overlay.set_guidance(
		target_id,
		target_rect,
		bounds_rect,
		badge,
		marker,
		accent,
		avoid_rect,
		paused
	)


func _resolve_tip_guidance_detail(tip_id: StringName) -> Dictionary:
	var phase := _get_current_phase()
	match tip_id:
		&"online_offer":
			if phase == SharedTypes.Phase.SERVING:
				return { "target_id": &"online_station", "marker": "!", "badge": "[Tip] Ketik: terima" }
			return {}
		&"first_driver_pickup":
			if phase == SharedTypes.Phase.SERVING and _service_controller != null:
				for dv in _service_controller.get_driver_views():
					if int(dv.get("state", dv.get("driver_state", -1))) == SharedTypes.DriverState.AT_PICKUP_SPOT:
						var did := StringName(dv.get("driver_id", &""))
						if did != &"":
							return { "target_id": did, "marker": "!", "badge": "[Tip] Ketik: saji" }
			return {}
		&"driver_overflow":
			if phase == SharedTypes.Phase.SERVING and _service_controller != null:
				for dv in _service_controller.get_driver_views():
					if int(dv.get("state", dv.get("driver_state", -1))) == SharedTypes.DriverState.OUTSIDE_DRIVER_QUEUE:
						var did := StringName(dv.get("driver_id", &""))
						if did != &"":
							return { "target_id": did, "marker": "!", "badge": "[Tip] Spot Penuh" }
			return { "target_id": &"driver_overflow", "marker": "!", "badge": "[Tip] Antrean Penuh" } if phase == SharedTypes.Phase.SERVING else {}
		&"potong_veggie":
			if phase == SharedTypes.Phase.SERVING:
				return { "target_id": &"work_table_chop", "marker": "!", "badge": "[Tip] Ketik: potong" }
			return {}
		&"serving_belanja":
			if phase != SharedTypes.Phase.SERVING:
				return {}
			if _kitchen_controller != null and _kitchen_controller.has_storage_unit(_last_shop_storage_unit_id):
				return { "target_id": _last_shop_storage_unit_id, "marker": "!", "badge": "[Tip] Kirim ~100d" }
			return { "target_id": &"storage_box", "marker": "!", "badge": "[Tip] Kirim ~100d" }
		&"recipe_unlock":
			if phase == SharedTypes.Phase.PLANNING:
				return { "target_id": &"ui_edit_menu_button", "marker": "!", "badge": "[Tip] Edit Menu" }
			return {}
		&"demand_and_debt":
			if phase == SharedTypes.Phase.RESULTS or phase == SharedTypes.Phase.FINISHED:
				return { "target_id": &"ui_day_result", "marker": "!", "badge": "[Tip] Penalti" }
			return {}
		_:
			return {}


func _resolve_guidance_target_rect(target_id: StringName) -> Dictionary:
	var vp := get_viewport()
	var vp_size := vp.get_visible_rect().size if vp != null else LOGICAL_VIEWPORT_SIZE
	var hud_w: float = left_hud_region.size.x if left_hud_region != null else 136.0
	var world_bounds := Rect2(hud_w, 0.0, maxf(160.0, vp_size.x - hud_w), vp_size.y)
	var full_bounds := Rect2(0.0, 0.0, vp_size.x, vp_size.y)

	match target_id:
		&"ui_start_service":
			if start_hint_label != null and start_hint_label.is_visible_in_tree():
				return { "rect": start_hint_label.get_global_rect().grow(3.0), "bounds_rect": full_bounds }
			return {}
		&"ui_edit_menu_button":
			if edit_menu_button != null and edit_menu_button.is_visible_in_tree():
				return { "rect": edit_menu_button.get_global_rect().grow(2.0), "bounds_rect": full_bounds }
			return {}
		&"ui_day_result":
			if day_result_side_panel != null and day_result_side_panel.visible:
				var raw_rect := day_result_side_panel.get_global_rect()
				var clamped_rect := raw_rect.intersection(full_bounds)
				return {
					"rect": clamped_rect if clamped_rect.size.x > 0.0 else raw_rect,
					"bounds_rect": full_bounds,
				}
			return {}

	if _world_map == null or not is_instance_valid(_world_map):
		return {}
	var node: Node2D = null
	if _world_map.registry != null and _world_map.registry.has_object(target_id):
		node = _world_map.registry.get_object(target_id)
	if node == null and _world_map.has_method(&"get_driver_visual_node"):
		node = _world_map.get_driver_visual_node(target_id)
	if node == null or not is_instance_valid(node) or not node.is_visible_in_tree():
		return {}

	return {
		"rect": _compute_world_node_canvas_rect(node),
		"bounds_rect": world_bounds,
	}


func _compute_world_node_canvas_rect(node: Node2D) -> Rect2:
	if node is Area2D:
		var has_shape := false
		var min_pt := Vector2(INF, INF)
		var max_pt := Vector2(-INF, -INF)
		for child in (node as Area2D).get_children():
			if not (child is CollisionShape2D):
				continue
			var col := child as CollisionShape2D
			if col.disabled or col.shape == null:
				continue
			var ext := Vector2(14.0, 14.0)
			if col.shape is RectangleShape2D:
				ext = (col.shape as RectangleShape2D).size * 0.5
			elif col.shape is CircleShape2D:
				var r := (col.shape as CircleShape2D).radius
				ext = Vector2(r, r)
			var xform := col.get_global_transform_with_canvas()
			for corner: Vector2 in [
				Vector2(-ext.x, -ext.y),
				Vector2(ext.x, -ext.y),
				Vector2(ext.x, ext.y),
				Vector2(-ext.x, ext.y),
			]:
				var c: Vector2 = xform * corner
				min_pt.x = minf(min_pt.x, c.x)
				min_pt.y = minf(min_pt.y, c.y)
				max_pt.x = maxf(max_pt.x, c.x)
				max_pt.y = maxf(max_pt.y, c.y)
			has_shape = true
		if has_shape:
			return Rect2(min_pt, max_pt - min_pt)

	var xform := node.get_global_transform_with_canvas()
	var center := xform.origin
	var scale_vec := xform.get_scale()
	var half := Vector2(15.0 * absf(scale_vec.x), 15.0 * absf(scale_vec.y))
	return Rect2(center - half, half * 2.0)


func _layout_onboarding_overlays(vp_size: Vector2, world_rect: Rect2) -> void:
	var world_left: float = clampf(world_rect.position.x, 0.0, vp_size.x)
	var world_w: float = maxf(160.0, vp_size.x - world_left)

	if story_dialogue_overlay != null:
		var dimmer := story_dialogue_overlay.get_node_or_null("WorldDimmer") as Control
		if dimmer != null:
			dimmer.position = Vector2(world_left, 0.0)
			dimmer.size = Vector2(world_w, vp_size.y)
	if story_popup != null:
		var sw: float = clampf(world_w - 20.0, 200.0, 468.0)
		var sh: float = clampf(126.0 if vp_size.y >= 320.0 else 120.0, 96.0, vp_size.y - 20.0)
		var sx: float = world_left + floorf((world_w - sw) * 0.5)
		var sy: float = maxf(10.0, vp_size.y - sh - 10.0)
		story_popup.position = Vector2(sx, sy)
		story_popup.size = Vector2(sw, sh)

	if tutorial_reference_overlay != null:
		var ref_dimmer := tutorial_reference_overlay.get_node_or_null("WorldDimmer") as Control
		if ref_dimmer != null:
			ref_dimmer.position = Vector2(world_left, 0.0)
			ref_dimmer.size = Vector2(world_w, vp_size.y)
	if reference_popup != null:
		var rw: float = clampf(world_w - 24.0, 220.0, 456.0)
		var rh: float = clampf(vp_size.y - 36.0, 180.0, 304.0)
		var rx: float = world_left + floorf((world_w - rw) * 0.5)
		var ry: float = floorf((vp_size.y - rh) * 0.5)
		reference_popup.position = Vector2(rx, ry)
		reference_popup.size = Vector2(rw, rh)

	var results_visible := day_result_side_panel != null and day_result_side_panel.visible
	var right_space: float = world_w
	if tutorial_help_button != null:
		var hx: float = (
			maxf(world_left + 6.0, day_result_side_panel.position.x - 78.0)
			if results_visible
			else vp_size.x - 76.0
		)
		tutorial_help_button.position = Vector2(hx, 4.0)
		tutorial_help_button.size = Vector2(72.0, 20.0)

	if results_visible:
		var panel_left := day_result_side_panel.position.x
		var avail_left: float = maxf(140.0, panel_left - world_left - 12.0)
		var bw: float = clampf(avail_left, 140.0, 234.0)
		var bh: float = clampf(120.0 if vp_size.y >= 320.0 else 96.0, 76.0, vp_size.y - 36.0)
		if tutorial_banner != null:
			tutorial_banner.position = Vector2(world_left + 6.0, maxf(8.0, vp_size.y - bh - 8.0))
			tutorial_banner.size = Vector2(bw, bh)
		if feature_tip_panel != null:
			var th: float = clampf(114.0 if vp_size.y >= 320.0 else 86.0, 68.0, vp_size.y - 40.0)
			var ty: float = (
				maxf(28.0, tutorial_banner.position.y - th - 6.0)
				if tutorial_banner != null and tutorial_banner.visible
				else 28.0
			)
			feature_tip_panel.position = Vector2(world_left + 6.0, ty)
			feature_tip_panel.size = Vector2(bw, th)
		return

	var strip_w: float = clampf(172.0 if vp_size.x >= 560.0 else 150.0, 128.0, maxf(130.0, right_space - 12.0))
	var bx: float = vp_size.x - strip_w - 4.0
	var by: float = 28.0
	var banner_h: float = clampf(122.0 if vp_size.y >= 320.0 else 102.0, 76.0, vp_size.y - by - 8.0)
	if tutorial_banner != null:
		tutorial_banner.position = Vector2(bx, by)
		tutorial_banner.size = Vector2(strip_w, banner_h)
	if feature_tip_panel != null:
		var th: float = clampf(114.0 if vp_size.y >= 320.0 else 92.0, 64.0, vp_size.y - 36.0)
		var ty: float = by
		if tutorial_banner != null and tutorial_banner.visible:
			ty = tutorial_banner.position.y + tutorial_banner.size.y + 6.0
			if ty + th > vp_size.y - 4.0:
				ty = maxf(28.0, vp_size.y - th - 4.0)
		feature_tip_panel.position = Vector2(bx, ty)
		feature_tip_panel.size = Vector2(strip_w, th)
