class_name RecipeEconomyEntry
extends Resource
## Progression and pricing entry inside EconomyConfig referencing a RecipeDef by ID.

@export var recipe_id: StringName = &""
@export var unlock_day: int = 1
@export var dine_in_price: int = 0


## Returns validation errors against `recipes_by_id` (StringName -> RecipeDef).
func validate(recipes_by_id: Dictionary = {}) -> PackedStringArray:
	var errors := PackedStringArray()
	if recipe_id == &"":
		errors.append("RecipeEconomyEntry: recipe_id must not be empty.")
	elif not recipes_by_id.is_empty() and not recipes_by_id.has(recipe_id):
		errors.append(
			"RecipeEconomyEntry: recipe_id '%s' does not match any RecipeDef." % recipe_id
		)
	if unlock_day < 1:
		errors.append(
			"RecipeEconomyEntry '%s': unlock_day must be >= 1." % recipe_id
		)
	if dine_in_price <= 0:
		errors.append(
			"RecipeEconomyEntry '%s': dine_in_price must be > 0." % recipe_id
		)
	return errors
