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
		
		if target.is_in_group("interactable"):
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
			drop_object()
			


func _on_timer_timeout():
	# 1. DURUM: Raycast hedefe çarpıyor mu?w
	if is_colliding() and get_collider().is_in_group("interactable"):
		var current_target = get_collider()
		
		if is_color_changed == false:
			$"../../CanvasLayer/Chrossair/ColorRect".color = Color.RED
			is_color_changed = true
		
		# Aynı hedefe bakmaya devam ediyoruz
		if current_target == last_target:
			look_time += 0.1
			tolerance_time = 0.0 # Gözümüz hedefte, toleransı sıfırla
			if look_time >= 0.5 and not is_ui_open:
				if current_target.has_method("get_info"):
					text_hud.get_child(0).text = current_target.get_info()
					text_hud.visible = true
					is_ui_open = true
		else:
			# Başka bir kutuya kaydık. Hemen silmek yerine tolerans tanı:
			tolerance_time += 0.1
			if tolerance_time >= 0.2: # 0.2 saniye boyunca cidden başka yere baktıysa
				_reset_gaze()
				last_target = current_target
				
	# 2. DURUM: Boşluğa bakıyoruz (Mikro-sapma anı burası)
	else:
		if last_target != null:
			tolerance_time += 0.1
			if tolerance_time >= 0.2: # 0.2 saniye boyunca havaya baktıysa kapat
				_reset_gaze()
func _reset_gaze():
	if last_target != null and is_ui_open:
		text_hud.visible = false
			
	look_time = 0.0
	is_ui_open = false
	last_target = null
	is_color_changed = false
	$"../../CanvasLayer/Chrossair/ColorRect".color = Color.WHITE
