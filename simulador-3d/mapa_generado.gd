extends MeshInstance3D

# ---  VARIABLES PARA EL AUTÓMATA ---
var voxel_grid: PackedInt32Array
var resolucion_y = 20 # Altura de la matriz volumétrica

# Diccionario de estados del autómata celular
const ESTADO_AIRE = 0
const ESTADO_SUBSUELO = 1 # Roca/Tierra (No combustible)
const ESTADO_MATORRAL = 2 # Combustible rápido (Rojo)
const ESTADO_ARBOL = 3    # Combustible lento (Azul)
const ESTADO_FUEGO = 99   # Fuego activo

# Variables globales para guardar las imágenes crudas en la memoria RAM
var imagen_elevacion: Image
var imagen_vegetacion: Image

# Esta es la resolución de la matriz tridimensional que usará tu simulador.
# Como el mapa mide 64x64 metros, usaremos 64 celdas.
var resolucion_matriz = 64

var escala_altura =  10

func _ready():
	print("Iniciando extracción de datos GIS procedurales...")
	
	# Accedemos al Material del nodo
	var material_shader = get_active_material(0) as ShaderMaterial
	
	# Obtenemos las texturas directamente de los parámetros del shader
	var textura_elevacion = material_shader.get_shader_parameter("mapa_elevacion") as NoiseTexture2D
	var textura_vegetacion = material_shader.get_shader_parameter("mapa_vegetacion") as NoiseTexture2D
	
	# Esperamos a que Godot termine de generar el ruido matemático
	await textura_elevacion.changed
	await textura_vegetacion.changed
	
	# Extraemos los datos puros (ahora sí, ya no son null)
	imagen_elevacion = textura_elevacion.get_image()
	imagen_vegetacion = textura_vegetacion.get_image()
	
	# Escalamos la imagen para que coincida exactamente con nuestra matriz 64x64
	# Usamos INTERPOLATE_NEAREST para no crear "colores borrosos" entre el rojo y el azul
	imagen_elevacion.resize(resolucion_matriz, resolucion_matriz, Image.INTERPOLATE_NEAREST)
	imagen_vegetacion.resize(resolucion_matriz, resolucion_matriz, Image.INTERPOLATE_NEAREST)
	
	print("¡Extracción completada! Imágenes cargadas en CPU.")
	
	# Construimos la matriz 3D
	_generar_matriz_3d()
	_generar_colision_terreno()






# ==========================================
# CONSTRUCCIÓN DEL VOLUMEN
# ==========================================
func _generar_matriz_3d():
	print("Traduciendo texturas a Voxel Grid 3D...")
	
	# 1. Preparamos el array plano gigante
	var total_celdas = resolucion_matriz * resolucion_y * resolucion_matriz
	voxel_grid = PackedInt32Array()
	voxel_grid.resize(total_celdas)
	
	# 2. Por defecto, todo el mapa es Aire
	voxel_grid.fill(ESTADO_AIRE)
	
	# 3. Escaneamos la superficie (X, Z) para construir las columnas (Y)
	for x in range(resolucion_matriz):
		for z in range(resolucion_matriz):
			
			# A. Leer la topografía
			var valor_relieve = imagen_elevacion.get_pixel(x, z).r
			# Convertimos la altura (0.0 a 1.0) a un "piso" de la matriz (0 a 63)
			var y_superficie = int(valor_relieve * (resolucion_y - 1))
			
			# B. Leer el combustible
			var color_veg = imagen_vegetacion.get_pixel(x, z)
			var estado_superficie = ESTADO_AIRE
			
			# Umbrales para detectar el color puro del NoiseTexture
			if color_veg.g > (color_veg.r + 0.15):
				# Si el verde supera al rojo por un poco, es Matorral
				estado_superficie = ESTADO_MATORRAL
			elif color_veg.r > (color_veg.g - 0.2):
				# Si el rojo tiene fuerza (típico de tu marrón #703d05), es Árbol
				estado_superficie = ESTADO_ARBOL
			else:
				# Hemos reducido drásticamente la "zona muerta". 
				# Ahora casi todo el mapa será combustible y habrá mucha menos roca.
				estado_superficie = ESTADO_SUBSUELO
				
			# C. Rellenar verticalmente esa coordenada (Gravedad)
			for y in range(resolucion_y):
				var indice_1d = _obtener_indice_1d(x, y, z)
				
				if y < y_superficie:
					# Todo lo que quede por debajo de la montaña es roca sólida
					voxel_grid[indice_1d] = ESTADO_SUBSUELO
				elif y == y_superficie:
					# Justo en la corteza terrestre plantamos el combustible
					voxel_grid[indice_1d] = estado_superficie
				# Si Y > y_superficie, la celda se queda como AIRE

	print("¡Matriz 3D lista! Total de celdas inicializadas: ", voxel_grid.size())

