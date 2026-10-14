extends Node3D

const FIGHTER = preload("res://scripts/fighter.gd")
var player: AfterbellFighter
var rival: AfterbellFighter
var camera: Camera3D
var ui: CanvasLayer
var player_health: ProgressBar
var rival_health: ProgressBar
var player_stamina: ProgressBar
var rival_stamina: ProgressBar
var message: Label
var flash: ColorRect
var flash_strength := 0.0
var shake := 0.0

func _ready() -> void:
	_configure_input()
	_make_world()
	_make_ui()
	_spawn_fighters()

func _configure_input() -> void:
	var bindings := {
		"move_forward": KEY_W, "move_back": KEY_S,
		"move_left": KEY_A, "move_right": KEY_D,
		"jab": KEY_J, "cross": KEY_K, "hook": KEY_L,
		"guard": KEY_SPACE, "slip_left": KEY_Q,
		"slip_right": KEY_E, "reset": KEY_R
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = bindings[action]
		InputMap.action_add_event(action, key)

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("reset"):
		get_tree().reload_current_scene()
	if player == null or rival == null:
		return
	player_health.value = player.health
	rival_health.value = rival.health
	player_stamina.value = player.stamina
	rival_stamina.value = rival.stamina
	flash_strength = move_toward(flash_strength, 0.0, delta * 4.5)
	flash.color.a = flash_strength
	shake = move_toward(shake, 0.0, delta * 4.0)
	var midpoint := (player.global_position + rival.global_position) * 0.5
	var separation := player.global_position.distance_to(rival.global_position)
	var desired := midpoint + Vector3(0.0, 3.2, 7.7 + separation * 0.45)
	camera.global_position = camera.global_position.lerp(desired, minf(1.0, delta * 3.0))
	camera.position += Vector3(randf_range(-shake, shake), randf_range(-shake, shake), 0.0) * delta
	camera.look_at(midpoint + Vector3.UP * 1.35, Vector3.UP)

func _spawn_fighters() -> void:
	player = FIGHTER.new()
	player.name = "Kestrel"
	player.player_controlled = true
	player.palette = {"skin": Color("b77850"), "cloth": Color("203848"), "glove": Color("f15e4c")}
	player.position = Vector3(-1.55, 0.26, 0.0)
	add_child(player)
	rival = FIGHTER.new()
	rival.name = "Vesper"
	rival.palette = {"skin": Color("79574a"), "cloth": Color("d8c4a0"), "glove": Color("37c6d0")}
	rival.position = Vector3(1.55, 0.26, 0.0)
	add_child(rival)
	player.enemy = rival
	rival.enemy = player
	player.strike_landed.connect(_on_strike)
	rival.strike_landed.connect(_on_strike)
	player.knocked_out.connect(_on_knockout)
	rival.knocked_out.connect(_on_knockout)

func _on_strike(_attacker: AfterbellFighter, _defender: AfterbellFighter, damage: float, blocked: bool) -> void:
	flash.color = Color("77cdd2") if blocked else Color("ffe1b0")
	flash_strength = 0.08 if blocked else minf(0.28, damage * 0.012)
	shake = 0.12 if blocked else minf(0.42, damage * 0.026)
	message.text = "GUARD" if blocked else "CLEAN HIT"
	get_tree().create_timer(0.32).timeout.connect(_clear_message)

func _clear_message() -> void:
	if player != null and not player.is_down and rival != null and not rival.is_down:
		message.text = ""

func _on_knockout(loser: AfterbellFighter) -> void:
	message.text = ("VESPER WINS" if loser == player else "KESTREL WINS") + "   •   R TO RESET"

func _make_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("080f19")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("607a8c")
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	_floor_box("Arena", Vector3(0, -0.18, 0), Vector3(25, 0.35, 25), Color("0d1720"), true)
	_floor_box("Raised canvas", Vector3(0, 0.08, 0), Vector3(9.2, 0.5, 9.2), Color("1b3440"), true)
	_floor_box("Center mat", Vector3(0, 0.343, 0), Vector3(8.85, 0.05, 8.85), Color("203d47"), false)
	for x in [-4.45, 4.45]:
		for z in [-4.45, 4.45]:
			_floor_box("Corner post", Vector3(x, 1.16, z), Vector3(0.18, 2.32, 0.18), Color("c69358"), true)
	for h in [0.83, 1.33, 1.83]:
		for z in [-4.45, 4.45]:
			_floor_box("Rope", Vector3(0, h, z), Vector3(8.9, 0.042, 0.042), Color("d3d3cb"), false)
		for x in [-4.45, 4.45]:
			_floor_box("Rope", Vector3(x, h, 0), Vector3(0.042, 0.042, 8.9), Color("d3d3cb"), false)
	# Colored lanes keep the procedural arena legible without external assets.
	for x in [-3.5, 3.5]:
		_floor_box("Corner accent", Vector3(x, 0.38, -3.5), Vector3(1.1, 0.009, 0.065), Color("d0a56f"), false)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55, -32, 0)
	key.light_color = Color("fff1db")
	key.light_energy = 1.2
	key.shadow_enabled = true
	add_child(key)
	for x in [-5.7, 5.7]:
		var light := OmniLight3D.new()
		light.position = Vector3(x, 4.6, 0)
		light.light_color = Color("61b6c9") if x < 0 else Color("f7aa69")
		light.light_energy = 2.2
		light.omni_range = 11.0
		add_child(light)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 48.0
	camera.position = Vector3(0, 3.4, 8.6)
	add_child(camera)
	camera.look_at(Vector3(0, 1.3, 0))

func _floor_box(label: String, at: Vector3, size: Vector3, color: Color, solid: bool) -> void:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.name = label
	root.position = at
	add_child(root)
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.74
	instance.material_override = mat
	root.add_child(instance)
	if solid:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		root.add_child(collider)

func _make_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(canvas)
	var top := HBoxContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 36
	top.offset_right = -36
	top.offset_top = 24
	top.offset_bottom = 88
	top.add_theme_constant_override("separation", 32)
	canvas.add_child(top)
	var left := _fighter_hud(top, "KESTREL  /  YOU", Color("f15e4c"))
	player_health = left[0]
	player_stamina = left[1]
	var right := _fighter_hud(top, "VESPER  /  CPU", Color("37c6d0"))
	rival_health = right[0]
	rival_stamina = right[1]
	message = Label.new()
	message.anchor_left = 0.0
	message.anchor_right = 1.0
	message.offset_top = 108
	message.offset_bottom = 150
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 27)
	message.add_theme_color_override("font_color", Color("fff3d5"))
	canvas.add_child(message)
	var controls := Label.new()
	controls.anchor_top = 1.0
	controls.anchor_bottom = 1.0
	controls.anchor_right = 1.0
	controls.offset_top = -46
	controls.offset_bottom = -12
	controls.text = "WASD MOVE     J JAB     K CROSS     L HOOK     SPACE GUARD     Q/E SLIP     R RESET"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 15)
	controls.add_theme_color_override("font_color", Color("ded8c9"))
	canvas.add_child(controls)
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash)

func _fighter_hud(container: HBoxContainer, title: String, accent: Color) -> Array[ProgressBar]:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(col)
	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", accent)
	col.add_child(name_label)
	var hp := ProgressBar.new()
	hp.max_value = 100
	hp.value = 100
	hp.show_percentage = false
	hp.custom_minimum_size.y = 13
	col.add_child(hp)
	var energy := ProgressBar.new()
	energy.max_value = 100
	energy.value = 100
	energy.show_percentage = false
	energy.custom_minimum_size.y = 7
	col.add_child(energy)
	return [hp, energy]
