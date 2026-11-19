extends SceneTree
## Headless tests for Milestone 0 World Hierarchy Migration: canonical containers,
## WorkTable split targets, OnlineStation, PlacementSlots metadata, and stateless
## spatial neighbor/Manhattan queries.

const CANONICAL_CONTAINERS: Array[String] = [
	"FloorTiles",
	"DineInWaitingAnchors",
	"Player",
	"KitchenStations",
	"KitchenWorkTables",
	"DiningTables",
	"OnlineStation",
	"DriverPickupSpots",
	"DriverOverflowAnchors",
	"DriverObjects",
	"PlacementSlots",
	"Decorations",
]

const INTERACTABLE_IDS: Array[StringName] = [
	&"storage_box",
	&"stove",
	&"washer",
	&"plate_rack",
	&"rice_cooker",
	&"trash",
	&"work_table",
	&"work_table_stage",
	&"work_table_chop",
	&"dining_table_01",
	&"dining_table_02",
	&"online_station",
]

const PICKUP_SPOT_IDS: Array[StringName] = [
	&"pickup_spot_01",
	&"pickup_spot_02",
	&"pickup_spot_03",
]

const WAITING_ANCHOR_IDS: Array[StringName] = [
	&"dine_in_wait_01",
	&"dine_in_wait_02",
	&"dine_in_wait_03",
	&"dine_in_wait_04",
]

const SLOT_IDS: Array[StringName] = [
	&"slot_utility_01",
	&"slot_utility_02",
	&"slot_utility_03",
	&"slot_utility_04",
	&"slot_utility_05",
	&"slot_table_01",
	&"slot_table_02",
	&"slot_table_03",
	&"slot_table_04",
	&"slot_table_05",
	&"slot_table_06",
]

const EXPECTED_FIXTURE_CELLS: Dictionary[StringName, Vector2i] = {
	&"washer": Vector2i(0, 0),
	&"stove": Vector2i(1, 0),
	&"rice_cooker": Vector2i(2, 0),
	&"storage_box": Vector2i(3, 0),
	&"plate_rack": Vector2i(4, 0),
	&"trash": Vector2i(7, 0),
	&"work_table": Vector2i(3, 2),
	&"online_station": Vector2i(6, 4),
	&"dining_table_01": Vector2i(2, 7),
	&"dining_table_02": Vector2i(4, 7),
}

const EXPECTED_SLOT_CELLS: Dictionary[StringName, Vector2i] = {
	&"slot_utility_01": Vector2i(5, 0),
	&"slot_utility_02": Vector2i(6, 0),
	&"slot_utility_03": Vector2i(2, 2),
	&"slot_utility_04": Vector2i(4, 2),
	&"slot_utility_05": Vector2i(5, 2),
	&"slot_table_01": Vector2i(0, 5),
	&"slot_table_02": Vector2i(2, 5),
	&"slot_table_03": Vector2i(4, 5),
	&"slot_table_04": Vector2i(5, 5),
	&"slot_table_05": Vector2i(0, 7),
	&"slot_table_06": Vector2i(5, 7),
}

const EXPECTED_PICKUP_CELLS: Dictionary[StringName, Vector2i] = {
	&"pickup_spot_01": Vector2i(7, 5),
	&"pickup_spot_02": Vector2i(7, 6),
	&"pickup_spot_03": Vector2i(7, 7),
}

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _run_all()
	print("SUMMARY fails=%d" % _fails)
	quit(_fails)


func _run_all() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	_check("load game_root.tscn", packed != null)
	if packed == null:
		return

	var game_root := packed.instantiate()
	root.add_child(game_root)
	await process_frame

	var world := game_root.get_node_or_null("World") as WorldMap
	_check("GameRoot/World is WorldMap", world != null)
	if world == null:
		game_root.free()
		return

	_test_canonical_containers(world)
	_test_starter_fixtures_and_unique_ids(world)
	_test_work_table_split_targets(world)
	_test_placement_slots_and_markers(world)
	_test_visual_only_nodes(world)
	_test_m5a2_starter_dining_tables(world)
	_test_art_integration_and_driver_visuals(world)
	_test_interactable_neighbors_and_queries(world)
	_test_m5a1_all_slots_occupied_reachability(world)
	_test_f1a_unified_road_and_backdrop(game_root, world)
	await _test_multi_tile_and_negative_queries(world)

	game_root.free()
	await process_frame


