extends VBoxContainer

signal keyPressed(int)

@onready var screen = %"Screen"
@onready var emulator = %"Emulator"
var Current_Inputs : Array[Dictionary] = [{},{},{},{},{},{},{},{}]
var Current_Outputs : Array = [0, 0, 0, 0, 0, 0, 0, 0]

var rng = RandomNumberGenerator.new()

@onready var input_bar = preload("res://Scenes/Port Tab.tscn")

func Read_Port(port: int):
	var output = 0
	match port:
		3:
			output = screen.get_pixel(Current_Outputs[1], Current_Outputs[2])
		4:
			output = Current_Outputs[4]
		5:
			output = rng.randi_range(0, 255)
		_:
			for key in Current_Inputs[port].keys():
				if Input.is_key_pressed(ValidKeys.VALID_KEYS[ValidKeys.KEY_NAMES.find(key)]):
					output |= Current_Inputs[port][key]
	return output

func Write_Port(port: int, value: int):
	match port:
		3:
			if value == 1:
				screen.add_change(Current_Outputs[1], Current_Outputs[2], true)
			elif value == 2:
				screen.add_change(Current_Outputs[1], Current_Outputs[2], false)
			elif value == 4:
				screen.update_screen()
			elif value == 8:
				screen.clear_buffer()
		4:
			screen.set_number_screen(value)
			Current_Outputs[4] = value
		_:
			Current_Outputs[port] = value
		
func create_input():
	var new_bar = input_bar.instantiate()
	new_bar.get_child(0).get_child(1).connect("button_up", close_input.bind(new_bar))
	new_bar.get_child(0).get_child(2).connect("button_up", update_key.bind(new_bar))
	new_bar.get_child(1).get_child(0).connect("item_selected", update_port.bind(new_bar))
	for child in new_bar.get_child(1).get_children():
		if child is CheckBox:
			child.connect("pressed", update_value.bind(new_bar))
	add_child(new_bar)
	move_child(new_bar, get_child_count() - 2)
	
func load_input(port, key, value):
	var new_bar = input_bar.instantiate()
	new_bar.get_child(0).get_child(1).connect("button_up", close_input.bind(new_bar))
	new_bar.get_child(0).get_child(2).connect("button_up", update_key.bind(new_bar))
	new_bar.get_child(1).get_child(0).connect("item_selected", update_port.bind(new_bar))
	for child in new_bar.get_child(1).get_children():
		if child is CheckBox:
			child.connect("pressed", update_value.bind(new_bar))
	new_bar.get_child(0).get_child(2).text = key
	new_bar.get_child(1).get_child(0).selected = [1, 2, 6, 7].find(port)
	var bin_value = String.num_int64(value, 2).reverse()
	var index = 0
	for character in bin_value.length():
		if bin_value[character] == "1":
			new_bar.get_child(1).get_child(10 - index).button_pressed = true
		index += 1
	new_bar.set_meta("PortChosen", true)
	new_bar.set_meta("KeyChosen", true)
	new_bar.set_meta("LastPort", port)
	add_child(new_bar)
	move_child(new_bar, get_child_count() - 2)
	update_input(key, port, value, new_bar)
	
func close_input(bar: Panel):
	Current_Inputs[[1, 2, 6, 7][bar.get_child(1).get_child(0).selected]].erase(bar.get_child(0).get_child(2).text)
	remove_child(bar)
	bar.queue_free()
	emulator.update_settings()

func update_key(bar: Panel):
	bar.get_child(0).get_child(2).text = "Waiting"
	var input_key: String = await keyPressed
	if input_key.is_empty():
		return
	if bar.get_meta("KeyChosen"):
		Current_Inputs[[1, 2, 6, 7][bar.get_child(1).get_child(0).selected]].erase(bar.get_child(0).get_child(2).text)
	else:
		bar.set_meta("KeyChosen", true)
	bar.get_child(0).get_child(2).text = input_key
	if bar.get_meta("PortChosen"):
		update_input(input_key, [1, 2, 6, 7][bar.get_child(1).get_child(0).selected], get_value(bar), bar)

func update_port(port: int, bar: Panel):
	if bar.get_meta("PortChosen"):
		Current_Inputs[bar.get_meta("LastPort")].erase(bar.get_child(0).get_child(2).text)
	else:
		bar.set_meta("PortChosen", true)
	bar.set_meta("LastPort", [1, 2, 6, 7][port])
	if bar.get_meta("KeyChosen"):
		update_input(bar.get_child(0).get_child(2).text, [1, 2, 6, 7][port], get_value(bar), bar)

func update_value(bar: Panel):
	if bar.get_meta("KeyChosen") and bar.get_meta("PortChosen"):
		update_input(bar.get_child(0).get_child(2).text, [1, 2, 6, 7][bar.get_child(1).get_child(0).selected], get_value(bar), bar)
		
func get_value(bar: Panel):
	var sum = 0
	var value = 128
	for child in bar.get_child(1).get_children():
		if child is CheckBox:
			if child.button_pressed:
				sum += value
			value /= 2
	return sum
	
func update_input(input_key: String, port: int, value: int, bar: Panel):
	var box = StyleBoxFlat.new()
	box.bg_color = Color.hex(0x383838FF)
	bar.add_theme_stylebox_override("panel", box)
	Current_Inputs[port][input_key] = value
	emulator.update_settings()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode in ValidKeys.VALID_KEYS:
			keyPressed.emit(ValidKeys.KEY_NAMES[event.keycode - 65])
		else:
			keyPressed.emit("")
