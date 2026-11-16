class_name IngredientDef
extends Resource
## Static ingredient definition and legal kitchen preparation transitions.
##
## Read-only at runtime. Holds no pricing data (owned by EconomyConfig) and no
## runtime stock counts.

@export var ingredient_id: StringName = &""
@export var display_name: String = ""
@export var transitions: Array[IngredientTransition] = []


## True when applying `command` to this ingredient in `from_state` is valid.
func can_transition(from_state: SharedTypes.PrepState, command: StringName) -> bool:
	return _find_transition(from_state, command) != null


## Resulting PrepState when applying `command` from `from_state`, or -1 if illegal.
func get_next_state(from_state: SharedTypes.PrepState, command: StringName) -> int:
	var transition := _find_transition(from_state, command)
	if transition == null:
		return -1
	return transition.to_state


## True when `state` is RAW or appears as a transition endpoint for this ingredient.
func is_valid_state(state: SharedTypes.PrepState) -> bool:
	if state == SharedTypes.PrepState.RAW:
		return true
	for transition in transitions:
		if transition == null:
			continue
		if transition.from_state == state or transition.to_state == state:
			return true
	return false


## Returns validation error messages; empty array means this definition is valid.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if ingredient_id == &"":
		errors.append("IngredientDef: ingredient_id must not be empty.")
	if display_name.strip_edges().is_empty():
		errors.append("IngredientDef '%s': display_name must not be empty." % ingredient_id)

	var seen_rules: Dictionary[String, bool] = {}
	for i in range(transitions.size()):
		var transition := transitions[i]
		if transition == null:
			errors.append("IngredientDef '%s': null transition at %d." % [ingredient_id, i])
			continue
		if transition.command == &"":
			errors.append(
				"IngredientDef '%s': empty command at transition %d." % [ingredient_id, i]
			)
			continue
		if transition.from_state == transition.to_state:
			errors.append(
				"IngredientDef '%s': transition %d has identical states." % [ingredient_id, i]
			)
		var rule_key := "%d:%s" % [transition.from_state, transition.command]
		if seen_rules.has(rule_key):
			errors.append(
				"IngredientDef '%s': duplicate rule '%s'." % [ingredient_id, rule_key]
			)
		seen_rules[rule_key] = true

	return errors


func _find_transition(
	from_state: SharedTypes.PrepState,
	command: StringName
) -> IngredientTransition:
	if command == &"":
		return null
	for transition in transitions:
		if transition == null:
			continue
		if transition.from_state == from_state and transition.command == command:
			return transition
	return null