func _test_canonical_containers(world: WorldMap) -> void:
	var child_names: Array[String] = []
	for child in world.get_children():
		child_names.append(child.name)

	_check("exact 12 canonical World children", child_names == CANONICAL_CONTAINERS)
	_check("obsolete WaitingLane removed", world.get_node_or_null("WaitingLane") == null)
	_check("obsolete OnlineArea removed", world.get_node_or_null("OnlineArea") == null)
	_check(
		"WorkTable moved out of KitchenStations",
		world.get_node_or_null("KitchenStations/WorkTable") == null
		and world.get_node_or_null("KitchenWorkTables/WorkTable") != null
	)
	_check("OnlineStation is Area2D", world.online_station is Area2D)


func _test_starter_fixtures_and_unique_ids(world: WorldMap) -> void:
	_check(
		"M5-A1 world dimensions 12x9 with 32x32 tiles",
		world.grid_size == Vector2i(12, 9)
		and world.tile_size == Vector2i(32, 32)
		and world.grid.size == Vector2i(12, 9)
		and world.grid.tile_size == Vector2i(32, 32)
	)
	_check("KitchenStations count == 6", world.kitchen_stations.get_child_count() == 6)
	_check("KitchenWorkTables count == 1", world.kitchen_work_tables.get_child_count() == 1)
	_check("DiningTables count == 2", world.dining_tables.get_child_count() == 2)
	_check("DriverPickupSpots count == 3", world.driver_pickup_spots.get_child_count() == 3)
	_check(
		"DriverOverflowAnchors count == 1",
		world.driver_overflow_anchors.get_child_count() == 1
	)
	_check("DriverObjects starts empty", world.driver_objects.get_child_count() == 0)
	_check("PlacementSlots count == 11", world.placement_slots.get_child_count() == 11)

	var ids := world.registry.get_ids()
	_check("31 unique scene IDs registered", ids.size() == 31)

	for id in INTERACTABLE_IDS + PICKUP_SPOT_IDS + WAITING_ANCHOR_IDS + SLOT_IDS:
		_check("registered ID " + String(id), world.registry.has_object(id))
	_check("registered driver_overflow", world.registry.has_object(&"driver_overflow"))

	for fixture_id: StringName in EXPECTED_FIXTURE_CELLS:
		var node := world.registry.get_object(fixture_id)
		var expected_cell: Vector2i = EXPECTED_FIXTURE_CELLS[fixture_id]
		_check(
			"starter fixture cell " + String(fixture_id) + " == " + str(expected_cell),
			node != null
			and world.global_to_cell(node.global_position) == expected_cell
			and world.grid.get_occupant(expected_cell) == fixture_id
		)


