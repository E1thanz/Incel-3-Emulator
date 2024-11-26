extends Label

func _process(delta: float) -> void:
	var fps = Engine.get_frames_per_second()
	if fps > 999:
		text = "FPS:999+"
	else:
		text = "FPS:%3d" % [fps]
