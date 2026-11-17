extends SceneTree
## Headless verification for Track A3: SharedTypes enums and static .tres resources.

const INGREDIENT_IDS: Array[StringName] = [
	&"beras",
	&"telur",
	&"ayam",
	&"tempe",
	&"sayur",
	&"sapi",
]

const RECIPE_IDS: Array[StringName] = [
	&"nasi_telor",
	&"nasi_ayam",
	&"nasi_komplit",
]

const UTILITY_IDS: Array[StringName] = [
	&"box",
	&"fridge",
	&"stove",
	&"washer",
	&"plate_rack",
	&"rice_cooker",
	&"dining_table",
]

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	_test_shared_types()
	var ingredients := _test_ingredients()
	var recipes := _test_recipes(ingredients)
	var utilities := _test_utilities()
	_test_economy_config(ingredients, recipes, utilities)
	_test_validation_negatives(ingredients, recipes, utilities)
	print("SUMMARY fails=%d" % _fails)
	quit(_fails)


func _test_shared_types() -> void:
	_check("Phase enum size", SharedTypes.Phase.size() == 5)
	_check("OrderKind enum size", SharedTypes.OrderKind.size() == 2)
	_check("OrderStatus enum size", SharedTypes.OrderStatus.size() == 3)
	_check("CustomerState enum size", SharedTypes.CustomerState.size() == 4)
	_check("TableState enum size", SharedTypes.TableState.size() == 4)
	_check("DriverState enum size", SharedTypes.DriverState.size() == 2)
	_check("FixtureKind enum size", SharedTypes.FixtureKind.size() == 7)
	_check("PrepState enum size", SharedTypes.PrepState.size() == 6)
	_check("DayOutcome enum size", SharedTypes.DayOutcome.size() == 3)


func _test_ingredients() -> Array[IngredientDef]:
	var list: Array[IngredientDef] = []
	var by_id: Dictionary[StringName, IngredientDef] = {}
	for id in INGREDIENT_IDS:
		var res := load("res://data/ingredients/%s.tres" % id) as IngredientDef
		_check("load ingredient " + String(id), res != null)
		if res == null:
			continue
		_check(
			"ingredient valid " + String(id),
			res.ingredient_id == id and res.validate().is_empty()
		)
		list.append(res)
		by_id[id] = res

	var beras := by_id.get(&"beras") as IngredientDef
	if beras != null:
		_check(
			"beras RAW->cuci->WASHED",
			beras.can_transition(SharedTypes.PrepState.RAW, &"cuci")
			and beras.get_next_state(SharedTypes.PrepState.RAW, &"cuci")
				== SharedTypes.PrepState.WASHED
		)
		_check(
			"beras WASHED->masak->COOKED_RICE",
			beras.get_next_state(SharedTypes.PrepState.WASHED, &"masak")
				== SharedTypes.PrepState.COOKED_RICE
		)
		_check(
			"beras RAW cannot masak",
			not beras.can_transition(SharedTypes.PrepState.RAW, &"masak")
			and beras.get_next_state(SharedTypes.PrepState.RAW, &"masak") == -1
		)

	var sayur := by_id.get(&"sayur") as IngredientDef
	if sayur != null:
		_check(
			"sayur RAW->potong->CHOPPED",
			sayur.get_next_state(SharedTypes.PrepState.RAW, &"potong")
				== SharedTypes.PrepState.CHOPPED
		)
		_check(
			"sayur CHOPPED->goreng->CHOPPED_AND_COOKED",
			sayur.get_next_state(SharedTypes.PrepState.CHOPPED, &"goreng")
				== SharedTypes.PrepState.CHOPPED_AND_COOKED
		)
		_check(
			"sayur RAW->goreng->COOKED",
			sayur.get_next_state(SharedTypes.PrepState.RAW, &"goreng")
				== SharedTypes.PrepState.COOKED
		)

	var ayam := by_id.get(&"ayam") as IngredientDef
	var telur := by_id.get(&"telur") as IngredientDef
	var tempe := by_id.get(&"tempe") as IngredientDef
	var sapi := by_id.get(&"sapi") as IngredientDef
	_check(
		"ayam maps raw chicken.png and cooked chicken.png",
		ayam != null
		and ayam.get_texture_for_state(SharedTypes.PrepState.RAW) != null
		and ayam.get_texture_for_state(SharedTypes.PrepState.RAW).resource_path
			== "res://assets/art/ingredients/raw chicken.png"
		and ayam.get_texture_for_state(SharedTypes.PrepState.COOKED) != null
		and ayam.get_texture_for_state(SharedTypes.PrepState.COOKED).resource_path
			== "res://assets/art/ingredients/cooked chicken.png"
	)
	_check(
		"telur maps raw egg.png and cooked egg.png",
		telur != null
		and telur.get_texture_for_state(SharedTypes.PrepState.RAW) != null
		and telur.get_texture_for_state(SharedTypes.PrepState.RAW).resource_path
			== "res://assets/art/ingredients/raw egg.png"
		and telur.get_texture_for_state(SharedTypes.PrepState.COOKED) != null
		and telur.get_texture_for_state(SharedTypes.PrepState.COOKED).resource_path
			== "res://assets/art/ingredients/cooked egg.png"
	)
	_check(
		"tempe maps raw tempe.png and cooked tempe.png",
		tempe != null
		and tempe.get_texture_for_state(SharedTypes.PrepState.RAW) != null
		and tempe.get_texture_for_state(SharedTypes.PrepState.RAW).resource_path
			== "res://assets/art/ingredients/raw tempe.png"
		and tempe.get_texture_for_state(SharedTypes.PrepState.COOKED) != null
		and tempe.get_texture_for_state(SharedTypes.PrepState.COOKED).resource_path
			== "res://assets/art/ingredients/cooked tempe.png"
	)
	_check(
		"beras maps rice.png icon/COOKED_RICE without fabricated raw texture",
		beras != null
		and beras.icon != null
		and beras.icon.resource_path == "res://assets/art/ingredients/rice.png"
		and beras.raw_texture == null
		and beras.get_texture_for_state(SharedTypes.PrepState.COOKED_RICE) == beras.icon
	)
	_check(
		"sayur maps veggies.png icon/RAW without fabricated cooked texture",
		sayur != null
		and sayur.icon != null
		and sayur.icon.resource_path == "res://assets/art/ingredients/veggies.png"
		and sayur.raw_texture == sayur.icon
		and sayur.cooked_texture == null
	)
	_check(
		"sapi leaves unconfirmed meat textures unassigned",
		sapi != null
		and sapi.icon == null
		and sapi.raw_texture == null
		and sapi.cooked_texture == null
	)

	return list


