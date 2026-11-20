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
	&"employee_hired": "Pegawai berhasil direkrut!",
	&"employee_dismissed": "Pegawai diberhentikan.",
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
var _employee_role_rows: Dictionary[StringName, Dictionary] = {}
var _employee_roster_rows: Dictionary[StringName, Dictionary] = {}
var _pending_dismiss_employee_id: StringName = &""

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
var _shown_initial_cara_main: bool = false
var _reference_paused_by_self: bool = false
var _reference_return_to_pause: bool = false
var _settings_return_to_pause: bool = false
var _exit_return_to_pause: bool = false
var _exit_paused_by_self: bool = false
var _tutorial_replay_pending_from_menu: bool = false
var _last_served_order_count: int = 0
var _last_online_served_count: int = 0
var _hovered_dirty_table_id: StringName = &""
var _last_mouse_canvas_pos: Vector2 = Vector2(-1.0, -1.0)

@onready var ui_root: Control = $UIRoot
@onready var menu_game_backdrop: TextureRect = $UIRoot/MenuGameBackdrop
@onready var left_hud_region: PanelContainer = $UIRoot/LeftHUDRegion
@onready var day_card: PanelContainer = $UIRoot/LeftHUDRegion/HUDColumn/DayCardRow/DayCard
@onready var hari_ke_banner: TextureRect = (
	$UIRoot/LeftHUDRegion/HUDColumn/DayCardRow/DayCard/DayCardColumn/HariKeBanner
)
@onready var day_value_label: Label = (
	$UIRoot/LeftHUDRegion/HUDColumn/DayCardRow/DayCard/DayCardColumn/DayValueLabel
)
@onready var day_label: Label = $UIRoot/LeftHUDRegion/HUDColumn/DayLabel
@onready var phase_label: Label = $UIRoot/LeftHUDRegion/HUDColumn/PhaseLabel
@onready var cash_panel: PanelContainer = $UIRoot/LeftHUDRegion/HUDColumn/CashPanel
@onready var cash_coin_icon: TextureRect = (
	$UIRoot/LeftHUDRegion/HUDColumn/CashPanel/CashRow/CashCoinIcon
)
@onready var cash_label: Label = $UIRoot/LeftHUDRegion/HUDColumn/CashPanel/CashRow/CashLabel
@onready var target_tamu_banner: TextureRect = (
	$UIRoot/LeftHUDRegion/HUDColumn/TargetSection/TargetGuestCardSection/TargetTamuBanner
)
@onready var target_guest_panel: PanelContainer = (
	$UIRoot/LeftHUDRegion/HUDColumn/TargetSection/TargetGuestCardSection/TargetGuestPanel
)
@onready var target_guest_value_label: Label = (
	$UIRoot/LeftHUDRegion/HUDColumn/TargetSection/TargetGuestCardSection/TargetGuestPanel/TargetGuestRow/TargetGuestValueLabel
)
@onready var target_guest_sub_label: Label = (
	$UIRoot/LeftHUDRegion/HUDColumn/TargetSection/TargetGuestCardSection/TargetGuestPanel/TargetGuestRow/TargetGuestSubLabel
)
@onready var goal_target_label: Label = (
	$UIRoot/LeftHUDRegion/HUDColumn/TargetSection/GoalTargetLabel
)
@onready var goal_label: Label = $UIRoot/LeftHUDRegion/HUDColumn/TargetSection/GoalLabel
@onready var goal_progress_bar: ProgressBar = (
	$UIRoot/LeftHUDRegion/HUDColumn/TargetSection/GoalProgressBar
)
@onready var hud_typing_section: VBoxContainer = (
	$UIRoot/LeftHUDRegion/HUDColumn/HudTypingSection
)
@onready var ketik_banner: TextureRect = (
	$UIRoot/LeftHUDRegion/HUDColumn/HudTypingSection/KetikBanner
)
@onready var hud_typing_panel: PanelContainer = (
	$UIRoot/LeftHUDRegion/HUDColumn/HudTypingSection/HudTypingPanel
)
@onready var start_hint_label: Label = (
	$UIRoot/LeftHUDRegion/HUDColumn/HudTypingSection/HudTypingPanel/TypingContentColumn/StartHintLabel
)
@onready var hud_typing_label: Label = (
	$UIRoot/LeftHUDRegion/HUDColumn/HudTypingSection/HudTypingPanel/TypingContentColumn/HudTypingLabel
)
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
@onready var employee_button: Button = (
	$UIRoot/LeftHUDRegion/HUDColumn/PlanningBox/EmployeeButton
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
@onready var retry_button: Button = (
	$UIRoot/DayResultSidePanel/ResultColumn/ResultFooter/RetryButton
)
@onready var result_menu_button: Button = (
	$UIRoot/DayResultSidePanel/ResultColumn/ResultFooter/ResultMenuButton
)

@onready var edit_menu_overlay: Control = $UIRoot/EditMenuOverlay
@onready var edit_menu_popup: PanelContainer = $UIRoot/EditMenuOverlay/EditMenuPopup
@onready var edit_menu_forecast_label: Label = (
	$UIRoot/EditMenuOverlay/EditMenuPopup/PopupColumn/EditMenuForecastLabel
)
@onready var edit_menu_recipe_list: VBoxContainer = (
	$UIRoot/EditMenuOverlay/EditMenuPopup/PopupColumn/EditMenuBodyRow/RecipeScroll/RecipeList
)
@onready var recipe_detail_panel: PanelContainer = $UIRoot/EditMenuOverlay/RecipeDetailPanel
@onready var recipe_detail_title_label: Label = (
	$UIRoot/EditMenuOverlay/RecipeDetailPanel/DetailColumn/RecipeDetailTitleLabel
)
@onready var recipe_detail_list: VBoxContainer = (
	$UIRoot/EditMenuOverlay/RecipeDetailPanel/DetailColumn/DetailScroll/RecipeDetailList
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
@onready var employee_overlay: Control = $UIRoot/EmployeeOverlay
@onready var employee_popup: PanelContainer = $UIRoot/EmployeeOverlay/EmployeePopup
@onready var employee_cash_label: Label = (
	$UIRoot/EmployeeOverlay/EmployeePopup/EmployeeColumn/EmployeeHeaderRow/EmployeeCashLabel
)
@onready var employee_salary_label: Label = (
	$UIRoot/EmployeeOverlay/EmployeePopup/EmployeeColumn/EmployeeHeaderRow/EmployeeSalaryLabel
)
@onready var employee_crowding_label: Label = (
	$UIRoot/EmployeeOverlay/EmployeePopup/EmployeeColumn/EmployeeCrowdingLabel
)
@onready var employee_role_list: VBoxContainer = (
	$UIRoot/EmployeeOverlay/EmployeePopup/EmployeeColumn/EmployeeScroll/EmployeeContentBox/RoleList
)
@onready var employee_roster_section_label: Label = (
	$UIRoot/EmployeeOverlay/EmployeePopup/EmployeeColumn/EmployeeScroll/EmployeeContentBox/RosterSectionLabel
)
@onready var employee_roster_list: VBoxContainer = (
	$UIRoot/EmployeeOverlay/EmployeePopup/EmployeeColumn/EmployeeScroll/EmployeeContentBox/RosterList
)
@onready var employee_error_label: Label = (
	$UIRoot/EmployeeOverlay/EmployeePopup/EmployeeColumn/EmployeeErrorLabel
)
@onready var employee_summary_label: Label = (
	$UIRoot/EmployeeOverlay/EmployeePopup/EmployeeColumn/EmployeeFooterRow/EmployeeSummaryLabel
)
@onready var employee_close_button: Button = (
	$UIRoot/EmployeeOverlay/EmployeePopup/EmployeeColumn/EmployeeFooterRow/EmployeeCloseButton
)
@onready var pause_overlay: Control = $UIRoot/PauseOverlay
@onready var pause_popup: PanelContainer = $UIRoot/PauseOverlay/PausePopup
@onready var pause_resume_button: Button = (
	$UIRoot/PauseOverlay/PausePopup/PauseColumn/PauseResumeButton
)
@onready var pause_settings_button: Button = (
	$UIRoot/PauseOverlay/PausePopup/PauseColumn/PauseSettingsButton
)
@onready var pause_reference_button: Button = (
	$UIRoot/PauseOverlay/PausePopup/PauseColumn/PauseReferenceButton
)
@onready var pause_main_menu_button: Button = (
	$UIRoot/PauseOverlay/PausePopup/PauseColumn/PauseMainMenuButton
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
@onready var reference_sections_box: VBoxContainer = (
	$UIRoot/TutorialReferenceOverlay/ReferencePopup/RefColumn/RefScroll/RefContentBox/RefSectionsBox
)
@onready var reference_body_richtext: RichTextLabel = (
	$UIRoot/TutorialReferenceOverlay/ReferencePopup/RefColumn/RefScroll/RefContentBox/RefBodyRichText
)
@onready var reference_body_label: Label = (
	$UIRoot/TutorialReferenceOverlay/ReferencePopup/RefColumn/RefScroll/RefContentBox/RefBodyLabel
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
@onready var hover_tooltip_panel: PanelContainer = $UIRoot/HoverTooltipPanel
@onready var hover_tooltip_label: Label = $UIRoot/HoverTooltipPanel/HoverTooltipLabel
@onready var main_menu_overlay: Control = $UIRoot/MainMenuOverlay
@onready var main_menu_bg: TextureRect = $UIRoot/MainMenuOverlay/MainMenuBackground
@onready var main_menu_cloud_tl: TextureRect = $UIRoot/MainMenuOverlay/MegaMendungTopLeft
@onready var main_menu_cloud_br: TextureRect = $UIRoot/MainMenuOverlay/MegaMendungBottomRight
@onready var main_menu_logo: TextureRect = $UIRoot/MainMenuOverlay/MainMenuCenter/MainMenuLogo
@onready var main_menu_play_button: Button = (
	$UIRoot/MainMenuOverlay/MainMenuCenter/MainMenuButtons/MainMenuPlayButton
)
@onready var main_menu_settings_button: Button = (
	$UIRoot/MainMenuOverlay/MainMenuCenter/MainMenuButtons/MainMenuSettingsButton
)
@onready var main_menu_quit_button: Button = (
	$UIRoot/MainMenuOverlay/MainMenuCenter/MainMenuButtons/MainMenuQuitButton
)
@onready var settings_overlay: Control = $UIRoot/SettingsOverlay
@onready var settings_popup: PanelContainer = $UIRoot/SettingsOverlay/SettingsPopup
@onready var settings_scroll: ScrollContainer = (
	$UIRoot/SettingsOverlay/SettingsPopup/SettingsColumn/SettingsScroll
)
@onready var settings_body: VBoxContainer = (
	$UIRoot/SettingsOverlay/SettingsPopup/SettingsColumn/SettingsScroll/SettingsBody
)
@onready var master_volume_slider: HSlider = (
	settings_body.get_node("MasterVolumeRow/MasterVolumeSlider") as HSlider
)
@onready var master_value_label: Label = (
	settings_body.get_node("MasterVolumeRow/MasterValueLabel") as Label
)
@onready var bgm_volume_slider: HSlider = (
	settings_body.get_node("BgmVolumeRow/BgmVolumeSlider") as HSlider
)
@onready var bgm_value_label: Label = (
	settings_body.get_node("BgmVolumeRow/BgmValueLabel") as Label
)
@onready var sfx_volume_slider: HSlider = (
	settings_body.get_node("SfxVolumeRow/SfxVolumeSlider") as HSlider
)
@onready var sfx_value_label: Label = (
	settings_body.get_node("SfxVolumeRow/SfxValueLabel") as Label
)
@onready var display_mode_button: Button = (
	settings_body.get_node("DisplayModeRow/DisplayModeButton") as Button
)
@onready var resolution_option_button: OptionButton = (
	settings_body.get_node("ResolutionRow/ResolutionOptionButton") as OptionButton
)
@onready var vsync_toggle_button: Button = (
	settings_body.get_node("VsyncRow/VsyncToggleButton") as Button
)
@onready var display_status_label: Label = (
	settings_body.get_node("DisplayStatusLabel") as Label
)
@onready var settings_reset_button: Button = (
	settings_body.get_node("OtherRow/SettingsResetButton") as Button
)
@onready var settings_feedback_label: Label = (
	settings_body.get_node("OtherRow/SettingsFeedbackLabel") as Label
)
@onready var settings_replay_tutorial_button: Button = (
	settings_body.get_node("TutorialRow/SettingsReplayTutorialButton") as Button
)
@onready var settings_tutorial_status_label: Label = (
	settings_body.get_node("TutorialRow/SettingsTutorialStatusLabel") as Label
)
@onready var settings_close_button: Button = (
	$UIRoot/SettingsOverlay/SettingsPopup/SettingsColumn/SettingsCloseButton
)
@onready var exit_confirm_overlay: Control = $UIRoot/ExitConfirmOverlay
@onready var exit_confirm_popup: PanelContainer = $UIRoot/ExitConfirmOverlay/ExitConfirmPopup
@onready var exit_confirm_title_label: Label = (
	exit_confirm_popup.get_node("ExitConfirmColumn/ExitConfirmTitleLabel") as Label
)
@onready var exit_confirm_message_label: Label = (
	exit_confirm_popup.get_node("ExitConfirmColumn/ExitConfirmMessageLabel") as Label
)
@onready var exit_confirm_cancel_button: Button = (
	exit_confirm_popup.get_node("ExitConfirmColumn/ExitConfirmButtons/ExitConfirmCancelButton")
	as Button
)
@onready var exit_confirm_quit_button: Button = (
	exit_confirm_popup.get_node("ExitConfirmColumn/ExitConfirmButtons/ExitConfirmQuitButton")
	as Button
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
	if left_hud_region != null and not left_hud_region.minimum_size_changed.is_connected(
		_on_left_hud_min_size_changed
	):
		left_hud_region.minimum_size_changed.connect(_on_left_hud_min_size_changed)
	_connect_ui_buttons()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(
		_on_viewport_size_changed
	):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	if reference_body_label != null:
		reference_body_label.text = NarrativeTutorialCatalog.get_reference_summary_text()
	if reference_body_richtext != null:
		reference_body_richtext.text = NarrativeTutorialCatalog.get_cara_main_bbcode()
	_populate_cara_main_sections()
	_layout_fixture_shop_overlay()
	_refresh_all()
	call_deferred(&"_check_auto_onboarding_start")


func _process(delta: float) -> void:
	_refresh_hover_tooltip()
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
			_refresh_employee_visuals()
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
	if is_main_menu_open() or is_settings_open() or is_exit_confirm_open():
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
	if is_employee_shop_open():
		return true
	if day_result_side_panel != null and day_result_side_panel.visible:
		return true
	return false


func is_main_menu_open() -> bool:
	return main_menu_overlay != null and main_menu_overlay.visible


func is_settings_open() -> bool:
	return settings_overlay != null and settings_overlay.visible


func is_exit_confirm_open() -> bool:
	return exit_confirm_overlay != null and exit_confirm_overlay.visible


func open_exit_confirm(from_pause: bool = false) -> void:
	if exit_confirm_overlay == null:
		return
	_exit_return_to_pause = from_pause
	if from_pause and pause_overlay != null:
		pause_overlay.visible = false
	elif (
		_is_serving_phase()
		and not is_main_menu_open()
		and not _is_gameplay_paused()
		and _game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_method(&"set_paused")
	):
		_exit_paused_by_self = true
		if not bool(_game_root.set_paused(true)):
			_exit_paused_by_self = false
	if exit_confirm_title_label != null:
		exit_confirm_title_label.text = "Keluar Game?"
	if exit_confirm_message_label != null:
		exit_confirm_message_label.text = "Yakin ingin keluar dari Ketik Saji?"
	exit_confirm_overlay.visible = true
	_layout_fixture_shop_overlay()
	if exit_confirm_cancel_button != null:
		exit_confirm_cancel_button.grab_focus()


func close_exit_confirm() -> void:
	if exit_confirm_overlay != null:
		exit_confirm_overlay.visible = false
	var was_paused_by_self := _exit_paused_by_self
	var return_to_pause := _exit_return_to_pause
	_exit_paused_by_self = false
	_exit_return_to_pause = false
	if (
		was_paused_by_self
		and _game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_method(&"set_paused")
	):
		_game_root.set_paused(false)
	elif return_to_pause and pause_overlay != null and _is_gameplay_paused():
		pause_overlay.visible = true
	_release_button_focus_if_any()
	_refresh_hud()
	_refresh_dialogue()


func open_settings(from_pause: bool = false) -> void:
	if settings_overlay == null:
		return
	_settings_return_to_pause = from_pause
	if from_pause and pause_overlay != null:
		pause_overlay.visible = false
	_populate_resolution_options()
	_sync_settings_controls("")
	settings_overlay.visible = true
	_layout_fixture_shop_overlay()
	if settings_close_button != null:
		settings_close_button.grab_focus()


func close_settings() -> void:
	if settings_overlay != null:
		settings_overlay.visible = false
	if _settings_return_to_pause and pause_overlay != null and _is_gameplay_paused():
		pause_overlay.visible = true
	_settings_return_to_pause = false
	_release_button_focus_if_any()


func _populate_resolution_options() -> void:
	if resolution_option_button == null:
		return
	resolution_option_button.clear()
	var resolutions: Array[Vector2i] = GameAudio.ALLOWED_RESOLUTIONS
	var audio := _get_audio_controller()
	if audio != null:
		resolutions = audio.get_allowed_resolutions()
	for i in range(resolutions.size()):
		var res := resolutions[i]
		resolution_option_button.add_item("%dx%d" % [res.x, res.y], i)
		resolution_option_button.set_item_metadata(i, res)


func _sync_settings_controls(feedback: String = "") -> void:
	var audio := _get_audio_controller()
	var master_v := audio.get_master_volume() if audio != null else GameAudio.DEFAULT_MASTER_VOLUME
	var music_v := audio.get_music_volume() if audio != null else GameAudio.DEFAULT_MUSIC_VOLUME
	var sfx_v := audio.get_sfx_volume() if audio != null else GameAudio.DEFAULT_SFX_VOLUME
	var snap := (
		audio.get_applied_display_snapshot()
		if audio != null
		else {
			"applied_ok": true,
			"fullscreen": GameAudio.DEFAULT_FULLSCREEN,
			"window_size": GameAudio.DEFAULT_RESOLUTION,
			"requested_resolution": GameAudio.DEFAULT_RESOLUTION,
			"vsync_enabled": GameAudio.DEFAULT_VSYNC,
			"feedback": "",
		}
	)
	var fullscreen := bool(snap.get("fullscreen", GameAudio.DEFAULT_FULLSCREEN))
	var actual_res := snap.get("window_size", GameAudio.DEFAULT_RESOLUTION) as Vector2i
	var requested_res := snap.get("requested_resolution", GameAudio.DEFAULT_RESOLUTION) as Vector2i
	var vsync_on := bool(snap.get("vsync_enabled", GameAudio.DEFAULT_VSYNC))

	if master_volume_slider != null:
		master_volume_slider.set_value_no_signal(master_v)
	_update_percent_label(master_value_label, master_v)
	if bgm_volume_slider != null:
		bgm_volume_slider.set_value_no_signal(music_v)
	_update_bgm_value_label(music_v)
	if sfx_volume_slider != null:
		sfx_volume_slider.set_value_no_signal(sfx_v)
	_update_percent_label(sfx_value_label, sfx_v)

	if display_mode_button != null:
		display_mode_button.text = "Layar Penuh" if fullscreen else "Berjendela"
	if resolution_option_button != null:
		for i in range(resolution_option_button.item_count):
			var item_res: Variant = resolution_option_button.get_item_metadata(i)
			if item_res is Vector2i and (item_res as Vector2i) == requested_res:
				resolution_option_button.select(i)
				break
		resolution_option_button.disabled = fullscreen
	if vsync_toggle_button != null:
		vsync_toggle_button.text = "Aktif" if vsync_on else "Mati"
	if display_status_label != null:
		if fullscreen:
			display_status_label.text = (
				"Aktif: Layar Penuh (%dx%d) · Resolusi jendela (%dx%d) berlaku saat Berjendela."
				% [actual_res.x, actual_res.y, requested_res.x, requested_res.y]
			)
		elif actual_res != requested_res:
			display_status_label.text = (
				"Aktif: Berjendela · %dx%d (dibatasi layar dari %dx%d)"
				% [actual_res.x, actual_res.y, requested_res.x, requested_res.y]
			)
		else:
			display_status_label.text = (
				"Aktif: Berjendela · %dx%d · VSync %s"
				% [actual_res.x, actual_res.y, "Aktif" if vsync_on else "Mati"]
			)
	if settings_feedback_label != null:
		settings_feedback_label.text = feedback
	if settings_tutorial_status_label != null:
		var t_done := _tutorial_completed
		var t_skip := _tutorial_skipped
		if audio != null:
			var t_state := audio.get_tutorial_state()
			t_done = t_done or bool(t_state.get("completed", false))
			t_skip = t_skip or bool(t_state.get("skipped", false))
		if _tutorial_replay_pending_from_menu or (is_tutorial_active() and _tutorial_step_index == 0):
			settings_tutorial_status_label.text = "Status: Siap dimulai dari Bab 1"
		elif t_done:
			settings_tutorial_status_label.text = "Status: Selesai"
		elif t_skip:
			settings_tutorial_status_label.text = "Status: Dilewati"
		else:
			settings_tutorial_status_label.text = "Status: Aktif"


func get_hover_tooltip_text() -> String:
	if hover_tooltip_panel == null or not hover_tooltip_panel.visible or hover_tooltip_label == null:
		return ""
	return hover_tooltip_label.text


func is_pause_open() -> bool:
	return pause_overlay != null and pause_overlay.visible


func open_pause() -> bool:
	if pause_overlay == null:
		return false
	if is_main_menu_open() or is_settings_open() or is_exit_confirm_open() or is_reference_open():
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
	if pause_resume_button != null:
		pause_resume_button.grab_focus()
	return true


func close_pause() -> void:
	if pause_overlay != null:
		pause_overlay.visible = false
	_reference_return_to_pause = false
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
	_exit_return_to_pause = false
	_exit_paused_by_self = false
	if exit_confirm_overlay != null:
		exit_confirm_overlay.visible = false
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
	if is_employee_shop_open():
		close_employee_shop()

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
	if (
		_run_controller.has_method(&"is_ingredient_unlocked")
		and not _run_controller.is_ingredient_unlocked(ingredient_id)
	):
		_show_shop_error("Bahan belum terbuka.")
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
	if _onboarding_enabled:
		if _is_serving_phase():
			_queue_feature_tip(&"serving_belanja")
		_evaluate_onboarding_progress()
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
	if is_employee_shop_open():
		close_employee_shop()

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
	if _onboarding_enabled:
		_tutorial_flags[&"edit_menu_confirmed"] = true
		_evaluate_onboarding_progress()
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
	if is_employee_shop_open():
		close_employee_shop()

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
		_queue_feature_tip(&"fixture_shop_tip")
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


func is_employee_shop_open() -> bool:
	return employee_overlay != null and employee_overlay.visible


func open_employee_shop() -> bool:
	if (
		not _is_planning_phase()
		or _is_gameplay_paused()
		or is_story_open()
		or is_reference_open()
		or employee_overlay == null
	):
		return false
	if _run_controller == null or not is_instance_valid(_run_controller):
		return false
	if is_edit_menu_open():
		close_edit_menu()
	if is_ingredient_shop_open():
		close_ingredient_shop()
	if is_fixture_shop_open():
		close_fixture_shop()

	_clear_feedback_state()
	if _kitchen_controller != null and is_instance_valid(_kitchen_controller):
		_kitchen_controller.clear_command_prefix()
	_clear_employee_error()
	_pending_dismiss_employee_id = &""
	_build_employee_shop_ui()
	employee_overlay.visible = true
	_tutorial_flags[&"employee_inspected"] = true
	_layout_fixture_shop_overlay()
	_refresh_employee_shop_view()
	_refresh_dialogue()
	_evaluate_onboarding_progress()
	return true


func close_employee_shop() -> void:
	if employee_overlay != null:
		employee_overlay.visible = false
	_pending_dismiss_employee_id = &""
	_clear_employee_error()
	_release_button_focus_if_any()
	_refresh_dialogue()
	_evaluate_onboarding_progress()


func hire_employee_role(role_id: StringName) -> StringName:
	if not is_employee_shop_open() or _is_gameplay_paused():
		return &""
	if _run_controller == null or not is_instance_valid(_run_controller):
		_show_employee_error("Sistem pegawai tidak tersedia.")
		return &""
	var check := _run_controller.can_hire_employee(role_id)
	if not bool(check.get("ok", false)):
		var reason := StringName(check.get("reason", &"invalid"))
		if reason == &"insufficient_funds":
			var need := int(check.get("hire_cost", 0))
			_show_employee_error("Dana Tidak Cukup (Biaya Rekrutmen: %s)." % format_rupiah(need))
		elif reason == &"not_planning":
			_show_employee_error("Rekrut Pegawai hanya bisa saat Perencanaan.")
		else:
			_show_employee_error("Gagal merekrut pegawai.")
		_refresh_employee_shop_view()
		return &""

	var emp_id := _run_controller.request_employee_hire(role_id)
	if emp_id == &"":
		_show_employee_error("Dana Tidak Cukup untuk merekrut pegawai.")
		_refresh_employee_shop_view()
		return &""

	_pending_dismiss_employee_id = &""
	_clear_employee_error()
	_build_employee_shop_ui()
	_refresh_employee_shop_view()
	_refresh_employee_visuals()
	_refresh_hud()
	if _onboarding_enabled:
		_queue_feature_tip(&"employee_hired")
		_evaluate_onboarding_progress()
	return emp_id


func request_dismiss_confirmation(employee_id: StringName) -> void:
	if not is_employee_shop_open() or _is_gameplay_paused():
		return
	_pending_dismiss_employee_id = employee_id
	_clear_employee_error()
	_build_employee_shop_ui()
	_refresh_employee_shop_view()


func cancel_dismiss_confirmation() -> void:
	_pending_dismiss_employee_id = &""
	_build_employee_shop_ui()
	_refresh_employee_shop_view()


func dismiss_employee_by_id(employee_id: StringName) -> bool:
	if not is_employee_shop_open() or _is_gameplay_paused():
		return false
	if _run_controller == null or not is_instance_valid(_run_controller):
		_show_employee_error("Sistem pegawai tidak tersedia.")
		return false
	if not _run_controller.request_employee_dismiss(employee_id):
		_show_employee_error("Gagal memberhentikan pegawai.")
		return false

	_pending_dismiss_employee_id = &""
	_clear_employee_error()
	_build_employee_shop_ui()
	_refresh_employee_shop_view()
	_refresh_employee_visuals()
	_refresh_hud()
	if _onboarding_enabled:
		_queue_feature_tip(&"employee_hired")
		_evaluate_onboarding_progress()
	return true


func get_employee_role_row(role_id: StringName) -> Dictionary:
	return _employee_role_rows.get(role_id, {})


func get_employee_roster_row(employee_id: StringName) -> Dictionary:
	return _employee_roster_rows.get(employee_id, {})


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
	if is_exit_confirm_open():
		if key_event.keycode == KEY_ESCAPE:
			_play_ui_click()
			close_exit_confirm()
			if is_inside_tree() and get_viewport() != null:
				get_viewport().set_input_as_handled()
		return
	if is_settings_open() and key_event.keycode == KEY_ESCAPE:
		_play_ui_click()
		close_settings()
		if is_inside_tree() and get_viewport() != null:
			get_viewport().set_input_as_handled()
		return
	if is_main_menu_open():
		return
	if not _is_serving_phase() and not _is_planning_phase():
		return
	if key_event.keycode == KEY_ESCAPE:
		_play_ui_click()
		if _handle_escape_key():
			if is_inside_tree() and get_viewport() != null:
				get_viewport().set_input_as_handled()
		return
	if _is_keyboard_blocked_by_focus_or_modal():
		return
	if _kitchen_controller == null:
		return

	if key_event.keycode == KEY_BACKSPACE:
		_play_ui_click()
		_clear_feedback_state()
		_kitchen_controller.backspace_command_prefix()
		_refresh_dialogue()
		if is_inside_tree() and get_viewport() != null:
			get_viewport().set_input_as_handled()
		return

	var ch := _extract_typed_character(key_event)
	if not ch.is_empty():
		_play_ui_click()
		_kitchen_controller.accept_typed_character(ch)
		if is_inside_tree() and get_viewport() != null:
			get_viewport().set_input_as_handled()


func _handle_escape_key() -> bool:
	if is_exit_confirm_open():
		close_exit_confirm()
		return true
	if is_settings_open():
		close_settings()
		return true
	if is_reference_open():
		close_reference()
		return true
	if is_pause_open():
		close_pause()
		return true
	if _is_gameplay_paused():
		return false
	if is_story_open():
		return open_pause()
	if is_ingredient_shop_open():
		close_ingredient_shop()
		return true
	if is_fixture_shop_open():
		close_fixture_shop()
		return true
	if is_employee_shop_open():
		close_employee_shop()
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
	if employee_button != null:
		if not employee_button.pressed.is_connected(_on_employee_shop_pressed):
			employee_button.pressed.connect(_on_employee_shop_pressed)
	if employee_close_button != null:
		if not employee_close_button.pressed.is_connected(_on_employee_close_pressed):
			employee_close_button.pressed.connect(_on_employee_close_pressed)
	if menu_stub_button != null:
		if not menu_stub_button.pressed.is_connected(_on_menu_stub_pressed):
			menu_stub_button.pressed.connect(_on_menu_stub_pressed)
	if exit_stub_button != null:
		if not exit_stub_button.pressed.is_connected(_on_exit_stub_pressed):
			exit_stub_button.pressed.connect(_on_exit_stub_pressed)
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
	if retry_button != null:
		if not retry_button.pressed.is_connected(_on_retry_pressed):
			retry_button.pressed.connect(_on_retry_pressed)
	if result_menu_button != null:
		if not result_menu_button.pressed.is_connected(_on_result_menu_pressed):
			result_menu_button.pressed.connect(_on_result_menu_pressed)
	if pause_settings_button != null:
		if not pause_settings_button.pressed.is_connected(_on_pause_settings_pressed):
			pause_settings_button.pressed.connect(_on_pause_settings_pressed)
	if pause_reference_button != null:
		if not pause_reference_button.pressed.is_connected(_on_pause_reference_pressed):
			pause_reference_button.pressed.connect(_on_pause_reference_pressed)
	if pause_main_menu_button != null:
		if not pause_main_menu_button.pressed.is_connected(_on_pause_main_menu_pressed):
			pause_main_menu_button.pressed.connect(_on_pause_main_menu_pressed)
	if main_menu_play_button != null:
		if not main_menu_play_button.pressed.is_connected(_on_main_menu_play_pressed):
			main_menu_play_button.pressed.connect(_on_main_menu_play_pressed)
	if main_menu_settings_button != null:
		if not main_menu_settings_button.pressed.is_connected(_on_main_menu_settings_pressed):
			main_menu_settings_button.pressed.connect(_on_main_menu_settings_pressed)
	if main_menu_quit_button != null:
		if not main_menu_quit_button.pressed.is_connected(_on_main_menu_quit_pressed):
			main_menu_quit_button.pressed.connect(_on_main_menu_quit_pressed)
	if master_volume_slider != null:
		if not master_volume_slider.value_changed.is_connected(_on_master_slider_changed):
			master_volume_slider.value_changed.connect(_on_master_slider_changed)
	if bgm_volume_slider != null:
		if not bgm_volume_slider.value_changed.is_connected(_on_bgm_slider_changed):
			bgm_volume_slider.value_changed.connect(_on_bgm_slider_changed)
	if sfx_volume_slider != null:
		if not sfx_volume_slider.value_changed.is_connected(_on_sfx_slider_changed):
			sfx_volume_slider.value_changed.connect(_on_sfx_slider_changed)
	if display_mode_button != null:
		if not display_mode_button.pressed.is_connected(_on_display_mode_pressed):
			display_mode_button.pressed.connect(_on_display_mode_pressed)
	if resolution_option_button != null:
		if not resolution_option_button.item_selected.is_connected(_on_resolution_selected):
			resolution_option_button.item_selected.connect(_on_resolution_selected)
	if vsync_toggle_button != null:
		if not vsync_toggle_button.pressed.is_connected(_on_vsync_toggle_pressed):
			vsync_toggle_button.pressed.connect(_on_vsync_toggle_pressed)
	if settings_reset_button != null:
		if not settings_reset_button.pressed.is_connected(_on_settings_reset_pressed):
			settings_reset_button.pressed.connect(_on_settings_reset_pressed)
	if settings_replay_tutorial_button != null:
		if not settings_replay_tutorial_button.pressed.is_connected(
			_on_settings_replay_tutorial_pressed
		):
			settings_replay_tutorial_button.pressed.connect(_on_settings_replay_tutorial_pressed)
	if tutorial_reference_overlay != null:
		var ref_dimmer := tutorial_reference_overlay.get_node_or_null("WorldDimmer") as ColorRect
		if ref_dimmer != null and not ref_dimmer.gui_input.is_connected(
			_on_reference_dimmer_gui_input
		):
			ref_dimmer.gui_input.connect(_on_reference_dimmer_gui_input)
	if settings_close_button != null:
		if not settings_close_button.pressed.is_connected(_on_settings_close_pressed):
			settings_close_button.pressed.connect(_on_settings_close_pressed)
	if exit_confirm_cancel_button != null:
		if not exit_confirm_cancel_button.pressed.is_connected(_on_exit_confirm_cancel_pressed):
			exit_confirm_cancel_button.pressed.connect(_on_exit_confirm_cancel_pressed)
	if exit_confirm_quit_button != null:
		if not exit_confirm_quit_button.pressed.is_connected(_on_exit_confirm_quit_pressed):
			exit_confirm_quit_button.pressed.connect(_on_exit_confirm_quit_pressed)
	_hook_button_click_sfx(ui_root)


func _get_audio_controller() -> GameAudio:
	if _game_root != null and is_instance_valid(_game_root) and _game_root.has_method(&"get_audio_controller"):
		return _game_root.get_audio_controller() as GameAudio
	return null


func _play_ui_click() -> void:
	var audio := _get_audio_controller()
	if audio != null:
		audio.play_click()


func _hook_button_click_sfx(root_node: Node) -> void:
	if root_node == null:
		return
	if root_node is Button:
		var b := root_node as Button
		if not b.has_meta(&"click_sfx_hooked"):
			b.set_meta(&"click_sfx_hooked", true)
			b.pressed.connect(_play_ui_click)
	for child in root_node.get_children():
		_hook_button_click_sfx(child)


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
	var audio := _get_audio_controller()
	if audio != null and audio.has_signal(&"display_settings_applied"):
		if not audio.display_settings_applied.is_connected(_on_display_settings_applied):
			audio.display_settings_applied.connect(_on_display_settings_applied)


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


	var audio := _get_audio_controller()
	if audio != null and audio.has_signal(&"display_settings_applied"):
		if audio.display_settings_applied.is_connected(_on_display_settings_applied):
			audio.display_settings_applied.disconnect(_on_display_settings_applied)


func _on_display_settings_applied(ok: bool, feedback: String) -> void:
	if is_settings_open():
		var msg := "" if ok else feedback
		_sync_settings_controls(msg)


func _on_edit_menu_pressed() -> void:
	open_edit_menu()


func _on_edit_menu_cancel_pressed() -> void:
	close_edit_menu()


func _on_edit_menu_confirm_pressed() -> void:
	submit_edit_menu(_pending_menu_selection)


func _on_menu_stub_pressed() -> void:
	# Toggle CARA MAIN guide from HUD button without spawning or activating Pause Menu.
	if not is_main_menu_open() and not is_settings_open() and not is_exit_confirm_open():
		if is_reference_open():
			close_reference()
		else:
			open_reference(false)


func _on_exit_stub_pressed() -> void:
	if is_main_menu_open() or is_settings_open() or is_exit_confirm_open():
		return
	open_exit_confirm(false)


func _on_main_menu_play_pressed() -> void:
	if _game_root != null and is_instance_valid(_game_root) and _game_root.has_method(&"request_start_play_from_menu"):
		_game_root.request_start_play_from_menu()
	_onboarding_boot_checked = false
	_refresh_main_menu_visibility()
	call_deferred(&"_check_auto_onboarding_start")


func _on_main_menu_settings_pressed() -> void:
	open_settings(false)


func _on_main_menu_quit_pressed() -> void:
	open_exit_confirm(false)


func _on_master_slider_changed(new_value: float) -> void:
	var audio := _get_audio_controller()
	if audio != null:
		audio.set_master_volume(new_value)
	_update_percent_label(master_value_label, new_value)


func _on_bgm_slider_changed(new_value: float) -> void:
	var audio := _get_audio_controller()
	if audio != null:
		audio.set_bgm_volume(new_value)
	_update_bgm_value_label(new_value)


func _on_sfx_slider_changed(new_value: float) -> void:
	var audio := _get_audio_controller()
	if audio != null:
		audio.set_sfx_volume(new_value)
	_update_percent_label(sfx_value_label, new_value)


func _on_display_mode_pressed() -> void:
	var audio := _get_audio_controller()
	var ok := true
	if audio != null:
		ok = audio.set_fullscreen_enabled(not audio.is_fullscreen_enabled())
	var err_msg := "" if (ok or audio == null) else String(audio.get_applied_display_snapshot().get("feedback", ""))
	_sync_settings_controls(err_msg)


func _on_resolution_selected(index: int) -> void:
	if resolution_option_button == null or index < 0 or index >= resolution_option_button.item_count:
		return
	var meta: Variant = resolution_option_button.get_item_metadata(index)
	var audio := _get_audio_controller()
	var ok := true
	if meta is Vector2i and audio != null:
		ok = audio.set_resolution(meta as Vector2i)
	var err_msg := "" if (ok or audio == null) else String(audio.get_applied_display_snapshot().get("feedback", ""))
	_sync_settings_controls(err_msg)


func _on_vsync_toggle_pressed() -> void:
	var audio := _get_audio_controller()
	var ok := true
	if audio != null:
		ok = audio.set_vsync_enabled(not audio.is_vsync_enabled())
	var err_msg := "" if (ok or audio == null) else String(audio.get_applied_display_snapshot().get("feedback", ""))
	_sync_settings_controls(err_msg)


func _on_settings_reset_pressed() -> void:
	var audio := _get_audio_controller()
	if audio != null:
		audio.reset_settings_to_default()
	_sync_settings_controls("Pengaturan direset ke default.")


func _on_settings_replay_tutorial_pressed() -> void:
	var audio := _get_audio_controller()
	if audio != null:
		audio.reset_tutorial_state(true)
	_tutorial_completed = false
	_tutorial_skipped = false
	_tutorial_step_index = 0
	_tutorial_flags.clear()
	_shown_feature_tips.clear()
	_pending_feature_tips.clear()
	_active_feature_tip_id = &""
	_tutorial_hint_text = ""
	if is_main_menu_open():
		_tutorial_replay_pending_from_menu = true
		_sync_settings_controls("Tutorial diulang saat Play dimulai.")
	else:
		_onboarding_explicitly_set = true
		_onboarding_enabled = true
		_tutorial_active = true
		_tutorial_started_day = _get_current_day_index()
		_tutorial_replay_pending_from_menu = false
		_sync_settings_controls("Tutorial diulang dari Bab 1.")
		_evaluate_onboarding_progress()
		_refresh_onboarding_visibility()


func _update_percent_label(lbl: Label, val: float) -> void:
	if lbl != null:
		lbl.text = "%d%%" % roundi(clampf(val, 0.0, 1.0) * 100.0)


func _update_bgm_value_label(val: float) -> void:
	_update_percent_label(bgm_value_label, val)


func _on_exit_confirm_cancel_pressed() -> void:
	close_exit_confirm()


func _on_exit_confirm_quit_pressed() -> void:
	request_exit_game()


func _on_settings_close_pressed() -> void:
	close_settings()


func _on_pause_settings_pressed() -> void:
	open_settings(true)


func _on_pause_reference_pressed() -> void:
	open_reference(true)


func _on_pause_main_menu_pressed() -> void:
	close_pause()
	if _game_root != null and is_instance_valid(_game_root) and _game_root.has_method(&"request_return_to_main_menu"):
		_reset_session_onboarding_state()
		_game_root.request_return_to_main_menu()
		_refresh_all()


func _on_retry_pressed() -> void:
	if _game_root != null and is_instance_valid(_game_root) and _game_root.has_method(&"request_restart_run"):
		_reset_session_onboarding_state()
		_game_root.request_restart_run()
		_refresh_all()


func _on_result_menu_pressed() -> void:
	if _game_root != null and is_instance_valid(_game_root) and _game_root.has_method(&"request_return_to_main_menu"):
		_reset_session_onboarding_state()
		_game_root.request_return_to_main_menu()
		_refresh_all()


func _reset_session_onboarding_state() -> void:
	_shown_day_stories.clear()
	_shown_day7_epilogue = false
	_shown_initial_cara_main = false
	_active_story_id = &""
	_active_story_lines.clear()
	_onboarding_boot_checked = false
	_reference_paused_by_self = false
	_reference_return_to_pause = false
	_last_served_order_count = 0
	_last_online_served_count = 0


func _on_shop_retrieve_pressed() -> void:
	close_ingredient_shop()


func _on_shop_cancel_pressed() -> void:
	close_ingredient_shop()


func _on_shop_checkout_pressed() -> void:
	submit_ingredient_shop()


func _find_first_available_placement_slot() -> StringName:
	if _world_map == null or not is_instance_valid(_world_map):
		return &""
	for slot_id in _world_map.get_placement_slot_ids():
		var sv := _world_map.get_placement_slot_view(slot_id)
		if bool(sv.get("occupied", false)):
			continue
		if String(slot_id).begins_with("slot_utility_"):
			return slot_id
	for slot_id in _world_map.get_placement_slot_ids():
		var sv := _world_map.get_placement_slot_view(slot_id)
		if not bool(sv.get("occupied", false)):
			return slot_id
	return &""


func _on_fixture_shop_pressed() -> void:
	var slot_id := _find_first_available_placement_slot()
	if slot_id == &"":
		_refresh_hud()
		return
	open_fixture_shop(slot_id)


func _on_fixture_cancel_pressed() -> void:
	close_fixture_shop()


func _on_fixture_confirm_pressed() -> void:
	submit_fixture_shop()


func _on_employee_shop_pressed() -> void:
	open_employee_shop()


func _on_employee_close_pressed() -> void:
	close_employee_shop()


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
	open_exit_confirm(true)


func _on_pause_changed(paused: bool) -> void:
	if pause_overlay != null:
		pause_overlay.visible = (
			paused
			and not _exit_paused_by_self
			and not _reference_paused_by_self
			and not _reference_return_to_pause
			and not _settings_return_to_pause
			and not _exit_return_to_pause
		)
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
	if phase != SharedTypes.Phase.PLANNING and is_employee_shop_open():
		close_employee_shop()
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
	if _onboarding_enabled and is_tutorial_active() and get_tutorial_step_id() == &"ch1_move":
		_tutorial_flags[&"player_moved"] = true
		_evaluate_onboarding_progress()
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
	if is_employee_shop_open():
		_build_employee_shop_ui()
		_refresh_employee_shop_view()
	_refresh_employee_visuals()
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
	_refresh_main_menu_visibility()
	_refresh_hud()
	_refresh_kitchen_visuals()
	_refresh_dine_in_visuals()
	_refresh_online_station_visual()
	_refresh_driver_visuals()
	_refresh_employee_visuals()
	_refresh_dialogue()
	_refresh_results_panel()
	_refresh_onboarding_visibility()


func _refresh_main_menu_visibility() -> void:
	if main_menu_overlay == null:
		return
	var in_menu := (
		_game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_method(&"is_in_main_menu")
		and bool(_game_root.is_in_main_menu())
	)
	main_menu_overlay.visible = in_menu
	if left_hud_region != null:
		left_hud_region.visible = not in_menu
	if menu_game_backdrop != null:
		menu_game_backdrop.visible = not in_menu


func _input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_last_mouse_canvas_pos = motion.position
		_refresh_hover_tooltip()


func _refresh_hover_tooltip() -> void:
	if hover_tooltip_panel == null or hover_tooltip_label == null:
		return
	if is_modal_blocking() or not _is_serving_phase():
		hover_tooltip_panel.visible = false
		_hovered_dirty_table_id = &""
		return
	if _world_map == null or _service_controller == null or not is_inside_tree():
		hover_tooltip_panel.visible = false
		_hovered_dirty_table_id = &""
		return
	var vp := get_viewport()
	if vp == null:
		hover_tooltip_panel.visible = false
		return
	var canvas_pos := _last_mouse_canvas_pos
	if canvas_pos.x < 0.0 or canvas_pos.y < 0.0:
		canvas_pos = vp.get_mouse_position()
	if _is_point_blocked_by_ui(canvas_pos):
		hover_tooltip_panel.visible = false
		_hovered_dirty_table_id = &""
		return
	var world_pos: Vector2 = _world_map.get_canvas_transform().affine_inverse() * canvas_pos
	var hit_id := _hit_test_interactable(world_pos)
	if hit_id != &"" and _service_controller.has_table(hit_id):
		var t_view := _service_controller.get_table_view(hit_id)
		if int(t_view.get("state", -1)) == SharedTypes.TableState.DIRTY:
			_hovered_dirty_table_id = hit_id
			hover_tooltip_label.text = "meja kotor"
			hover_tooltip_panel.visible = true
			hover_tooltip_panel.reset_size()
			var tip_sz := hover_tooltip_panel.get_combined_minimum_size()
			hover_tooltip_panel.size = tip_sz
			var vp_sz := _get_viewport_logical_size()
			var tx := clampf(canvas_pos.x - tip_sz.x * 0.5, 140.0, vp_sz.x - tip_sz.x - 4.0)
			var ty := clampf(canvas_pos.y - tip_sz.y - 8.0, 4.0, vp_sz.y - tip_sz.y - 4.0)
			hover_tooltip_panel.position = Vector2(tx, ty)
			return
	_hovered_dirty_table_id = &""
	hover_tooltip_panel.visible = false


func _refresh_kitchen_visuals() -> void:
	if _world_map == null or not is_instance_valid(_world_map):
		return
	if _kitchen_controller == null or not is_instance_valid(_kitchen_controller):
		return

	var held_view := _kitchen_controller.get_held_item_view()
	var held_has := not held_view.is_empty()
	var held_plated: bool = held_has and held_view.get("plate_id", &"") != &""
	var held_textures := _resolve_item_textures(held_view)
	var held_dish_icon := _resolve_dish_icon_for_item_view(held_view)
	var player_visual := _world_map.player as PlayerVisual
	if player_visual != null:
		player_visual.sync_held_item_visual(held_has, held_plated, held_textures, held_dish_icon)

	var table_view := _kitchen_controller.get_work_table_view(&"work_table")
	var table_has := not table_view.is_empty()
	var table_plated: bool = table_has and table_view.get("plate_id", &"") != &""
	var table_textures := _resolve_item_textures(table_view)
	var table_dish_icon := _resolve_dish_icon_for_item_view(table_view)

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
		cooker_portions,
		table_dish_icon
	)
	if (
		_world_map.has_method(&"sync_counter_slot_visuals")
		and _world_map.has_method(&"get_long_counter_slot_ids")
	):
		var slot_views: Dictionary = {}
		for slot_id in _world_map.get_long_counter_slot_ids():
			var s_view := _kitchen_controller.get_work_table_view(slot_id)
			if not s_view.is_empty():
				slot_views[slot_id] = {
					"is_plated": s_view.get("plate_id", &"") != &"",
					"textures": _resolve_item_textures(s_view),
					"dish_icon": _resolve_dish_icon_for_item_view(s_view),
				}
		_world_map.sync_counter_slot_visuals(slot_views)
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
	var recipe_icons: Dictionary = {}
	for view: Dictionary in driver_views:
		var recipe_id := StringName(view.get("recipe_id", &""))
		if recipe_id == &"" or recipe_names.has(recipe_id):
			continue
		recipe_names[recipe_id] = _get_recipe_display_name(recipe_id)
		var icon := _get_recipe_icon(recipe_id)
		if icon != null:
			recipe_icons[recipe_id] = icon
	_world_map.sync_driver_visuals(driver_views, recipe_names, recipe_icons)


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
	var dish_icon := _get_recipe_icon(preview_id) if preview_id != &"" else null
	_world_map.sync_online_station_visual(
		preview_id,
		enabled,
		recipe_label,
		part_textures,
		dish_icon
	)


func _get_recipe_display_name(recipe_id: StringName) -> String:
	if recipe_id == &"":
		return ""
	if _kitchen_controller != null and is_instance_valid(_kitchen_controller):
		var def := _kitchen_controller.get_recipe_def(recipe_id)
		if def != null and not def.display_name.is_empty():
			return def.display_name
	return String(recipe_id)


func _get_recipe_icon(recipe_id: StringName) -> Texture2D:
	if recipe_id == &"" or _kitchen_controller == null or not is_instance_valid(_kitchen_controller):
		return null
	var def := _kitchen_controller.get_recipe_def(recipe_id)
	return def.icon if def != null else null


func _resolve_dish_icon_for_item_view(item_view: Dictionary) -> Texture2D:
	if item_view.is_empty():
		return null
	var matched_id := StringName(item_view.get("matched_recipe_id", &""))
	if matched_id == &"":
		return null
	return _get_recipe_icon(matched_id)


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
	var recipe_icons: Dictionary = {}
	if _kitchen_controller != null and is_instance_valid(_kitchen_controller):
		for view: Dictionary in customer_views:
			var recipe_id := StringName(view.get("recipe_id", &""))
			if recipe_id == &"" or recipe_names.has(recipe_id):
				continue
			var def := _kitchen_controller.get_recipe_def(recipe_id)
			if def != null and not def.display_name.is_empty():
				recipe_names[recipe_id] = def.display_name
			if def != null and def.icon != null:
				recipe_icons[recipe_id] = def.icon

	_world_map.sync_dine_in_visuals(customer_views, table_views, recipe_names, recipe_icons)


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
	_refresh_main_menu_visibility()
	if (
		_game_root != null
		and is_instance_valid(_game_root)
		and _game_root.has_method(&"is_in_main_menu")
		and bool(_game_root.is_in_main_menu())
	):
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
	var completed_dine_in: int = 0
	var initial_dine_in: int = planned_quota
	if _service_controller != null and is_instance_valid(_service_controller):
		var queue_view: Dictionary = _service_controller.get_customer_queue_view()
		unspawned_quota = int(queue_view.get("day_queue_remaining", 0))
		completed_dine_in = int(queue_view.get("completed_dine_in_count", 0))
		var q_init := int(queue_view.get("day_queue_initial", 0))
		if q_init > 0 or phase != SharedTypes.Phase.PLANNING:
			initial_dine_in = q_init

	var elapsed: float = 0.0
	if _game_root != null and is_instance_valid(_game_root):
		if _game_root.has_method(&"get_service_elapsed"):
			elapsed = float(_game_root.get_service_elapsed())

	var vp_size := _get_viewport_logical_size()
	var hud_w := clampf(ui_safe_rect.size.x, 0.0, maxf(0.0, vp_size.x - 200.0))
	if menu_game_backdrop != null:
		menu_game_backdrop.position = Vector2.ZERO
		menu_game_backdrop.size = Vector2(roundf(vp_size.y * 511.0 / 1080.0), vp_size.y)
	_sync_left_hud_rect(vp_size, hud_w)
	_layout_fixture_shop_overlay()

	day_label.text = "Hari %d/7" % day_index if day_index <= 7 else "Hari %d" % day_index
	if day_value_label != null:
		day_value_label.text = "%d/7" % day_index if day_index <= 7 else "%d" % day_index
	var is_planning := (phase == SharedTypes.Phase.PLANNING)
	var is_serving := (phase == SharedTypes.Phase.SERVING)
	phase_label.text = (
		"persiapan sebelum buka"
		if is_planning
		else PHASE_LABELS.get(phase, "Perencanaan")
	)
	cash_label.text = "Kas: %s" % format_rupiah(cash)

	if target_guest_value_label != null and target_guest_sub_label != null:
		if is_planning:
			target_guest_value_label.text = "%d" % planned_quota
			target_guest_sub_label.text = "dari %d" % maxi(planned_quota, potential_demand)
		else:
			target_guest_value_label.text = "%d" % completed_dine_in
			target_guest_sub_label.text = "dari %d" % maxi(completed_dine_in, initial_dine_in)

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
		var has_free_slot := _find_first_available_placement_slot() != &""
		fixture_shop_button.visible = is_planning
		fixture_shop_button.disabled = (not is_planning) or (not has_free_slot)
		if (not is_planning or not has_free_slot) and fixture_shop_button.has_focus():
			fixture_shop_button.release_focus()
	if employee_button != null:
		employee_button.visible = is_planning
		employee_button.disabled = not is_planning
		var emp_cnt := 0
		if _run_controller != null and is_instance_valid(_run_controller):
			emp_cnt = _run_controller.get_hired_employees().size()
		employee_button.text = "Pegawai (%d)" % emp_cnt if emp_cnt > 0 else "Pegawai"
		if not is_planning and employee_button.has_focus():
			employee_button.release_focus()
	if menu_stub_button != null:
		menu_stub_button.disabled = (not is_planning and not is_serving)
		if (not is_planning and not is_serving) and menu_stub_button.has_focus():
			menu_stub_button.release_focus()
	if exit_stub_button != null:
		exit_stub_button.disabled = not is_planning
		if not is_planning and exit_stub_button.has_focus():
			exit_stub_button.release_focus()
	if potential_demand_label != null:
		potential_demand_label.text = "Potensi Tamu: %d" % potential_demand
		potential_demand_label.visible = false
	forecast_quota_label.text = "Target Tamu: %d" % planned_quota
	forecast_quota_label.visible = false
	if start_hint_label != null:
		start_hint_label.text = "Ketik: buka"

	service_box.visible = (
		is_serving
		or phase == SharedTypes.Phase.CLOSING
	)
	service_elapsed_label.text = "Waktu: %.1f dtk" % elapsed
	unspawned_quota_label.text = "Antrean Datang: %d" % unspawned_quota
	if hud_typing_panel != null:
		var sel_id := (
			_kitchen_controller.get_selected_target_id()
			if _kitchen_controller != null and is_instance_valid(_kitchen_controller)
			else &""
		)
		var cur_prefix := (
			_kitchen_controller.get_command_prefix()
			if _kitchen_controller != null and is_instance_valid(_kitchen_controller)
			else ""
		)
		var cur_allowed := (
			_kitchen_controller.get_allowed_commands_for_selected_target()
			if _kitchen_controller != null and is_instance_valid(_kitchen_controller)
			else ([] as Array[String])
		)
		_sync_hud_typing_mirror(phase, sel_id, cur_prefix, cur_allowed)
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
		_sync_hud_typing_mirror(phase, &"", "", [] as Array[String])
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
		_sync_hud_typing_mirror(phase, selected_id, prefix, allowed)
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

	_sync_hud_typing_mirror(phase, selected_id, prefix, allowed)
	_update_dialogue_position()
	_refresh_visual_guidance()


func _sync_hud_typing_mirror(
	phase: int,
	selected_id: StringName,
	prefix: String,
	allowed: Array[String]
) -> void:
	var active_phase := (
		phase == SharedTypes.Phase.PLANNING
		or phase == SharedTypes.Phase.SERVING
	)
	if hud_typing_section != null:
		hud_typing_section.visible = active_phase
	if hud_typing_panel != null:
		hud_typing_panel.visible = active_phase
	var is_idle_planning := (
		phase == SharedTypes.Phase.PLANNING
		and selected_id == &""
		and prefix.is_empty()
	)
	if start_hint_label != null:
		start_hint_label.visible = is_idle_planning
		start_hint_label.text = "Ketik: buka"
	if hud_typing_label == null:
		return
	hud_typing_label.visible = not is_idle_planning
	if not prefix.is_empty():
		hud_typing_label.text = "[%s]" % prefix.to_lower()
	elif not allowed.is_empty():
		hud_typing_label.text = ", ".join(allowed)
	elif phase == SharedTypes.Phase.PLANNING and selected_id == &"":
		hud_typing_label.text = "buka"
	else:
		hud_typing_label.text = "Pilih objek"


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
		if retry_button != null:
			retry_button.visible = false
			retry_button.disabled = true
		if result_menu_button != null:
			result_menu_button.visible = false
			result_menu_button.disabled = true
		if continue_button.has_focus():
			continue_button.release_focus()
		if extra_mode_button.has_focus():
			extra_mode_button.release_focus()
		return

	var day_index: int = _get_current_day_index()
	var settlement: Dictionary = {}
	var goal_outcome: int = SharedTypes.DayOutcome.UNDECIDED
	var day7_target: int = 700000
	if _run_controller != null and is_instance_valid(_run_controller):
		settlement = _run_controller.get_day_settlement_view(day_index)
		var run_view := _run_controller.get_run_view()
		goal_outcome = int(
			settlement.get("day7_outcome", run_view.get("goal_outcome", goal_outcome))
		)
		day7_target = int(run_view.get("day_7_target", 700000))

	var end_cash := int(settlement.get("end_cash", 0))
	var begin_cash := int(settlement.get("begin_cash", 0))
	var ing_buy := int(settlement.get("ingredient_purchase_total", 0))
	var fix_buy := int(settlement.get("fixture_purchase_total", 0))
	var fix_sale := int(settlement.get("fixture_sale_total", 0))
	var rev_dine := int(settlement.get("order_revenue_dinein", 0))
	var rev_online := int(settlement.get("order_revenue_online", 0))
	var refund := int(settlement.get("refund_total", 0))
	var elec := int(settlement.get("electricity_charge", 0))
	var emp_hire := int(settlement.get("employee_hire_total", 0))
	var emp_salary := int(settlement.get("employee_salary_total", 0))
	var comp_dine := int(settlement.get("completed_dinein_count", 0))
	var comp_on := int(settlement.get("completed_online_count", 0))
	var fail_dine := int(settlement.get("failed_dinein_count", 0))
	var fail_on := int(settlement.get("failed_online_count", 0))
	var debt_before := int(settlement.get("penalty_debt_before", 0))
	var debt_after := int(settlement.get("penalty_debt_after", 0))
	var next_forecast := int(settlement.get("forecast_next_day", 0))

	var lines: PackedStringArray = []
	if phase == SharedTypes.Phase.FINISHED and day_index == 7:
		if goal_outcome == SharedTypes.DayOutcome.WON:
			result_title_label.text = "Target tercapai!"
			KetikUiArt.style_heading_label(result_title_label, 15, Color(0.86, 1.0, 0.72, 1.0))
			lines.append("Hari 7 selesai")
			lines.append("Kas akhir: %s (Setelah listrik)" % format_rupiah(end_cash))
			lines.append("Target: %s" % format_rupiah(day7_target))
			var surplus := end_cash - day7_target
			if surplus == 0:
				lines.append("Pas target")
			else:
				var surplus_str := format_rupiah(surplus)
				lines.append("Target tercapai" if surplus_str == "Rp 0" else "Lebih %s" % surplus_str)
			lines.append("Warungmu berhasil! Mau lanjut jualan?")
		else:
			result_title_label.text = "Belum tercapai"
			KetikUiArt.style_heading_label(result_title_label, 15, Color(1.0, 0.72, 0.68, 1.0))
			lines.append("Hari 7 selesai")
			lines.append("Kas akhir: %s (Setelah listrik)" % format_rupiah(end_cash))
			lines.append("Target: %s" % format_rupiah(day7_target))
			var shortfall := day7_target - end_cash
			var short_str := format_rupiah(shortfall)
			lines.append("Masih kurang" if short_str == "Rp 0" else "Kurang %s" % short_str)
			lines.append("Target belum tercapai. Coba strategi baru, yuk!")
		lines.append("")
		lines.append("Selesai (Makan/Online): %d / %d" % [comp_dine, comp_on])
		lines.append("Terlewat (Makan/Online): %d / %d" % [fail_dine, fail_on])
	else:
		result_title_label.text = "Hari %d selesai" % day_index
		KetikUiArt.style_heading_label(result_title_label, 15, KetikUiArt.COLOR_CREAM)
		lines.append("Kas akhir: %s" % format_rupiah(end_cash))
		lines.append("Kas awal: %s" % format_rupiah(begin_cash))
		lines.append("Pendapatan: +%s (%s + %s)" % [
			format_rupiah(rev_dine + rev_online),
			format_rupiah(rev_dine),
			format_rupiah(rev_online),
		])
		lines.append("Belanja bahan: -%s" % format_rupiah(ing_buy))
		if fix_buy > 0:
			lines.append("Beli alat: -%s" % format_rupiah(fix_buy))
		if fix_sale > 0:
			lines.append("Jual alat: +%s" % format_rupiah(fix_sale))
		if emp_hire > 0:
			lines.append("Biaya Rekrutmen Pegawai: -%s" % format_rupiah(emp_hire))
		if refund > 0:
			lines.append("Refund: +%s" % format_rupiah(refund))
		lines.append("Listrik: -%s" % format_rupiah(elec))
		if emp_salary > 0:
			lines.append("Gaji Harian Pegawai: -%s" % format_rupiah(emp_salary))
		lines.append("Pesanan selesai: %d (Makan %d / Online %d)" % [comp_dine + comp_on, comp_dine, comp_on])
		lines.append("Terlewat: %d (Makan %d / Online %d)" % [fail_dine + fail_on, fail_dine, fail_on])
		lines.append("Perkiraan besok: %d tamu" % next_forecast)
		if debt_before != 0 or debt_after != 0:
			lines.append("Pengurang tamu: %d jadi %d" % [debt_before, debt_after])

	settlement_summary_label.text = "\n".join(lines)
	KetikUiArt.style_wood_body_label(settlement_summary_label, 11)
	if result_narrative_label != null:
		var caption := (
			NarrativeTutorialCatalog.get_day_closing_caption(day_index, goal_outcome)
			if _onboarding_enabled
			else ""
		)
		result_narrative_label.text = caption
		result_narrative_label.visible = not caption.is_empty()
		KetikUiArt.style_wood_body_label(result_narrative_label, 10, KetikUiArt.COLOR_WOOD_MID)

	var can_continue := (phase == SharedTypes.Phase.RESULTS and day_index != 7)
	var is_day7_fin := (phase == SharedTypes.Phase.FINISHED and day_index == 7)
	var can_extra := is_day7_fin and goal_outcome == SharedTypes.DayOutcome.WON
	var can_retry := is_day7_fin and goal_outcome != SharedTypes.DayOutcome.WON
	continue_button.visible = can_continue
	continue_button.disabled = not can_continue
	if not can_continue and continue_button.has_focus():
		continue_button.release_focus()

	extra_mode_button.visible = can_extra
	extra_mode_button.disabled = not can_extra
	if not can_extra and extra_mode_button.has_focus():
		extra_mode_button.release_focus()

	if retry_button != null:
		retry_button.visible = can_retry
		retry_button.disabled = not can_retry
	if result_menu_button != null:
		result_menu_button.visible = is_day7_fin
		result_menu_button.disabled = not is_day7_fin


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
	if ui_root != null:
		ui_root.theme = KetikUiArt.build_ui_theme()

	if main_menu_bg != null:
		main_menu_bg.texture = KetikUiArt.load_tex(KetikUiArt.BG_MAIN_MENU_PATH)
	if main_menu_logo != null:
		main_menu_logo.texture = KetikUiArt.load_tex(KetikUiArt.LOGO_MAIN_MENU_PATH)
	if main_menu_cloud_tl != null:
		main_menu_cloud_tl.texture = KetikUiArt.load_tex(KetikUiArt.DECOR_CLOUD_1_PATH)
	if main_menu_cloud_br != null:
		main_menu_cloud_br.texture = KetikUiArt.load_tex(KetikUiArt.DECOR_CLOUD_2_PATH)
	if main_menu_play_button != null:
		KetikUiArt.apply_button_skin(main_menu_play_button, false, 10, 6)
		KetikUiArt.attach_button_caption(main_menu_play_button, KetikUiArt.CAP_PLAY_PATH, 14, 6)
	if main_menu_settings_button != null:
		KetikUiArt.apply_button_skin(main_menu_settings_button, false, 10, 6)
		KetikUiArt.attach_button_caption(
			main_menu_settings_button,
			KetikUiArt.CAP_SETTINGS_PATH,
			10,
			8
		)
	if main_menu_quit_button != null:
		KetikUiArt.apply_button_skin(main_menu_quit_button, false, 10, 6)
		KetikUiArt.attach_button_caption(main_menu_quit_button, KetikUiArt.CAP_QUIT_PATH, 14, 7)

	if settings_popup != null:
		KetikUiArt.apply_wood_board(settings_popup, false, 14, 12)
		var st_title := settings_popup.get_node_or_null("SettingsColumn/SettingsTitleLabel") as Label
		KetikUiArt.style_heading_label(st_title, 16)
		if settings_body != null:
			for sec_name in ["AudioSectionLabel", "DisplaySectionLabel", "OtherSectionLabel"]:
				var sec_lbl := settings_body.get_node_or_null(sec_name) as Label
				KetikUiArt.style_wood_body_label(sec_lbl, 11, KetikUiArt.COLOR_WOOD_MID)
			for row_pair in [
				["MasterVolumeRow/MasterLabel", master_value_label],
				["BgmVolumeRow/BgmLabel", bgm_value_label],
				["SfxVolumeRow/SfxLabel", sfx_value_label],
				["DisplayModeRow/DisplayModeLabel", null],
				["ResolutionRow/ResolutionLabel", null],
				["VsyncRow/VsyncLabel", null],
			]:
				var row_lbl := settings_body.get_node_or_null(String(row_pair[0])) as Label
				KetikUiArt.style_wood_body_label(row_lbl, 11)
				if row_pair[1] != null:
					KetikUiArt.style_wood_body_label(row_pair[1] as Label, 11)
		for slider in [master_volume_slider, bgm_volume_slider, sfx_volume_slider]:
			KetikUiArt.apply_slider_skin(slider)
		for btn in [
			display_mode_button,
			vsync_toggle_button,
			settings_reset_button,
			settings_replay_tutorial_button,
		]:
			if btn != null:
				KetikUiArt.apply_button_skin(btn, false, 8, 3)
				btn.add_theme_font_size_override("font_size", 11)
		if settings_tutorial_status_label != null:
			KetikUiArt.style_wood_body_label(
				settings_tutorial_status_label, 10, KetikUiArt.COLOR_WOOD_MID
			)
		if resolution_option_button != null:
			KetikUiArt.apply_option_button_skin(resolution_option_button, 8, 3)
			resolution_option_button.add_theme_font_size_override("font_size", 11)
		if display_status_label != null:
			KetikUiArt.style_wood_body_label(display_status_label, 10, KetikUiArt.COLOR_WOOD_MID)
		if settings_feedback_label != null:
			KetikUiArt.style_wood_body_label(settings_feedback_label, 10, KetikUiArt.COLOR_SUCCESS)
	if settings_close_button != null:
		KetikUiArt.apply_button_skin(settings_close_button, false, 10, 4)

	if exit_confirm_popup != null:
		KetikUiArt.apply_wood_board(exit_confirm_popup, false, 14, 12)
		KetikUiArt.style_heading_label(exit_confirm_title_label, 16)
		KetikUiArt.style_wood_body_label(exit_confirm_message_label, 12)
	if exit_confirm_cancel_button != null:
		KetikUiArt.apply_button_skin(exit_confirm_cancel_button, false, 10, 4)
	if exit_confirm_quit_button != null:
		KetikUiArt.apply_button_skin(
			exit_confirm_quit_button, false, 10, 4, Color(1.0, 0.78, 0.74, 1.0)
		)

	if menu_game_backdrop != null:
		menu_game_backdrop.texture = KetikUiArt.load_tex(KetikUiArt.UI_HUD_STRIP_PATH)
		menu_game_backdrop.visible = true
	if left_hud_region != null:
		var trans := StyleBoxEmpty.new()
		trans.content_margin_left = 8.0
		trans.content_margin_right = 8.0
		trans.content_margin_top = 6.0
		trans.content_margin_bottom = 6.0
		left_hud_region.add_theme_stylebox_override("panel", trans)
	if day_card != null:
		var cal_sb := KetikUiArt.make_tex_box(
			KetikUiArt.UI_PAPER_CALENDAR_PATH, 16, 10, 14, 14, 8, 4
		)
		cal_sb.content_margin_top = 3.0
		cal_sb.content_margin_bottom = 8.0
		day_card.add_theme_stylebox_override("panel", cal_sb)
	if hari_ke_banner != null:
		hari_ke_banner.texture = KetikUiArt.load_tex(KetikUiArt.HDR_HARI_KE_PATH)
	if day_value_label != null:
		KetikUiArt.style_wood_body_label(day_value_label, 14)
	if day_label != null:
		KetikUiArt.style_wood_body_label(day_label, 12)
	if phase_label != null:
		KetikUiArt.style_heading_label(phase_label, 9, Color(0.92, 0.86, 0.72, 0.94))
		phase_label.add_theme_constant_override("outline_size", 2)
		phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if cash_panel != null:
		cash_panel.add_theme_stylebox_override(
			"panel",
			KetikUiArt.make_tex_box(KetikUiArt.UI_PANEL_COIN_PATH, 8, 6, 8, 6, 6, 3)
		)
	if cash_coin_icon != null:
		cash_coin_icon.texture = KetikUiArt.load_tex(KetikUiArt.ICON_COINS_PATH)
	if cash_label != null:
		KetikUiArt.style_heading_label(cash_label, 12, Color(1.0, 0.90, 0.42, 1.0))
		cash_label.add_theme_constant_override("outline_size", 3)
		cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if target_tamu_banner != null:
		target_tamu_banner.texture = KetikUiArt.load_tex(KetikUiArt.HDR_TARGET_TAMU_PATH)
	if target_guest_panel != null:
		target_guest_panel.add_theme_stylebox_override(
			"panel",
			KetikUiArt.make_tex_box(KetikUiArt.UI_BOARD_CUSTOMER_PATH, 10, 8, 10, 8, 8, 4)
		)
	if target_guest_value_label != null:
		KetikUiArt.style_wood_body_label(
			target_guest_value_label,
			15,
			Color(0.68, 0.14, 0.08, 1.0)
		)
	if target_guest_sub_label != null:
		KetikUiArt.style_wood_body_label(target_guest_sub_label, 10)
	if goal_target_label != null:
		KetikUiArt.style_heading_label(goal_target_label, 10)
		goal_target_label.add_theme_constant_override("outline_size", 2)
	if goal_label != null:
		KetikUiArt.style_heading_label(goal_label, 9, Color(0.92, 0.86, 0.72, 0.95))
		goal_label.add_theme_constant_override("outline_size", 2)
	if potential_demand_label != null:
		KetikUiArt.style_heading_label(potential_demand_label, 10)
		potential_demand_label.visible = false
	if forecast_quota_label != null:
		forecast_quota_label.visible = false
	if service_elapsed_label != null:
		KetikUiArt.style_heading_label(service_elapsed_label, 11)
		service_elapsed_label.add_theme_constant_override("outline_size", 3)
	if unspawned_quota_label != null:
		KetikUiArt.style_heading_label(unspawned_quota_label, 11)
		unspawned_quota_label.add_theme_constant_override("outline_size", 3)
	if ketik_banner != null:
		ketik_banner.texture = KetikUiArt.load_tex(KetikUiArt.HDR_KETIK_PATH)
	if hud_typing_panel != null:
		hud_typing_panel.add_theme_stylebox_override(
			"panel",
			KetikUiArt.make_tex_box(KetikUiArt.UI_TEXTBOX_PATH, 10, 8, 10, 8, 8, 5)
		)
	if start_hint_label != null:
		KetikUiArt.style_heading_label(start_hint_label, 11, KetikUiArt.COLOR_CREAM)
		start_hint_label.add_theme_constant_override("outline_size", 3)
		start_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if hud_typing_label != null:
		KetikUiArt.style_heading_label(hud_typing_label, 11, KetikUiArt.COLOR_CREAM)
		hud_typing_label.add_theme_constant_override("outline_size", 3)
	if edit_menu_button != null:
		KetikUiArt.apply_button_skin(edit_menu_button, false, 8, 3)
		KetikUiArt.attach_button_caption(edit_menu_button, KetikUiArt.CAP_EDIT_MENU_PATH, 12, 4)
	if fixture_shop_button != null:
		KetikUiArt.apply_button_skin(fixture_shop_button, false, 8, 3)
		KetikUiArt.attach_button_caption(fixture_shop_button, KetikUiArt.CAP_BELI_ALAT_PATH, 12, 4)
	if employee_button != null:
		KetikUiArt.apply_button_skin(employee_button, false, 8, 3)
	if menu_stub_button != null:
		KetikUiArt.apply_button_skin(
			menu_stub_button,
			true,
			3,
			3,
			Color(0.92, 0.88, 0.84, 1.0)
		)
		menu_stub_button.tooltip_text = "Cara Main"
		KetikUiArt.attach_button_caption(menu_stub_button, KetikUiArt.ICON_MENU_PATH, 6, 5)
	if exit_stub_button != null:
		KetikUiArt.apply_button_skin(
			exit_stub_button,
			true,
			3,
			3,
			Color(0.92, 0.88, 0.84, 1.0)
		)
		exit_stub_button.tooltip_text = "Keluar Game"
		KetikUiArt.attach_button_caption(exit_stub_button, KetikUiArt.ICON_QUIT_PATH, 6, 5)
	if pause_button != null:
		KetikUiArt.apply_button_skin(
			pause_button,
			false,
			8,
			2,
			Color(0.86, 0.81, 0.78, 1.0)
		)
		pause_button.add_theme_font_size_override("font_size", 11)

	if interaction_dialogue != null:
		interaction_dialogue.add_theme_stylebox_override(
			"panel",
			_make_panel_style(Color(0.24, 0.14, 0.08, 0.96), Color(0.76, 0.56, 0.34, 1.0), 6)
		)
	if hover_tooltip_panel != null:
		hover_tooltip_panel.add_theme_stylebox_override(
			"panel",
			KetikUiArt.make_tex_box(KetikUiArt.UI_PANEL_COIN_PATH, 6, 4, 6, 4, 8, 4)
		)
	if hover_tooltip_label != null:
		KetikUiArt.style_heading_label(hover_tooltip_label, 11)

	if edit_menu_popup != null:
		KetikUiArt.apply_wood_board(edit_menu_popup, false, 14, 8, 6, 6, true)
		var em_title := edit_menu_popup.get_node_or_null("PopupColumn/PopupTitleLabel") as Label
		_attach_header_art_banner(em_title, KetikUiArt.HDR_EDIT_MENU_PATH, 24.0)
		var em_hint := edit_menu_popup.get_node_or_null("PopupColumn/PopupHintLabel") as Label
		KetikUiArt.style_wood_body_label(em_hint, 10)
		KetikUiArt.style_wood_body_label(edit_menu_forecast_label, 11, KetikUiArt.COLOR_WOOD_MID)
	if edit_menu_cancel_button != null:
		KetikUiArt.apply_button_skin(edit_menu_cancel_button, false, 8, 3)
		KetikUiArt.attach_button_caption(edit_menu_cancel_button, KetikUiArt.CAP_BATAL_PATH, 12, 4)
	if edit_menu_confirm_button != null:
		KetikUiArt.apply_button_skin(edit_menu_confirm_button, false, 8, 3)
		KetikUiArt.attach_button_caption(edit_menu_confirm_button, KetikUiArt.CAP_SIMPAN_PATH, 12, 3)

	if recipe_detail_panel != null:
		KetikUiArt.apply_wood_board(recipe_detail_panel, false, 12, 8, 6, 6, true)
		KetikUiArt.style_wood_body_label(recipe_detail_title_label, 14)
		var detail_col := recipe_detail_panel.get_node_or_null("DetailColumn") as VBoxContainer
		if detail_col != null and detail_col.get_node_or_null("ResepHeaderBanner") == null:
			var resep_tex := KetikUiArt.load_tex(KetikUiArt.HDR_RESEP_PATH)
			if resep_tex != null:
				var r_ban := TextureRect.new()
				r_ban.name = "ResepHeaderBanner"
				r_ban.texture = resep_tex
				r_ban.custom_minimum_size = Vector2(0, 22)
				r_ban.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				r_ban.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				r_ban.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				r_ban.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				r_ban.mouse_filter = Control.MOUSE_FILTER_IGNORE
				detail_col.add_child(r_ban)
				detail_col.move_child(r_ban, 0)

	if ingredient_shop_popup != null:
		KetikUiArt.apply_wood_board(ingredient_shop_popup, false, 14, 12)
		var sh_title := ingredient_shop_popup.get_node_or_null(
			"ShopColumn/ShopHeaderRow/ShopTitleLabel"
		) as Label
		_attach_header_art_banner(sh_title, KetikUiArt.HDR_BELANJA_BAHAN_PATH, 24.0)
		KetikUiArt.style_wood_body_label(shop_target_label, 11, KetikUiArt.COLOR_WOOD_MID)
		KetikUiArt.style_wood_body_label(shop_total_label, 12)
		KetikUiArt.style_wood_body_label(shop_pending_label, 10, KetikUiArt.COLOR_WOOD_MID)
	if shop_cancel_button != null:
		KetikUiArt.apply_button_skin(shop_cancel_button, false, 10, 4)
		KetikUiArt.attach_button_caption(shop_cancel_button, KetikUiArt.CAP_BATAL_PATH, 10, 4)
	if shop_checkout_button != null:
		KetikUiArt.apply_button_skin(shop_checkout_button, false, 10, 4)
		KetikUiArt.attach_button_caption(shop_checkout_button, KetikUiArt.CAP_BELI_PATH, 12, 4)
	if shop_retrieve_button != null:
		KetikUiArt.apply_button_skin(shop_retrieve_button, false, 8, 4)

	if fixture_shop_popup != null:
		KetikUiArt.apply_wood_board(fixture_shop_popup, false, 14, 12)
		var fx_title := fixture_shop_popup.get_node_or_null(
			"FixtureColumn/FixtureHeaderRow/FixtureTitleLabel"
		) as Label
		_attach_header_art_banner(fx_title, KetikUiArt.HDR_BELANJA_ALAT_PATH, 24.0)
		KetikUiArt.style_wood_body_label(fixture_selection_label, 12)
		_ensure_fixture_electricity_badge()
	if fixture_cancel_button != null:
		KetikUiArt.apply_button_skin(fixture_cancel_button, false, 10, 4)
		KetikUiArt.attach_button_caption(fixture_cancel_button, KetikUiArt.CAP_BATAL_PATH, 10, 4)
	if fixture_confirm_button != null:
		KetikUiArt.apply_button_skin(fixture_confirm_button, false, 10, 4)
		KetikUiArt.attach_button_caption(fixture_confirm_button, KetikUiArt.CAP_BELI_PATH, 12, 4)
	if employee_popup != null:
		KetikUiArt.apply_wood_board(employee_popup, false, 14, 10, 6, 8, true)
		var emp_title := employee_popup.get_node_or_null(
			"EmployeeColumn/EmployeeHeaderRow/EmployeeTitleLabel"
		) as Label
		if emp_title != null:
			KetikUiArt.style_heading_label(emp_title, 16)
		KetikUiArt.style_wood_body_label(employee_cash_label, 11)
		KetikUiArt.style_wood_body_label(employee_salary_label, 11, KetikUiArt.COLOR_WOOD_MID)
		KetikUiArt.style_wood_body_label(employee_crowding_label, 10, KetikUiArt.COLOR_WOOD_MID)
		var emp_role_hdr := employee_popup.get_node_or_null(
			"EmployeeColumn/EmployeeScroll/EmployeeContentBox/RoleSectionLabel"
		) as Label
		KetikUiArt.style_wood_body_label(emp_role_hdr, 12, Color(0.43, 0.13, 0.04, 1.0))
		KetikUiArt.style_wood_body_label(
			employee_roster_section_label, 12, Color(0.43, 0.13, 0.04, 1.0)
		)
		KetikUiArt.style_wood_body_label(employee_summary_label, 11)
	if employee_close_button != null:
		KetikUiArt.apply_button_skin(employee_close_button, false, 10, 4)

	if day_result_side_panel != null:
		KetikUiArt.apply_wood_board(day_result_side_panel, true, 12, 12)
	for btn: Button in [continue_button, extra_mode_button, retry_button, result_menu_button]:
		if btn != null:
			KetikUiArt.apply_button_skin(btn, false, 10, 4)

	if pause_popup != null:
		KetikUiArt.apply_wood_board(pause_popup, false, 14, 12)
		var p_title := pause_popup.get_node_or_null("PauseColumn/PauseTitleLabel") as Label
		var p_status := pause_popup.get_node_or_null("PauseColumn/PauseStatusLabel") as Label
		KetikUiArt.style_heading_label(p_title, 16)
		KetikUiArt.style_wood_body_label(p_status, 11)
	for pbtn: Button in [
		pause_resume_button,
		pause_settings_button,
		pause_reference_button,
		pause_main_menu_button,
		pause_exit_button,
	]:
		if pbtn != null:
			KetikUiArt.apply_button_skin(pbtn, false, 10, 4)

	if reference_popup != null:
		KetikUiArt.apply_wood_board(reference_popup, false, 16, 8, 6, 6, true)
		var ref_title := reference_popup.get_node_or_null("RefColumn/RefTitleLabel") as Label
		KetikUiArt.style_heading_label(ref_title, 16)
	if reference_body_richtext != null:
		reference_body_richtext.add_theme_font_size_override("normal_font_size", 11)
		reference_body_richtext.add_theme_color_override("default_color", KetikUiArt.COLOR_WOOD_DARK)
	if reference_restart_button != null:
		KetikUiArt.apply_button_skin(reference_restart_button, false, 10, 3)
	if reference_close_button != null:
		KetikUiArt.apply_button_skin(reference_close_button, false, 12, 3)

	if tutorial_banner != null:
		KetikUiArt.apply_wood_board(tutorial_banner, false, 10, 8)
		KetikUiArt.style_heading_label(tutorial_title_label, 12)
		KetikUiArt.style_wood_body_label(tutorial_body_label, 10)
		KetikUiArt.apply_button_skin(tutorial_skip_button, false, 6, 2)
		KetikUiArt.apply_button_skin(tutorial_next_button, false, 6, 2)
	if feature_tip_panel != null:
		KetikUiArt.apply_wood_board(feature_tip_panel, false, 10, 8)
		KetikUiArt.style_heading_label(tip_title_label, 11)
		KetikUiArt.style_wood_body_label(tip_body_label, 10)
		KetikUiArt.apply_button_skin(tip_dismiss_button, false, 6, 2)

	if story_popup != null:
		KetikUiArt.apply_wood_board(story_popup, false, 16, 8, 6, 6, true)
	if story_portrait_frame != null:
		story_portrait_frame.add_theme_stylebox_override(
			"panel",
			KetikUiArt.make_tex_box(KetikUiArt.UI_BUTTON_SQ_PATH, 4, 4, 4, 4, 3, 3)
		)
	if story_title_label != null:
		KetikUiArt.style_heading_label(story_title_label, 15)
		story_title_label.add_theme_constant_override("outline_size", 3)
	if story_speaker_label != null:
		KetikUiArt.style_wood_body_label(story_speaker_label, 12, Color(0.46, 0.14, 0.04, 1.0))
	if story_body_label != null:
		KetikUiArt.style_wood_body_label(story_body_label, 13, KetikUiArt.COLOR_WOOD_DARK)
		story_body_label.add_theme_constant_override("line_spacing", 2)
	if story_progress_label != null:
		KetikUiArt.style_wood_body_label(story_progress_label, 11, Color(0.36, 0.18, 0.08, 1.0))
	if story_skip_button != null:
		KetikUiArt.apply_button_skin(story_skip_button, false, 10, 3)
		story_skip_button.add_theme_font_size_override("font_size", 12)
	if story_continue_button != null:
		KetikUiArt.apply_button_skin(story_continue_button, false, 10, 3)
		story_continue_button.add_theme_font_size_override("font_size", 12)


func _attach_header_art_banner(lbl: Label, tex_path: String, height_px: float) -> void:
	if lbl == null:
		return
	var tex := KetikUiArt.load_tex(tex_path)
	if tex == null:
		KetikUiArt.style_heading_label(lbl, 14)
		return
	var parent := lbl.get_parent()
	if parent == null:
		return
	lbl.visible = false
	var banner := parent.get_node_or_null("HeaderArtBanner") as TextureRect
	if banner == null:
		banner = TextureRect.new()
		banner.name = "HeaderArtBanner"
		banner.custom_minimum_size = Vector2(0, height_px)
		banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		banner.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(banner)
		parent.move_child(banner, lbl.get_index())
	banner.texture = tex


func _ensure_fixture_electricity_badge() -> void:
	if fixture_shop_popup == null:
		return
	var hdr := fixture_shop_popup.get_node_or_null("FixtureColumn/FixtureHeaderRow") as HBoxContainer
	if hdr == null:
		return
	var badge := hdr.get_node_or_null("ElectricityBadge") as PanelContainer
	if badge == null:
		badge = PanelContainer.new()
		badge.name = "ElectricityBadge"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_stylebox_override(
			"panel",
			KetikUiArt.make_tex_box(KetikUiArt.UI_PANEL_ELECTRIC_PATH, 8, 6, 8, 6, 8, 3)
		)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 4)
		badge.add_child(row)
		var icon := TextureRect.new()
		icon.texture = KetikUiArt.load_tex(KetikUiArt.ICON_ELECTRIC_PATH)
		icon.custom_minimum_size = Vector2(14, 14)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var lbl := Label.new()
		lbl.name = "PowerTotalLabel"
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		KetikUiArt.style_heading_label(lbl, 11)
		lbl.text = "Rp 0/hari"
		row.add_child(lbl)
		hdr.add_child(badge)


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

		var row_card := PanelContainer.new()
		row_card.name = "RecipeRow_%s" % recipe_id
		row_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit_menu_recipe_list.add_child(row_card)

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 4)
		row_card.add_child(row)

		var toggle_btn := CheckBox.new()
		toggle_btn.name = "CheckBox_%s" % recipe_id
		toggle_btn.text = ""
		toggle_btn.custom_minimum_size = Vector2(26, 26)
		toggle_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		toggle_btn.focus_mode = Control.FOCUS_ALL
		toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var empty_cb := StyleBoxEmpty.new()
		for st: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			toggle_btn.add_theme_stylebox_override(st, empty_cb)
		var cb_tex := TextureRect.new()
		cb_tex.name = "CheckArt"
		cb_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cb_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cb_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cb_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cb_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		toggle_btn.add_child(cb_tex)
		var selected := _pending_menu_selection.has(recipe_id)
		toggle_btn.set_pressed_no_signal(selected)
		toggle_btn.toggled.connect(
			func(pressed: bool) -> void:
				_play_ui_click()
				_on_recipe_button_toggled(recipe_id, pressed)
		)
		row.add_child(toggle_btn)

		var dish_tex := _get_recipe_icon(recipe_id)
		var icon_rect := TextureRect.new()
		icon_rect.name = "DishIcon"
		icon_rect.texture = dish_tex
		icon_rect.custom_minimum_size = Vector2(24, 24)
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon_rect)

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
			"row": row_card,
			"toggle_button": toggle_btn,
			"preview_button": preview_btn,
			"check_art": cb_tex,
			"dish_icon": icon_rect,
		}
		_update_recipe_button_visual(toggle_btn, recipe_id, selected)
	_hook_button_click_sfx(edit_menu_recipe_list)


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

	var row_info: Dictionary = _edit_menu_rows.get(recipe_id, {})
	var row_card := row_info.get("row", null) as Control
	var cb_art := row_info.get("check_art", null) as TextureRect
	if cb_art != null and is_instance_valid(cb_art):
		cb_art.texture = KetikUiArt.load_tex(
			KetikUiArt.UI_CHECKBOX_ON_PATH if selected else KetikUiArt.UI_CHECKBOX_OFF_PATH
		)

	var is_previewed := (_previewed_recipe_id == recipe_id)
	if row_card != null and is_instance_valid(row_card):
		KetikUiArt.apply_card_skin(row_card, true, false, is_previewed, 8, 5)
	if preview_btn != null and is_instance_valid(preview_btn):
		var empty_sb := StyleBoxEmpty.new()
		empty_sb.content_margin_left = 4.0
		empty_sb.content_margin_right = 4.0
		for st: String in ["normal", "hover", "pressed", "focus"]:
			preview_btn.add_theme_stylebox_override(st, empty_sb)
		preview_btn.add_theme_color_override(
			"font_color",
			Color(1.0, 0.94, 0.64, 1.0) if is_previewed else KetikUiArt.COLOR_CREAM
		)
		preview_btn.add_theme_color_override("font_outline_color", KetikUiArt.COLOR_OUTLINE_BROWN)
		preview_btn.add_theme_constant_override("outline_size", 3)


