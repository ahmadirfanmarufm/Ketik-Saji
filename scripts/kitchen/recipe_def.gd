class_name RecipeDef
extends Resource
## Static recipe definition describing display identity, icon key, and exact parts.
##
## Read-only at runtime. Holds no pricing or unlock_day data (those live in
## RecipeEconomyEntry inside EconomyConfig, referencing recipe_id).

@export var recipe_id: StringName = &""
@export var display_name: String = ""
@export var icon_key: StringName = &""
@export var icon: Texture2D = null
@export_multiline var description: String = ""
@export var required_parts: Array[RecipePartDef] = []


## Returns validation errors against `ingredients_by_id` (StringName -> IngredientDef).
func validate(ingredients_by_id: Dictionary = {}) -> PackedStringArray:
	var errors := PackedStringArray()
	if recipe_id == &"":
		errors.append("RecipeDef: recipe_id must not be empty.")
	if display_name.strip_edges().is_empty():
		errors.append("RecipeDef '%s': display_name must not be empty." % recipe_id)
	if icon_key == &"":
		errors.append("RecipeDef '%s': icon_key must not be empty." % recipe_id)
	if required_parts.is_empty():
		errors.append("RecipeDef '%s': required_parts must not be empty." % recipe_id)
		return errors

	for i in range(required_parts.size()):
		var part := required_parts[i]
		if part == null:
			errors.append("RecipeDef '%s': null required_part at %d." % [recipe_id, i])
			continue
		if part.ingredient_id == &"":
			errors.append(
				"RecipeDef '%s': empty ingredient_id at part %d." % [recipe_id, i]
			)
			continue
		if not ingredients_by_id.is_empty():
			var ingredient := ingredients_by_id.get(part.ingredient_id) as IngredientDef
			if ingredient == null:
				errors.append(
					"RecipeDef '%s': unknown ingredient_id '%s'." % [
						recipe_id, part.ingredient_id
					]
				)
			elif not ingredient.is_valid_state(part.required_state):
				errors.append(
					"RecipeDef '%s': invalid state %d for '%s'." % [
						recipe_id, part.required_state, part.ingredient_id
					]
				)

	return errors
