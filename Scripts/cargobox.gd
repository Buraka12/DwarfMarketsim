extends RigidBody3D

@export var itemdata : ItemData
@onready var visual_items: Node3D = $VisualItems
@onready var box_inner_size: Node3D = $MeshInstance3D
@onready var animplayer : AnimationPlayer = $MeshInstance3D/AnimationPlayer

var boxsize : Vector3 = Vector3(0.5, 0.3, 0.3)
var stored_items : Array = [] # 3D Modelleri tutacak
var is_box_opened : bool = false

# Matris değişkenleri (Hem doğarken hem eklerken kullanmak için dışarı aldık)
var max_x: int
var max_y: int
var max_z: int
var cell_size: Vector3
var offset_x: float
var offset_y: float
var offset_z: float
var max_capacity: int = 0

func _ready() -> void:
	if itemdata != null and itemdata.model != null:
		setup_matrix_calculations()
		generate_visual_items()

# Matematik hesaplarını tek bir yerde yapıyoruz
func setup_matrix_calculations():
	var temp_item = itemdata.model.instantiate()
	var info = get_true_model_info(temp_item)
	temp_item.queue_free()
	
	var model_size = info["size"]
	var lowest_point = info["lowest_y"]
	cell_size = model_size + itemdata.item_spacing
	var y_padding = 0.02 
	
	max_x = int(boxsize.x / cell_size.x)
	max_y = int((boxsize.y - y_padding) / cell_size.y)
	max_z = int(boxsize.z / cell_size.z)
	max_capacity = max_x * max_y * max_z
	
	offset_x = (max_x - 1) * cell_size.x / 2.0
	offset_z = (max_z - 1) * cell_size.z / 2.0
	offset_y = -(boxsize.y / 2.0) - lowest_point + 0.01

func generate_visual_items():
	if max_capacity <= 0:
		return
		
	# Kutuyu başlangıçta tam kapasite doldur
	for i in range(max_capacity):
		var new_item = itemdata.model.instantiate()
		visual_items.add_child(new_item)
		
		# Pozisyonlama
		new_item.position = calculate_local_pos_at_index(i)
		
		# Array'e itemdata'yı değil, KENDİSİNİ kaydediyoruz
		stored_items.append(new_item)

# Verilen indeksteki local pozisyonu hesaplayan modüler fonksiyon
func calculate_local_pos_at_index(index: int) -> Vector3:
	var grid_x = index % max_x
	var grid_z = (index / max_x) % max_z
	var grid_y = index / (max_x * max_z)
	
	return Vector3(
		(grid_x * cell_size.x) - offset_x,
		(grid_y * cell_size.y) + offset_y,
		(grid_z * cell_size.z) - offset_z
	)

# R Tuşu için: Dışarıdan gelen görseli kutuya ekle
func add_one_item(item_node: Node3D):
	if stored_items.size() >= max_capacity:
		item_node.queue_free()
		return # Kutu dolu
		
	visual_items.add_child(item_node)
	
	var index = stored_items.size()
	stored_items.append(item_node)
	
	# Pozisyonunu ayarla
	item_node.position = calculate_local_pos_at_index(index)

# E Tuşu için: Kutudan son ürünü sök
func remove_one_item():
	if stored_items.size() > 0:
		# Array'den son modeli kopar
		var item_to_remove = stored_items.pop_back()
		var start_pos = item_to_remove.global_position
		item_to_remove.queue_free() # Dünyadan sil
		return start_pos # Başlangıç koordinatını döndür
	return null

func can_accept_item(item_info: ItemData) -> bool:
	return stored_items.size() < max_capacity and itemdata == item_info

func get_item_count() -> int:
	return stored_items.size()

func get_info():
	var infotext = "Kutu: " + itemdata.itemname + "\nAdet: " + str(stored_items.size()) + " / " + str(max_capacity)
	return infotext
	
func open_box():
	if is_box_opened == false:
		is_box_opened = true
		animplayer.play("Box_Open")
	
func close_box():
	if is_box_opened == true:
		is_box_opened = false
		animplayer.play_backwards("Box_Open")

func get_true_model_info(item_node: Node) -> Dictionary:
	var total_size = Vector3(0.1, 0.1, 0.1)
	var lowest_y = 9999.0 
	var visual_nodes = item_node.find_children("*", "VisualInstance3D", true, false)
	for child in visual_nodes:
		var aabb = child.get_aabb()
		var actual_size = aabb.size * child.scale
		total_size = actual_size
		var bottom_point = (aabb.position.y * child.scale.y) + child.position.y
		if bottom_point < lowest_y:
			lowest_y = bottom_point
	if lowest_y == 9999.0:
		lowest_y = 0.0
	return {"size": total_size, "lowest_y": lowest_y}
