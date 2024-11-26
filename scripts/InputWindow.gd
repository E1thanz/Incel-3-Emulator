extends Panel

var mouse_in : bool = false
var dragging : bool = false
var relativePosition = Vector2()

func _close_button():
	anchors_preset = Control.PRESET_CENTER
	visible = false
	for child in get_child(1).get_child(0).get_child(0).get_children():
		if child is Panel:
			if !child.get_meta("KeyChosen") or !child.get_meta("PortChosen"):
				get_child(1).get_child(0).get_child(0).remove_child(child)
				child.queue_free()
	
func show_window():
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
			position = get_parent().get_local_mouse_position() - relativePosition + Vector2(10, 10)
			position = position.max(Vector2(0, 0)).min(Vector2(1920,1080) - size)

func _mouse_entered():
	mouse_in = true


func _mouse_exited():
	mouse_in = false
