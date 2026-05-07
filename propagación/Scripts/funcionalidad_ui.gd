extends Node

# --- Referencias al Cerebro y Shaders ---
@export var cerebro: Node
@export var colorRectA: ColorRect
@export var colorRectB: ColorRect

# --- Referencias a los 3 menús ---
@export var menu_principal: VBoxContainer
@export var menu_interactivo: VBoxContainer
@export var menu_montecarlo: VBoxContainer

# --- Referencias a los botones menu principal ---
@export var btn_modo_tiempo_real: Button
@export var btn_modo_montecarlo: Button

# --- Referencias a los bootones menu tiempo real ---
@export var slider_vel: Slider
@export var slider_dir: Slider 
@export var btn_volver_interactivo: Button


# --- Referencias a los bootones menu Montecarlo ---
@export var spinbox_n: SpinBox
@export var btn_confirmar_montecarlo: Button
@export var btn_volver_montecarlo: Button
@export var visor_pantalla: TextureRect

func _ready():
	#Conectar botones del Menú Principal
	btn_modo_tiempo_real.pressed.connect(OnTiempoReal)
	btn_modo_montecarlo.pressed.connect(OnMontecarlo)
	
	#Conectar botones de Volver
	btn_volver_interactivo.pressed.connect(OnVolverMenu)
	btn_volver_montecarlo.pressed.connect(OnVolverMenu)
	
	# Conectar botón de confirmar Montecarlo
	btn_confirmar_montecarlo.pressed.connect(OnConfirmarMontecarlo)
	
	# Conectar Sliders tiempo real
	slider_vel.value_changed.connect(OnChangeVelocity)
	slider_dir.value_changed.connect(OnChangedirection)
	
	cerebro.montecarlo_completado.connect(OnMontecarloFinalizado)
	
	# Estado inicial: Mostrar el menú principal
	OnVolverMenu()


func OnTiempoReal():
	if visor_pantalla != null:
		visor_pantalla.texture = cerebro.buffer_a.get_texture()
	menu_principal.visible = false
	menu_montecarlo.visible = false
	menu_interactivo.visible = true
	#Modo 1: Tiempo real
	cerebro.iniciar_simulacion(1)

func OnMontecarlo():
	# Mostramos el menú para preguntar cuántas iteraciones queremos.
	menu_principal.visible = false
	menu_interactivo.visible = false
	menu_montecarlo.visible = true

func OnConfirmarMontecarlo():
	# Ocultamos el botón de confirmar
	btn_confirmar_montecarlo.visible = false
	
	var iteraciones = spinbox_n.value
	print("Iniciando Montecarlo con ", iteraciones, " iteraciones...")
	
	# Modo 2: Montecarlo 
	cerebro.iniciar_simulacion(2, iteraciones)

func OnMontecarloFinalizado():
	print("UI: Recibido aviso de fin de Montecarlo. Mostrando mapa de calor.")
	# Cambiamos la textura a la que se ha generado del acumulador de Montecarlo
	visor_pantalla.texture = cerebro.buffer_acumulador.get_texture()
	

func OnVolverMenu():
	# Restauramos la UI
	menu_interactivo.visible = false
	menu_montecarlo.visible = false
	menu_principal.visible = true
	btn_confirmar_montecarlo.visible = true 
	
	# Volvemos a mostrar el buffer a en la pantalla
	if visor_pantalla != null:
			visor_pantalla.texture = cerebro.buffer_a.get_texture()
	cerebro.detener_simulacion()


# --- FUNCIONES DE LOS SLIDERS ---
func OnChangeVelocity(valor: float):
	if colorRectA.material is ShaderMaterial: colorRectA.material.set_shader_parameter("velocidad_viento", valor)
	if colorRectB.material is ShaderMaterial: colorRectB.material.set_shader_parameter("velocidad_viento", valor)

func OnChangedirection(valor: float):
	if colorRectA.material is ShaderMaterial: colorRectA.material.set_shader_parameter("direccion_viento", valor)
	if colorRectB.material is ShaderMaterial: colorRectB.material.set_shader_parameter("direccion_viento", valor)
