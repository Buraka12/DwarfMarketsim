extends CharacterBody3D

@onready var head = $Head

const SPEED = 5.0
const ACCELERATION = 10.0
const FRICTION = 10.0     
const JUMP_VELOCITY = 3.5
var mouse_sensitivity = 0.004
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var zoom = false


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# YENİ HAREKET FİZİĞİ (İvme ve Sürtünme)
	if direction:
		# Aniden SPEED'e eşitlemek yerine, yavaşça SPEED'e doğru lerp'liyoruz
		velocity.x = lerp(velocity.x, direction.x * SPEED, ACCELERATION * delta)
		velocity.z = lerp(velocity.z, direction.z * SPEED, ACCELERATION * delta)
	else:
		# Elimizi tuştan çektiğimizde aniden 0'a eşitlemek yerine yavaşça durduruyoruz (Fren)
		velocity.x = lerp(velocity.x, 0.0, FRICTION * delta)
		velocity.z = lerp(velocity.z, 0.0, FRICTION * delta)
		
	move_and_slide()
	var object
	for i in range(get_slide_collision_count()):
		object = get_slide_collision(i)
		var push_target = object.get_collider()
		if push_target is RigidBody3D:
			var hit_normal = object.get_normal()
			if hit_normal.y > 0.5:
				continue
			
			var push_dir = -hit_normal
			push_dir.y = 0.0
			push_dir = push_dir.normalized()
			var box_speed = push_target.linear_velocity.length()
			
			if box_speed < 4.0: 
				push_target.apply_central_impulse(push_dir * 1)
			
	
	# ESC
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom") and zoom == false:
		zoom = true
		$Head/Camera3D.fov = 15
	elif event.is_action_pressed("zoom") and zoom == true:
		zoom = false
		$Head/Camera3D.fov = 75
