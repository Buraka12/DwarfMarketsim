extends Node3D

@export var target_node: Node 

func interact():
	if target_node != null:
		#"toggle_state" diye bir fonksiyon varsa onu çalıştır
		if target_node.has_method("toggle_state"):
			target_node.toggle_state()
		else:
			print("Hata: Hedefte toggle_state yok!")