func _test_recipes(ingredients: Array[IngredientDef]) -> Array[RecipeDef]:
	var ing_map: Dictionary = {}
	for ing in ingredients:
		ing_map[ing.ingredient_id] = ing

	var list: Array[RecipeDef] = []
	for id in RECIPE_IDS:
		var res := load("res://data/recipes/%s.tres" % id) as RecipeDef
		_check("load recipe " + String(id), res != null)
		if res == null:
			continue
		_check(
			"recipe valid " + String(id),
			res.recipe_id == id and res.validate(ing_map).is_empty()
		)
		_check("recipe has no unlock_day field", not ("unlock_day" in res))
		list.append(res)

	if list.size() == 3:
		_check("nasi_telor 2 parts", list[0].required_parts.size() == 2)
		_check("nasi_ayam 3 parts", list[1].required_parts.size() == 3)
		_check("nasi_komplit 5 parts", list[2].required_parts.size() == 5)

	return list


func _test_utilities() -> Array[UtilityDef]:
	var list: Array[UtilityDef] = []
	for id in UTILITY_IDS:
		var res := load("res://data/utilities/%s.tres" % id) as UtilityDef
		_check("load utility " + String(id), res != null)
		if res == null:
			continue
		_check(
			"utility valid " + String(id),
			res.utility_id == id
			and res.footprint == Vector2i.ONE
			and res.validate().is_empty()
		)
		list.append(res)
	return list


func _test_economy_config(
	ingredients: Array[IngredientDef],
	recipes: Array[RecipeDef],
	utilities: Array[UtilityDef]
) -> void:
	var cfg := load("res://data/economy_config.tres") as EconomyConfig
	_check("load economy_config", cfg != null)
	if cfg == null:
		return

	var report := cfg.validate(ingredients, recipes, utilities)
	var errors: PackedStringArray = report["errors"]
	var warnings: PackedStringArray = report["warnings"]
	_check("economy_config validate 0 errors", errors.is_empty())
	_check("economy_config emits Days 4-7 content warning", warnings.size() == 1)

	var e1 := cfg.get_recipe_entry(&"nasi_telor")
	_check(
		"nasi_telor entry day 1 Rp20000",
		e1 != null and e1.unlock_day == 1 and e1.dine_in_price == 20000
	)
	_check("day 1 unlocked count == 1", cfg.get_unlocked_recipe_ids(1).size() == 1)
	_check("day 3 unlocked count == 3", cfg.get_unlocked_recipe_ids(3).size() == 3)
	_check("confirmed timings unchanged", is_equal_approx(cfg.diner_patience_seconds, 100.0)
		and is_equal_approx(cfg.online_deadline_seconds, 60.0))


func _test_validation_negatives(
	ingredients: Array[IngredientDef],
	recipes: Array[RecipeDef],
	utilities: Array[UtilityDef]
) -> void:
	var cfg := load("res://data/economy_config.tres") as EconomyConfig
	if cfg == null:
		return

	var bad_cfg := cfg.duplicate(true) as EconomyConfig
	var ghost_entry := RecipeEconomyEntry.new()
	ghost_entry.recipe_id = &"nonexistent_dish"
	ghost_entry.unlock_day = 4
	ghost_entry.dine_in_price = 15000
	bad_cfg.recipe_entries.append(ghost_entry)
	var bad_report := bad_cfg.validate(ingredients, recipes, utilities)
	_check(
		"rejects dangling RecipeEconomyEntry.recipe_id",
		not (bad_report["errors"] as PackedStringArray).is_empty()
	)

	var bad_part := RecipePartDef.new()
	bad_part.ingredient_id = &"unknown_ing"
	var bad_recipe := RecipeDef.new()
	bad_recipe.recipe_id = &"bad_dish"
	bad_recipe.display_name = "Bad"
	bad_recipe.icon_key = &"bad_dish"
	bad_recipe.required_parts = [bad_part]
	_check(
		"rejects unknown recipe ingredient",
		not bad_recipe.validate({"beras": ingredients[0]}).is_empty()
	)
