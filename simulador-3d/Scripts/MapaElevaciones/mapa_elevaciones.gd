extends MeshInstance3D

@export var controlador: Node
@export var cubo_frontal: MeshInstance3D

# --- MEDIDAS REALES DE TU TERRENO EN GODOT ---
# Sustituye estos valores por el "Size" exacto que le pusiste a tu PlaneMesh
@export var tamano_plano_x: float = 1598.0
@export var tamano_plano_z: float = 1393.0

# --- VARIABLES PARA EL AUTÓMATA ---
var voxel_grid: PackedInt32Array

# Diccionario de estados del autómata celular
const ESTADO_AIRE = 0
const ESTADO_SUBSUELO = 1 # Roca / Camino (Rosa) / Terreno (Verde) - ¡NO ARDE!
const ESTADO_MATORRAL = 2 # Vegetación Baja (Rojo)
const ESTADO_ARBOL = 3    # Vegetación Alta (Azul)
const ESTADO_FUEGO = 99   # Fuego activo

var imagen_elevacion: Image
var imagen_vegetacion: Image

var resolucion_matriz = 356
var resolucion_y = 60 # Altura de la matriz volumétrica

# Ajustado al valor de tu nuevo shader (Diferencia entre Min y Max del DEM)
var escala_altura = 140.648 

func _ready():
	print("Iniciando extracción de datos GIS topográficos...")
	
	var material_shader = get_active_material(0) as ShaderMaterial
	
	# Extraemos las texturas como imágenes normales, no como ruido procedimental
	var textura_elevacion = material_shader.get_shader_parameter("mapa_elevacion") as Texture2D
	var textura_vegetacion = material_shader.get_shader_parameter("mapa_vegetacion") as Texture2D
	
	# Extraemos los datos puros a la RAM del procesador
	imagen_elevacion = textura_elevacion.get_image()
	imagen_vegetacion = textura_vegetacion.get_image()
	
	imagen_elevacion.decompress()
	imagen_vegetacion.decompress()
	
	# Ajustamos a la cuadrícula del voxel grid
	imagen_elevacion.resize(resolucion_matriz, resolucion_matriz, Image.INTERPOLATE_NEAREST)
	imagen_vegetacion.resize(resolucion_matriz, resolucion_matriz, Image.INTERPOLATE_NEAREST)
	
	print("¡Imágenes cargadas en CPU! Construyendo matriz...")
	
	_generar_matriz_3d()
	_generar_colision_terreno()
	enviar_mapa_combustibles_a_gpu()


func _generar_matriz_3d():
	var total_celdas = resolucion_matriz * resolucion_y * resolucion_matriz
	voxel_grid = PackedInt32Array()
	voxel_grid.resize(total_celdas)
	voxel_grid.fill(ESTADO_AIRE)
	
	for x in range(resolucion_matriz):
		for z in range(resolucion_matriz):
			
			var valor_relieve = imagen_elevacion.get_pixel(x, z).r
			var y_superficie = int(valor_relieve * (resolucion_y - 1))
			
			var color_veg = imagen_vegetacion.get_pixel(x, z)
			var estado_superficie = ESTADO_AIRE
			
			# --- LÓGICA DE DETECCIÓN POR COLORES ---
			# Si el azul domina y no hay casi rojo -> ÁRBOL
			if color_veg.b > 0.5 and color_veg.r < 0.5:
				estado_superficie = ESTADO_ARBOL
			
			# Si el rojo domina y no hay casi azul -> MATORRAL
			elif color_veg.r > 0.5 and color_veg.b < 0.5:
				estado_superficie = ESTADO_MATORRAL
			
			# Si es verde (g>0.5), o rosa (r>0.5 Y b>0.5), o foto original -> SUBSUELO
			else:
				estado_superficie = ESTADO_SUBSUELO
				
			# Rellenar verticalmente esa coordenada
			for y in range(resolucion_y):
				var indice_1d = _obtener_indice_1d(x, y, z)
				
				if y < y_superficie:
					voxel_grid[indice_1d] = ESTADO_SUBSUELO
				elif y >= y_superficie and y <= y_superficie + 4:
					voxel_grid[indice_1d] = estado_superficie

	print("¡Matriz 3D lista! Total de celdas inicializadas: ", voxel_grid.size())


func _obtener_indice_1d(x: int, y: int, z: int) -> int:
	return x + (y * resolucion_matriz) + (z * resolucion_matriz * resolucion_y)