func _refresh_recipe_detail_panel() -> void:
	if recipe_detail_title_label == null or recipe_detail_list == null:
		return
	for child in recipe_detail_list.get_children():
		recipe_detail_list.remove_child(child)
		child.free()

	if _previewed_recipe_id == &"":
		recipe_detail_title_label.text = "Resep"
		KetikUiArt.style_wood_body_label(recipe_detail_title_label, 13, KetikUiArt.COLOR_WOOD_MID)
		var hint_lbl := Label.new()
		hint_lbl.name = "DetailEmptyLabel"
		hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		KetikUiArt.style_wood_body_label(hint_lbl, 11, KetikUiArt.COLOR_WOOD_MID)
		hint_lbl.text = "Pilih hidangan untuk lihat bahan."
		recipe_detail_list.add_child(hint_lbl)
		return

	var def: RecipeDef = (
		_kitchen_controller.get_recipe_def(_previewed_recipe_id)
		if _kitchen_controller != null and is_instance_valid(_kitchen_controller)
		else null
	)
	recipe_detail_title_label.text = _get_recipe_display_name(_previewed_recipe_id)
	KetikUiArt.style_wood_body_label(recipe_detail_title_label, 14, KetikUiArt.COLOR_WOOD_DARK)
	if def == null:
		return

	var icon_tex := _get_recipe_icon(_previewed_recipe_id)
	if icon_tex != null:
		var dish_img := TextureRect.new()
		dish_img.name = "DetailDishIcon"
		dish_img.texture = icon_tex
		dish_img.custom_minimum_size = Vector2(36, 36)
		dish_img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		dish_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dish_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dish_img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		dish_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		recipe_detail_list.add_child(dish_img)

	if not def.description.is_empty():
		var desc_lbl := Label.new()
		desc_lbl.name = "RecipeDescriptionLabel"
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_constant_override("line_spacing", 2)
		KetikUiArt.style_wood_body_label(desc_lbl, 11, KetikUiArt.COLOR_WOOD_DARK)
		desc_lbl.text = def.description
		recipe_detail_list.add_child(desc_lbl)

	for i in range(def.required_parts.size()):
		var part := def.required_parts[i]
		if part == null:
			continue
		var line_lbl := Label.new()
		line_lbl.name = "IngredientLine_%d" % i
		line_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		KetikUiArt.style_wood_body_label(line_lbl, 11)
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
	var unlocked_filter: Array[StringName] = []
	if _run_controller != null and is_instance_valid(_run_controller) and _run_controller.has_method(&"get_unlocked_ingredient_ids"):
		unlocked_filter = _run_controller.get_unlocked_ingredient_ids()
	var registered: Array[StringName] = _kitchen_controller.get_ingredient_ids()
	for id in SHOP_INGREDIENT_ORDER:
		if (
			registered.has(id)
			and (unlocked_filter.is_empty() or unlocked_filter.has(id))
			and _get_ingredient_unit_price(id) > 0
		):
			result.append(id)
	for id in registered:
		if (
			not result.has(id)
			and (unlocked_filter.is_empty() or unlocked_filter.has(id))
			and _get_ingredient_unit_price(id) > 0
		):
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
		if (
			_run_controller.has_method(&"is_ingredient_unlocked")
			and not _run_controller.is_ingredient_unlocked(ing_id)
		):
			return "Bahan '%s' belum terbuka." % _get_ingredient_display_name(ing_id)
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
		var card := PanelContainer.new()
		card.name = "ShopRow_%s" % ing_id
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		KetikUiArt.apply_card_skin(card, false, false, false, 10, 6)
		shop_ingredient_list.add_child(card)

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 6)
		card.add_child(row)

		var def := _kitchen_controller.get_ingredient_def(ing_id)
		var raw_tex: Texture2D = (
			def.get_texture_for_state(SharedTypes.PrepState.RAW) if def != null else null
		)
		var icon_rect := TextureRect.new()
		icon_rect.texture = raw_tex
		icon_rect.custom_minimum_size = Vector2(22, 22)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon_rect)

		var title_lbl := Label.new()
		title_lbl.text = "%s: %s" % [
			_get_ingredient_display_name(ing_id),
			format_rupiah(_get_ingredient_unit_price(ing_id)),
		]
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.clip_text = true
		KetikUiArt.style_heading_label(title_lbl, 12)
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(title_lbl)

		var price_label := Label.new()
		price_label.visible = false
		price_label.text = format_rupiah(_get_ingredient_unit_price(ing_id))
		price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(price_label)

		var minus_btn := Button.new()
		minus_btn.name = "Minus_%s" % ing_id
		minus_btn.text = "-"
		minus_btn.custom_minimum_size = Vector2(24, 24)
		minus_btn.add_theme_font_size_override("font_size", 13)
		minus_btn.focus_mode = Control.FOCUS_ALL
		minus_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		KetikUiArt.apply_button_skin(minus_btn, true, 4, 2)
		minus_btn.pressed.connect(func() -> void: adjust_shop_quantity(ing_id, -1))
		row.add_child(minus_btn)

		var qty_label := Label.new()
		qty_label.text = "0"
		qty_label.custom_minimum_size = Vector2(24, 0)
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		KetikUiArt.style_heading_label(qty_label, 12)
		qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(qty_label)

		var plus_btn := Button.new()
		plus_btn.name = "Plus_%s" % ing_id
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(24, 24)
		plus_btn.add_theme_font_size_override("font_size", 13)
		plus_btn.focus_mode = Control.FOCUS_ALL
		plus_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		KetikUiArt.apply_button_skin(plus_btn, true, 4, 2)
		plus_btn.pressed.connect(func() -> void: adjust_shop_quantity(ing_id, 1))
		row.add_child(plus_btn)

		var subtotal_label := Label.new()
		subtotal_label.visible = false
		subtotal_label.text = format_rupiah(0)
		subtotal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(subtotal_label)

		_shop_ingredient_rows[ing_id] = {
			"card": card,
			"title_label": title_lbl,
			"minus_button": minus_btn,
			"plus_button": plus_btn,
			"qty_label": qty_label,
			"subtotal_label": subtotal_label,
			"price_label": price_label,
		}
	_hook_button_click_sfx(shop_ingredient_list)


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
		shop_total_label.text = "Total belanja: %s" % format_rupiah(get_shop_total())


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
		slot_box.custom_minimum_size = Vector2(0, 24)
		slot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_box.add_theme_stylebox_override(
			"panel",
			KetikUiArt.make_tex_box(KetikUiArt.UI_PANEL_COIN_PATH, 8, 8, 8, 8, 8, 4)
		)
		var pill_row := HBoxContainer.new()
		pill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill_row.add_theme_constant_override("separation", 4)
		slot_box.add_child(pill_row)

		if ing_id != &"" and qty > 0 and _kitchen_controller != null:
			var def := _kitchen_controller.get_ingredient_def(ing_id)
			var raw_tex: Texture2D = (
				def.get_texture_for_state(SharedTypes.PrepState.RAW) if def != null else null
			)
			if raw_tex != null:
				var ic := TextureRect.new()
				ic.texture = raw_tex
				ic.custom_minimum_size = Vector2(14, 14)
				ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
				pill_row.add_child(ic)

		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.clip_text = true
		KetikUiArt.style_heading_label(lbl, 10)
		if ing_id == &"" or qty <= 0:
			lbl.text = "Kosong (0/%d)" % cap
		else:
			lbl.text = "%s %d/%d" % [_get_ingredient_display_name(ing_id), qty, cap]
		pill_row.add_child(lbl)
		slot_box.set_meta(&"slot_label_ref", lbl)
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
		select_btn.custom_minimum_size = Vector2(64, 26)
		select_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		select_btn.add_theme_font_size_override("font_size", 11)
		select_btn.text = "+"
		KetikUiArt.apply_button_skin(select_btn, false, 6, 2)
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
	_hook_button_click_sfx(fixture_list)