func _test_work_table_split_targets(world: WorldMap) -> void:
	var table_node := world.registry.get_object(&"work_table")
	var stage_node := world.registry.get_object(&"work_table_stage") as Area2D
	var chop_node := world.registry.get_object(&"work_table_chop") as Area2D

	_check("work_table and split targets exist",
		table_node != null and stage_node != null and chop_node != null
	)
	if table_node == null or stage_node == null or chop_node == null:
		return

	_check(
		"split targets are children of WorkTable",
		stage_node.get_parent() == table_node and chop_node.get_parent() == table_node
	)
	_check(
		"split targets link parent_world_id",
		stage_node.get_meta(WorldMap.PARENT_WORLD_ID_META, &"") == &"work_table"
		and chop_node.get_meta(WorldMap.PARENT_WORLD_ID_META, &"") == &"work_table"
	)

	var expected_cell := Vector2i(3, 2)
	_check(
		"WorkTable owns grid footprint once",
		world.grid.get_occupant(expected_cell) == &"work_table"
		and world.grid.get_footprint(&"work_table") == [expected_cell]
		and world.grid.get_footprint(&"work_table_stage").is_empty()
		and world.grid.get_footprint(&"work_table_chop").is_empty()
	)
	_check(
		"get_target_footprint resolves split targets to parent cell",
		world.get_target_footprint(&"work_table_stage") == [expected_cell]
		and world.get_target_footprint(&"work_table_chop") == [expected_cell]
	)

	var stage_shape := stage_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var chop_shape := chop_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_check("split targets have CollisionShape2D", stage_shape != null and chop_shape != null)
	if stage_shape != null and chop_shape != null:
		var s_rect := (stage_shape.shape as RectangleShape2D).get_rect()
		s_rect.position += stage_node.position
		var c_rect := (chop_shape.shape as RectangleShape2D).get_rect()
		c_rect.position += chop_node.position
		_check("split target hitboxes do not overlap", not s_rect.intersects(c_rect))


func _test_placement_slots_and_markers(world: WorldMap) -> void:
	for slot_id in SLOT_IDS:
		var slot := world.registry.get_object(slot_id)
		_check("slot node exists " + String(slot_id), slot != null)
		if slot == null:
			continue

		var meta_slot_id := StringName(slot.get_meta(WorldMap.SLOT_ID_META, &""))
		var allowed: PackedInt32Array = slot.get_meta(
			WorldMap.ALLOWED_FIXTURE_KINDS_META,
			PackedInt32Array()
		)
		var fp_size: Vector2i = slot.get_meta(WorldMap.FOOTPRINT_SIZE_META, Vector2i.ZERO)
		var cell := world.global_to_cell(slot.global_position)

		_check("slot_id metadata matches " + String(slot_id), meta_slot_id == slot_id)
		_check("slot allowed_fixture_kinds non-empty " + String(slot_id), not allowed.is_empty())
		_check("slot footprint_size positive " + String(slot_id), fp_size.x > 0 and fp_size.y > 0)
		_check(
			"slot cell matches approved M5-A1 position " + String(slot_id),
			cell == EXPECTED_SLOT_CELLS[slot_id]
		)
		_check(
			"empty slot does not occupy walkable floor " + String(slot_id),
			world.grid.is_free(cell) and world.get_target_footprint(slot_id).is_empty()
		)
		_check("slot has no Area2D/collision " + String(slot_id), not (slot is Area2D))

	for spot_id in PICKUP_SPOT_IDS:
		var spot := world.registry.get_object(spot_id)
		var spot_cell := world.global_to_cell(spot.global_position)
		var has_free_neighbor := false
		for n in world.grid.get_cardinal_neighbors(spot_cell):
			if world.grid.is_free(n):
				has_free_neighbor = true
		_check(
			"pickup spot cell matches M5-A1 and is non-walkable " + String(spot_id),
			spot_cell == EXPECTED_PICKUP_CELLS[spot_id]
			and not world.grid.is_walkable(spot_cell)
		)
		_check("pickup spot has free cardinal neighbor " + String(spot_id), has_free_neighbor)
		_check("pickup spot is Marker2D not fixture " + String(spot_id),
			spot is Marker2D and not world.grid.is_occupied(spot_cell))

	for wait_id in WAITING_ANCHOR_IDS:
		var wait_node := world.registry.get_object(wait_id)
		var wait_cell := world.global_to_cell(wait_node.global_position)
		_check(
			"waiting anchor on right-side column 9 and non-walkable " + String(wait_id),
			wait_node is Marker2D
			and wait_cell.x == 9
			and not world.grid.is_walkable(wait_cell)
		)

	var overflow_node := world.registry.get_object(&"driver_overflow")
	var overflow_cell := world.global_to_cell(overflow_node.global_position)
	_check(
		"driver_overflow in right-side road (cols 10..11) and non-walkable",
		overflow_node is Marker2D
		and overflow_cell.x >= 10
		and overflow_cell.x <= 11
		and not world.grid.is_walkable(overflow_cell)
	)


