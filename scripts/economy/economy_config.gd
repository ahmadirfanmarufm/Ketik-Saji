class_name EconomyConfig
extends Resource
## Static tunable economy, progression, pricing, and confirmed service timing config.
##
## Numeric balance values are prototype TUNING data (not final approved values).
## Confirmed live service durations default to 100s, 20s, 20s, 60s, 100s.

@export_group("Prototype Balance (TUNING)")
@export var starting_cash: int = 100000
@export var day_7_cash_target: int = 700000
@export var day_1_base_dinein_quota: int = 4
@export var arrival_increment_per_day: int = 4
@export var menu_demand_bonus_curve: Array[int] = [0, 4, 7, 8, 9]
@export var potential_demand_conversion_percent: int = 80
@export var online_sale_percent: int = 70
@export var fixture_resale_percent: int = 50
@export var plates_per_rack: int = 4
@export var rice_cooker_electricity_per_day: int = 2000
@export var fridge_electricity_per_day: int = 4000
@export var ingredient_buy_prices: Dictionary[StringName, int] = {}
@export var recipe_entries: Array[RecipeEconomyEntry] = []

@export_group("Workforce Balance (Less is More, More is Worse)")
@export var employee_cook_hire_cost: int = 60000
@export var employee_cook_daily_salary: int = 35000
@export var employee_cook_base_interval_seconds: float = 4.0
@export var employee_cashier_hire_cost: int = 45000
@export var employee_cashier_daily_salary: int = 28000
@export var employee_cashier_base_interval_seconds: float = 3.0
@export var employee_cashier_patience_bonus_seconds: float = 12.0
@export var employee_waiter_hire_cost: int = 50000
@export var employee_waiter_daily_salary: int = 30000
@export var employee_waiter_base_interval_seconds: float = 4.0
@export var employee_diminishing_weights: Array[float] = [1.0, 0.75, 0.50, 0.35]
@export var employee_crowding_threshold: int = 2
@export var employee_crowding_penalty_per_extra: float = 0.30
@export var employee_crowding_overhead_per_extra: int = 20000

@export_group("Confirmed Service Timings (Seconds)")
@export var diner_patience_seconds: float = 100.0
@export var diner_spawn_interval_seconds: float = 20.0
@export var diner_eat_seconds: float = 20.0
@export var online_deadline_seconds: float = 60.0
@export var service_delivery_seconds: float = 100.0

@export_group("Periodic Online Offer Timings (Seconds)")
@export var online_offer_initial_delay_seconds: float = 10.0
@export var online_offer_interval_seconds: float = 15.0
@export var online_offer_active_duration_seconds: float = 15.0


## Returns the RecipeEconomyEntry for `recipe_id`, or null if absent.
func get_recipe_entry(recipe_id: StringName) -> RecipeEconomyEntry:
	for entry in recipe_entries:
		if entry != null and entry.recipe_id == recipe_id:
			return entry
	return null


## Returns unit buy price for `ingredient_id`, or -1 if unconfigured.
func get_ingredient_price(ingredient_id: StringName) -> int:
	return int(ingredient_buy_prices.get(ingredient_id, -1))


## Returns supported employee role IDs in deterministic display order.
func get_employee_role_ids() -> Array[StringName]:
	return [&"cook", &"cashier", &"waiter"]


## Returns role metadata and TUNING economics for `role_id`, or {} if unknown.
func get_employee_role_def(role_id: StringName) -> Dictionary:
	match role_id:
		&"cook":
			return {
				"role_id": &"cook",
				"role_enum": SharedTypes.EmployeeRole.COOK,
				"display_name": "Koki",
				"hire_cost": employee_cook_hire_cost,
				"daily_salary": employee_cook_daily_salary,
				"base_interval_seconds": employee_cook_base_interval_seconds,
				"benefit_summary": "Cuci piring, isi rice cooker, dan masak bahan pesanan (telur/daging/ayam/tempe)",
			}
		&"cashier":
			return {
				"role_id": &"cashier",
				"role_enum": SharedTypes.EmployeeRole.CASHIER,
				"display_name": "Kasir",
				"hire_cost": employee_cashier_hire_cost,
				"daily_salary": employee_cashier_daily_salary,
				"base_interval_seconds": employee_cashier_base_interval_seconds,
				"patience_bonus_seconds": employee_cashier_patience_bonus_seconds,
				"benefit_summary": "Terima pesanan online saat tempat kosong dan perpanjang kesabaran tamu",
			}
		&"waiter":
			return {
				"role_id": &"waiter",
				"role_enum": SharedTypes.EmployeeRole.WAITER,
				"display_name": "Pelayan",
				"hire_cost": employee_waiter_hire_cost,
				"daily_salary": employee_waiter_daily_salary,
				"base_interval_seconds": employee_waiter_base_interval_seconds,
				"benefit_summary": "Bersihkan meja kotor dan antar hidangan matang di meja konter",
			}
	return {}