func _refresh_employee_visuals() -> void:
	if _world_map == null or not is_instance_valid(_world_map):
		return
	if not _world_map.has_method(&"sync_employee_visuals"):
		return
	var employees: Array[Dictionary] = []
	if _run_controller != null and is_instance_valid(_run_controller):
		employees = _run_controller.get_hired_employees()
	var worker_views: Array[Dictionary] = []
	var held_textures: Dictionary = {}
	if _kitchen_controller != null and is_instance_valid(_kitchen_controller):
		if _kitchen_controller.has_method(&"get_employee_worker_views"):
			worker_views.append_array(_kitchen_controller.get_employee_worker_views())
		for ing_id in _kitchen_controller.get_ingredient_ids():
			var idef := _kitchen_controller.get_ingredient_def(ing_id)
			if idef != null and idef.cooked_texture != null:
				held_textures[ing_id] = idef.cooked_texture
			elif idef != null and idef.icon != null:
				held_textures[ing_id] = idef.icon
		if _run_controller != null and is_instance_valid(_run_controller):
			var rv := _run_controller.get_run_view()
			for raw_rid: Variant in rv.get("unlocked_recipe_ids", []):
				var rid := StringName(raw_rid)
				var rdef := _kitchen_controller.get_recipe_def(rid)
				if rdef != null and rdef.icon != null:
					held_textures[rid] = rdef.icon
	if _service_controller != null and is_instance_valid(_service_controller):
		if _service_controller.has_method(&"get_employee_worker_views"):
			worker_views.append_array(_service_controller.get_employee_worker_views())
	_world_map.sync_employee_visuals(employees, worker_views, held_textures)


