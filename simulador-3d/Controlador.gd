extends Node

@export var cubo_frontal: MeshInstance3D 
@export var slider_viento: HSlider

const TAMANO_GRID = Vector3i(64, 64, 64)
const TAMANO_WORKGROUP = Vector3i(8,8,8)


# --- VARIABLES DE LA GPU ---
var rd: RenderingDevice
var shader_pipeline: RID #RID --> Resource ID


# Memoria VRAM (Ping-Pong)
var textura_a: RID
var textura_b: RID
var set_a_lee_b_escribe: RID
var set_b_lee_a_escribe: RID

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
	
	set_a_lee_b_escribe = crear_conexiones(textura_a, textura_b, shader_id)
	set_b_lee_a_escribe = crear_conexiones(textura_b, textura_a, shader_id)

	# Encender el fuego inicial y conectar el visor
	encender_chispa_inicial()
	crear_puente_visual()


func _process(_delta):
	frame_actual += 1
	if frame_actual % 10 != 0:
		return
		
	ejecutar_compute_shader()


# EL BUCLE PRINCIPAL
func ejecutar_compute_shader():
	# Empaquetamos el tiempo actual
	var tiempo_float = Time.get_ticks_msec() / 1000.0

	# NUEVO: Leemos los grados del Slider de la UI (si existe, si no, usamos 90)
	var direccion_grados = 90.0
	if slider_viento != null:
		direccion_grados = slider_viento.value

	var dir_rad = deg_to_rad(direccion_grados)

	# Empaquetamos los 8 flotantes (32 bytes exactos). 
	# Los 4 primeros son el tiempo, los 4 segundos el entorno.
	var push_constant = PackedFloat32Array([tiempo_float, 0.0, 0.0, 0.0,15.0, dir_rad, 0.2, 0.0 ])
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
	
	# R8: Solo un canal Rojo de 8 bits
	# UNORM: Convierte los valores que van de 0-255 a decimales 0.0-1.0
	formato.format = RenderingDevice.DATA_FORMAT_R8_UNORM 
	
	# STORAGE_BIT: Permite que el Compute Shader lea y escriba
	# CAN_UPDATE_BIT: Permite que la CPU le inyecte datos(la chispa)
	# SAMPLING_BIT: Permite que el otro shader la lea para dibujarla en pantalla
	formato.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	
	return rd.texture_create(formato, RDTextureView.new(), [])

func crear_conexiones(tex_lectura: RID, tex_escritura: RID, shader_id: RID) -> RID:
	var cable_0 = RDUniform.new()
	cable_0.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	cable_0.binding = 0
	cable_0.add_id(tex_lectura)
	
	var cable_1 = RDUniform.new()
	cable_1.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	cable_1.binding = 1
	cable_1.add_id(tex_escritura)
	
	return rd.uniform_set_create([cable_0, cable_1], shader_id, 0)

func encender_chispa_inicial():
	
	var total_bytes = TAMANO_GRID.x * TAMANO_GRID.y * TAMANO_GRID.z
	var array_datos = PackedByteArray()
	array_datos.resize(total_bytes)
	array_datos.fill(0) # Todo apagado (0)
	
	var cx = 32; var cy = 32; var cz = 32;
	
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
