extends RigidBody3D

@export var itemdata : ItemData
@onready var visual_items: Node3D = $VisualItems
@onready var box_inner_size: Node3D = $MeshInstance3D
@onready var animplayer : AnimationPlayer = $MeshInstance3D/AnimationPlayer


var boxsize : Vector3 = Vector3(0.5,0.3,0.3)
var stored_items : Array = []
var is_box_opened : bool = false

func _ready() -> void:
	if itemdata != null and itemdata.model != null:
		generate_visual_items()

func generate_visual_items():
	var temp_item = itemdata.model.instantiate()
	var info = get_true_model_info(temp_item)
	temp_item.queue_free()
	
	var model_size = info["size"]
	var lowest_point = info["lowest_y"]
	
	var cell_size = model_size + itemdata.item_spacing
	
	var y_padding = 0.02 
	
	var max_x = int(boxsize.x / cell_size.x)
	var max_y = int((boxsize.y - y_padding) / cell_size.y)
	var max_z = int(boxsize.z / cell_size.z)
	
	if max_x == 0 or max_y == 0 or max_z == 0:
		print("Kutu çok küçük veya ürün çok büyük!")
		return
	
	var offset_x = (max_x - 1) * cell_size.x / 2.0
	var offset_z = (max_z - 1) * cell_size.z / 2.0
	
	var offset_y = -(boxsize.y / 2.0) - lowest_point + 0.01
	
	for x in range(max_x):
		for y in range(max_y):
			for z in range(max_z):
				
				var new_item = itemdata.model.instantiate()
				visual_items.add_child(new_item)
				stored_items.append(new_item) #arraye koyduk
				
				var new_position = Vector3(
					(x * cell_size.x) - offset_x,
					(y * cell_size.y) + offset_y,
					(z * cell_size.z) - offset_z
				)
				new_item.position = new_position
	
func get_true_model_info(item_node: Node) -> Dictionary:
	var total_size = Vector3(0.1, 0.1, 0.1)
	var lowest_y = 9999.0 # Başlangıçta çok yüksek bir değer veriyoruz ki her halükarda daha küçüğünü bulsun
	
	var visual_nodes = item_node.find_children("*", "VisualInstance3D", true, false)
	
	for child in visual_nodes:
		var aabb = child.get_aabb()
		var actual_size = aabb.size * child.scale
		total_size = actual_size
		
		var bottom_point = (aabb.position.y * child.scale.y) + child.position.y
		
		if bottom_point < lowest_y:
			lowest_y = bottom_point
			
	if lowest_y == 9999.0:
		lowest_y = str()
		
	return {"size": total_size, "lowest_y": lowest_y}

func get_info():
	var infotext = "Ürün: " + itemdata.itemname + "\nAdet: " + str(stored_items.size())
	return infotext
	
func open_box():
	if is_box_opened == false:
		is_box_opened = true
		animplayer.play("Box_Open")
	
func close_box():
	if is_box_opened == true:
		is_box_opened =false
		animplayer.play_backwards("Box_Open")
"""
1. Veri Katmanı (Data-Driven Design)
En başta her şeyi kutunun koduna yazmak yerine ItemData adında özel bir kaynak (Resource) sınıfı oluşturduk.

Amacı: Kutuyu "aptal" ama "kullanışlı" bırakmak. Kutu, içinde süt mü var, enerji içeceği mi var asla umursamaz. Sadece itemdata değişkeninin içine ne koyarsan onun verisini okur.

Bu sayede oyuna 1000 tane yeni ürün eklesen bile kargo kutusu için tek bir satır kod yazmana gerek kalmaz.

2. İllüzyon ve Performans (Instancing)
generate_visual_items() fonksiyonunun içindeki temel mantık bir göz boyamadır.

Oyuncu kutuya baktığında 24 tane süt görüyor ama aslında orada fiziksel hiçbir obje yok.

itemdata.model.instantiate() diyerek ürünün sadece "görüntüsünü" (Mesh) kutunun içine bir çocuk düğüm (Child Node) olarak ekliyoruz. RigidBody (Fizik) hesaplamaları olmadığı için bilgisayarın işlemcisi hiç yorulmuyor.

3. Model Tarayıcı (Kurşun Geçirmez Fonksiyon)
Yazdığımız get_true_model_info fonksiyonu, senin veya modellemeci arkadaşının Blender'da yapabileceği tüm orijin noktası (Pivot) hatalarını yok eden o sihirli kısımdır.

find_children: Modelin içine girip gizlenmiş gerçek 3D görseli (VisualInstance3D) bulur.

get_aabb(): Objenin etrafına görünmez bir kutu çizer ve bize bunun matematiksel boyutunu (size) verir.

lowest_y Algoritması: Modelin merkezinin nerede olduğunu umursamaz. Köşelerden en aşağıda olanı hesaplar ve modelin Godot içindeki gizli kayma payını (child.position.y) buna ekleyerek fiziksel olarak en dip noktayı bulur.

4. Dinamik Kapasite (Bölme İşlemi)
Kutunun kaç tane ürün alacağını elle yazmak yerine, bu işi oyun motoruna bıraktık.

Hücre Boyutu (cell_size): Ürünün kendi boyutu ile senin verdiğin boşluk (item_spacing) değerini toplar. Bu, her bir ürünün uzayda kaplayacağı kişisel alanıdır.

max_x, max_y, max_z: Kutunun iç hacmini (box_inner_size), bu hücre boyutuna böleriz. int() kullanarak sayıyı aşağı yuvarlarız (çünkü kutuya 4.5 tane süt sığmaz, 4 tane sığar). Artık kutunun dinamik kapasitesi hesaplanmıştır.

5. Offset (Merkezleme) Matematiği
Döngüler sıfırdan (x = 0) başladığı için, eğer bir müdahale yapmazsak ilk ürün kutunun tam ortasında (0,0,0) doğar ve diğerleri kutunun dışına doğru dizilerek taşar.

offset_x ve offset_z: Ürünleri kutunun sol üst köşesine doğru iter. Formülü şudur: (Maksimum ürün sayısı - 1) çarpı (Hücre Boyutu) bölü 2. Bu sayede ürün dizilimi tam olarak kutunun merkezini ortalar.

offset_y: Kutunun yüksekliğinin yarısı kadar eksiye (tabana) iner. Ardından tarayıcıdan gelen o gerçek dip noktasını (lowest_point) bundan çıkartarak ürünü milimetrik olarak zemine yapıştırır. Senin eklediğin + 0.01 ise nefes alma payı (Padding) olur.

6. Matris (İç İçe Döngüler)
Son olarak o meşhur üçlü for döngüsü çalışır.

X, Y ve Z eksenlerinde adım adım ilerler.

Her adımda yeni bir model yaratır.

Bulunduğu döngü sayısını (x, y, z), hücre boyutuyla çarpar ve hesapladığımız o "Offset" (kaydırma) değerlerini çıkartarak her bir ürünün 3 boyutlu uzaydaki kusursuz pozisyonunu belirler.

Ortaya çıkan bu sistem, ileride geliştireceğin 3D market simülatörü projesinde yapacağın büyük depo dizilimlerinin ve raf algoritmalarının doğrudan bel kemiğidir.
"""
