extends Node3D


# Referencias a los nodos
@onready var objeto_frontal = $Frontal
@onready var slider_steps = $CanvasLayer/VBoxContainer/PasosSlider
@onready var slider_densidad = $CanvasLayer/VBoxContainer/DensidadSlider

func _ready():
	# Conectamos las señales de los sliders por código
	slider_steps.value_changed.connect(_on_steps_changed)
	slider_densidad.value_changed.connect(_on_densidad_changed)

func _on_steps_changed(valor: float):
	# Obtenemos el material del nodo Frontal
	var mat = objeto_frontal.get_active_material(0)
	if mat is ShaderMaterial:
		# Actualizamos el uniform MAX_STEPS (debe ser int)
		mat.set_shader_parameter("MAX_STEPS", int(valor))

func _on_densidad_changed(valor: float):
	var mat = objeto_frontal.get_active_material(0)
	if mat is ShaderMaterial:
		# Actualizamos el uniform de densidad
		mat.set_shader_parameter("Densidad", valor)
