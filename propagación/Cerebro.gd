extends Node

@export var buffer_a: SubViewport
@export var buffer_b: SubViewport
@export var rect_a: ColorRect
@export var rect_b: ColorRect

var frame_actual = 0
var buffer_a_es_lectura = true

func _ready():
	# 1. Obtenemos las texturas dinámicas de los Viewports
	var tex_a = buffer_a.get_texture()
	var tex_b = buffer_b.get_texture()
	
	# 2. Conectamos los shaders de forma cruzada
	# El Shader de A lee lo que generó B
	rect_a.material.set_shader_parameter("mapa_anterior", tex_b)
	# El Shader de B lee lo que generó A
	rect_b.material.set_shader_parameter("mapa_anterior", tex_a)
	
	# 3. Encendemos el fuego inicial para arrancar la simulación
	crear_chispa_inicial()

func crear_chispa_inicial():
	# Creamos un cuadradito rojo puro en el centro
	var chispa = ColorRect.new()
	chispa.color = Color(1, 0, 0, 1)
	chispa.custom_minimum_size = Vector2(2, 2)
	chispa.position = Vector2(31, 31) 
	
	buffer_a.add_child(chispa)

func _process(_delta):
	# Opcional: Ralentizamos un poco la simulación para poder verla bien
	# Si quitas esto, el fuego llenará la pantalla en menos de 1 segundo.
	frame_actual += 1
	if frame_actual % 3 != 0:
		return
		
	# --- EL CORAZÓN DEL PING-PONG ---
	if buffer_a_es_lectura:
		#rect_b.material.set_shader_parameter("mapa_anterior", buffer_a.get_texture())
		# Si A es lectura, apagamos su actualización y encendemos B para que escriba
		buffer_a.render_target_update_mode = SubViewport.UPDATE_DISABLED
		buffer_b.render_target_update_mode = SubViewport.UPDATE_ONCE
	else:
		#rect_a.material.set_shader_parameter("mapa_anterior", buffer_b.get_texture())
		# Al revés
		buffer_b.render_target_update_mode = SubViewport.UPDATE_DISABLED
		buffer_a.render_target_update_mode = SubViewport.UPDATE_ONCE
		
	# Cambiamos el turno para el siguiente ciclo
	buffer_a_es_lectura = !buffer_a_es_lectura
