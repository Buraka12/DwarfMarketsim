extends RayCast3D

@export var player_body : CharacterBody3D
@onready var text_hud: Panel = $"../../CanvasLayer/TextHud"

var held_object : RigidBody3D = null
var look_time : float = 0.0
var last_target : Node3D = null
var is_ui_open : bool = false
var tolerance_time : float = 0.0
var is_color_changed : bool = false

func try_pick_up():
	if is_colliding():
		var target = get_collider()
		
		if target.is_in_group("pickable"):
			held_object = target
			held_object.add_collision_exception_with(player_body)
			$"../RemoteTransform3D".remote_path = held_object.get_path()
			held_object.freeze = true
			
			if held_object.has_method("open_box"):
				held_object.open_box()
				
			text_hud.position.x += 150
			
func drop_object():
	if held_object != null:
		$"../RemoteTransform3D".remote_path = ""
		
		if held_object is RigidBody3D:
			var throw_dir = -global_transform.basis.z
			held_object.apply_central_impulse(throw_dir) 
			held_object.freeze = false
			held_object.remove_collision_exception_with(player_body)
			
			if held_object.has_method("close_box"):
				held_object.close_box()
				
			text_hud.position.x -= 150
		held_object = null

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if held_object == null:
			try_pick_up()
		else:
			var looking_at_shelf = false
			
			if is_colliding():
				var target = get_collider()
				if target.owner != null and target.owner.has_method("try_add_item"):
					looking_at_shelf = true
					
			if looking_at_shelf:
				_on_place_timer_timeout()
				$PlaceTimer.start()      
			else:
				drop_object()
				
	elif event.is_action_released("interact"):
		$PlaceTimer.stop()
		

func _on_place_timer_timeout() -> void:
	if is_colliding():
		var target = get_collider()
		if target.owner != null and target.owner.has_method("try_add_item") and held_object.get_item_count() > 0:
			var is_placed = target.owner.try_add_item(held_object.itemdata, target)
			if is_placed : 
				var start_pos = held_object.remove_one_item()
				# tween animasyonu
			else :
				$PlaceTimer.stop()

func _on_ui_timer_timeout() -> void:
	var hud_text = "" 
	
	if held_object != null and held_object.has_method("get_info"):
		hud_text = held_object.get_info()
		
	if is_colliding() and get_collider().is_in_group("interactable"):
		var current_target = get_collider()
		
		if is_color_changed == false:
			$"../../CanvasLayer/Chrossair/ColorRect".color = Color.RED
			is_color_changed = true
		
		if current_target == last_target:
			look_time += 0.1
			tolerance_time = 0.0
			if look_time >= 0.5:
				# kargo
				if current_target.has_method("get_info"):
					hud_text = current_target.get_info()
				# shelf
				elif current_target.owner != null and current_target.owner.has_method("get_zone_info"):
					hud_text = current_target.owner.get_zone_info(current_target)
		else:
			tolerance_time += 0.1
			if tolerance_time >= 0.2:
				_reset_gaze()
				last_target = current_target
				
	else:
		if last_target != null:
			tolerance_time += 0.1
			if tolerance_time >= 0.2: 
				_reset_gaze()

	if hud_text != "":
		update_hud(hud_text)
	else:
		text_hud.visible = false
		is_ui_open = false
		
func _reset_gaze():
	look_time = 0.0
	last_target = null
	is_color_changed = false
	$"../../CanvasLayer/Chrossair/ColorRect".color = Color.WHITE
			
	look_time = 0.0
	is_ui_open = false
	last_target = null
	is_color_changed = false
	$"../../CanvasLayer/Chrossair/ColorRect".color = Color.WHITE

func update_hud(info_text: String) -> void:
	text_hud.get_child(0).text = info_text
	text_hud.visible = true
	is_ui_open = true
