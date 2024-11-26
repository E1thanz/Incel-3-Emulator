extends Panel

var mouse_in : bool = false
var dragging : bool = false
var relativePosition = Vector2()

signal save_response(response)

func _close_button():
	visible = false
	save_response.emit(false)
	
func show_request():
	anchors_preset = Control.PRESET_CENTER
	visible = true

func _mouse_input_event(event):
	if event is InputEventMouseButton:
		if event.is_pressed() && mouse_in:
			relativePosition = get_local_mouse_position()
			dragging = true
		else:
			dragging = false
	elif event is InputEventMouseMotion:
		if dragging:
			position = get_parent().get_local_mouse_position() - relativePosition
			position = position.max(Vector2(-965, -64)).min(Vector2(1920,1080) + Vector2(-965, -64) - size)

func _mouse_entered():
	mouse_in = true


func _mouse_exited():
	mouse_in = false


func _exit_and_save() -> void:
	visible = false
	save_response.emit(true)

func _exit_without_save() -> void:
	visible = false
	save_response.emit(false)