## Computes total effective throughput factor for `role_count` staff in one role
## while factoring diminishing marginal gains and kitchen crowding penalties.
func compute_effective_role_factor(role_count: int, total_employees: int) -> float:
	if role_count <= 0 or employee_diminishing_weights.is_empty():
		return 0.0
	var raw_factor := 0.0
	for idx in range(role_count):
		var w_idx := mini(idx, employee_diminishing_weights.size() - 1)
		raw_factor += maxf(0.05, float(employee_diminishing_weights[w_idx]))
	var extra_crowding := maxi(0, total_employees - employee_crowding_threshold)
	var crowding_divisor := 1.0 + float(extra_crowding) * maxf(0.0, employee_crowding_penalty_per_extra)
	return raw_factor / maxf(1.0, crowding_divisor)


## Computes effective crowding multiplier (> 1.0 indicates slower coordination).
func compute_crowding_multiplier(total_employees: int) -> float:
	var extra_crowding := maxi(0, total_employees - employee_crowding_threshold)
	return 1.0 + float(extra_crowding) * maxf(0.0, employee_crowding_penalty_per_extra)


## Computes extra daily coordination overhead when active staff exceeds crowding threshold.
func compute_crowding_overhead(total_employees: int) -> int:
	var extra_crowding := maxi(0, total_employees - employee_crowding_threshold)
	return extra_crowding * maxi(0, employee_crowding_overhead_per_extra)


