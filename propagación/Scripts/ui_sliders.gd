extends Node

@export var objeto_frontal: MeshInstance3D
@export var slider_steps: Slider
@export var slider_densidad: Slider

func _ready():
	# Conectamos las señales de los sliders por código
	slider_steps.value_changed.connect(_on_steps_changed)
	slider_densidad.value_changed.connect(_on_densidad_changed)

func _on_steps_changed(valor: float):
	var mat = objeto_frontal.get_active_material(0)
	if mat is ShaderMaterial:
		mat.set_shader_parameter("RadioEsfera", valor)

func _on_densidad_changed(valor: float):
	var mat = objeto_frontal.get_active_material(0)
	if mat is ShaderMaterial:
		mat.set_shader_parameter("Densidad", valor)
