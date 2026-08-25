extends Node

@export var cubo_frontal: MeshInstance3D 

@export var slider_DirViento: HSlider
@export var slider_humedad: HSlider
@export var slider_VelViento: HSlider

@export var label_DirViento: Label
@export var label_humedad: Label
@export var label_VelViento: Label


const TAMANO_GRID = Vector3i(128, 40, 128)
const TAMANO_WORKGROUP = Vector3i(8,8,8)


# --- VARIABLES DE LA GPU ---
var rd: RenderingDevice
var shader_pipeline: RID #RID --> Resource ID



# Memoria VRAM (Ping-Pong)
var textura_a: RID
var textura_b: RID
var set_a_lee_b_escribe: RID
var set_b_lee_a_escribe: RID

var textura_combustibles: RID

var buffer_a_es_lectura = true
var frame_actual = 0

# Textura para 3D que está vinculada a una textura creada en el RenderingDevice
var textura_visual: Texture3DRD 


func _ready():
	# Asignar el Rendering Device
	rd = RenderingServer.get_rendering_device()
	
	var archivo_shader = load("res://Shaders/SimuladorFuego.glsl")
	# Trasformamos el shader a un spriv y lo subimos a la GPU
	var shader_spirv = archivo_shader.get_spirv()
	var shader_id = rd.shader_create_from_spirv(shader_spirv)
	
	# Ceramos el pipeline para la comunicacion
	shader_pipeline = rd.compute_pipeline_create(shader_id)
	
	# Reservar la memoria y crear conexiones
	textura_a = crear_memoria_3d_vacia()
	textura_b = crear_memoria_3d_vacia()
	textura_combustibles = crear_memoria_3d_vacia()
	
	set_a_lee_b_escribe = crear_conexiones(textura_a, textura_b, shader_id)
	set_b_lee_a_escribe = crear_conexiones(textura_b, textura_a, shader_id)

	# Encender el fuego inicial y conectar el visor
	crear_puente_visual()
	
	#Conecto los sliders
	if slider_VelViento and label_VelViento:
		slider_VelViento.value_changed.connect(_on_vel_viento_cambiado)
		_on_vel_viento_cambiado(slider_VelViento.value) # Forzamos el texto inicial al arrancar

	if slider_DirViento and label_DirViento:
		slider_DirViento.value_changed.connect(_on_dir_viento_cambiado)
		_on_dir_viento_cambiado(slider_DirViento.value)

	if slider_humedad and label_humedad:
		slider_humedad.value_changed.connect(_on_humedad_cambiada)
		_on_humedad_cambiada(slider_humedad.value)


func _process(_delta):
	#frame_actual += 1
	#if frame_actual % 10 != 0:
		#return
		
	ejecutar_compute_shader()


# EL BUCLE PRINCIPAL
func ejecutar_compute_shader():
	# Empaquetamos el tiempo actual
	var semilla_cpu = Time.get_ticks_msec() / 1000.0
	# Leemos la DIRECCIÓN del viento
	var direccion_grados = 90.0
	if slider_DirViento != null:
		direccion_grados = slider_DirViento.value
	var dir_rad = deg_to_rad(direccion_grados)
	
	#Leemos la velocidad del viento
	var velViento = 15.0
	if slider_VelViento != null:
		velViento = slider_VelViento.value
	
	#Leemos la humedad
	var humedad = 0.2
	if slider_humedad != null:
		humedad = slider_humedad.value / 100.0
	
	# Empaquetamos los 8 flotantes (32 bytes exactos). 
	# Los 4 primeros son el tiempo, los 4 segundos el entorno.
	var push_constant = PackedFloat32Array([semilla_cpu, 0.0, 0.0, 0.0, velViento, dir_rad, humedad, 0.0 ])
	var bytes = push_constant.to_byte_array()
	
	# Preparamos las órdenes de la GPU 
	var compute_list = rd.compute_list_begin()
	
	# Le doy la tuberia a usar
	rd.compute_list_bind_compute_pipeline(compute_list, shader_pipeline)
	
	# Le paso el tiempo
	rd.compute_list_set_push_constant(compute_list, bytes, bytes.size())

	# Intercambio de Buffers
	if buffer_a_es_lectura:
		rd.compute_list_bind_uniform_set(compute_list, set_a_lee_b_escribe, 0)
	else:
		rd.compute_list_bind_uniform_set(compute_list, set_b_lee_a_escribe, 0)

	# Dividimos los 64 voxels por los 8 hilos (ceil para evitar errores si la división no es exacta)
	var grupos_x = ceil(TAMANO_GRID.x / float(TAMANO_WORKGROUP.x))
	var grupos_y = ceil(TAMANO_GRID.y / float(TAMANO_WORKGROUP.y))
	var grupos_z = ceil(TAMANO_GRID.z / float(TAMANO_WORKGROUP.z))
	rd.compute_list_dispatch(compute_list, grupos_x, grupos_y, grupos_z)

	# Enviamos a procesar
	rd.compute_list_end()

	# Preparamos el siguiente turno
	buffer_a_es_lectura = !buffer_a_es_lectura
	actualizar_puente_visual()