func _clear_employee_error() -> void:
	if employee_error_label != null:
		employee_error_label.text = ""
		employee_error_label.visible = false


func _show_employee_error(msg: String) -> void:
	if employee_error_label != null:
		employee_error_label.text = msg
		employee_error_label.visible = not msg.is_empty()
		KetikUiArt.style_wood_body_label(employee_error_label, 10, KetikUiArt.COLOR_DANGER)


func _create_employee_icon_control() -> Control:
	var box := Control.new()
	box.name = "EmployeeIcon"
	box.custom_minimum_size = Vector2(24, 32)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = null
	if _world_map != null and is_instance_valid(_world_map) and _world_map.employee_texture != null:
		tex = _world_map.employee_texture
	else:
		tex = KetikUiArt.load_tex("res://assets/art/characters/pegawai.png")
	if tex != null:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.position = Vector2(5, 1)
		rect.size = Vector2(14, 31)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(rect)
	return box


func _build_employee_shop_ui() -> void:
	_employee_role_rows.clear()
	_employee_roster_rows.clear()
	if employee_role_list != null:
		for child in employee_role_list.get_children():
			employee_role_list.remove_child(child)
			child.free()
	if employee_roster_list != null:
		for child in employee_roster_list.get_children():
			employee_roster_list.remove_child(child)
			child.free()

	if _run_controller == null or not is_instance_valid(_run_controller):
		return

	if employee_role_list != null:
		for role_id in _run_controller.get_employee_role_ids():
			var role_def := _run_controller.get_employee_role_def(role_id)
			if role_def.is_empty():
				continue
			var row_panel := PanelContainer.new()
			row_panel.name = "EmployeeRole_%s" % role_id
			row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			employee_role_list.add_child(row_panel)

			var row_box := HBoxContainer.new()
			row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row_box.add_theme_constant_override("separation", 6)
			row_panel.add_child(row_box)

			row_box.add_child(_create_employee_icon_control())

			var info_col := VBoxContainer.new()
			info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			info_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
			info_col.add_theme_constant_override("separation", 1)
			row_box.add_child(info_col)

			var title_lbl := Label.new()
			title_lbl.name = "TitleLabel"
			title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			KetikUiArt.style_heading_label(title_lbl, 12)
			var hire_cost := int(role_def.get("hire_cost", 0))
			var salary := int(role_def.get("daily_salary", 0))
			title_lbl.text = "%s · Biaya Rekrutmen %s · Gaji Harian %s" % [
				String(role_def.get("display_name", String(role_id))),
				format_rupiah(hire_cost),
				format_rupiah(salary),
			]
			info_col.add_child(title_lbl)

			var desc_lbl := Label.new()
			desc_lbl.name = "DescriptionLabel"
			desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			KetikUiArt.style_heading_label(desc_lbl, 10, KetikUiArt.COLOR_MUTED_LIGHT)
			desc_lbl.add_theme_constant_override("outline_size", 3)
			desc_lbl.text = "Manfaat Pekerjaan: %s" % String(role_def.get("benefit_summary", ""))
			info_col.add_child(desc_lbl)

			var hire_btn := Button.new()
			hire_btn.name = "HireButton"
			hire_btn.focus_mode = Control.FOCUS_ALL
			hire_btn.mouse_filter = Control.MOUSE_FILTER_STOP
			hire_btn.custom_minimum_size = Vector2(68, 25)
			hire_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hire_btn.add_theme_font_size_override("font_size", 11)
			hire_btn.text = "Rekrut"
			KetikUiArt.apply_button_skin(hire_btn, false, 6, 2)
			var captured_role := role_id
			hire_btn.pressed.connect(
				func() -> void:
					hire_employee_role(captured_role)
			)
			row_box.add_child(hire_btn)

			_employee_role_rows[role_id] = {
				"panel": row_panel,
				"title_label": title_lbl,
				"description_label": desc_lbl,
				"hire_button": hire_btn,
				"base_benefit": String(role_def.get("benefit_summary", "")),
			}
		_hook_button_click_sfx(employee_role_list)

	if employee_roster_list != null:
		var employees := _run_controller.get_hired_employees()
		if employees.is_empty():
			var empty_lbl := Label.new()
			empty_lbl.name = "EmptyRosterLabel"
			empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			empty_lbl.text = "Belum ada Karyawan Aktif (Total Gaji Harian: Rp 0)."
			KetikUiArt.style_wood_body_label(empty_lbl, 10, KetikUiArt.COLOR_WOOD_MID)
			employee_roster_list.add_child(empty_lbl)
		else:
			for rec: Dictionary in employees:
				var emp_id := StringName(rec.get("employee_id", &""))
				var r_panel := PanelContainer.new()
				r_panel.name = "RosterRow_%s" % emp_id
				r_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				r_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
				KetikUiArt.apply_card_skin(r_panel, false, false, false, 8, 4)
				employee_roster_list.add_child(r_panel)

				var r_box := HBoxContainer.new()
				r_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				r_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
				r_box.add_theme_constant_override("separation", 6)
				r_panel.add_child(r_box)

				var r_lbl := Label.new()
				r_lbl.name = "RosterInfoLabel"
				r_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				r_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				r_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				r_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				var is_confirming := (_pending_dismiss_employee_id == emp_id)
				if is_confirming:
					r_lbl.text = "Yakin Pecat Pegawai %s? (Biaya Rekrutmen tidak kembali)" % String(
						rec.get("display_name", String(emp_id))
					)
					KetikUiArt.style_heading_label(r_lbl, 10, KetikUiArt.COLOR_WARN_LIGHT)
					r_lbl.add_theme_constant_override("outline_size", 3)
				else:
					r_lbl.text = "%s (%s) · Gaji Harian: %s · Masuk H%d · Aktif" % [
						String(rec.get("display_name", "")),
						String(emp_id),
						format_rupiah(int(rec.get("daily_salary", 0))),
						int(rec.get("hired_day", 1)),
					]
					KetikUiArt.style_heading_label(r_lbl, 11)
					r_lbl.add_theme_constant_override("outline_size", 3)
				r_box.add_child(r_lbl)

				if is_confirming:
					var cancel_btn := Button.new()
					cancel_btn.name = "CancelDismissButton"
					cancel_btn.focus_mode = Control.FOCUS_ALL
					cancel_btn.mouse_filter = Control.MOUSE_FILTER_STOP
					cancel_btn.custom_minimum_size = Vector2(52, 23)
					cancel_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					cancel_btn.add_theme_font_size_override("font_size", 10)
					cancel_btn.text = "Batal"
					KetikUiArt.apply_button_skin(cancel_btn, false, 6, 2)
					cancel_btn.pressed.connect(cancel_dismiss_confirmation)
					r_box.add_child(cancel_btn)

				var dismiss_btn := Button.new()
				dismiss_btn.name = "DismissButton"
				dismiss_btn.focus_mode = Control.FOCUS_ALL
				dismiss_btn.mouse_filter = Control.MOUSE_FILTER_STOP
				dismiss_btn.custom_minimum_size = Vector2(96, 23)
				dismiss_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				dismiss_btn.add_theme_font_size_override("font_size", 10)
				dismiss_btn.text = "Konfirmasi Pecat" if is_confirming else "Pecat Pegawai"
				KetikUiArt.apply_button_skin(dismiss_btn, false, 6, 2)
				var captured_emp := emp_id
				if is_confirming:
					dismiss_btn.pressed.connect(
						func() -> void:
							dismiss_employee_by_id(captured_emp)
					)
				else:
					dismiss_btn.pressed.connect(
						func() -> void:
							request_dismiss_confirmation(captured_emp)
					)
				r_box.add_child(dismiss_btn)

				_employee_roster_rows[emp_id] = {
					"panel": r_panel,
					"info_label": r_lbl,
					"dismiss_button": dismiss_btn,
				}
			_hook_button_click_sfx(employee_roster_list)