func _test_visual_only_nodes(world: WorldMap) -> void:
	_check(
		"Player not registered in WorldRegistry",
		world.registry.find_id(world.player) == &""
		and not world.registry.has_object(&"player")
	)
	var all_decor_passive := world.decorations.get_child_count() == 8
	for child in world.decorations.get_children():
		if not (child is Sprite2D) or (child is Area2D) or child.has_meta(WorldMap.WORLD_ID_META):
			all_decor_passive = false
		if world.registry.find_id(child as Node2D) != &"":
			all_decor_passive = false
	_check(
		"Decorations contains passive counter/wall sprites not registered in WorldRegistry",
		world.registry.find_id(world.decorations) == &""
		and all_decor_passive
	)
	var counter_non_walkable := true
	for cx in range(0, 6):
		var c := Vector2i(cx, 4)
		if world.grid.is_walkable(c) or world.grid.is_occupied(c):
			counter_non_walkable = false
	var wall_non_walkable := true
	for wy in [0, 1, 2, 3, 4, 8]:
		var wc := Vector2i(8, wy)
		if world.grid.is_walkable(wc) or world.grid.is_occupied(wc):
			wall_non_walkable = false
	var doorway_and_passage_free := world.grid.is_free(Vector2i(7, 4))
	for dy in [5, 6, 7]:
		if not world.grid.is_free(Vector2i(8, dy)):
			doorway_and_passage_free = false
	_check(
		"passive long counter and interior wall are non-walkable while doorway/passage are free",
		counter_non_walkable and wall_non_walkable and doorway_and_passage_free
	)
	_check(
		"Player starts at cell (6, 3) which remains free",
		world.global_to_cell(world.player.global_position) == Vector2i(6, 3)
		and world.grid.is_free(Vector2i(6, 3))
	)


func _test_m5a2_starter_dining_tables(world: WorldMap) -> void:
	for table_id: StringName in [&"dining_table_01", &"dining_table_02"]:
		var table_node := world.registry.get_object(table_id) as Area2D
		_check("starter table is Area2D " + String(table_id), table_node != null)
		if table_node == null:
			continue

		var chair_spr := table_node.get_node_or_null("ChairVisual") as Sprite2D
		var seat_anchor := table_node.get_node_or_null("SeatAnchor") as Marker2D
		var tabletop := table_node.get_node_or_null("TabletopPlaceholder") as Node2D
		var table_hb := table_node.get_node_or_null("TableHitbox") as CollisionShape2D
		var chair_hb := table_node.get_node_or_null("ChairHitbox") as CollisionShape2D

		_check(
			"starter ChairVisual south-side with chair sprite " + String(table_id),
			chair_spr != null
			and chair_spr.position.y > 0.0
			and chair_spr.texture != null
			and chair_spr.texture.resource_path == "res://assets/art/tiles/Warung-Tileset.png"
			and chair_spr.region_enabled
			and chair_spr.region_rect == WorldMap.REGION_DINING_CHAIR
			and chair_spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		)
		_check(
			"starter SeatAnchor south-side Marker2D " + String(table_id),
			seat_anchor != null
			and seat_anchor.position.y > 0.0
			and world.get_table_seat_anchor(table_id) == seat_anchor
		)
		_check(
			"starter tabletop placeholder distinct from chair " + String(table_id),
			tabletop != null
			and table_node.get_node_or_null("Sprite2D") == null
			and tabletop.get_node_or_null("TabletopSurface") != null
		)
		var table_cell := world.global_to_cell(table_node.global_position)
		var south_cell := table_cell + Vector2i(0, 1)
		var south_center_global := world.cell_to_global(south_cell)
		_check(
			"starter table/chair hitboxes & south cell clear " + String(table_id),
			table_hb != null
			and chair_hb != null
			and chair_hb.position.y > 0.0
			and WorldMap.point_hits_area_shapes(table_node, table_node.global_position)
			and WorldMap.point_hits_area_shapes(table_node, chair_hb.global_position)
			and not WorldMap.point_hits_area_shapes(table_node, south_center_global)
		)
		_check(
			"chair & SeatAnchor unregistered and 1x1 footprint preserved " + String(table_id),
			world.registry.find_id(chair_spr) == &""
			and world.registry.find_id(seat_anchor) == &""
			and world.grid.get_footprint(table_id) == [table_cell]
			and world.grid.is_free(south_cell)
		)
	_check("M5-A2 preserves exact 31 registered scene IDs", world.registry.get_ids().size() == 31)


