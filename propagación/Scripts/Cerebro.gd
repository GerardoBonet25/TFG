extends Node

signal montecarlo_completado

@export var buffer_a: SubViewport
@export var buffer_b: SubViewport
@export var buffer_acumulador: SubViewport
@export var rect_a: ColorRect
@export var rect_b: ColorRect

var frame_actual = 0
var buffer_a_es_lectura = true

# 0--> Menu Principal   1-->Tiempo Real   2--> Montecarlo   3--> Visualizar resultados Montecarlo
var modo_actual = 0 
var iteraciones_montecarlo = 0

# --- VARIABLES DE MONTECARLO ---
var iteracion_actual = 0
var frames_simulados = 0
const MAX_FRAMES_POR_INCENDIO = 200 # Cuánto tiempo "arde" cada simulación antes de parar (frames,pasos en cada simulación)

func _ready():
	var tex_a = buffer_a.get_texture()
	var tex_b = buffer_b.get_texture()
	rect_a.material.set_shader_parameter("mapa_anterior", tex_b)
	rect_b.material.set_shader_parameter("mapa_anterior", tex_a)
	
	limpiar_buffers()

func iniciar_simulacion(modo: int, iteraciones: int = 0):
	modo_actual = modo
	iteraciones_montecarlo = iteraciones
	
	
	await limpiar_buffers()
	
	if modo_actual == 1:
		# Activamos el VSYNC
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		crear_chispa_inicial()
		
	if modo_actual == 2:
		# Desactivamos el V-Sync para que los FPS vuelen al máximo
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0 # 0 significa sin límite
		
		iteracion_actual = 0
		frames_simulados = 0
		await limpiar_acumulador()
		crear_chispa_inicial()

func detener_simulacion():
	modo_actual = 0
	# Restauramos la velocidad normal por si nos enciontrabamos en Montecarlo
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	
	await limpiar_buffers()
	await limpiar_acumulador()
	frame_actual = 0
	buffer_a_es_lectura = true

func limpiar_buffers():
	#Creamos un color react todo negro encima de cada buffer
	var negro_a = ColorRect.new()
	negro_a.color = Color(0, 0, 0, 1); negro_a.size = Vector2(64, 64)
	buffer_a.add_child(negro_a)

	var negro_b = ColorRect.new()
	negro_b.color = Color(0, 0, 0, 1); negro_b.size = Vector2(64, 64)
	buffer_b.add_child(negro_b)

	# Disparamos la actualización 
	buffer_a.render_target_update_mode = SubViewport.UPDATE_ONCE
	buffer_b.render_target_update_mode = SubViewport.UPDATE_ONCE

	await get_tree().process_frame
	await get_tree().process_frame

	# Destruimos los "telones" 
	if is_instance_valid(negro_a): negro_a.queue_free()
	if is_instance_valid(negro_b): negro_b.queue_free()

func limpiar_acumulador():
	buffer_acumulador.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	buffer_acumulador.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	buffer_acumulador.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER

func crear_chispa_inicial():
	var chispa = ColorRect.new()
	chispa.color = Color(1, 0, 0, 1)
	chispa.custom_minimum_size = Vector2(2, 2)
	chispa.position = Vector2(32, 32) 
	buffer_a.add_child(chispa)


func guardar_en_acumulador():
	# Creamos una foto del fuego actual
	var captura = TextureRect.new()
	captura.texture = buffer_a.get_texture()

	# Le decimos que lo SUME a la imagen de fondo
	# BLEND_MODE_ADD: Sume los colores
	# BLEND_MODE_MIX: El color nuevo aplasta y sustituye al color de fondo
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	captura.material = mat

	# P_quemado = 1 / N
	# Al bajarle la opacidad a 1/N cuando se sumen N incendios 
	# las zonas que siempre se queman llegarán a 1.0
	var peso = 1.0 / float(iteraciones_montecarlo)
	captura.modulate = Color(1.0, 1.0, 1.0, peso)

	# Lo estampamos en el Acumulador
	buffer_acumulador.add_child(captura)
	buffer_acumulador.render_target_update_mode = SubViewport.UPDATE_ONCE

	await get_tree().process_frame
	await get_tree().process_frame
	captura.queue_free()
	
	
func _process(_delta):
	if modo_actual == 0:
		return
		
	frame_actual += 1
	
	#Modo 1: Simulacion real
	if modo_actual == 1 and frame_actual % 3 != 0:
		
		return
	
	if modo_actual == 2:
		frames_simulados += 1
		# Si el incendio actual ya ha ardido durante su tiempo límite
		if frames_simulados >= MAX_FRAMES_POR_INCENDIO:
			modo_actual = -1 # Pausamos momentáneamente el _process
					
			await guardar_en_acumulador()
			iteracion_actual += 1
			print("Iteración ", iteracion_actual, " completada")

			if iteracion_actual < iteraciones_montecarlo:
				# Reiniciamos para el siguiente incendio
				await limpiar_buffers()
				crear_chispa_inicial()
				frames_simulados = 0
				modo_actual = 2 # Reanudamos
			else:
				print("Montecarlo finalizado")
				# Restauramos la velocidad normal
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
				await limpiar_buffers()
				modo_actual = 3 # Estado 3 = Visualizar resultados
				frames_simulados = 0
				iteracion_actual = 0
				
				montecarlo_completado.emit()
	
	# Intercambio de buffer
	if buffer_a_es_lectura:
		buffer_a.render_target_update_mode = SubViewport.UPDATE_DISABLED
		buffer_b.render_target_update_mode = SubViewport.UPDATE_ONCE
	else:
		buffer_b.render_target_update_mode = SubViewport.UPDATE_DISABLED
		buffer_a.render_target_update_mode = SubViewport.UPDATE_ONCE
		
	buffer_a_es_lectura = !buffer_a_es_lectura