func _refresh_employee_shop_view() -> void:
	if _run_controller == null or not is_instance_valid(_run_controller):
		return
	var run_view := _run_controller.get_run_view()
	var cash := int(run_view.get("cash", 0))
	var wf: Dictionary = run_view.get("workforce_summary", _run_controller.get_workforce_summary())
	var total_emp := int(wf.get("total_employees", 0))
	var daily_salary := int(wf.get("daily_salary_total", 0))
	var crowded := bool(wf.get("crowded", false))
	var crowding_mult := float(wf.get("crowding_multiplier", 1.0))
	var crowding_overhead := int(wf.get("crowding_overhead", 0))
	var by_role: Dictionary = wf.get("by_role", {})

	if employee_cash_label != null:
		employee_cash_label.text = "Kas: %s" % format_rupiah(cash)
		KetikUiArt.style_wood_body_label(employee_cash_label, 11)
	if employee_salary_label != null:
		employee_salary_label.text = "Total Gaji Harian: %s" % format_rupiah(daily_salary)
		KetikUiArt.style_wood_body_label(employee_salary_label, 11, KetikUiArt.COLOR_WOOD_MID)
	if employee_crowding_label != null:
		if crowded:
			var crowd_eff_pct := int(round((1.0 / maxf(1.0, crowding_mult)) * 100.0))
			employee_crowding_label.text = (
				"Peringatan: Dapur padat (%d Karyawan Aktif)! Efisiensi Kerja turun %d%%, tambahan koordinasi +%s/hari."
				% [total_emp, crowd_eff_pct, format_rupiah(crowding_overhead)]
			)
			KetikUiArt.style_wood_body_label(employee_crowding_label, 10, KetikUiArt.COLOR_DANGER)
		else:
			employee_crowding_label.text = (
				"Tim ramping lebih efektif. Menambah peran sama menurunkan Efisiensi Kerja dan menaikkan Gaji Harian."
			)
			KetikUiArt.style_wood_body_label(employee_crowding_label, 10, KetikUiArt.COLOR_WOOD_MID)
	if employee_roster_section_label != null:
		employee_roster_section_label.text = "Karyawan Aktif (%d)" % total_emp
	if employee_summary_label != null:
		employee_summary_label.text = "Karyawan Aktif: %d · Total Gaji Harian: %s" % [
			total_emp,
			format_rupiah(daily_salary),
		]
		KetikUiArt.style_wood_body_label(employee_summary_label, 11)

	for role_id: StringName in _employee_role_rows:
		var row: Dictionary = _employee_role_rows[role_id]
		var panel := row.get("panel") as PanelContainer
		var title_lbl := row.get("title_label") as Label
		var desc_lbl := row.get("description_label") as Label
		var hire_btn := row.get("hire_button") as Button
		var role_info: Dictionary = by_role.get(role_id, {})
		var cnt := int(role_info.get("count", 0))
		var factor := float(role_info.get("effective_factor", 0.0))
		var eff_pct := int(round((factor / float(cnt)) * 100.0)) if cnt > 0 else 100
		var check := _run_controller.can_hire_employee(role_id)
		var affordable := bool(check.get("ok", false))
		if panel != null:
			KetikUiArt.apply_card_skin(panel, false, not affordable, false, 8, 5)
		if title_lbl != null:
			KetikUiArt.style_heading_label(
				title_lbl,
				12,
				KetikUiArt.COLOR_CREAM if affordable else Color(0.86, 0.84, 0.80, 1.0)
			)
		if desc_lbl != null:
			var base_b := String(row.get("base_benefit", ""))
			desc_lbl.text = (
				"Manfaat Pekerjaan: %s · Efisiensi Kerja: %d%% (Aktif: %d)" % [base_b, eff_pct, cnt]
				if cnt > 0
				else "Manfaat Pekerjaan: %s · Efisiensi Kerja: 100%%" % base_b
			)
			KetikUiArt.style_heading_label(
				desc_lbl,
				10,
				KetikUiArt.COLOR_MUTED_LIGHT if affordable else Color(0.80, 0.78, 0.75, 0.95)
			)
			desc_lbl.add_theme_constant_override("outline_size", 3)
		if hire_btn != null:
			hire_btn.modulate = Color.WHITE if affordable else Color(0.82, 0.76, 0.72, 0.92)
	_layout_fixture_shop_overlay()


