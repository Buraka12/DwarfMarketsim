extends Node3D

@onready var shelf: MeshInstance3D = $"Market Shelf"

var zones_data : Array = []

func _ready() -> void:
	for child in shelf.get_children():
		var zone_dict = {
			"helper_box": child,          # Görünmez ölçüm kutumuz
			"body": child.get_node("StaticBody3D"), # Çarpışmayı algılayan düğüm
			"stored_items": [],           # Bu rafa koyulan ürünlerin listesi
			"current_item_data": null     # Bu raftaki ürün tipi (Süt, vb.)
		}
		zones_data.append(zone_dict)
		
func get_zone_info(hit_body) -> String:
	for zone in zones_data:
		if zone["body"] == hit_body:
			if zone["current_item_data"] != null:
				return "Raf: " + zone["current_item_data"].itemname + "\nAdet: " + str(zone["stored_items"].size())
			else:
				return "Boş Raf"
				
	return ""
		
func try_add_item(itemdata, hit_body):
	for zone in zones_data:
		if zone["body"] == hit_body:
			if zone["stored_items"].size() == 0 or zone["current_item_data"] == itemdata:
				var temp_model = itemdata.model.instantiate()
				var item_aabb = AABB()
				var model_scale = Vector3.ONE
				
				if temp_model is MeshInstance3D:
					item_aabb = temp_model.mesh.get_aabb()
					model_scale = temp_model.scale
				else:
					item_aabb = temp_model.get_child(0).mesh.get_aabb()
					model_scale = temp_model.get_child(0).scale
					
				var item_mesh_size = item_aabb.size * model_scale
				var pivot_to_bottom = -item_aabb.position.y * model_scale.y
				
				temp_model.free()
				
				var total_item_size = item_mesh_size + itemdata.item_spacing
				var box_size = zone["helper_box"].mesh.get_aabb().size
				
				var max_x = int(box_size.x / total_item_size.x)
				var max_y = int(box_size.y / total_item_size.y)
				var max_z = int(box_size.z / total_item_size.z)
				var max_capacity = max_x * max_y * max_z
				if zone["stored_items"].size() < max_capacity:
					zone["current_item_data"] = itemdata
					zone["stored_items"].append(itemdata)
					
					var current_index = zone["stored_items"].size() - 1
					
					place_item_visual(zone, itemdata, current_index, total_item_size, max_x, max_z,pivot_to_bottom)
					# ---------------------------------
					
					print("Eklendi! Raftaki " + itemdata.itemname + " sayısı: ", zone["stored_items"].size())
					return true
					
				else:
					print("Bu raf bölmesi tamamen dolu!")
					return false
			else:
				print("Buraya bunu koyamazsın, başka bir ürün var!")
				return false
				
	return false 
	
func try_remove_item(hit_body):
	for zone in zones_data:
		if zone["body"] == hit_body:
			if zone["stored_items"] > 0 :
				
			
	


func place_item_visual(zone, itemdata, index, total_item_size, max_x, max_z, pivot_to_bottom):
	var visual_instance = itemdata.model.instantiate()
	var helper_mesh = zone["helper_box"]
	
	helper_mesh.get_parent().add_child(visual_instance)
	
	var aabb = helper_mesh.mesh.get_aabb()
	var grid_x = index % max_x
	var grid_z = (index / max_x) % max_z
	var reverse_z = (max_z - 1 ) - grid_z
	var grid_y = index / (max_x * max_z)
	var start_x = aabb.position.x + (total_item_size.x / 2.0)
	var start_z = aabb.position.z + (total_item_size.z / 2.0)
	var start_y = aabb.position.y + pivot_to_bottom
	var local_pos = Vector3(
		start_x + (grid_x * total_item_size.x),
		start_y + (grid_y * total_item_size.y),
		start_z + (reverse_z * total_item_size.z)
	)
	visual_instance.position = helper_mesh.position + local_pos
