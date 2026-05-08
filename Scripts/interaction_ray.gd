extends RayCast3D

var held_object = null
@onready var hold_position = $"../HoldPosition"

func _process(_delta):
	if Input.is_action_just_pressed("interact"):
		if held_object == null:
			try_pick_up()
		else:
			drop_object()

func try_pick_up():
	if is_colliding():
		var target = get_collider()
		
		if target.is_in_group("interactable"):
			held_object = target
			
			if held_object is RigidBody3D:
				held_object.freeze = true 
			
			held_object.reparent(hold_position)
			held_object.global_position = hold_position.global_position
			held_object.global_rotation = hold_position.global_rotation

func drop_object():
	if held_object != null:
		var world = get_tree().current_scene
		held_object.reparent(world)
		
		if held_object is RigidBody3D:
			held_object.freeze = false
			var throw_dir = -global_transform.basis.z
			held_object.apply_central_impulse(throw_dir * 3.0) 
			
		held_object = null