# FUNCIONES AUXILIARES DE MEMORIA Y VISUALIZACIÓN

func crear_memoria_3d_vacia() -> RID:
	
	var formato = RDTextureFormat.new()
	formato.texture_type = RenderingDevice.TEXTURE_TYPE_3D
	formato.width = TAMANO_GRID.x
	formato.height = TAMANO_GRID.y
	formato.depth = TAMANO_GRID.z
	formato.format = RenderingDevice.DATA_FORMAT_R8_UNORM 
	formato.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	# NUEVO: Llenamos el buffer de ceros (apagado) antes de mandarlo a VRAM
	var total_bytes = TAMANO_GRID.x * TAMANO_GRID.y * TAMANO_GRID.z
	var array_vacio = PackedByteArray()
	array_vacio.resize(total_bytes)
	array_vacio.fill(0) 
	
	# Le pasamos el array_vacio en lugar de unos corchetes vacíos []
	return rd.texture_create(formato, RDTextureView.new(), [array_vacio])

func crear_conexiones(tex_lectura: RID, tex_escritura: RID, shader_id: RID) -> RID:
	var cable_0 = RDUniform.new()
	cable_0.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	cable_0.binding = 0
	cable_0.add_id(tex_lectura)
	
	var cable_1 = RDUniform.new()
	cable_1.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	cable_1.binding = 1
	cable_1.add_id(tex_escritura)
	
	# Conectamos el mapa de combustibles al binding = 2
	var cable_2 = RDUniform.new()
	cable_2.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	cable_2.binding = 2
	cable_2.add_id(textura_combustibles)
	
	return rd.uniform_set_create([cable_0, cable_1,cable_2], shader_id, 0)

func encender_chispa_inicial():
	
	var total_bytes = TAMANO_GRID.x * TAMANO_GRID.y * TAMANO_GRID.z
	var array_datos = PackedByteArray()
	array_datos.resize(total_bytes)
	array_datos.fill(0) # Todo apagado (0)
	
	var cx = 32; var cy = 10; var cz = 32;
	
	# Fórmula matemática para aplanar coordenadas 3D en un Array 1D:
	# Indice = (Z * Ancho * Alto) + (Y * Ancho) + X
	var indice = (cz * TAMANO_GRID.x * TAMANO_GRID.y) + (cy * TAMANO_GRID.x) + cx
	
	# Encendemos la chispa (255 en 8-bits equivale al 1.0 en el shader)
	array_datos[indice] = 255
	
	# Subimos los datos a la tarjeta gráfica (al Buffer A)
	rd.texture_update(textura_a, 0, array_datos)

func crear_puente_visual():
	textura_visual = Texture3DRD.new()
	
	# Verificamos que has asignado el cubo en el inspector
	if cubo_frontal != null:
		var material = cubo_frontal.material_override
		if material != null:
			material.set_shader_parameter("textura_volumen", textura_visual)
		else:
			push_error("El Cubo Frontal no tiene un Material asignado")
	else:
		push_error("El Cubo Frontal no esta asignado")

func actualizar_puente_visual():
	# Apuntamos el visor siempre al buffer más reciente
	if buffer_a_es_lectura:
		textura_visual.texture_rd_rid = textura_b
	else:
		textura_visual.texture_rd_rid = textura_a

func agregar_fuego_en(cx: int, cy: int, cz: int):
	var indice = (cz * TAMANO_GRID.x * TAMANO_GRID.y) + (cy * TAMANO_GRID.x) + cx
	
	# Averiguamos qué textura está leyendo la gráfica en este frame
	var textura_activa = textura_a if buffer_a_es_lectura else textura_b
	
	# Descargamos la memoria actual de la gráfica al procesador
	var array_datos = rd.texture_get_data(textura_activa, 0)
	
	# Encendemos el vóxel exacto (255 = fuego puro)
	array_datos[indice] = 255
	
	# Volvemos a subir los datos actualizados a la gráfica
	rd.texture_update(textura_activa, 0, array_datos)

func cargar_mapa_combustibles(array_datos: PackedByteArray):
	rd.texture_update(textura_combustibles, 0, array_datos)
	print("🌳 Mapa de combustibles inyectado en la GPU correctamente.")


# --- NUEVO: FUNCIONES DE ACTUALIZACIÓN ---
func _on_vel_viento_cambiado(valor: float):
	label_VelViento.text = "Vel. Viento: " + str(valor) + " km/h"

func _on_dir_viento_cambiado(valor: float):
	label_DirViento.text = "Dirección: " + str(valor) + "º"

func _on_humedad_cambiada(valor: float):
	label_humedad.text = "Humedad: " + str(valor) + " %"
