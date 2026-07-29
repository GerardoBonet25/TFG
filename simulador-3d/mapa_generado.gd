extends MeshInstance3D

@export var controlador: Node
@export var cubo_frontal: MeshInstance3D

# ---  VARIABLES PARA EL AUTÓMATA ---
var voxel_grid: PackedInt32Array


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
var resolucion_matriz = 192
var resolucion_y = 60 # Altura de la matriz volumétrica

var escala_altura =  20

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
	enviar_mapa_combustibles_a_gpu()



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
					voxel_grid[indice_1d] = ESTADO_SUBSUELO
				elif y >= y_superficie and y <= y_superficie + 4:
					# AÑADIMOS GROSOR: Llenamos la corteza terrestre y 2 capas más arriba.
					# Esto dota al combustible de volumen para el raymarching.
					voxel_grid[indice_1d] = estado_superficie
				# Si y > y_superficie + 2, la celda se queda como AIRE

	print("¡Matriz 3D lista! Total de celdas inicializadas: ", voxel_grid.size())

# Función matemática para navegar por el array 1D como si fuera 3D
func _obtener_indice_1d(x: int, y: int, z: int) -> int:
	return x + (y * resolucion_matriz) + (z * resolucion_matriz * resolucion_y)

func enviar_mapa_combustibles_a_gpu():
	var total_celdas = resolucion_matriz * resolucion_y * resolucion_matriz
	var array_combustibles = PackedByteArray()
	array_combustibles.resize(total_celdas) # Se llena de 0 (aire/roca) por defecto
	
	for z in range(resolucion_matriz):
		for y in range(resolucion_y):
			for x in range(resolucion_matriz):
				
				# 1. Leemos el estado de la CPU usando tu función de indexado
				var indice_cpu = _obtener_indice_1d(x, y, z)
				var estado = voxel_grid[indice_cpu]
				
				# 2. Calculamos el índice de la GPU (Formato 3D estricto)
				var indice_gpu = (z * resolucion_matriz * resolucion_y) + (y * resolucion_matriz) + x
				
				# 3. Traducimos los estados a bytes (0-255) para que el Shader entienda qué quema
				if estado == ESTADO_MATORRAL:
					# Enviamos 100. El shader leerá 0.39 (Combustible ligero, arde muy rápido)
					array_combustibles[indice_gpu] = 100
					
				elif estado == ESTADO_ARBOL:
					# Enviamos 255. El shader leerá 1.00 (Combustible pesado, arde más lento)
					array_combustibles[indice_gpu] = 255
	
	if controlador:
		controlador.cargar_mapa_combustibles(array_combustibles)
	else:
		push_error("No se pudo enviar el mapa. controlador_gpu vacío.")
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
			
			# --- TRADUCCIÓN DINÁMICA DE ESPACIOS ---
			if cubo_frontal != null and controlador != null:
				# 1. Convertimos el punto global del impacto al espacio local del cubo (de -0.5 a 0.5)
				var pos_local_cubo = cubo_frontal.to_local(punto_global)
				
				# 2. Normalizamos al rango de 0.0 a 1.0
				var pos_normalizada = pos_local_cubo + Vector3(0.5, 0.5, 0.5)
				
				# 3. Leemos la resolución real directamente de la constante de la GPU (ej: 192, 60, 192)
				var resolucion = controlador.TAMANO_GRID
				
				var x_matriz = int(pos_normalizada.x * resolucion.x)
				var z_matriz = int(pos_normalizada.z * resolucion.z)
				
				# 4. Comprobamos los límites usando la resolución real
				if x_matriz >= 0 and x_matriz < resolucion.x and z_matriz >= 0 and z_matriz < resolucion.z:
					_encender_fuego_en(x_matriz, z_matriz)
			else:
				push_error("Falta asignar 'cubo_frontal' o 'controlador_gpu' en el inspector del Terreno.")


func _encender_fuego_en(x: int, z: int):
	for y in range(resolucion_y - 1, -1, -1):
		var indice = _obtener_indice_1d(x, y, z)
		var estado_actual = voxel_grid[indice]
		
		if estado_actual != ESTADO_AIRE:
			
			if estado_actual == ESTADO_MATORRAL or estado_actual == ESTADO_ARBOL:
				voxel_grid[indice] = ESTADO_FUEGO
				
				# ¡LA MAGIA! Le decimos a la tarjeta gráfica que queme ese punto
				if controlador:
					controlador.agregar_fuego_en(x, y, z)
					print("🔥 ¡Chispa inyectada en la GPU! -> X: ", x, " Y: ", y, " Z: ", z)
				else:
					push_error("Falta asignar el Controlador GPU en el inspector.")
					
			elif estado_actual == ESTADO_SUBSUELO:
				print("Has hecho clic en [TIERRA/ROCA]. Este material no arde.")
			
			break

# ==========================================
# COLISIÓN FÍSICA EXACTA (HEIGHTMAP)
# ==========================================
func _generar_colision_terreno():
	print("Generando colisión física del terreno...")
	
	# ... (tu código para crear el shape y rellenar el array de alturas se queda IGUAL) ...
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
	
	# 4. Creamos los nodos
	var nodo_colision = CollisionShape3D.new()
	nodo_colision.shape = shape
	
	var cuerpo_estatico = StaticBody3D.new()
	cuerpo_estatico.add_child(nodo_colision)
	
	# --- LA MODIFICACIÓN CLAVE ---
	# Calculamos la proporción entre el mundo físico (64) y la matriz (192)
	# Esto da 0.3333... que es el tamaño real de cada "celda" en metros
	var tamano_plano_fisico = 64.0
	var factor_escala = tamano_plano_fisico / float(resolucion_matriz)
	
	# Aplastamos la colisión en X y Z, pero mantenemos la altura (Y) intacta en 1.0
	cuerpo_estatico.scale = Vector3(factor_escala, 1.0, factor_escala)
	# -----------------------------
	
	add_child(cuerpo_estatico)
	print("¡Colisión del terreno generada con éxito!")
