extends Label

func _process(delta: float) -> void:
	var fps = Engine.get_frames_per_second()
	var frame_time = delta * 1000.0
	
	text = "FPS: " + str(fps) + "\n"
	text += "Tiempo de fotograma: " + str(snapped(frame_time, 0.01)) + " ms"