# Función matemática para navegar por el array 1D como si fuera 3D
func _obtener_indice_1d(x: int, y: int, z: int) -> int:
	return x + (y * resolucion_matriz) + (z * resolucion_matriz * resolucion_y)


# # ==========================================
# INTERACCIÓN: LA CHISPA DEL FUEGO
# ==========================================
func _input(event):
	# Si hacemos clic izquierdo
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		
		var camara = get_viewport().get_camera_3d()
		if not camara: return
		
		# 1. Calculamos el centro exacto de la pantalla
		var centro_pantalla = get_viewport().get_visible_rect().size / 2.0
		
		# 2. Disparamos el rayo desde el centro de la cámara hacia adelante
		var origen_rayo = camara.project_ray_origin(centro_pantalla)
		var direccion_rayo = camara.project_ray_normal(centro_pantalla)
		var fin_rayo = origen_rayo + (direccion_rayo * 1000.0)
		
		# 3. Preparamos el raycast físico
		var espacio_fisico = get_world_3d().direct_space_state
		var parametros_rayo = PhysicsRayQueryParameters3D.create(origen_rayo, fin_rayo)
		
		# 4. Impacto
		var impacto = espacio_fisico.intersect_ray(parametros_rayo)
		
		if impacto:
			var punto_global = impacto.position
			
			var x_matriz = int(punto_global.x + (resolucion_matriz / 2.0))
			var z_matriz = int(punto_global.z + (resolucion_matriz / 2.0))
			
			if x_matriz >= 0 and x_matriz < resolucion_matriz and z_matriz >= 0 and z_matriz < resolucion_matriz:
				_encender_fuego_en(x_matriz, z_matriz)


func _encender_fuego_en(x: int, z: int):
	# Buscamos de arriba a abajo cuál es la primera celda sólida (corteza)
	for y in range(resolucion_y - 1, -1, -1):
		var indice = _obtener_indice_1d(x, y, z)
		var estado_actual = voxel_grid[indice]
		
		# Si encontramos algo que no es AIRE, prendemos fuego
		if estado_actual != ESTADO_AIRE:
			
			# Comprobamos el tipo exacto de celda que hemos tocado
			if estado_actual == ESTADO_MATORRAL:
				voxel_grid[indice] = ESTADO_FUEGO
				print("🔥 ¡Fuego iniciado en [MATORRALES/ARBUSTOS]! (X: ", x, " Y: ", y, " Z: ", z, ")")
				
			elif estado_actual == ESTADO_ARBOL:
				voxel_grid[indice] = ESTADO_FUEGO
				print("🔥 ¡Fuego iniciado en [ÁRBOLES]! (X: ", x, " Y: ", y, " Z: ", z, ")")
				
			elif estado_actual == ESTADO_SUBSUELO:
				print("Has hecho clic en [TIERRA/ROCA]. Este material no arde.")
			
			# Rompemos el bucle porque ya hemos encontrado la superficie, 
			# independientemente de si ha ardido o no.
			break

# ==========================================
# COLISIÓN FÍSICA EXACTA (HEIGHTMAP)
# ==========================================
func _generar_colision_terreno():
	print("Generando colisión física del terreno...")
	
	# 1. Creamos la forma del mapa de alturas
	var shape = HeightMapShape3D.new()
	shape.map_width = resolucion_matriz
	shape.map_depth = resolucion_matriz
	
	# 2. Preparamos un array para guardar las alturas
	var alturas = PackedFloat32Array()
	alturas.resize(resolucion_matriz * resolucion_matriz)
	
	# 3. Rellenamos las alturas leyendo nuestra imagen ya procesada
	for z in range(resolucion_matriz):
		for x in range(resolucion_matriz):
			var valor_ruido = imagen_elevacion.get_pixel(x, z).r
			var altura_real = valor_ruido * escala_altura
			
			# Calculamos el índice unidimensional para el HeightMap
			var indice = (z * resolucion_matriz) + x
			alturas[indice] = altura_real
			
	shape.map_data = alturas
	
	# 4. Creamos los nodos físicos por código y los añadimos a la escena
	var nodo_colision = CollisionShape3D.new()
	nodo_colision.shape = shape
	
	var cuerpo_estatico = StaticBody3D.new()
	cuerpo_estatico.add_child(nodo_colision)
	
	# Lo añadimos como hijo de nuestro MeshInstance3D
	add_child(cuerpo_estatico)
	print("¡Colisión del terreno generada con éxito!")
