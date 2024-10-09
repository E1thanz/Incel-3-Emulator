extends Panel

var mouse_in : bool = false
var dragging : bool = false
var relativePosition = Vector2()

func _close_button():
	anchors_preset = Control.PRESET_CENTER
	visible = false
	
func show_error(errorMessage : String):
	$ErrorLabel.text = "[center][color=red]" + errorMessage + "[/color][/center]"
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

func _mouse_entered():
	mouse_in = true


func _mouse_exited():
	mouse_in = false
