class_name RecipePartDef
extends Resource
## One required processed ingredient unit within a RecipeDef multiset.

@export var ingredient_id: StringName = &""
@export var required_state: SharedTypes.PrepState = SharedTypes.PrepState.COOKED
