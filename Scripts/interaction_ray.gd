extends RayCast3D

@export var player_body : CharacterBody3D
@onready var text_hud: Panel = $"../../CanvasLayer/TextHud"
@onready var hold_position: Marker3D = $"../HoldPosition"

var held_object : RigidBody3D = null
var look_time : float = 0.0
var last_target : Node3D = null
var is_ui_open : bool = false
var tolerance_time : float = 0.0
var is_color_changed : bool = false

func _physics_process(delta: float) -> void:
	if held_object != null:
		var target_pos = hold_position.global_position
		var current_pos = held_object.global_position
		var distance = current_pos.distance_to(target_pos)
		
		# HL2 Kuralı: Çok uzaklaşırsa veya duvara fena takılırsa düşür
		if distance > 2.0:
			drop_object()
		else:
			# --- 1. ÇİZGİSEL HAREKET (Titremeyi Önleyen Hız Eklemesi) ---
			var direction = target_pos - current_pos
			var pull_speed = 15.0
			
			# Oyuncunun hızını da kutunun hızına ekliyoruz (Seninle beraber koşması için)
			var player_vel = player_body.velocity 
			held_object.linear_velocity = (direction * pull_speed) + player_vel
			
			# --- 2. AÇISAL HAREKET (Kamerayla Birlikte Dönmesi İçin) ---
			var target_basis = hold_position.global_basis
			var current_basis = held_object.global_basis
			
			# X, Y ve Z eksenlerinin farkını hesaplayan mükemmel dönüş matematiği
			var rot_diff = current_basis.x.cross(target_basis.x) + current_basis.y.cross(target_basis.y) + current_basis.z.cross(target_basis.z)
			
			var rot_speed = 10.0 # Kutunun kameraya ayak uydurma hızı (Yumuşaklığını buradan ayarlayabilirsin)
			held_object.angular_velocity = rot_diff * rot_speed
func try_pick_up():
	if is_colliding():
		var target = get_collider()
		if target.is_in_group("pickable"):
			held_object = target
			held_object.add_collision_exception_with(player_body) # Oyuncuyu ittirmesin
			
			# YENİ FİZİK KURALLARI: Dondurma yok, sadece yerçekimini kapat!
			held_object.gravity_scale = 0.0 
			held_object.angular_damp = 10.0 # Elimizdeyken fırıldak gibi dönmesin
			held_object.linear_damp = 10.0  # Hareketleri yumuşasın
			
			if held_object.has_method("open_box"):
				held_object.open_box()
			
func drop_object():
	if held_object != null:
		# ESKİ AYARLARA GERİ DÖN
		held_object.gravity_scale = 1.0
		held_object.angular_damp = 0.0
		held_object.linear_damp = 0.0
		held_object.remove_collision_exception_with(player_body)
		
		# Fırlatma kuvveti (Throw impulse) aynen kalsın
		var throw_dir = -global_transform.basis.z
		held_object.apply_central_impulse(throw_dir * 5.0) # İstersen buradaki gücü artırabilirsin
		
		if held_object.has_method("close_box"):
			held_object.close_box()
			
		held_object = null

func _input(event: InputEvent) -> void:
	# ETKİLEŞİM VE DİZME TUŞU (E)
	if event.is_action_pressed("interact"):
		if held_object == null:
			# --- ELİMİZ BOŞKEN YAPILACAKLAR ---
			if is_colliding():
				var target = get_collider()
				
				# 1. ÖNCELİK: Baktığımız şey bir düğme/şalter mi?
				if target.has_method("interact"):
					target.interact() # Tıkla ve ışığı aç/kapat!
					
				# 2. ÖNCELİK: Baktığımız şey kargo kutusu mu?
				elif target.is_in_group("pickable"):
					try_pick_up() # Eline al
		else:
			# --- ELİMİZ DOLUYKEN YAPILACAKLAR (Burayı ellemiyoruz, aynı kalıyor) ---
			var looking_at_shelf = false
			if is_colliding() and get_collider().owner != null and get_collider().owner.has_method("try_add_item"):
				looking_at_shelf = true
					
			if looking_at_shelf:
				_on_place_timer_timeout() 
				if has_node("PlaceTimer"): $PlaceTimer.start()      
			else:
				drop_object() 
				
	elif event.is_action_released("interact"):
		if has_node("PlaceTimer"): $PlaceTimer.stop()
	# GERİ ALMA TUŞU (R)
	elif event.is_action_pressed("reverse"):
		if held_object != null:
			if is_colliding() and get_collider().owner != null and get_collider().owner.has_method("try_add_item"):
				_on_reverse_timer_timeout() # İlk ürünü anında geri al
				if has_node("ReverseTimer"): $ReverseTimer.start()
					
	elif event.is_action_released("reverse"):
		if has_node("ReverseTimer"): $ReverseTimer.stop()

