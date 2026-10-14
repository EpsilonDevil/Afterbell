extends CharacterBody3D
class_name AfterbellFighter

signal strike_landed(attacker: AfterbellFighter, defender: AfterbellFighter, damage: float, guarded: bool)
signal knocked_out(fighter: AfterbellFighter)

const RAGDOLL = preload("res://scripts/ragdoll.gd")
const ATTACKS := {
	"jab": {"startup": 0.085, "active": 0.085, "recovery": 0.20, "damage": 6.0, "range": 1.53, "stamina": 7.0, "side": -1.0},
	"cross": {"startup": 0.16, "active": 0.09, "recovery": 0.32, "damage": 12.0, "range": 1.62, "stamina": 12.0, "side": 1.0},
	"hook": {"startup": 0.21, "active": 0.11, "recovery": 0.42, "damage": 17.0, "range": 1.28, "stamina": 17.0, "side": -1.0}
}

var enemy: AfterbellFighter
var player_controlled := false
var palette := {"skin": Color("ba7958"), "cloth": Color("152336"), "glove": Color("fd5943")}
var health := 100.0
var stamina := 100.0
var is_down := false
var guarding := false
var slipping := 0.0
var attack_name := ""
var attack_elapsed := 0.0
var already_hit := false
var hurt_timer := 0.0
var ai_timer := 0.0
var ai_guard_timer := 0.0
var visual: Node3D
var left_arm: Node3D
var right_arm: Node3D
var head: Node3D
var chest: Node3D
var left_glove: Node3D
var right_glove: Node3D
var last_glove_position := Vector3.ZERO

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	floor_snap_length = 0.24
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.85
	var collision := CollisionShape3D.new()
	collision.position.y = 0.93
	collision.shape = capsule
	add_child(collision)
	_make_visual()