func _get_viewport_logical_size() -> Vector2:
	if is_inside_tree() and get_viewport() != null:
		var vis := get_viewport().get_visible_rect().size
		if vis.x > 0.0 and vis.y > 0.0:
			return vis
	return LOGICAL_VIEWPORT_SIZE


func _on_left_hud_min_size_changed() -> void:
	var vp_size := _get_viewport_logical_size()
	var hud_w := clampf(ui_safe_rect.size.x, 0.0, maxf(0.0, vp_size.x - 200.0))
	_sync_left_hud_rect(vp_size, hud_w)


func _sync_left_hud_rect(vp_size: Vector2, hud_w: float) -> void:
	if left_hud_region == null:
		return
	var compact := vp_size.y < 320.0
	var hud_col := left_hud_region.get_node_or_null("HUDColumn") as VBoxContainer
	if hud_col != null:
		hud_col.add_theme_constant_override("separation", 1 if compact else 3)
		hud_col.position = Vector2(8.0, 4.0 if compact else 6.0)
		hud_col.size = Vector2(
			maxf(1.0, hud_w - 16.0),
			maxf(1.0, vp_size.y - (8.0 if compact else 12.0))
		)
	var target_sec := left_hud_region.get_node_or_null("HUDColumn/TargetSection") as VBoxContainer
	if target_sec != null:
		target_sec.add_theme_constant_override("separation", 1 if compact else 2)
	if day_card != null:
		day_card.custom_minimum_size = Vector2(82.0 if compact else 92.0, 29.0 if compact else 42.0)
	if hari_ke_banner != null:
		hari_ke_banner.custom_minimum_size = Vector2(0.0, 7.0 if compact else 10.0)
	if day_value_label != null:
		day_value_label.add_theme_font_size_override("font_size", 11 if compact else 14)
	if cash_panel != null:
		cash_panel.custom_minimum_size = Vector2(0.0, 18.0 if compact else 22.0)
	if target_guest_panel != null:
		target_guest_panel.custom_minimum_size = Vector2(0.0, 22.0 if compact else 32.0)
	if hud_typing_panel != null:
		hud_typing_panel.custom_minimum_size = Vector2(0.0, 21.0 if compact else 34.0)
	if planning_box != null:
		planning_box.add_theme_constant_override("separation", 1 if compact else 2)
	if edit_menu_button != null:
		edit_menu_button.custom_minimum_size = Vector2(0.0, 18.0 if compact else 22.0)
	if fixture_shop_button != null:
		fixture_shop_button.custom_minimum_size = Vector2(0.0, 18.0 if compact else 22.0)
	if employee_button != null:
		employee_button.custom_minimum_size = Vector2(0.0, 18.0 if compact else 21.0)
	if menu_stub_button != null:
		menu_stub_button.custom_minimum_size = Vector2(20.0 if compact else 26.0, 18.0 if compact else 23.0)
	if exit_stub_button != null:
		exit_stub_button.custom_minimum_size = Vector2(20.0 if compact else 26.0, 18.0 if compact else 23.0)
	if pause_button != null:
		pause_button.custom_minimum_size = Vector2(0.0, 16.0 if compact else 19.0)
	left_hud_region.position = ui_safe_rect.position
	left_hud_region.size = Vector2(hud_w, vp_size.y)


