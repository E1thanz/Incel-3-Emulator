extends ColorRect

var screen_x = 32: set = set_x
var screen_y = 32: set = set_y
@onready var grid : GridContainer = get_child(0).get_child(0)
var address_wrapping = false
var signed_mode = false
var buffer = []
var changes = []

func set_number_screen(value: int):
	%"NumDisplay".text = "[center]%s[/center]" % ((value if value < 128 else 254 - value) if signed_mode else value)

func set_x(new_x: int):
	screen_x = new_x
	
func set_y(new_y: int):
	screen_y = new_y

func clear_buffer():
	for y in screen_y:
		for x in screen_x:
			buffer[y][x] = false
	changes.clear()
	
func update_screen():
	for change in changes:
		set_pixel(change[0], change[1], change[2])
	changes.clear()

func _ready() -> void:
	for y in screen_y:
		buffer.append([])
		for x in screen_x:
			buffer[-1].append(false)
	create_screen()
	
func test_screen():
	for i in screen_y:
		for j in screen_x:
			if fmod(i + j, 2) == 0:
				set_pixel(j, i, true)

func create_screen():
	if screen_x < 1 or 128 < screen_x:
		return
			
	if screen_y < 1 or 128 < screen_y:
		return
	
	grid.columns = screen_x
	changes.clear()
	buffer.clear()
	
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	
	for y in screen_y:
		buffer.append([])
		for x in screen_x:
			buffer[-1].append(false)
			var pixel = ColorRect.new()
			pixel.color = Color.hex(0x000000ff)
			pixel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pixel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			grid.add_child(pixel)

func add_change(x, y, value: bool):
	if x < 0 or y < 0:
		return
	if address_wrapping:
		x = int(x % screen_x)
		y = int(y % screen_y)
	elif screen_x <= x or screen_y <= y:
		return
	changes.append([x, y, value])
	buffer[y][x] = value

func set_pixel(x, y, value: bool):
	grid.get_child(x + (screen_y - y - 1) * screen_x).color = Color.hex(0xffffffff) if value else Color.hex(0x000000ff)

func get_pixel(x, y):
	if x < 0 or y < 0:
		return
	if address_wrapping:
		x = int(fmod(x, screen_x))
		y = int(fmod(y, screen_y))
	elif screen_x <= x or screen_y <= y:
		return
	#return 1 if grid.get_child(x + (screen_y - y - 1) * screen_x).color == Color.hex(0xffffffff) else 0
	return 1 if buffer[y][x] else 0
	
func _Screen_Wrapping_Toggled(toggled_on: bool) -> void:
	address_wrapping = toggled_on

func _signed_mode_toggled(toggled_on: bool) -> void:
	signed_mode = toggled_on
	set_number_screen(%"PortManager".Current_Outputs[4])
