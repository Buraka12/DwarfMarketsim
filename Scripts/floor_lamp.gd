extends Node3D
@onready var mesh: MeshInstance3D = $Lamb/Cylinder_001
@onready var light_bulb: OmniLight3D = $Lamb/Cylinder_001/OmniLight3D

var is_on: bool = false

func _ready() -> void:
	if light_bulb.visible == true and mesh.material_overlay.emission_energy_multiplier != 1.0:
		is_on = true

func toggle_state():
	is_on = !is_on # Durumu tersine çevir (Açıksa kapat, kapalıysa aç)
	
	if is_on:
		light_bulb.visible = true
		mesh.material_overlay.emission_energy_multiplier = 16
	else:
		light_bulb.visible = false
		mesh.material_overlay.emission_energy_multiplier = 1
