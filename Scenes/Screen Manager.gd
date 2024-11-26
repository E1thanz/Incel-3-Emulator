extends Panel

@export var check_list: Array[CheckBox] = []
@export var other_panel: Panel
var selected: int = 4

func _ready() -> void:
	size.x = 24 + 28 * selected
	position.x = 605 - 28 * selected
	check_list[selected].button_pressed = true
	check_list[selected].disabled = true
	var i = 7
	for child in get_parent().get_child(2).get_children():
		if child is CheckBox:
			child.connect("pressed", _on_check_box_toggled.bind(i))
			i -= 1
			
func sync(self_node: int) -> void:
	check_list[self_node].disabled = true
	check_list[selected].disabled = false
	check_list[selected].button_pressed = false
	selected = self_node
	size.x = 24 + 28 * selected
	position.x = 605 - 28 * selected
	%Screen.update_screen()

func _on_check_box_toggled(self_node: int) -> void:
	check_list[self_node].disabled = true
	check_list[selected].disabled = false
	check_list[selected].button_pressed = false
	selected = self_node
	size.x = 24 + 28 * selected
	position.x = 605 - 28 * selected
	%Screen.set_x(pow(2, self_node + 1))
	%Screen.set_y(pow(2, self_node + 1))
	other_panel.sync(self_node)
