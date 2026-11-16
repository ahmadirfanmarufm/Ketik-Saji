class_name IngredientTransition
extends Resource
## Immutable preparation step rule mapping (from_state, command) -> to_state.

@export var from_state: SharedTypes.PrepState = SharedTypes.PrepState.RAW
@export var command: StringName = &""
@export var to_state: SharedTypes.PrepState = SharedTypes.PrepState.RAW