func _on_viewport_size_changed() -> void:
	_layout_fixture_shop_overlay()
	_refresh_hud()
	if is_reference_open():
		_populate_cara_main_sections()


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
	if employee_overlay != null and employee_popup != null:
		var emp_dimmer := employee_overlay.get_node_or_null("WorldDimmer") as ColorRect
		if emp_dimmer != null:
			emp_dimmer.position = world_rect.position
			emp_dimmer.size = world_rect.size
		var emp_w := minf(488.0, avail_w)
		var emp_h := minf(332.0, avail_h)
		var emp_x := world_rect.position.x + floorf((world_rect.size.x - emp_w) * 0.5)
		var emp_y := world_rect.position.y + floorf((world_rect.size.y - emp_h) * 0.5)
		var emp_scroll := employee_popup.get_node_or_null(
			"EmployeeColumn/EmployeeScroll"
		) as ScrollContainer
		if emp_scroll != null:
			emp_scroll.custom_minimum_size = Vector2(0.0, 64.0)
			emp_scroll.clip_contents = true
		employee_popup.custom_minimum_size = Vector2.ZERO
		employee_popup.position = Vector2(emp_x, emp_y)
		employee_popup.size = Vector2(emp_w, emp_h)
		employee_popup.set_deferred(&"size", Vector2(emp_w, emp_h))
	if edit_menu_overlay != null:
		var edit_dimmer := edit_menu_overlay.get_node_or_null("WorldDimmer") as ColorRect
		if edit_dimmer != null:
			edit_dimmer.position = world_rect.position
			edit_dimmer.size = world_rect.size
		if edit_menu_popup != null and recipe_detail_panel != null:
			if avail_w >= 310.0:
				var gap_x := 10.0 if avail_w >= 400.0 else 6.0
				var detail_w := clampf(roundf(avail_w * 0.35), 118.0, 174.0)
				var edit_w := minf(296.0, avail_w - detail_w - gap_x)
				var total_w := edit_w + gap_x + detail_w
				var edit_h := minf(284.0, avail_h)
				var detail_h := clampf(roundf(edit_h * 0.78), 160.0, edit_h)
				var start_x := world_rect.position.x + floorf((world_rect.size.x - total_w) * 0.5)
				var start_y := world_rect.position.y + floorf((world_rect.size.y - edit_h) * 0.5)
				edit_menu_popup.custom_minimum_size = Vector2.ZERO
				edit_menu_popup.position = Vector2(start_x, start_y)
				edit_menu_popup.size = Vector2(edit_w, edit_h)
				recipe_detail_panel.custom_minimum_size = Vector2.ZERO
				recipe_detail_panel.position = Vector2(start_x + edit_w + gap_x, start_y)
				recipe_detail_panel.size = Vector2(detail_w, detail_h)
			else:
				var stack_w := minf(296.0, avail_w)
				var gap_y := 6.0
				var edit_h := clampf(floorf((avail_h - gap_y) * 0.60), 120.0, 220.0)
				var detail_h := maxf(84.0, avail_h - edit_h - gap_y)
				var stack_x := world_rect.position.x + floorf((world_rect.size.x - stack_w) * 0.5)
				var stack_y := world_rect.position.y + margin_y
				edit_menu_popup.custom_minimum_size = Vector2.ZERO
				edit_menu_popup.position = Vector2(stack_x, stack_y)
				edit_menu_popup.size = Vector2(stack_w, edit_h)
				recipe_detail_panel.custom_minimum_size = Vector2.ZERO
				recipe_detail_panel.position = Vector2(stack_x, stack_y + edit_h + gap_y)
				recipe_detail_panel.size = Vector2(stack_w, detail_h)
		elif edit_menu_popup != null:
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
	if settings_popup != null:
		var s_w := minf(356.0, maxf(248.0, vp_size.x - 20.0))
		var s_h := minf(320.0, maxf(192.0, vp_size.y - 16.0))
		settings_popup.custom_minimum_size = Vector2.ZERO
		settings_popup.position = Vector2(
			floorf((vp_size.x - s_w) * 0.5),
			floorf((vp_size.y - s_h) * 0.5)
		)
		settings_popup.size = Vector2(s_w, s_h)
	if exit_confirm_popup != null:
		var e_w := minf(268.0, maxf(212.0, vp_size.x - 24.0))
		var e_min := exit_confirm_popup.get_combined_minimum_size()
		var e_h := clampf(maxf(122.0, e_min.y), 112.0, maxf(122.0, vp_size.y - 24.0))
		exit_confirm_popup.position = Vector2(
			floorf((vp_size.x - e_w) * 0.5),
			floorf((vp_size.y - e_h) * 0.5)
		)
		exit_confirm_popup.size = Vector2(e_w, e_h)
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

	var run_view := _run_controller.get_run_view()
	var cash := int(run_view.get("cash", 0))
	var daily_power := int(run_view.get("daily_electricity_charge", 0))
	if fixture_shop_popup != null:
		var p_lbl := fixture_shop_popup.get_node_or_null(
			"FixtureColumn/FixtureHeaderRow/ElectricityBadge/HBoxContainer/PowerTotalLabel"
		) as Label
		if p_lbl == null:
			p_lbl = fixture_shop_popup.find_child("PowerTotalLabel", true, false) as Label
		if p_lbl != null:
			p_lbl.text = "%s/hari" % format_rupiah(daily_power)

	for u_id: StringName in _fixture_shop_rows:
		var controls: Dictionary = _fixture_shop_rows[u_id]
		var def := _run_controller.get_utility_def(u_id)
		if def == null:
			continue
		var selected := (u_id == _selected_fixture_utility_id)
		var affordable := cash >= def.purchase_price
		var panel := controls["panel"] as PanelContainer
		KetikUiArt.apply_card_skin(panel, false, not affordable, selected, 8, 5)
		var t_lbl := controls.get("title_label", null) as Label
		KetikUiArt.style_heading_label(t_lbl, 12)
		var d_lbl := controls.get("description_label", null) as Label
		KetikUiArt.style_heading_label(
			d_lbl,
			10,
			KetikUiArt.COLOR_MUTED_LIGHT if affordable else Color(0.84, 0.84, 0.84, 1.0)
		)
		var select_btn := controls["select_button"] as Button
		select_btn.set_pressed_no_signal(selected and affordable)
		select_btn.disabled = not affordable
		select_btn.text = "tidak cukup" if not affordable else ("Terpilih" if selected else "+")

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
	if is_main_menu_open():
		return
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
		if _tutorial_replay_pending_from_menu:
			_tutorial_replay_pending_from_menu = false
			_reset_tutorial_runtime_state()
		else:
			_load_tutorial_persistence()
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


func open_reference(from_pause: bool = false) -> bool:
	if is_main_menu_open() or is_settings_open() or is_exit_confirm_open():
		return false
	if is_story_open() or is_edit_menu_open() or is_ingredient_shop_open() or is_fixture_shop_open():
		return false
	if is_employee_shop_open():
		return false
	if tutorial_reference_overlay == null:
		return false

	var opened_from_pause := from_pause or is_pause_open()
	if _is_gameplay_paused() and not opened_from_pause:
		return false

	if opened_from_pause:
		_reference_return_to_pause = true
		_reference_paused_by_self = false
		if pause_overlay != null:
			pause_overlay.visible = false
	else:
		_reference_return_to_pause = false
		if (
			_is_serving_phase()
			and not _is_gameplay_paused()
			and _game_root != null
			and is_instance_valid(_game_root)
			and _game_root.has_method(&"set_paused")
		):
			# Mark before set_paused(true) so synchronous pause_changed never opens PauseOverlay.
			_reference_paused_by_self = true
			if not bool(_game_root.set_paused(true)):
				_reference_paused_by_self = false
				return false

	if reference_body_label != null:
		reference_body_label.text = NarrativeTutorialCatalog.get_reference_summary_text()
	if reference_body_richtext != null:
		reference_body_richtext.text = NarrativeTutorialCatalog.get_cara_main_bbcode()
	_populate_cara_main_sections()
	if reference_restart_button != null:
		reference_restart_button.visible = true
		reference_restart_button.disabled = opened_from_pause
	tutorial_reference_overlay.visible = true
	_layout_fixture_shop_overlay()
	_refresh_onboarding_visibility()
	if reference_close_button != null:
		reference_close_button.grab_focus()
	return true


func _populate_cara_main_sections() -> void:
	if reference_sections_box == null:
		return
	for child in reference_sections_box.get_children():
		reference_sections_box.remove_child(child)
		child.free()

	var compact := _get_viewport_logical_size().y < 320.0
	var sec_blocks: Array[Dictionary] = []
	for sec in NarrativeTutorialCatalog.get_cara_main_sections():
		sec_blocks.append(sec)
	sec_blocks.append({
		"heading": "",
		"bullets": ["Selamat berjualan, semoga nggak ikut matang!"],
		"plain_body": true,
		"closing": true,
	})

	for idx in range(sec_blocks.size()):
		if idx > 0:
			var sep_wrap := MarginContainer.new()
			sep_wrap.name = "SectionSeparator_%d" % idx
			sep_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sep_wrap.add_theme_constant_override("margin_top", 3 if compact else 4)
			sep_wrap.add_theme_constant_override("margin_bottom", 3 if compact else 4)
			var sep := HSeparator.new()
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sep_line := StyleBoxLine.new()
			sep_line.color = Color(0.56, 0.36, 0.18, 0.72)
			sep_line.thickness = 1
			sep.add_theme_stylebox_override("separator", sep_line)
			sep_wrap.add_child(sep)
			reference_sections_box.add_child(sep_wrap)

		var block_data := sec_blocks[idx]
		var sec_box := VBoxContainer.new()
		sec_box.name = "CaraMainSection_%d" % idx
		sec_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sec_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sec_box.add_theme_constant_override("separation", 2)

		var heading_txt := str(block_data.get("heading", ""))
		if not heading_txt.is_empty():
			var h_lbl := Label.new()
			h_lbl.name = "Heading"
			h_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h_lbl.text = heading_txt
			KetikUiArt.style_wood_body_label(
				h_lbl,
				11 if compact else 12,
				Color(0.43, 0.13, 0.04, 1.0)
			)
			sec_box.add_child(h_lbl)

		var plain_body := bool(block_data.get("plain_body", false))
		var is_closing := bool(block_data.get("closing", false))
		var bullets: Array = block_data.get("bullets", [])
		for b_i in range(bullets.size()):
			var b_raw := str(bullets[b_i])
			var line_text := b_raw if plain_body else ("- " + b_raw)
			if line_text.contains("[color="):
				var rt := RichTextLabel.new()
				rt.name = "Line_%d" % b_i
				rt.bbcode_enabled = true
				rt.fit_content = true
				rt.scroll_active = false
				rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
				rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				rt.add_theme_font_size_override("normal_font_size", 10 if compact else 11)
				rt.add_theme_color_override("default_color", KetikUiArt.COLOR_WOOD_DARK)
				rt.add_theme_constant_override("line_separation", 1)
				rt.text = line_text
				sec_box.add_child(rt)
			else:
				var lbl := Label.new()
				lbl.name = "Line_%d" % b_i
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				lbl.add_theme_constant_override("line_spacing", 1)
				KetikUiArt.style_wood_body_label(
					lbl,
					10 if compact else 11,
					Color(0.35, 0.12, 0.04, 1.0) if is_closing else KetikUiArt.COLOR_WOOD_DARK
				)
				lbl.text = line_text
				sec_box.add_child(lbl)

		reference_sections_box.add_child(sec_box)


func _on_reference_dimmer_gui_input(event: InputEvent) -> void:
	if not is_reference_open():
		return
	var mouse_btn := event as InputEventMouseButton
	if mouse_btn != null and mouse_btn.pressed and mouse_btn.button_index == MOUSE_BUTTON_LEFT:
		var ref_dimmer := tutorial_reference_overlay.get_node_or_null("WorldDimmer") as Control
		if ref_dimmer != null:
			ref_dimmer.accept_event()
		if is_inside_tree() and get_viewport() != null:
			get_viewport().set_input_as_handled()
		_play_ui_click()
		close_reference()


func close_reference() -> void:
	if tutorial_reference_overlay != null:
		tutorial_reference_overlay.visible = false
	var was_paused_by_self := _reference_paused_by_self
	var return_to_pause := _reference_return_to_pause
	_reference_paused_by_self = false
	_reference_return_to_pause = false
	if was_paused_by_self:
		if (
			_game_root != null
			and is_instance_valid(_game_root)
			and _game_root.has_method(&"set_paused")
		):
			_game_root.set_paused(false)
	elif return_to_pause and pause_overlay != null and _is_gameplay_paused():
		pause_overlay.visible = true
		if pause_resume_button != null:
			pause_resume_button.grab_focus()
	if not (return_to_pause and pause_overlay != null and pause_overlay.visible):
		_release_button_focus_if_any()
	_refresh_onboarding_visibility()
	_refresh_dialogue()


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
		if _onboarding_enabled and _is_planning_phase():
			_start_tutorial()
			if not _shown_initial_cara_main:
				_shown_initial_cara_main = true
				call_deferred(&"open_reference")


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


func _reset_tutorial_runtime_state() -> void:
	_tutorial_completed = false
	_tutorial_skipped = false
	_tutorial_active = false
	_tutorial_step_index = 0
	_tutorial_flags.clear()
	_tutorial_hint_text = ""
	_shown_feature_tips.clear()
	_pending_feature_tips.clear()
	_active_feature_tip_id = &""


func _load_tutorial_persistence() -> void:
	var audio := _get_audio_controller()
	if audio == null or not audio.has_method(&"get_tutorial_state"):
		return
	var st: Dictionary = audio.get_tutorial_state()
	_tutorial_completed = bool(st.get("completed", false))
	_tutorial_skipped = bool(st.get("skipped", false))
	var steps := NarrativeTutorialCatalog.get_tutorial_steps()
	_tutorial_step_index = clampi(int(st.get("step_index", 0)), 0, maxi(0, steps.size() - 1))
	_shown_feature_tips.clear()
	var tips_v: Variant = st.get("shown_tips", [])
	if tips_v is Array:
		for t_v in (tips_v as Array):
			var t_id := StringName(str(t_v))
			if t_id != &"":
				_shown_feature_tips[t_id] = true
	_tutorial_flags.clear()
	var flags_v: Variant = st.get("flags", {})
	if flags_v is Dictionary:
		for k in (flags_v as Dictionary):
			_tutorial_flags[StringName(str(k))] = bool((flags_v as Dictionary)[k])


func _save_tutorial_persistence() -> void:
	var audio := _get_audio_controller()
	if audio == null or not audio.has_method(&"save_tutorial_state"):
		return
	var shown_list: Array[String] = []
	for k: StringName in _shown_feature_tips:
		if bool(_shown_feature_tips[k]):
			shown_list.append(String(k))
	var flag_out: Dictionary = {}
	for f_k: StringName in _tutorial_flags:
		if bool(_tutorial_flags[f_k]):
			flag_out[String(f_k)] = true
	audio.save_tutorial_state({
		"completed": _tutorial_completed,
		"skipped": _tutorial_skipped,
		"step_index": _tutorial_step_index,
		"shown_tips": shown_list,
		"flags": flag_out,
	}, true)


func _start_tutorial() -> void:
	if not _onboarding_enabled or _tutorial_completed or _tutorial_skipped:
		_tutorial_active = false
		return
	var steps := NarrativeTutorialCatalog.get_tutorial_steps()
	if steps.is_empty():
		_tutorial_active = false
		_tutorial_completed = true
		return
	_tutorial_started_day = _get_current_day_index()
	_tutorial_step_index = clampi(_tutorial_step_index, 0, steps.size() - 1)
	_tutorial_active = true
	_evaluate_onboarding_progress()
	_update_tutorial_banner_view()
	_refresh_onboarding_visibility()


func is_tutorial_active() -> bool:
	return (
		_onboarding_enabled
		and _tutorial_active
		and not _tutorial_completed
		and not _tutorial_skipped
	)


func is_tutorial_completed() -> bool:
	return _tutorial_completed


func is_tutorial_skipped() -> bool:
	return _tutorial_skipped


func get_tutorial_chapter() -> int:
	if not is_tutorial_active():
		return 0
	var steps := NarrativeTutorialCatalog.get_tutorial_steps()
	if _tutorial_step_index < 0 or _tutorial_step_index >= steps.size():
		return 0
	return int(steps[_tutorial_step_index].get("chapter", 0))


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
	_save_tutorial_persistence()
	_refresh_onboarding_visibility()
	_release_button_focus_if_any()


func restart_tutorial() -> void:
	_onboarding_explicitly_set = true
	_onboarding_enabled = true
	_onboarding_boot_checked = true
	_tutorial_replay_pending_from_menu = false
	_reset_tutorial_runtime_state()
	_tutorial_started_day = _get_current_day_index()
	_tutorial_active = true
	var audio := _get_audio_controller()
	if audio != null and audio.has_method(&"reset_tutorial_state"):
		audio.reset_tutorial_state(true)
	if is_reference_open():
		close_reference()
	if is_story_open():
		_close_story_internal()
	_evaluate_onboarding_progress()
	_update_tutorial_banner_view()
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
	if bool(_shown_feature_tips.get(tip_id, false)):
		return
	if NarrativeTutorialCatalog.get_feature_discovery_tip(tip_id).is_empty():
		return
	if _active_feature_tip_id == &"":
		_activate_feature_tip(tip_id)
		_save_tutorial_persistence()
		_refresh_onboarding_visibility()
	elif _active_feature_tip_id != tip_id and not _pending_feature_tips.has(tip_id):
		_pending_feature_tips.append(tip_id)


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
	match step_id:
		&"ch1_objective":
			_tutorial_flags[&"ch1_objective_done"] = true
		&"ch5_accept_online":
			_tutorial_flags[&"ch5_online_skipped"] = true
		&"ch5_serve_online":
			_tutorial_flags[&"ch5_online_skipped"] = true
		&"ch7_review_results":
			_tutorial_flags[&"ch7_results_done"] = true
		&"ch6_employee_overview":
			if bool(_tutorial_flags.get(&"employee_inspected", false)):
				_tutorial_flags[&"ch6_employee_done"] = true
		&"ch8_ready":
			_tutorial_flags[&"ch8_ready_done"] = true
	_evaluate_onboarding_progress()
	_refresh_onboarding_visibility()
	_release_button_focus_if_any()


func _on_tip_dismiss_pressed() -> void:
	dismiss_feature_tip()


func _on_tutorial_help_pressed() -> void:
	if is_reference_open():
		close_reference()
	else:
		open_reference(false)


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
		_last_online_served_count = 0
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
			if _has_online_credit_increase():
				_tutorial_flags[&"online_served"] = true
				_tutorial_hint_text = "Pesanan online tersaji ke pengantar!"
			else:
				_tutorial_hint_text = "Pesanan tersaji ke pelanggan!"
		&"online_accepted":
			_tutorial_flags[&"online_accepted"] = true
			_tutorial_hint_text = "Order online diterima! Perhatikan batas 60 detik."
		&"wrong_order":
			if is_tutorial_active() and get_tutorial_step_id() in [&"ch4_serve_dinein", &"ch5_serve_online"]:
				_tutorial_hint_text = "Hidangan belum sesuai! Pastikan piring sudah menjadi menu yang diminta."
		&"invalid_key":
			if (
				is_tutorial_active()
				and get_tutorial_step_id() == &"ch4_serve_dinein"
				and _kitchen_controller != null
				and not _has_valid_nasi_telor_in_hand_or_table()
			):
				_tutorial_hint_text = "Rakit dulu Nasi Telor matang sebelum mengetik 'saji'."
		&"table_cleaned":
			_tutorial_flags[&"table_cleaned"] = true
			_tutorial_hint_text = "Meja bersih! Cuci piring kotor di Wastafel."
		&"plate_washed":
			_tutorial_flags[&"plate_washed"] = true
			_tutorial_hint_text = "Piring bersih kembali ke tangan!"


func _has_online_credit_increase() -> bool:
	if _service_controller == null:
		return false
	var qv := _service_controller.get_customer_queue_view()
	var online_comp := int(qv.get("completed_online_count", 0))
	if online_comp > _last_online_served_count:
		_last_online_served_count = online_comp
		return true
	return false


