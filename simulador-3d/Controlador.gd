extends Node

@export var cubo_frontal: MeshInstance3D # Asigna tu CuboFrontal desde el Inspector

const TAMANO_GRID = Vector3i(64, 64, 64)


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
	var shader_spirv = archivo_shader.get_spirv()
	var shader_id = rd.shader_create_from_spirv(shader_spirv)
	shader_pipeline = rd.compute_pipeline_create(shader_id)
	
	# RESERVAR LA MEMORIA Y CREAR CONEXIONES
	textura_a = crear_memoria_3d_vacia()
	textura_b = crear_memoria_3d_vacia()
	
	set_a_lee_b_escribe = crear_conexiones(textura_a, textura_b, shader_id)
	set_b_lee_a_escribe = crear_conexiones(textura_b, textura_a, shader_id)

	#ENCENDER EL FUEGO INICIAL Y CONECTAR EL VISOR
	encender_chispa_inicial()
	crear_puente_visual()


func _process(_delta):
	# Estrangulamos el cálculo para que el ojo humano pueda verlo (ej. cada 6 frames)
	frame_actual += 1
	if frame_actual % 10 != 0:
		return
		
	ejecutar_compute_shader()


# ====================================================================
# EL BUCLE PRINCIPAL (DISPARO DEL SHADER)
# ====================================================================

func ejecutar_compute_shader():
	# Empaquetamos el tiempo actual para el calculo de el numero aleatorio
	var tiempo_float = Time.get_ticks_msec() / 1000.0
	var push_constant = PackedFloat32Array([tiempo_float, 0.0, 0.0, 0.0])
	var bytes = push_constant.to_byte_array()

	# Preparamos las órdenes de la GPU
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, shader_pipeline)
	rd.compute_list_set_push_constant(compute_list, bytes, bytes.size())

	# Intercambio de Buffers
	if buffer_a_es_lectura:
		rd.compute_list_bind_uniform_set(compute_list, set_a_lee_b_escribe, 0)
	else:
		rd.compute_list_bind_uniform_set(compute_list, set_b_lee_a_escribe, 0)

	# Dividimos los 64 voxels por los 8 hilos (Workgroups del GLSL)
	var grupos_x = int(TAMANO_GRID.x / 8.0)
	var grupos_y = int(TAMANO_GRID.y / 8.0)
	var grupos_z = int(TAMANO_GRID.z / 8.0)
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
	formato.format = RenderingDevice.DATA_FORMAT_R8_UNORM # 1 Solo canal de 8 bits
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
	
	# Buscamos el centro exacto del volumen 3D (32, 32, 32)
	var cx = 32; var cy = 32; var cz = 32
	
	# Fórmula matemática para aplanar coordenadas 3D en un Array 1D:
	# Indice = (Z * Ancho * Alto) + (Y * Ancho) + X
	var indice_centro = (cz * TAMANO_GRID.x * TAMANO_GRID.y) + (cy * TAMANO_GRID.x) + cx
	
	# Encendemos la chispa (255 en 8-bits equivale al 1.0 en el shader)
	array_datos[indice_centro] = 255
	
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
			push_error("El Cubo Frontal no tiene un Material Override asignado.")
	else:
		push_error("Por favor, asigna el Cubo Frontal en el Inspector del nodo Cerebro.")

func actualizar_puente_visual():
	# Apuntamos el visor siempre al buffer más reciente
	if buffer_a_es_lectura:
		textura_visual.texture_rd_rid = textura_b
	else:
		textura_visual.texture_rd_rid = textura_a
