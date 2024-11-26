extends VBoxContainer

var keys = "qwertyuiopasdfghjklzxcvbnm".to_upper().split()
var button = preload("res://Scenes/Keyboard Button.tscn")
var map = {}

func _ready() -> void:
	var active_node = get_child(0)
	var key_index = 0
	for i in range(10):
		var new_button = button.instantiate()
		map[keys[key_index]] = new_button
		new_button.get_child(0).text = keys[key_index]
		active_node.add_child(new_button)
		key_index += 1
	active_node = get_child(1)
	for i in range(9):
		var new_button = button.instantiate()
		map[keys[key_index]] = new_button
		new_button.get_child(0).text = keys[key_index]
		active_node.add_child(new_button)
		active_node.move_child(active_node.get_child(active_node.get_child_count() - 2), active_node.get_child_count() - 1)
		key_index += 1
	active_node = get_child(2)
	for i in range(7):
		var new_button = button.instantiate()
		map[keys[key_index]] = new_button
		new_button.get_child(0).text = keys[key_index]
		active_node.add_child(new_button)
		active_node.move_child(active_node.get_child(active_node.get_child_count() - 2), active_node.get_child_count() - 1)
		key_index += 1
	
func _input(event):
	if event is InputEventKey:
		if event.keycode in ValidKeys.VALID_KEYS:
			var _button: Panel = map[ValidKeys.KEY_NAMES[event.keycode - 65].to_upper()]
			var new_style = StyleBoxFlat.new()
			new_style.bg_color = Color.hex(0x333333FF) if event.is_pressed() else Color.hex(0x222222FF)
			_button.add_theme_stylebox_override("panel", new_style)