func _evaluate_onboarding_progress() -> void:
	if not _onboarding_enabled:
		return
	_evaluate_feature_discovery()
	if not is_tutorial_active():
		_refresh_onboarding_visibility()
		return

	var phase := _get_current_phase()
	var steps := NarrativeTutorialCatalog.get_tutorial_steps()
	var prev_idx := _tutorial_step_index
	var safety: int = 0
	while _tutorial_active and _tutorial_step_index < steps.size() and safety < 18:
		safety += 1
		var step_id := StringName(steps[_tutorial_step_index].get("id", &""))
		if not _is_tutorial_step_satisfied(step_id, phase):
			break
		_tutorial_step_index += 1
		if _tutorial_step_index >= steps.size():
			_tutorial_completed = true
			_tutorial_active = false
			break

	if _tutorial_step_index != prev_idx:
		if _tutorial_step_index >= prev_idx + 2:
			_tutorial_hint_text = ""
		_save_tutorial_persistence()

	_update_tutorial_banner_view()
	_refresh_onboarding_visibility()


func _is_tutorial_step_satisfied(step_id: StringName, phase: int) -> bool:
	var already_results := (
		phase == SharedTypes.Phase.RESULTS
		or phase == SharedTypes.Phase.FINISHED
	)
	var day_index := _get_current_day_index()
	var online_closed := _is_online_tutorial_bypassed(phase, day_index)
	match step_id:
		&"ch1_objective":
			return (
				bool(_tutorial_flags.get(&"ch1_objective_done", false))
				or bool(_tutorial_flags.get(&"player_moved", false))
				or phase != SharedTypes.Phase.PLANNING
				or day_index >= 2
			)
		&"ch1_move":
			return (
				bool(_tutorial_flags.get(&"player_moved", false))
				or phase != SharedTypes.Phase.PLANNING
				or day_index >= 2
			)
		&"ch2_edit_menu":
			return (
				bool(_tutorial_flags.get(&"edit_menu_confirmed", false))
				or phase != SharedTypes.Phase.PLANNING
				or day_index >= 2
			)
		&"ch2_buy_ingredients":
			var both_ready := _has_or_used_ingredient(&"beras") and _has_or_used_ingredient(&"telur")
			return already_results or day_index >= 2 or phase == SharedTypes.Phase.SERVING or both_ready
		&"ch2_open_service":
			return (
				phase == SharedTypes.Phase.SERVING
				or phase == SharedTypes.Phase.CLOSING
				or already_results
				or day_index >= 2
			)
		&"ch3_take_rice":
			return (
				already_results
				or day_index >= 2
				or bool(_tutorial_flags.get(&"rice_picked", false))
				or _held_has_ingredient(&"beras")
				or bool(_tutorial_flags.get(&"rice_washed", false))
				or bool(_tutorial_flags.get(&"rice_cooked", false))
				or _rice_cooker_has_cooked_rice()
			)
		&"ch3_wash_rice":
			return (
				already_results
				or day_index >= 2
				or bool(_tutorial_flags.get(&"rice_washed", false))
				or _held_has_ingredient_state(&"beras", SharedTypes.PrepState.WASHED)
				or bool(_tutorial_flags.get(&"rice_cooked", false))
				or _rice_cooker_has_cooked_rice()
			)
		&"ch3_cook_rice":
			return (
				already_results
				or day_index >= 2
				or bool(_tutorial_flags.get(&"rice_cooked", false))
				or _rice_cooker_has_cooked_rice()
				or _has_valid_nasi_telor_in_hand_or_table()
				or bool(_tutorial_flags.get(&"order_served", false))
			)
		&"ch3_cook_egg":
			return (
				already_results
				or day_index >= 2
				or bool(_tutorial_flags.get(&"telur_cooked", false))
				or _stove_or_plate_has_cooked_telur()
				or _has_valid_nasi_telor_in_hand_or_table()
				or bool(_tutorial_flags.get(&"order_served", false))
			)
		&"ch4_assemble":
			return (
				already_results
				or day_index >= 2
				or _has_valid_nasi_telor_in_hand_or_table()
				or bool(_tutorial_flags.get(&"dish_assembled", false))
				or bool(_tutorial_flags.get(&"order_served", false))
			)
		&"ch4_serve_dinein":
			return already_results or day_index >= 2 or bool(_tutorial_flags.get(&"order_served", false))
		&"ch4_clean_and_wash":
			return (
				already_results
				or day_index >= 2
				or (
					bool(_tutorial_flags.get(&"table_cleaned", false))
					and bool(_tutorial_flags.get(&"plate_washed", false))
				)
			)
		&"ch5_accept_online":
			var has_drivers := _service_controller != null and not _service_controller.get_driver_views().is_empty()
			return (
				online_closed
				or bool(_tutorial_flags.get(&"ch5_online_skipped", false))
				or bool(_tutorial_flags.get(&"online_accepted", false))
				or has_drivers
				or bool(_tutorial_flags.get(&"online_served", false))
			)
		&"ch5_serve_online":
			return (
				online_closed
				or bool(_tutorial_flags.get(&"ch5_online_skipped", false))
				or bool(_tutorial_flags.get(&"online_served", false))
				or _has_online_credit_increase()
			)
		&"ch7_review_results":
			return (
				bool(_tutorial_flags.get(&"ch7_results_done", false))
				or (phase == SharedTypes.Phase.PLANNING and day_index >= 2)
				or phase == SharedTypes.Phase.FINISHED
			)
		&"ch6_employee_overview":
			var inspected := bool(_tutorial_flags.get(&"employee_inspected", false))
			var closed_after_inspect := inspected and not is_employee_shop_open()
			return (
				bool(_tutorial_flags.get(&"ch6_employee_done", false))
				or closed_after_inspect
				or phase == SharedTypes.Phase.FINISHED
			)
		&"ch8_ready":
			return (
				bool(_tutorial_flags.get(&"ch8_ready_done", false))
				or phase == SharedTypes.Phase.FINISHED
			)
		_:
			return false


func _is_online_tutorial_bypassed(phase: int, day_index: int) -> bool:
	if phase == SharedTypes.Phase.FINISHED:
		return true
	if day_index >= 3:
		return true
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
		&"ch1_objective":
			marker = "1"
		&"ch1_move":
			marker = "1"
			target_id = &"ui_floor_hint"
			badge = "[1] Klik Lantai"
		&"ch2_edit_menu":
			marker = "2"
			target_id = &"ui_edit_menu_button"
			badge = "[2] Edit Menu"
		&"ch2_buy_ingredients":
			marker = "2"
			target_id = &"storage_box"
			badge = "[2] Ketik: beli"
			var has_b := _has_or_used_ingredient(&"beras")
			var has_t := _has_or_used_ingredient(&"telur")
			var missing := "Beras dan Telur" if (not has_b and not has_t) else ("Beras" if not has_b else "Telur")
			body = "Kita butuh %s. Klik Kotak Bahan → ketik 'beli', lalu beli bahannya!" % missing
		&"ch2_open_service":
			marker = "2"
			target_id = &"ui_start_service"
			badge = "[2] Ketik: buka"
			if _kitchen_controller != null and _kitchen_controller.get_selected_target_id() != &"":
				body = "Stok siap! Klik lantai / ESC dulu untuk lepas objek, lalu ketik 'buka'."
		&"ch3_take_rice":
			marker = "3"
			target_id = _find_storage_with_ingredient(&"beras")
			badge = "[3] Ketik: beras"
		&"ch3_wash_rice":
			marker = "3"
			if _view_has_ingredient_state(held, &"beras", SharedTypes.PrepState.RAW):
				target_id = &"washer"
				badge = "[3] Ketik: cuci"
			elif _view_has_ingredient_state(table, &"beras", SharedTypes.PrepState.RAW):
				target_id = &"work_table_stage"
				badge = "[3] Ambil Beras"
			else:
				target_id = _find_storage_with_ingredient(&"beras")
				badge = "[3] Ketik: beras"
		&"ch3_cook_rice":
			marker = "3"
			target_id = &"rice_cooker"
			badge = "[3] Ketik: masak"
		&"ch3_cook_egg":
			marker = "3"
			if _view_has_ingredient_state(held, &"telur", SharedTypes.PrepState.RAW):
				target_id = &"stove"
				badge = "[3] Ketik: goreng"
				body = "Sekarang goreng telurnya! Klik Kompor lalu ketik 'goreng'."
			elif _view_has_ingredient_state(table, &"telur", SharedTypes.PrepState.RAW):
				target_id = &"work_table_stage"
				badge = "[3] Ambil Telur"
			elif not held.is_empty() and table.is_empty():
				target_id = &"work_table_stage"
				badge = "[3] Taruh Dulu"
				body = "Kosongkan tangan (klik Meja Kerja) dulu agar bisa mengambil 'telur' di Kotak Bahan."
			elif _storage_has_ingredient(&"telur"):
				target_id = _find_storage_with_ingredient(&"telur")
				badge = "[3] Ketik: telur"
			else:
				target_id = &"storage_box"
				badge = "[3] Ketik: beli"
				body = "Stok telur habis! Klik Kotak Bahan → ketik 'beli' untuk membeli telur."
		&"ch4_assemble":
			marker = "4"
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
					badge = "[4] Gabung Meja Kerja"
				else:
					target_id = &"plate_rack"
					badge = "[4] Klik Rak Piring"
			elif held_plate_id != &"" and held_parts.is_empty():
				if table_has_egg or table_has_rice:
					target_id = &"work_table_stage"
					badge = "[4] Klik Meja Kerja"
				else:
					target_id = &"rice_cooker"
					badge = "[4] Ketik: nasi"
			elif held_plate_id != &"" and held_has_egg and not held_has_rice:
				if table_has_rice:
					target_id = &"work_table_stage"
					badge = "[4] Gabung Nasi"
				else:
					target_id = &"rice_cooker"
					badge = "[4] Ketik: nasi"
			elif held_plate_id != &"" and held_has_rice and not held_has_egg:
				if table_has_egg:
					target_id = &"work_table_stage"
					badge = "[4] Gabung Telur"
				else:
					target_id = _find_storage_with_ingredient(&"telur")
					badge = "[4] Goreng Telur"
			elif not table.is_empty():
				target_id = &"work_table_stage" if table_plate_id != &"" else &"plate_rack"
				badge = "[4] Lanjut Rakit"
			else:
				target_id = &"plate_rack"
				badge = "[4] Klik Rak Piring"
		&"ch4_serve_dinein":
			marker = "4"
			if StringName(table.get("matched_recipe_id", &"")) == &"nasi_telor" and held.is_empty():
				target_id = &"work_table_stage"
				badge = "[4] Ambil Nasi Telor"
			else:
				target_id = _find_waiting_table_for_tutorial()
				badge = "[4] Ketik: saji"
		&"ch4_clean_and_wash":
			var dirty_tid := _find_dirty_table_for_tutorial()
			if bool(_tutorial_flags.get(&"table_cleaned", false)) or _washer_dirty_plate_count() > 0:
				marker = "4b"
				if not held.is_empty() and table.is_empty():
					target_id = &"work_table_stage"
					badge = "[4b] Taruh Dulu"
					body = "Kosongkan tangan di Meja Kerja sebelum mencuci piring di Wastafel."
				else:
					target_id = &"washer"
					badge = "[4b] Ketik: cuci"
					body = "Piring kotor masuk Wastafel. Kosongkan tangan → Wastafel → ketik 'cuci'."
			elif dirty_tid != &"":
				marker = "4a"
				target_id = dirty_tid
				badge = "[4a] Ketik: bersihkan"
				body = "Meja kotor! Klik meja tersebut lalu ketik 'bersihkan'."
			else:
				marker = "4"
				var eat_tid := _find_eating_table_for_tutorial()
				target_id = eat_tid if eat_tid != &"" else &"dining_table_01"
				badge = "[4] Tunggu Makan"
		&"ch5_accept_online":
			marker = "5"
			if phase == SharedTypes.Phase.PLANNING:
				target_id = &"ui_start_service"
				badge = "[5] Ketik: buka"
				allow_next = false
				body = "Stok siap untuk Hari ke-2! Ketik 'buka' untuk mencoba Pesanan Online saat warung buka."
			else:
				var ov := _service_controller.get_online_offer_view() if _service_controller != null else {}
				if bool(ov.get("acceptance_enabled", false)):
					target_id = &"online_station"
					badge = "[5] Ketik: terima"
					allow_next = false
				else:
					target_id = &"online_station"
					badge = "[5] Pantau Online"
					var rem := int(_service_controller.get_customer_queue_view().get("day_queue_remaining", 99)) if _service_controller != null else 99
					allow_next = rem <= 2
					if rem <= 2:
						body = "Kuota tamu hampir habis jadi tawaran online hari ini tutup. Klik 'Lewati Bab' atau lanjutkan berjualan."
					else:
						body = "Tunggu tawaran online muncul berkala di Meja Online, lalu klik & ketik 'terima'!"
		&"ch5_serve_online":
			marker = "5"
			target_id = _find_pickup_driver_for_tutorial()
			badge = "[5] Saji Pengantar" if target_id != &"" else "[5] Siapkan Order"
			allow_next = _service_controller != null and _service_controller.get_driver_views().is_empty()
		&"ch7_review_results":
			marker = "7"
			target_id = &"ui_day_result"
			badge = "[7] Hasil Hari"
			allow_next = (phase == SharedTypes.Phase.RESULTS or phase == SharedTypes.Phase.FINISHED)
			if not allow_next:
				body = "Selesaikan sisa pelanggan & pengantar hari ini sampai warung tutup otomatis, lalu tinjau Hasil Hari!"
		&"ch6_employee_overview":
			marker = "6"
			target_id = &"ui_employee_button"
			badge = "[6] Pegawai"
			allow_next = bool(_tutorial_flags.get(&"employee_inspected", false))
			if allow_next:
				body = "Bagus! Kamu sudah melihat menu Kelola Pegawai. Ingat: rekrut secukupnya saja. Klik 'Mengerti' untuk lanjut."
		&"ch8_ready":
			marker = "8"
			target_id = &"ui_fixture_shop_button"
			badge = "[8] Siap!"

	if not _tutorial_hint_text.is_empty() and step_id != &"ch1_objective" and phase != SharedTypes.Phase.RESULTS:
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


func _find_pickup_driver_for_tutorial() -> StringName:
	if _service_controller == null:
		return &""
	for dv in _service_controller.get_driver_views():
		if int(dv.get("state", dv.get("driver_state", -1))) == SharedTypes.DriverState.AT_PICKUP_SPOT:
			return StringName(dv.get("driver_id", &""))
	return &""


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
	var in_menu := is_main_menu_open()
	var story_open := is_story_open()
	var ref_open := is_reference_open()
	var modal_blocking := (
		in_menu
		or is_settings_open()
		or is_exit_confirm_open()
		or is_pause_open()
		or story_open
		or ref_open
	)

	if story_dialogue_overlay != null:
		story_dialogue_overlay.visible = (
			not in_menu and _onboarding_enabled and story_open and not paused
		)
		if story_dialogue_overlay.visible:
			_update_story_dialogue_view()

	if tutorial_reference_overlay != null:
		tutorial_reference_overlay.visible = (
			not in_menu
			and ref_open
			and (not paused or _reference_paused_by_self or _reference_return_to_pause)
			and not story_open
		)

	if tutorial_help_button != null:
		tutorial_help_button.visible = (
			not in_menu and _onboarding_enabled and not paused and not story_open
		)
		tutorial_help_button.text = "? Cara Main"
		KetikUiArt.apply_button_skin(tutorial_help_button, false, 6, 2)

	var show_tut_banner := (
		is_tutorial_active()
		and not modal_blocking
		and not paused
		and not is_edit_menu_open()
		and not is_ingredient_shop_open()
		and not is_fixture_shop_open()
		and not is_employee_shop_open()
	)
	if tutorial_banner != null:
		if show_tut_banner:
			_update_tutorial_banner_view()
		tutorial_banner.visible = show_tut_banner

	var show_tip := (
		_onboarding_enabled
		and _active_feature_tip_id != &""
		and not modal_blocking
		and not paused
	)
	if feature_tip_panel != null:
		feature_tip_panel.visible = show_tip

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
	if (
		not _onboarding_enabled
		or _is_gameplay_paused()
		or is_main_menu_open()
		or is_settings_open()
		or is_exit_confirm_open()
		or is_pause_open()
		or is_story_open()
		or is_reference_open()
		or is_edit_menu_open()
		or is_ingredient_shop_open()
		or is_fixture_shop_open()
		or is_employee_shop_open()
	):
		tutorial_guidance_overlay.clear_guidance()
		return

	var target_id: StringName = &""
	var marker := ""
	var badge := ""
	var accent := Color(0.32, 0.96, 0.62, 1.0)
	if _active_feature_tip_id != &"":
		var tip_d := _resolve_tip_guidance_detail(_active_feature_tip_id)
		if not tip_d.is_empty():
			target_id = StringName(tip_d.get("target_id", &""))
			marker = str(tip_d.get("marker", "!"))
			badge = str(tip_d.get("badge", ""))
			accent = Color(1.0, 0.82, 0.28, 1.0)
	if target_id == &"" and is_tutorial_active():
		var step_d := _resolve_step_guidance_detail()
		target_id = StringName(step_d.get("target_id", &""))
		marker = str(step_d.get("marker", ""))
		badge = str(step_d.get("badge", ""))

	if target_id == &"":
		tutorial_guidance_overlay.clear_guidance()
		return

	var resolved := _resolve_guidance_target_rect(target_id)
	var t_rect: Rect2 = resolved.get("rect", Rect2())
	var b_rect: Rect2 = resolved.get("bounds_rect", Rect2(Vector2.ZERO, _get_viewport_logical_size()))
	if t_rect.size.x <= 0.0 or t_rect.size.y <= 0.0:
		tutorial_guidance_overlay.clear_guidance()
		return

	var avoid := tutorial_banner.get_global_rect() if (tutorial_banner != null and tutorial_banner.visible) else Rect2()
	tutorial_guidance_overlay.set_guidance(
		target_id,
		t_rect,
		b_rect,
		badge,
		marker,
		accent,
		avoid,
		_is_gameplay_paused()
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
			return {}
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
		&"employee_hired":
			if phase == SharedTypes.Phase.PLANNING:
				return { "target_id": &"ui_employee_button", "marker": "!", "badge": "[Tip] Pegawai" }
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
		&"ui_fixture_shop_button":
			if fixture_shop_button != null and fixture_shop_button.is_visible_in_tree():
				return { "rect": fixture_shop_button.get_global_rect().grow(2.0), "bounds_rect": full_bounds }
			return {}
		&"ui_employee_button":
			if employee_button != null and employee_button.is_visible_in_tree():
				return { "rect": employee_button.get_global_rect().grow(2.0), "bounds_rect": full_bounds }
			return {}
		&"ui_floor_hint":
			if _world_map != null and is_instance_valid(_world_map):
				var floor_pt: Vector2 = _world_map.get_canvas_transform() * _world_map.cell_to_global(Vector2i(5, 3))
				return { "rect": Rect2(floor_pt - Vector2(14.0, 14.0), Vector2(28.0, 28.0)), "bounds_rect": world_bounds }
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
		var sw: float = clampf(world_w - 20.0, 220.0, 472.0)
		var sh: float = clampf(164.0 if vp_size.y >= 320.0 else 156.0, 136.0, vp_size.y - 20.0)
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
		var rw: float = clampf(world_w - 16.0, 220.0, 488.0)
		var rh: float = clampf(vp_size.y - 16.0, 220.0, 344.0)
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
