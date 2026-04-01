extends Camera3D
@export var camaraTrasera: Camera3D
@export var subViewPort: SubViewport

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	if camaraTrasera:
		camaraTrasera.global_transform = global_transform
		camaraTrasera.fov = fov
	if subViewPort:
		subViewPort.size = get_viewport().size