func _test_art_integration_and_driver_visuals(world: WorldMap) -> void:
	_check(
		"FloorTiles has TileSet and 108 populated cells with nearest filter",
		world.floor_layer.tile_set != null
		and world.floor_layer.tile_set.tile_size == Vector2i(32, 32)
		and world.floor_layer.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and world.floor_layer.get_used_cells().size() == 108
		and world.floor_layer.get_cell_atlas_coords(Vector2i(5, 2)) == WorldMap.TILE_KITCHEN_FLOOR
		and world.floor_layer.get_cell_atlas_coords(Vector2i(5, 6)) == WorldMap.TILE_DINING_FLOOR
	)

	var player_sprite := world.player.get_node_or_null("Visual/Sprite") as Sprite2D
	_check(
		"Player sprite uses player.png (16x32) with nearest filter and z_index 1",
		player_sprite != null
		and player_sprite.texture != null
		and player_sprite.texture.resource_path == "res://assets/art/characters/player.png"
		and player_sprite.texture.get_size() == Vector2(16, 32)
		and player_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and world.player.z_index == 1
	)

	var expected_regions: Dictionary[StringName, Rect2] = {
		&"storage_box": WorldMap.REGION_STORAGE_BOX,
		&"stove": WorldMap.REGION_STOVE,
		&"washer": WorldMap.REGION_WASHER,
		&"plate_rack": WorldMap.REGION_PLATE_RACK,
		&"rice_cooker": WorldMap.REGION_RICE_COOKER,
		&"trash": WorldMap.REGION_TRASH,
		&"work_table": WorldMap.REGION_WORK_TABLE,
		&"online_station": WorldMap.REGION_ONLINE_STATION,
	}
	for fixture_id: StringName in expected_regions:
		var node := world.registry.get_object(fixture_id)
		var spr := node.get_node_or_null("Sprite2D") as Sprite2D if node != null else null
		_check(
			"fixture sprite integrated " + String(fixture_id),
			spr != null
			and spr.texture != null
			and spr.texture.resource_path == "res://assets/art/tiles/Warung-Tileset.png"
			and spr.region_enabled
			and spr.region_rect == expected_regions[fixture_id]
			and spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		)

	_check(
		"WorldMap character textures bound (gojek, pegawai, 7 customer variants)",
		world.driver_texture != null
		and world.driver_texture.resource_path == "res://assets/art/characters/npc gojek.png"
		and world.employee_texture != null
		and world.employee_texture.resource_path == "res://assets/art/characters/pegawai.png"
		and world.customer_textures.size() == 7
		and world.get_customer_texture_by_index(0) != null
		and world.get_customer_texture_for_id(&"cust_1_01") != null
	)

	# Verify GoFood driver visual sync for pickup spot and overflow:
	world.sync_driver_visuals([
		{
			"driver_id": &"drv_test_01",
			"order_id": &"ord_test_01",
			"state": SharedTypes.DriverState.AT_PICKUP_SPOT,
			"spot_id_or_empty": &"pickup_spot_01",
		},
		{
			"driver_id": &"drv_test_02",
			"order_id": &"ord_test_02",
			"state": SharedTypes.DriverState.OUTSIDE_DRIVER_QUEUE,
			"spot_id_or_empty": &"",
		},
	])
	var spot_drv := world.registry.get_object(&"drv_test_01")
	_check(
		"in-spot driver registered as Area2D at pickup_spot_01 with free neighbors",
		spot_drv is Area2D
		and spot_drv.position == Vector2(240, 176)
		and world.get_free_cardinal_neighbors(&"drv_test_01") == [
			Vector2i(7, 4),
			Vector2i(8, 5),
			Vector2i(6, 5),
		]
		and not world.registry.has_object(&"drv_test_02")
		and world.driver_objects.get_child_count() == 2
	)
	world.sync_driver_visuals([])
	_check(
		"clearing driver visuals cleans DriverObjects and WorldRegistry",
		world.driver_objects.get_child_count() == 0
		and not world.registry.has_object(&"drv_test_01")
		and not world.grid.is_occupied(Vector2i(7, 5))
	)


