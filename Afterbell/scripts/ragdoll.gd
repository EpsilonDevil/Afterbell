extends Node3D
## A linked, free-simulating proxy. A production character will replace these
## primitive shapes with skinned art and a tuned PhysicalBoneSimulator3D rig.

var bodies: Dictionary = {}

func _make_part(part_name: String, center: Vector3, size: Vector3, color: Color, mass_value: float) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = part_name
	body.mass = mass_value
	body.position = center
	body.collision_layer = 8
	body.collision_mask = 1 | 8
	body.continuous_cd = true
	add_child(body)
	var shape := CapsuleShape3D.new()
	shape.radius = size.x
	shape.height = maxf(size.y, size.x * 2.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = shape.radius
	mesh.height = shape.height
	visual.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.08
	mat.roughness = 0.48
	visual.material_override = mat
	body.add_child(visual)
	bodies[part_name] = body
	return body

func _link(a: String, b: String, anchor: Vector3) -> void:
	var joint := PinJoint3D.new()
	joint.position = anchor
	add_child(joint)
	joint.node_a = joint.get_path_to(bodies[a])
	joint.node_b = joint.get_path_to(bodies[b])
	joint.exclude_nodes_from_collision = true

func build(origin: Vector3, facing: Vector3, palette: Dictionary, impact: Vector3) -> void:
	global_position = origin
	var skin: Color = palette.skin
	var cloth: Color = palette.cloth
	var glove: Color = palette.glove
	_make_part("hip", Vector3(0, 0.92, 0), Vector3(0.22, 0.42, 0), cloth, 10.0)
	_make_part("chest", Vector3(0, 1.38, 0), Vector3(0.28, 0.63, 0), skin, 15.0)
	_make_part("head", Vector3(0, 1.92, 0), Vector3(0.17, 0.34, 0), skin, 5.0)
	for side in [-1, 1]:
		var prefix := "l" if side == -1 else "r"
		_make_part(prefix + "_arm", Vector3(side * 0.43, 1.38, 0), Vector3(0.12, 0.52, 0), skin, 3.0)
		_make_part(prefix + "_glove", Vector3(side * 0.56, 1.06, 0), Vector3(0.14, 0.29, 0), glove, 2.0)
		_make_part(prefix + "_leg", Vector3(side * 0.19, 0.52, 0), Vector3(0.15, 0.83, 0), cloth, 7.0)
	_link("hip", "chest", Vector3(0, 1.14, 0))
	_link("chest", "head", Vector3(0, 1.72, 0))
	for side in [-1, 1]:
		var prefix := "l" if side == -1 else "r"
		_link("chest", prefix + "_arm", Vector3(side * 0.29, 1.61, 0))
		_link(prefix + "_arm", prefix + "_glove", Vector3(side * 0.53, 1.16, 0))
		_link("hip", prefix + "_leg", Vector3(side * 0.17, 0.8, 0))
	bodies.chest.apply_central_impulse(impact * 12.0 + Vector3.UP * 8.0)
	bodies.head.apply_central_impulse(impact * 3.0)
	bodies.hip.angular_velocity = Vector3(facing.z, 0.0, -facing.x) * 2.0
