extends PanelContainer

var selected = false
var disabled = false

signal change_selected_file_signal(button)
signal close_file_signal(button)

func _ready():
	update_selection()
	
func update_selection():
	if disabled:
		return
	var styleBox = StyleBoxFlat.new()
	if selected:
		styleBox.bg_color = Color.hex(0x2D2D2DFF)
	else:
		styleBox.bg_color = Color.hex(0x272727FF)
	styleBox.corner_radius_top_left = 15
	styleBox.corner_radius_top_right = 15
	add_theme_stylebox_override("panel", styleBox)

func _on_mouse_entered() -> void:
	if disabled:
		return
	$"HBoxContainer/Label".add_theme_color_override("font_color", Color.hex(0xFFFFFFFF))
	var styleBox = StyleBoxFlat.new()
	if selected:
		styleBox.bg_color = Color.hex(0x343434FF)
	else:
		styleBox.bg_color = Color.hex(0x2D2D2DFF)
	styleBox.corner_radius_top_left = 15
	styleBox.corner_radius_top_right = 15
	add_theme_stylebox_override("panel", styleBox)

func _on_mouse_exited() -> void:
	if disabled:
		return
	$"HBoxContainer/Label".add_theme_color_override("font_color", Color.hex(0x5FB3F5FF))
	var styleBox = StyleBoxFlat.new()
	if selected:
		styleBox.bg_color = Color.hex(0x2D2D2DFF)
	else:
		styleBox.bg_color = Color.hex(0x272727FF)
	styleBox.corner_radius_top_left = 15
	styleBox.corner_radius_top_right = 15
	add_theme_stylebox_override("panel", styleBox)

func _on_gui_input(event: InputEvent):
	if disabled:
		return
	if event is InputEventMouseButton:
		if event.is_pressed():
			change_selected_file_signal.emit(self)

func _close_button() -> void:
	if disabled:
		return
	close_file_signal.emit(self)
	
func disable(disable_bool: bool):
	disabled = disable_bool
	get_child(0).get_child(2).disabled = disable_bool
	if disable_bool:
		get_child(0).get_child(1).add_theme_color_override("font_color", Color.hex(0x808080ff))
	else:
		get_child(0).get_child(1).add_theme_color_override("font_color", Color.hex(0x5fb3f5ff))
