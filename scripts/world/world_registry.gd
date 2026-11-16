class_name WorldRegistry
extends RefCounted
## Maps stable world object IDs to their scene nodes.
##
## Holds references and identity only. It owns no gameplay data (fixture
## ownership, orders, stock, table state) and never mutates the nodes.

var _objects: Dictionary[StringName, Node2D] = {}


## Registers a node under a stable ID. Returns false (and logs an error, since
## this is an authoring/programming mistake) if the ID is empty, the node is
## null/freed, the ID is already taken, or the node is already registered under
## another ID. An existing entry is never overwritten.
func register_object(object_id: StringName, node: Node2D) -> bool:
	if object_id == &"":
		push_error("WorldRegistry: cannot register an empty ID.")
		return false

	if not is_instance_valid(node):
		push_error("WorldRegistry: cannot register null/invalid node for ID '%s'." % object_id)
		return false

	if _objects.has(object_id):
		push_error("WorldRegistry: duplicate ID '%s' rejected." % object_id)
		return false

	if find_id(node) != &"":
		push_error("WorldRegistry: node '%s' is already registered as '%s'." % [
			node.name, find_id(node)
		])
		return false

	_objects[object_id] = node
	return true


## Removes an entry. Returns false if the ID is not registered.
func unregister_object(object_id: StringName) -> bool:
	return _objects.erase(object_id)


## Removes an entry only if it currently maps to `node`.
## Prevents an old or replaced node from removing a newer registration.
func unregister_node(object_id: StringName, node: Node2D) -> bool:
	if not is_instance_valid(node):
		return false

	var current: Variant = _objects.get(object_id)
	if not is_instance_valid(current) or current != node:
		return false

	return _objects.erase(object_id)


func has_object(object_id: StringName) -> bool:
	return _objects.has(object_id)


## The registered node, or null if the ID is unknown or the node was freed.
func get_object(object_id: StringName) -> Node2D:
	var node: Variant = _objects.get(object_id)
	if not is_instance_valid(node):
		return null
	return node as Node2D


## The ID a node is registered under, or &"" if it is not registered.
func find_id(node: Node2D) -> StringName:
	if not is_instance_valid(node):
		return &""

	for object_id in _objects:
		var candidate: Variant = _objects[object_id]
		if is_instance_valid(candidate) and candidate == node:
			return object_id
	return &""


## All registered IDs in sorted order (deterministic).
func get_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_objects.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids
