class_name WorldGrid
extends RefCounted
## Pure spatial data for the restaurant grid: coordinate conversion, bounds,
## floor walkability and footprint occupancy.
##
## Coordinate convention: cell (0, 0) is the top-left cell; x grows right and
## y grows down. All positions here are in the owning WorldMap's LOCAL space
## (cell (0, 0) starts at local (0, 0)). WorldMap converts to/from global space.
##
## This class only answers spatial questions. It does not move anything and
## does not decide which cells an actor may use.

## Cardinal neighbor order is fixed so results are deterministic: up, right, down, left.
const CARDINAL_OFFSETS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]

var size: Vector2i
var tile_size: Vector2i

var _valid: bool = false
var _walkable_cells: Dictionary[Vector2i, bool] = {}
var _occupant_by_cell: Dictionary[Vector2i, StringName] = {}
var _cells_by_occupant: Dictionary[StringName, Array] = {}


func _init(grid_size: Vector2i = Vector2i(12, 9), cell_size: Vector2i = Vector2i(32, 32)) -> void:
	var valid_grid := grid_size.x > 0 and grid_size.y > 0
	var valid_tile := cell_size.x > 0 and cell_size.y > 0
	if not valid_grid:
		push_error("WorldGrid: grid_size must be positive, got %s." % grid_size)
	if not valid_tile:
		push_error("WorldGrid: tile_size must be positive, got %s." % cell_size)

	_valid = valid_grid and valid_tile
	if not _valid:
		size = Vector2i.ZERO
		tile_size = Vector2i.ZERO
		return

	size = grid_size
	tile_size = cell_size


## True when both grid_size and tile_size were initialized with positive dimensions.
func is_valid() -> bool:
	return _valid


func is_in_bounds(cell: Vector2i) -> bool:
	if not _valid:
		return false
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


## Local-space center of a cell. Valid for out-of-bounds cells too.
## Returns Vector2.ZERO if the grid was initialized with invalid dimensions.
func cell_to_local(cell: Vector2i) -> Vector2:
	if not _valid:
		return Vector2.ZERO
	return Vector2(cell * tile_size) + Vector2(tile_size) * 0.5


## Cell containing a local-space position. May return an out-of-bounds cell.
## Returns Vector2i(-1, -1) if the grid was initialized with invalid dimensions.
func local_to_cell(local_position: Vector2) -> Vector2i:
	if not _valid:
		return Vector2i(-1, -1)
	return Vector2i(
		floori(local_position.x / tile_size.x),
		floori(local_position.y / tile_size.y)
	)


## Local-space rectangle covered by a block of cells.
## Returns an empty Rect2 if the grid was initialized with invalid dimensions.
func cell_rect_to_local(cell_rect: Rect2i) -> Rect2:
	if not _valid:
		return Rect2()
	return Rect2(Vector2(cell_rect.position * tile_size), Vector2(cell_rect.size * tile_size))


## Marks one floor cell walkable or not. Returns false if the cell is out of bounds.
func set_walkable(cell: Vector2i, walkable: bool) -> bool:
	if not is_in_bounds(cell):
		return false

	if walkable:
		_walkable_cells[cell] = true
	else:
		_walkable_cells.erase(cell)
	return true


## Marks every in-bounds cell of a rect walkable or not. Out-of-bounds cells are ignored.
func set_walkable_rect(cell_rect: Rect2i, walkable: bool) -> void:
	if not _valid:
		return
	for y in range(cell_rect.position.y, cell_rect.end.y):
		for x in range(cell_rect.position.x, cell_rect.end.x):
			set_walkable(Vector2i(x, y), walkable)


## True for an in-bounds floor cell, regardless of occupancy.
func is_walkable(cell: Vector2i) -> bool:
	return _walkable_cells.has(cell)


func is_occupied(cell: Vector2i) -> bool:
	return _occupant_by_cell.has(cell)


## ID of the object whose footprint covers the cell, or &"" if none.
func get_occupant(cell: Vector2i) -> StringName:
	return _occupant_by_cell.get(cell, &"")


## True for a walkable cell that no footprint covers.
func is_free(cell: Vector2i) -> bool:
	return is_walkable(cell) and not is_occupied(cell)


## Claims cells for an object ID. All-or-nothing: returns false and changes
## nothing if the ID is empty or already has a footprint, the cell list is
## empty or contains duplicates, or any cell is out of bounds or occupied.
func occupy(occupant_id: StringName, cells: Array[Vector2i]) -> bool:
	if occupant_id == &"" or cells.is_empty():
		return false

	if _cells_by_occupant.has(occupant_id):
		return false

	var seen: Dictionary[Vector2i, bool] = {}
	for cell in cells:
		if not is_in_bounds(cell) or is_occupied(cell) or seen.has(cell):
			return false
		seen[cell] = true

	for cell in cells:
		_occupant_by_cell[cell] = occupant_id
	_cells_by_occupant[occupant_id] = cells.duplicate()
	return true


## Frees an object's footprint. Returns false if the ID has none.
func release(occupant_id: StringName) -> bool:
	if not _cells_by_occupant.has(occupant_id):
		return false

	for cell: Vector2i in _cells_by_occupant[occupant_id]:
		_occupant_by_cell.erase(cell)
	_cells_by_occupant.erase(occupant_id)
	return true


## Copy of an object's footprint cells, empty if it has none.
func get_footprint(occupant_id: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if _cells_by_occupant.has(occupant_id):
		result.assign(_cells_by_occupant[occupant_id])
	return result


## In-bounds orthogonal neighbors in the fixed order up, right, down, left.
func get_cardinal_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in CARDINAL_OFFSETS:
		var neighbor: Vector2i = cell + offset
		if is_in_bounds(neighbor):
			result.append(neighbor)
	return result


## In-bounds cardinal neighbors of a multi-cell footprint, excluding the
## footprint itself. No duplicates; ordered by footprint order, then up/right/down/left.
## Callers filter with is_free() and choose among the results.
func get_footprint_neighbors(footprint: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in footprint:
		for neighbor in get_cardinal_neighbors(cell):
			if not footprint.has(neighbor) and not result.has(neighbor):
				result.append(neighbor)
	return result