## Returns recipe IDs unlocked on or before `day_index`, preserving entry order.
func get_unlocked_recipe_ids(day_index: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in recipe_entries:
		if entry != null and entry.recipe_id != &"" and entry.unlock_day <= day_index:
			result.append(entry.recipe_id)
	return result


## Returns cumulative diminishing Potential Demand bonus for `active_recipe_count`.
func get_menu_demand_bonus(active_recipe_count: int) -> int:
	if active_recipe_count <= 1 or menu_demand_bonus_curve.is_empty():
		return 0
	var idx := mini(active_recipe_count - 1, menu_demand_bonus_curve.size() - 1)
	return maxi(0, int(menu_demand_bonus_curve[idx]))


## Validates static data integrity and referential IDs across catalogs.
## Returns { "errors": PackedStringArray, "warnings": PackedStringArray }.
func validate(
	ingredients: Array[IngredientDef],
	recipes: Array[RecipeDef],
	utilities: Array[UtilityDef]
) -> Dictionary:
	var errors := PackedStringArray()
	var warnings := PackedStringArray()

	var ingredients_by_id: Dictionary[StringName, IngredientDef] = {}
	for ingredient in ingredients:
		if ingredient == null:
			errors.append("Catalog contains null IngredientDef.")
			continue
		errors.append_array(ingredient.validate())
		if ingredient.ingredient_id != &"":
			if ingredients_by_id.has(ingredient.ingredient_id):
				errors.append("Duplicate ingredient_id '%s'." % ingredient.ingredient_id)
			else:
				ingredients_by_id[ingredient.ingredient_id] = ingredient

	var recipes_by_id: Dictionary[StringName, RecipeDef] = {}
	for recipe in recipes:
		if recipe == null:
			errors.append("Catalog contains null RecipeDef.")
			continue
		errors.append_array(recipe.validate(ingredients_by_id))
		if recipe.recipe_id != &"":
			if recipes_by_id.has(recipe.recipe_id):
				errors.append("Duplicate recipe_id '%s'." % recipe.recipe_id)
			else:
				recipes_by_id[recipe.recipe_id] = recipe

	var utilities_by_id: Dictionary[StringName, UtilityDef] = {}
	for utility in utilities:
		if utility == null:
			errors.append("Catalog contains null UtilityDef.")
			continue
		errors.append_array(utility.validate())
		if utility.utility_id != &"":
			if utilities_by_id.has(utility.utility_id):
				errors.append("Duplicate utility_id '%s'." % utility.utility_id)
			else:
				utilities_by_id[utility.utility_id] = utility

	_validate_balance_fields(errors)
	_validate_prices(ingredients_by_id, errors)
	_validate_recipe_entries(recipes_by_id, errors, warnings)
	return { "errors": errors, "warnings": warnings }


func _validate_balance_fields(errors: PackedStringArray) -> void:
	if day_7_cash_target <= 0:
		errors.append("EconomyConfig: day_7_cash_target must be > 0.")
	if day_1_base_dinein_quota < 0 or arrival_increment_per_day < 0:
		errors.append("EconomyConfig: dine-in quota values must be >= 0.")
	if potential_demand_conversion_percent <= 0 or potential_demand_conversion_percent > 100:
		errors.append("EconomyConfig: potential_demand_conversion_percent must be in (0, 100].")
	if menu_demand_bonus_curve.is_empty():
		errors.append("EconomyConfig: menu_demand_bonus_curve must not be empty.")
	else:
		if int(menu_demand_bonus_curve[0]) != 0:
			errors.append("EconomyConfig: menu_demand_bonus_curve[0] (1 recipe) must be 0.")
		for i in range(1, menu_demand_bonus_curve.size()):
			var prev_val := int(menu_demand_bonus_curve[i - 1])
			var curr_val := int(menu_demand_bonus_curve[i])
			if curr_val < prev_val:
				errors.append("EconomyConfig: menu_demand_bonus_curve must be non-decreasing.")
				break
			if i >= 2:
				var prev_inc := prev_val - int(menu_demand_bonus_curve[i - 2])
				var curr_inc := curr_val - prev_val
				if curr_inc > prev_inc:
					errors.append(
						"EconomyConfig: menu_demand_bonus_curve increments must diminish."
					)
					break
	if online_sale_percent <= 0 or online_sale_percent >= 100:
		errors.append("EconomyConfig: online_sale_percent must be in (0, 100).")
	if fixture_resale_percent < 0 or fixture_resale_percent >= 100:
		errors.append("EconomyConfig: fixture_resale_percent must be in [0, 100).")
	if plates_per_rack <= 0:
		errors.append("EconomyConfig: plates_per_rack must be > 0.")
	if rice_cooker_electricity_per_day < 0 or fridge_electricity_per_day < 0:
		errors.append("EconomyConfig: electricity rates must be >= 0.")
	if (
		employee_cook_hire_cost <= 0
		or employee_cashier_hire_cost <= 0
		or employee_waiter_hire_cost <= 0
	):
		errors.append("EconomyConfig: employee hire costs must be > 0.")
	if (
		employee_cook_daily_salary < 0
		or employee_cashier_daily_salary < 0
		or employee_waiter_daily_salary < 0
		or employee_crowding_overhead_per_extra < 0
	):
		errors.append("EconomyConfig: employee daily salaries must be >= 0.")
	if (
		employee_cook_base_interval_seconds <= 0.0
		or employee_cashier_base_interval_seconds <= 0.0
		or employee_waiter_base_interval_seconds <= 0.0
	):
		errors.append("EconomyConfig: employee task intervals must be > 0.")
	if employee_diminishing_weights.is_empty():
		errors.append("EconomyConfig: employee_diminishing_weights must not be empty.")
	else:
		for i in range(employee_diminishing_weights.size()):
			var w := float(employee_diminishing_weights[i])
			if w <= 0.0:
				errors.append("EconomyConfig: employee_diminishing_weights must be > 0.")
				break
			if i > 0 and w > float(employee_diminishing_weights[i - 1]):
				errors.append("EconomyConfig: employee_diminishing_weights must not increase.")
				break
	if (
		diner_patience_seconds <= 0.0
		or diner_spawn_interval_seconds <= 0.0
		or diner_eat_seconds <= 0.0
		or online_deadline_seconds <= 0.0
		or service_delivery_seconds <= 0.0
	):
		errors.append("EconomyConfig: all timing durations must be > 0.")
	if (
		online_offer_initial_delay_seconds <= 0.0
		or online_offer_interval_seconds <= 0.0
		or online_offer_active_duration_seconds <= 0.0
	):
		errors.append("EconomyConfig: all periodic online offer timings must be > 0.")


func _validate_prices(
	ingredients_by_id: Dictionary[StringName, IngredientDef],
	errors: PackedStringArray
) -> void:
	for ingredient_id in ingredients_by_id:
		if get_ingredient_price(ingredient_id) <= 0:
			errors.append(
				"EconomyConfig: missing/nonpositive price for ingredient '%s'." % ingredient_id
			)
	for price_key: StringName in ingredient_buy_prices:
		if not ingredients_by_id.has(price_key):
			errors.append(
				"EconomyConfig: price configured for unknown ingredient '%s'." % price_key
			)


func _validate_recipe_entries(
	recipes_by_id: Dictionary[StringName, RecipeDef],
	errors: PackedStringArray,
	warnings: PackedStringArray
) -> void:
	var seen_entries: Dictionary[StringName, bool] = {}
	var max_unlock_day: int = 0
	for i in range(recipe_entries.size()):
		var entry := recipe_entries[i]
		if entry == null:
			errors.append("EconomyConfig: null RecipeEconomyEntry at %d." % i)
			continue
		errors.append_array(entry.validate(recipes_by_id))
		if entry.recipe_id != &"":
			if seen_entries.has(entry.recipe_id):
				errors.append(
					"EconomyConfig: duplicate entry for recipe_id '%s'." % entry.recipe_id
				)
			seen_entries[entry.recipe_id] = true
		max_unlock_day = maxi(max_unlock_day, entry.unlock_day)

	if recipe_entries.is_empty():
		errors.append("EconomyConfig: recipe_entries must contain at least one recipe.")
	elif recipe_entries.size() < 7 or max_unlock_day < 7:
		warnings.append(
			"CONTENT PENDING: %d recipe(s) authored (max unlock_day %d); Days 4-7 pending." % [
				recipe_entries.size(), max_unlock_day
			]
		)