func _test_interactable_neighbors_and_queries(world: WorldMap) -> void:
	for target_id in INTERACTABLE_IDS:
		var free_neighbors := world.get_free_cardinal_neighbors(target_id)
		var nearest := world.find_nearest_free_neighbor(target_id, Vector2i(6, 3))
		_check(
			"interactable has free cardinal neighbor " + String(target_id),
			not free_neighbors.is_empty() and free_neighbors.has(nearest)
		)

	# OnlineStation at (6, 4) has UP(6,3), RIGHT(7,4), DOWN(6,5); LEFT(5,4) is non-walkable counter.
	_check(
		"online_station neighbors are (6,3), (7,4), (6,5) and nearest from (6,3) is (6,3)",
		world.get_free_cardinal_neighbors(&"online_station") == [
			Vector2i(6, 3),
			Vector2i(7, 4),
			Vector2i(6, 5),
		]
		and world.find_nearest_free_neighbor(&"online_station", Vector2i(6, 3))
			== Vector2i(6, 3)
	)

	# DiningTable01 at (2, 7) has 4 free neighbors: UP(2,6), RIGHT(3,7), DOWN(2,8), LEFT(1,7).
	var dt1_neighbors := world.get_free_cardinal_neighbors(&"dining_table_01")
	_check(
		"dining_table_01 cardinal neighbor order UP/RIGHT/DOWN/LEFT",
		dt1_neighbors == [
			Vector2i(2, 6),
			Vector2i(3, 7),
			Vector2i(2, 8),
			Vector2i(1, 7),
		]
	)
	# Tie-break checks around DiningTable01 (2, 7):
	# From (3, 6), UP(2, 6) and RIGHT(3, 7) both have Manhattan distance 1 -> UP(2, 6) wins.
	_check(
		"tie-break UP beats RIGHT from (3, 6)",
		world.find_nearest_free_neighbor(&"dining_table_01", Vector2i(3, 6))
			== Vector2i(2, 6)
	)
	# From (3, 8), RIGHT(3, 7) and DOWN(2, 8) both have distance 1 -> RIGHT(3, 7) wins.
	_check(
		"tie-break RIGHT beats DOWN from (3, 8)",
		world.find_nearest_free_neighbor(&"dining_table_01", Vector2i(3, 8))
			== Vector2i(3, 7)
	)
	# From (1, 8), DOWN(2, 8) and LEFT(1, 7) both have distance 1 -> DOWN(2, 8) wins.
	_check(
		"tie-break DOWN beats LEFT from (1, 8)",
		world.find_nearest_free_neighbor(&"dining_table_01", Vector2i(1, 8))
			== Vector2i(2, 8)
	)
	# From (0, 7), LEFT(1, 7) has unique shortest distance 1 -> LEFT(1, 7) wins.
	_check(
		"shortest Manhattan distance wins from (0, 7)",
		world.find_nearest_free_neighbor(&"dining_table_01", Vector2i(0, 7))
			== Vector2i(1, 7)
	)