# --- E TUŞU: Kutudan Rafa Uçuş (Kavisli) ---
func _on_place_timer_timeout() -> void:
	if is_colliding():
		var target = get_collider()
		if target.owner != null and target.owner.has_method("try_add_item") and held_object.get_item_count() > 0:
			
			# Rafın görünmez objesini al (Uçuş bitince görünür olacak)
			var target_item_node = target.owner.try_add_item(held_object.itemdata, target)
			
			if target_item_node != null: 
				# Kutunun içindeki modeli sök, başlangıç koordinatını al
				var start_pos = held_object.remove_one_item()
				var end_pos = target_item_node.global_position
				
				# Kutudayken rafa dizildiği için görünmez yap (Tween uçuş bitince açacak)
				target_item_node.visible = false 
				
				# 1. Sahte Aktörü (Dummy) Yarat
				var dummy_item = held_object.itemdata.model.instantiate()
				get_tree().current_scene.add_child(dummy_item) # Ana sahneye koy
				dummy_item.global_position = start_pos
				
				# --- SİHİRLİ KAVİSLİ UÇUŞ TWEEN MATEMATİĞİ ---
				var tween = get_tree().create_tween()
				var flight_duration = 0.25
				
				# Tepe noktası: Kutunun yüksekliği ile Rafın yüksekliğinin ortalamasından bir miktar yukarı
				var arc_height = max(start_pos.y, end_pos.y) + 0.15
				
				# Tepeye Zıplama (Ease-Out)
				tween.tween_property(dummy_item, "global_position:y", arc_height, flight_duration * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				
				# Uçuş (Linear/Sine) - Yatay düzlemde uçuş zıplamanın başından başlar
				tween.parallel().tween_property(dummy_item, "global_position:x", end_pos.x, flight_duration).set_trans(Tween.TRANS_SINE)
				tween.parallel().tween_property(dummy_item, "global_position:z", end_pos.z, flight_duration).set_trans(Tween.TRANS_SINE)
				
				# Yere Düşüş (Ease-In) - Yatay uçuş biterken Y düşüşü başlar
				tween.tween_property(dummy_item, "global_position:y", end_pos.y, flight_duration * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				
				# Final Callback
				tween.tween_callback(func():
					if is_instance_valid(dummy_item):
						dummy_item.queue_free()
					
					# KRİTİK KONTROL: R tuşu spamlanıp bu obje çoktan silinmiş olabilir!
					if is_instance_valid(target_item_node):
						target_item_node.visible = true
				)
				
			else:
				if has_node("PlaceTimer"): $PlaceTimer.stop()

# --- R TUŞU: Raftan Kutuya Uçuş (Mükemmel Geri Alma) ---
func _on_reverse_timer_timeout() -> void:
	if is_colliding() and held_object != null:
		var target = get_collider()
		
		if target.owner != null and target.owner.has_method("try_prepare_remove_item") and held_object.can_accept_item(held_object.itemdata):
			
			# Rafın ürününü sök ama silme, görünmez objeyi al (Dünyadan silmek için)
			var shelf_item_node = target.owner.try_prepare_remove_item(target, held_object.itemdata)
			
			if shelf_item_node != null:
				# Uçuş koordinatları
				var start_pos = shelf_item_node.global_position
				
				# Kutunun içindeki target pozisyonunu al (Kutudayken nereye "löp" diye düşecek?)
				var current_index_in_box = held_object.get_item_count()
				var local_target_pos = held_object.calculate_local_pos_at_index(current_index_in_box)
				
				# Local'den Global'e çeviriyoruz (Kutunun global transformu ile)
				# ÇÖZÜM: held_object.visual_items.to_global(local_target_pos) yapmalıyız
				var end_pos = held_object.visual_items.to_global(local_target_pos)
				
				# 1. Sahte Aktörü (Dummy) Yarat (Raftan Kutunun Türünü türet)
				var dummy_item = held_object.itemdata.model.instantiate()
				get_tree().current_scene.add_child(dummy_item) 
				dummy_item.global_position = start_pos
				
				# --- SİHİRLİ GERİ ALMA TWEEN MATEMATİĞİ (Ters Arc) ---
				var tween = get_tree().create_tween()
				var flight_duration = 0.2
				
				# Tepe noktası: Rafın yüksekliği ile Kutunun yüksekliğinin ortalamasından bir miktar yukarı
				var arc_height = max(start_pos.y, end_pos.y) + 0.3 
				
				# Önce Raftan Yukarı Zıplama (Ease-Out)
				tween.tween_property(dummy_item, "global_position:y", arc_height, flight_duration * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				
				# Kutunun üzerine Yatay Uçuş (Linear/Sine)
				tween.parallel().tween_property(dummy_item, "global_position:x", end_pos.x, flight_duration).set_trans(Tween.TRANS_SINE)
				tween.parallel().tween_property(dummy_item, "global_position:z", end_pos.z, flight_duration).set_trans(Tween.TRANS_SINE)
				
				# Kutunun içine "Löp" Düşüş (Ease-In)
				tween.tween_property(dummy_item, "global_position:y", end_pos.y, flight_duration * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				
				# Final Callback
				tween.tween_callback(func():
					if is_instance_valid(dummy_item):
						dummy_item.queue_free()          
					
					# Asıl model hala duruyorsa sil
					if is_instance_valid(shelf_item_node):
						shelf_item_node.queue_free()
					
					
					# Rafa haber ver, raf zone'unu sıfırlasın
					target.owner.finalize_removal(target)
					
					# Kutunun içine rafa koyduğumuz 3D modeli değil, KENDİ türettiğimiz modeli ekliyoruz
					var box_accept_node = held_object.itemdata.model.instantiate()
					held_object.add_one_item(box_accept_node)
				)
				
			else:
				if has_node("ReverseTimer"): $ReverseTimer.stop()

# Modüler UI Güncelleyici
func update_hud(info_text: String) -> void:
	text_hud.get_child(0).text = info_text
	text_hud.visible = true
	is_ui_open = true

# Hiyerarşik UI Döngüsü
func _on_ui_timer_timeout() -> void:
	var gosterilecek_metin = "" 
	
	# Katman 1: Kutu
	if held_object != null and held_object.has_method("get_info"):
		gosterilecek_metin = held_object.get_info()
		
	# Katman 2: Lazer Hedefi (Öncelikli)
	if is_colliding() and get_collider().is_in_group("interactable"):
		var current_target = get_collider()
		
		if is_color_changed == false:
			$"../../CanvasLayer/Chrossair/ColorRect".color = Color.RED
			is_color_changed = true
		
		if current_target == last_target:
			look_time += 0.1
			tolerance_time = 0.0
			if look_time >= 0.5:
				if current_target.has_method("get_info"):
					gosterilecek_metin = current_target.get_info()
				elif current_target.owner != null and current_target.owner.has_method("get_zone_info"):
					gosterilecek_metin = current_target.owner.get_zone_info(current_target)
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

	# Katman 3: Karar
	if gosterilecek_metin != "":
		update_hud(gosterilecek_metin)
	else:
		text_hud.visible = false
		is_ui_open = false

func _reset_gaze():
	look_time = 0.0
	last_target = null
	is_color_changed = false
	$"../../CanvasLayer/Chrossair/ColorRect".color = Color.WHITE
