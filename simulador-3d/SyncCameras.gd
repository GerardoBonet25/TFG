extends Camera3D

@export var camaraTrasera: Camera3D
@export var subViewPort: SubViewport

# Parámetros de control ajustables desde el Inspector
@export var velocidad_movimiento: float = 5.0
@export var sensibilidad_raton: float = 0.002

func _ready() -> void:
	# Capturamos el ratón al inicio para poder girar la cámara en 3D libremente
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# 1. Sincronizamos las propiedades ópticas al inicio
	if camaraTrasera:
		camaraTrasera.fov = fov
		camaraTrasera.near = near
		camaraTrasera.far = far

	# 2. Conectamos la señal nativa de cambio de tamaño de ventana a nuestra función
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	_on_viewport_size_changed()

# Esta función SOLO se ejecutará cuando la ventana cambie de tamaño
func _on_viewport_size_changed() -> void:
	if subViewPort:
		subViewPort.size = get_viewport().size

func _unhandled_input(event: InputEvent) -> void:
	# Permitir liberar o recuperar el ratón pulsando la tecla Escape (ui_cancel)
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Control de rotación con el movimiento del ratón
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Girar horizontalmente (Eje Y global)
		rotate_y(-event.relative.x * sensibilidad_raton)
		
		# Girar verticalmente (Eje X local) limitando el ángulo para evitar que la cámara se invierta
		var cambio_x = -event.relative.y * sensibilidad_raton
		if rotation.x + cambio_x < deg_to_rad(89) and rotation.x + cambio_x > deg_to_rad(-89):
			rotate_object_local(Vector3.RIGHT, cambio_x)

func _process(delta: float) -> void:
	# --- CONTROL DE MOVIMIENTO (WASD) ---
	var direccion = Vector3.ZERO
	var basis = global_transform.basis # Obtenemos la orientación local de la cámara

	# Comprobamos las teclas físicas para que funcione independientemente de la distribución del teclado
	if Input.is_physical_key_pressed(KEY_W):
		direccion -= basis.z # Hacia adelante
	if Input.is_physical_key_pressed(KEY_S):
		direccion += basis.z # Hacia atrás
	if Input.is_physical_key_pressed(KEY_A):
		direccion -= basis.x # Izquierda
	if Input.is_physical_key_pressed(KEY_D):
		direccion += basis.x # Derecha

	# Si hay movimiento, normalizamos el vector para evitar ir más rápido en diagonal
	if direccion != Vector3.ZERO:
		direccion = direccion.normalized()
		global_position += direccion * velocidad_movimiento * delta
	
	