func _test_m5a1_all_slots_occupied_reachability(world: WorldMap) -> void:
	var temp_ids: Array[StringName] = []
	for slot_id in SLOT_IDS:
		var slot_cell: Vector2i = EXPECTED_SLOT_CELLS[slot_id]
		var temp_id := StringName("temp_" + String(slot_id))
		var dummy := Node2D.new()
		world.add_child(dummy)
		if world.register_object(temp_id, dummy, [slot_cell]):
			temp_ids.append(temp_id)

	_check("all 11 placement slots occupied simultaneously", temp_ids.size() == 11)

	var all_starters_reachable := true
	for target_id in INTERACTABLE_IDS:
		if world.get_free_cardinal_neighbors(target_id).is_empty():
			all_starters_reachable = false

	var all_placed_reachable := true
	for placed_id in temp_ids:
		if world.get_free_cardinal_neighbors(placed_id).is_empty():
			all_placed_reachable = false

	var all_pickups_reachable := true
	for spot_id in PICKUP_SPOT_IDS:
		var spot_cell: Vector2i = EXPECTED_PICKUP_CELLS[spot_id]
		var has_free := false
		for n in world.grid.get_cardinal_neighbors(spot_cell):
			if world.grid.is_free(n):
				has_free = true
				break
		if not has_free:
			all_pickups_reachable = false

	_check(
		"all 12 starter interactables remain cardinally reachable when all 11 slots occupied",
		all_starters_reachable
	)
	_check(
		"all 11 placed slot fixtures remain cardinally reachable when all 11 slots occupied",
		all_placed_reachable
	)
	_check(
		"all 3 pickup spots retain free cardinal neighbors when all 11 slots occupied",
		all_pickups_reachable
	)

	for placed_id in temp_ids:
		var node := world.registry.get_object(placed_id)
		world.unregister_object(placed_id)
		if node != null:
			world.remove_child(node)
			node.free()


func _test_multi_tile_and_negative_queries(world: WorldMap) -> void:
	# Unknown / empty target IDs and passive markers fail safely.
	_check("empty target_id footprint empty", world.get_target_footprint(&"").is_empty())
	_check("unknown target_id footprint empty", world.get_target_footprint(&"no_such").is_empty())
	_check(
		"unknown target_id nearest returns INVALID_CELL",
		world.find_nearest_free_neighbor(&"no_such", Vector2i(6, 3)) == WorldMap.INVALID_CELL
	)
	_check(
		"out-of-bounds from_cell returns INVALID_CELL",
		world.find_nearest_free_neighbor(&"stove", Vector2i(-1, -1)) == WorldMap.INVALID_CELL
		and world.find_nearest_free_neighbor(&"stove", Vector2i(99, 99)) == WorldMap.INVALID_CELL
	)
	_check(
		"waiting anchor has empty fixture footprint",
		world.get_target_footprint(&"dine_in_wait_01").is_empty()
	)

	# Child target with broken parent_world_id fails safely.
	var bad_child := Node2D.new()
	bad_child.set_meta(WorldMap.PARENT_WORLD_ID_META, &"missing_parent")
	world.add_child(bad_child)
	_check("register bad_child", world.register_object(&"bad_child", bad_child, []))
	_check(
		"broken parent_world_id returns empty footprint and INVALID_CELL",
		world.get_target_footprint(&"bad_child").is_empty()
		and world.find_nearest_free_neighbor(&"bad_child", Vector2i(6, 3))
			== WorldMap.INVALID_CELL
	)
	bad_child.queue_free()
	await process_frame
	await process_frame
	_check(
		"bad_child auto-unregistered on queue_free",
		not world.registry.has_object(&"bad_child")
	)

	# Multi-tile 2x1 fixture registration and neighbor query.
	var wide_fixture := Node2D.new()
	world.add_child(wide_fixture)
	var cells: Array[Vector2i] = [Vector2i(5, 3), Vector2i(6, 3)]
	_check("register 2x1 wide_fixture", world.register_object(&"wide_fix", wide_fixture, cells))
	_check("wide_fixture footprint matches", world.get_target_footprint(&"wide_fix") == cells)
	_check(
		"wide_fixture nearest from (6, 2) is (6, 2)",
		world.find_nearest_free_neighbor(&"wide_fix", Vector2i(6, 2)) == Vector2i(6, 2)
	)
	wide_fixture.queue_free()
	await process_frame
	await process_frame
	_check(
		"wide_fixture cells released after queue_free",
		world.grid.is_free(Vector2i(5, 3)) and world.grid.is_free(Vector2i(6, 3))
	)


