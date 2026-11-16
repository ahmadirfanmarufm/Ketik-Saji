class_name UtilityDef
extends Resource
## Static fixture/utility catalog definition (footprint in tile units, pricing, power).
##
## Read-only at runtime. Allowed PlacementSlot restrictions live on map slots,
## not inside UtilityDef.

@export var utility_id: StringName = &""
@export var display_name: String = ""
@export var fixture_kind: SharedTypes.FixtureKind = SharedTypes.FixtureKind.BOX
@export var footprint: Vector2i = Vector2i.ONE
@export var purchase_price: int = 0
@export var daily_electricity_cost: int = 0
@export var plates_per_rack: int = 0


## Returns validation errors; empty array means this definition is valid.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if utility_id == &"":
		errors.append("UtilityDef: utility_id must not be empty.")
	if display_name.strip_edges().is_empty():
		errors.append("UtilityDef '%s': display_name must not be empty." % utility_id)
	if footprint.x <= 0 or footprint.y <= 0:
		errors.append(
			"UtilityDef '%s': footprint must be positive, got %s." % [utility_id, footprint]
		)
	if purchase_price < 0:
		errors.append(
			"UtilityDef '%s': purchase_price must be >= 0." % utility_id
		)
	if daily_electricity_cost < 0:
		errors.append(
			"UtilityDef '%s': daily_electricity_cost must be >= 0." % utility_id
		)
	if plates_per_rack < 0:
		errors.append(
			"UtilityDef '%s': plates_per_rack must be >= 0." % utility_id
		)
	if fixture_kind == SharedTypes.FixtureKind.PLATE_RACK and plates_per_rack <= 0:
		errors.append(
			"UtilityDef '%s': PLATE_RACK requires plates_per_rack > 0." % utility_id
		)
	return errors