func enviar_mapa_combustibles_a_gpu():
	var total_celdas = resolucion_matriz * resolucion_y * resolucion_matriz
	var array_combustibles = PackedByteArray()
	array_combustibles.resize(total_celdas) 
	
	for z in range(resolucion_matriz):
		for y in range(resolucion_y):
			for x in range(resolucion_matriz):
				
				var indice_cpu = _obtener_indice_1d(x, y, z)
				var estado = voxel_grid[indice_cpu]
				var indice_gpu = (z * resolucion_matriz * resolucion_y) + (y * resolucion_matriz) + x
				
				if estado == ESTADO_MATORRAL:
					array_combustibles[indice_gpu] = 100
				elif estado == ESTADO_ARBOL:
					array_combustibles[indice_gpu] = 255
	
	if controlador:
		controlador.cargar_mapa_combustibles(array_combustibles)
	else:
		push_error("No se pudo enviar el mapa. controlador vacío.")


func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		
		var camara = get_viewport().get_camera_3d()
		if not camara: return
		
		var centro_pantalla = get_viewport().get_visible_rect().size / 2.0
		var origen_rayo = camara.project_ray_origin(centro_pantalla)
		var direccion_rayo = camara.project_ray_normal(centro_pantalla)
		var fin_rayo = origen_rayo + (direccion_rayo * 3000.0) # Alargado para mapas grandes
		
		var espacio_fisico = get_world_3d().direct_space_state
		var parametros_rayo = PhysicsRayQueryParameters3D.create(origen_rayo, fin_rayo)
		
		var impacto = espacio_fisico.intersect_ray(parametros_rayo)
		
		if impacto:
			var punto_global = impacto.position
			
			if cubo_frontal != null and controlador != null:
				var pos_local_cubo = cubo_frontal.to_local(punto_global)
				var pos_normalizada = pos_local_cubo + Vector3(0.5, 0.5, 0.5)
				var resolucion = controlador.TAMANO_GRID
				
				var x_matriz = int(pos_normalizada.x * resolucion.x)
				var z_matriz = int(pos_normalizada.z * resolucion.z)
				
				if x_matriz >= 0 and x_matriz < resolucion.x and z_matriz >= 0 and z_matriz < resolucion.z:
					_encender_fuego_en(x_matriz, z_matriz)
			else:
				push_error("Falta asignar 'cubo_frontal' o 'controlador' en el inspector.")


func _encender_fuego_en(x: int, z: int):
	for y in range(resolucion_y - 1, -1, -1):
		var indice = _obtener_indice_1d(x, y, z)
		var estado_actual = voxel_grid[indice]
		
		if estado_actual != ESTADO_AIRE:
			if estado_actual == ESTADO_MATORRAL or estado_actual == ESTADO_ARBOL:
				voxel_grid[indice] = ESTADO_FUEGO
				
				if controlador:
					controlador.agregar_fuego_en(x, y, z)
					print("🔥 ¡Fuego! -> X: ", x, " Y: ", y, " Z: ", z)
			elif estado_actual == ESTADO_SUBSUELO:
				print("Has hecho clic en TIERRA/CAMINO. No arde.")
			
			break


func _generar_colision_terreno():
	print("Generando colisión física a escala real...")
	
	var shape = HeightMapShape3D.new()
	shape.map_width = resolucion_matriz
	shape.map_depth = resolucion_matriz
	
	var alturas = PackedFloat32Array()
	alturas.resize(resolucion_matriz * resolucion_matriz)
	
	for z in range(resolucion_matriz):
		for x in range(resolucion_matriz):
			var valor_ruido = imagen_elevacion.get_pixel(x, z).r
			var altura_real = valor_ruido * escala_altura
			var indice = (z * resolucion_matriz) + x
			alturas[indice] = altura_real
			
	shape.map_data = alturas
	
	var nodo_colision = CollisionShape3D.new()
	nodo_colision.shape = shape
	var cuerpo_estatico = StaticBody3D.new()
	cuerpo_estatico.add_child(nodo_colision)
	
	# Usamos las variables exportadas para deformar la colisión 
	# y que encaje perfectamente con tu malla rectangular
	var factor_escala_x = tamano_plano_x / float(resolucion_matriz)
	var factor_escala_z = tamano_plano_z / float(resolucion_matriz)
	
	cuerpo_estatico.scale = Vector3(factor_escala_x, 1.0, factor_escala_z)
	
	add_child(cuerpo_estatico)
	print("¡Colisión generada! Tamaño físico: ", tamano_plano_x, " x ", tamano_plano_z)