func _test_f1a_unified_road_and_backdrop(game_root: Node, world: WorldMap) -> void:
	var road_connected := true
	for y in range(world.grid_size.y):
		var exp_c9 := WorldMap.TILE_LANE_MID_LEFT
		var exp_c10 := WorldMap.TILE_LANE_FILL
		var exp_c11 := WorldMap.TILE_LANE_MID_RIGHT
		if y == 0:
			exp_c9 = WorldMap.TILE_LANE_TOP_LEFT
			exp_c10 = WorldMap.TILE_LANE_TOP_MID
			exp_c11 = WorldMap.TILE_LANE_TOP_RIGHT
		elif y == world.grid_size.y - 1:
			exp_c9 = WorldMap.TILE_LANE_BOT_LEFT
			exp_c10 = WorldMap.TILE_LANE_BOT_MID
			exp_c11 = WorldMap.TILE_LANE_BOT_RIGHT
		if (
			world.floor_layer.get_cell_atlas_coords(Vector2i(9, y)) != exp_c9
			or world.floor_layer.get_cell_atlas_coords(Vector2i(10, y)) != exp_c10
			or world.floor_layer.get_cell_atlas_coords(Vector2i(11, y)) != exp_c11
		):
			road_connected = false
		for x in [9, 10, 11]:
			if world.grid.is_walkable(Vector2i(x, y)):
				road_connected = false
	_check(
		"F1-A cols 9..11 form one connected 3-tile road while remaining non-walkable",
		road_connected
	)

	# Verify programmatic _populate_floor_tiles() fallback matches authored tile_map_data.
	world.floor_layer.clear()
	world._populate_floor_tiles()
	_check(
		"F1-A _populate_floor_tiles() fallback builds connected 108-cell road",
		world.floor_layer.get_used_cells().size() == 108
		and world.floor_layer.get_cell_atlas_coords(Vector2i(9, 4)) == WorldMap.TILE_LANE_MID_LEFT
		and world.floor_layer.get_cell_atlas_coords(Vector2i(10, 4)) == WorldMap.TILE_LANE_FILL
		and world.floor_layer.get_cell_atlas_coords(Vector2i(11, 4)) == WorldMap.TILE_LANE_MID_RIGHT
	)

	var backdrop := game_root.get_node_or_null("WorldBackdrop") as Node2D
	var passive_only := backdrop != null
	var wall_sprites_ok := false
	if backdrop != null:
		var wall_count := 0
		for child in backdrop.get_children():
			if child is Area2D or child is CollisionObject2D or child is Control:
				passive_only = false
			if child is Node2D and world.registry.find_id(child as Node2D) != &"":
				passive_only = false
			if child is Sprite2D:
				var spr := child as Sprite2D
				if (
					spr.texture != null
					and spr.texture.resource_path == "res://assets/art/tiles/Warung-Tileset.png"
					and spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
				):
					wall_count += 1
		wall_sprites_ok = (wall_count == 4)
	_check(
		"F1-A WorldBackdrop is passive, draws behind World, and uses Warung-Tileset rear wall",
		backdrop != null
		and passive_only
		and wall_sprites_ok
		and backdrop.z_index < world.z_index
		and backdrop.get_index() < world.get_index()
		and world.registry.find_id(backdrop) == &""
	)