func _material(color: Color, rough: float = 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = 0.08
	return m

func _part(parent: Node3D, part_name: String, pos: Vector3, radius: float, height: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = part_name
	pivot.position = pos
	parent.add_child(pivot)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	pivot.add_child(mesh_instance)
	return pivot

func _make_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	var skin: Color = palette.skin
	var cloth: Color = palette.cloth
	var glove: Color = palette.glove
	chest = _part(visual, "Torso", Vector3(0, 1.31, 0), 0.31, 0.70, skin)
	_part(visual, "Trunks", Vector3(0, 0.91, 0), 0.31, 0.35, cloth)
	head = _part(visual, "Head", Vector3(0, 1.90, 0), 0.18, 0.40, skin)
	for side in [-1, 1]:
		var x: float = side * 0.23
		_part(visual, "Shin", Vector3(x, 0.44, 0), 0.145, 0.8, cloth)
		_part(visual, "Boot", Vector3(x, 0.15, -0.14), 0.14, 0.31, Color("e9e4d8"))
		var arm := _part(visual, "Arm", Vector3(side * 0.42, 1.47, -0.12), 0.115, 0.50, skin)
		var mitt := _part(arm, "Glove", Vector3(side * 0.04, -0.18, -0.22), 0.155, 0.32, glove)
		if side < 0:
			left_arm = arm
			left_glove = mitt
		else:
			right_arm = arm
			right_glove = mitt

func _physics_process(delta: float) -> void:
	if is_down:
		return
	hurt_timer = maxf(0.0, hurt_timer - delta)
	stamina = minf(100.0, stamina + delta * (9.0 if attack_name.is_empty() else 2.0))
	if enemy != null and not enemy.is_down:
		var target := enemy.global_position
		target.y = global_position.y
		if global_position.distance_squared_to(target) > 0.001:
			look_at(target, Vector3.UP)
	var move_axis := Vector2.ZERO
	if player_controlled:
		move_axis = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		guarding = Input.is_action_pressed("guard") and attack_name.is_empty()
		if Input.is_action_just_pressed("slip_left"):
			slipping = -0.23
		if Input.is_action_just_pressed("slip_right"):
			slipping = 0.23
		for candidate in ["jab", "cross", "hook"]:
			if Input.is_action_just_pressed(candidate):
				start_attack(candidate)
	else:
		_ai(delta)
		if enemy != null and not enemy.is_down:
			var local_target := global_transform.basis.inverse() * (enemy.global_position - global_position)
			if local_target.length() > 1.55:
				move_axis.y = -1.0
			elif local_target.length() < 0.89:
				move_axis.y = 1.0
			move_axis.x = sin(Time.get_ticks_msec() * 0.0014) * 0.28
	slipping = move_toward(slipping, 0.0, delta * 1.55)
	var desired := (global_transform.basis.x * move_axis.x + global_transform.basis.z * move_axis.y) * (2.8 if attack_name.is_empty() else 1.25)
	velocity.x = move_toward(velocity.x, desired.x, delta * 16.0)
	velocity.z = move_toward(velocity.z, desired.z, delta * 16.0)
	velocity.y = -0.5 if is_on_floor() else velocity.y - 16.0 * delta
	move_and_slide()
	_update_attack(delta)
	_animate_pose(delta)

func _ai(delta: float) -> void:
	ai_timer -= delta
	ai_guard_timer -= delta
	guarding = ai_guard_timer > 0.0 and attack_name.is_empty()
	if enemy == null or enemy.is_down:
		return
	var distance := global_position.distance_to(enemy.global_position)
	if enemy.attack_name != "" and distance < 1.8 and randf() < delta * 2.0:
		ai_guard_timer = randf_range(0.3, 0.7)
	if ai_timer <= 0.0 and distance < 1.75:
		ai_timer = randf_range(0.35, 0.9)
		if not guarding:
			start_attack(["jab", "jab", "cross", "hook"].pick_random())

func start_attack(kind: String) -> void:
	if is_down or guarding or not attack_name.is_empty():
		return
	var data: Dictionary = ATTACKS[kind]
	if stamina < data.stamina:
		return
	stamina -= data.stamina
	attack_name = kind
	attack_elapsed = 0.0
	already_hit = false
	last_glove_position = _glove_world()

func _glove_world() -> Vector3:
	var glove: Node3D = right_glove if attack_name == "cross" else left_glove
	return glove.global_position

func _update_attack(delta: float) -> void:
	if attack_name.is_empty():
		return
	var data: Dictionary = ATTACKS[attack_name]
	attack_elapsed += delta
	var start: float = data.startup
	var end: float = start + data.active
	if attack_elapsed >= start and attack_elapsed <= end and not already_hit:
		_sweep_glove(last_glove_position, _glove_world(), data)
	last_glove_position = _glove_world()
	if attack_elapsed >= end + data.recovery:
		attack_name = ""

func _sweep_glove(from: Vector3, to: Vector3, data: Dictionary) -> void:
	if enemy == null or enemy.is_down:
		return
	var forward := -global_transform.basis.z
	var distance := global_position.distance_to(enemy.global_position)
	if distance > data.range + 0.55 or forward.dot((enemy.global_position - global_position).normalized()) < 0.45:
		return
	var sphere := SphereShape3D.new()
	sphere.radius = 0.19
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 2
	query.exclude = [get_rid()]
	# Multiple substeps cover the moving glove without relying on a single end-frame overlap.
	for i in range(5):
		var p := from.lerp(to, float(i + 1) / 5.0)
		p = p.lerp(global_position + forward * data.range + Vector3.UP * 1.56, 0.42)
		query.transform = Transform3D(Basis.IDENTITY, p)
		for hit in get_world_3d().direct_space_state.intersect_shape(query, 8):
			if hit.collider == enemy:
				already_hit = true
				var blocked := enemy.guarding and enemy.attack_name.is_empty()
				var damage: float = data.damage * (0.22 if blocked else 1.0)
				enemy.take_hit(damage, forward, blocked)
				strike_landed.emit(self, enemy, damage, blocked)
				return

func take_hit(amount: float, direction: Vector3, blocked: bool) -> void:
	if is_down:
		return
	var evade := absf(slipping) > 0.14 and not blocked
	if evade:
		amount *= 0.35
	health = maxf(0.0, health - amount)
	stamina = maxf(0.0, stamina - (amount * (0.7 if blocked else 0.25)))
	hurt_timer = 0.19 if not blocked else 0.08
	velocity += direction * (0.7 if blocked else 1.8)
	if health <= 0.0:
		knockout(direction)

func knockout(direction: Vector3) -> void:
	is_down = true
	visual.visible = false
	set_collision_layer_value(2, false)
	set_collision_mask_value(2, false)
	var proxy := RAGDOLL.new()
	get_parent().add_child(proxy)
	proxy.build(global_position, -global_transform.basis.z, palette, direction)
	knocked_out.emit(self)

func _animate_pose(delta: float) -> void:
	var time := Time.get_ticks_msec() * 0.001
	var sway := sin(time * 4.0) * 0.025
	visual.position.x = lerpf(visual.position.x, slipping, minf(1.0, delta * 16.0))
	visual.position.y = sway
	chest.rotation.z = lerpf(chest.rotation.z, -slipping * 0.45, minf(1.0, delta * 12.0))
	head.rotation.x = lerpf(head.rotation.x, -0.18 if hurt_timer > 0 else 0.0, minf(1.0, delta * 15.0))
	for arm in [left_arm, right_arm]:
		arm.rotation.x = lerpf(arm.rotation.x, -0.48 if guarding else 0.0, minf(1.0, delta * 14.0))
		arm.position.z = lerpf(arm.position.z, -0.35 if guarding else -0.12, minf(1.0, delta * 14.0))
	if not attack_name.is_empty():
		var data: Dictionary = ATTACKS[attack_name]
		var start: float = data.startup
		var end: float = start + data.active
		var extension := 0.0
		if attack_elapsed < start:
			extension = attack_elapsed / start * 0.24
		elif attack_elapsed < end:
			extension = 0.24 + (attack_elapsed - start) / data.active * 0.77
		else:
			extension = maxf(0.0, 1.0 - (attack_elapsed - end) / data.recovery)
		var attacking_arm: Node3D = right_arm if attack_name == "cross" else left_arm
		attacking_arm.position.z = -0.12 - extension * 0.95
		attacking_arm.rotation.y = extension * (-0.65 if attack_name == "hook" else 0.0)
