extends ColorRect

@onready var regs_label = %"Reg Values"
@onready var ram_label = %"Ram Values"
@onready var flags_label = %"Flag Values"
@onready var pc_label = %"PC Label"
@onready var start_stop_button = %"Start Stop Button"
@onready var step_button = %"Step Button"
@onready var reset_button = %"Reset Button"
@onready var follow_program_check_button = %"Follow Check Button"
@onready var screen_wrapping_check_button = %"Screen Wrapping Check Button"
@onready var signed_number_display_button = %"SignedNumberToggle"
@onready var speed_slider = %"SpeedSlider"
@onready var speed_input = %"SpeedInput"
@onready var screen = %"Screen"
@onready var program_view = %"Program View"
@onready var port_manager = %"PortManager"
var follow_program = false
var is_runnable = true
var is_running = false
var ips = 1

var ram_values = []
var regs_values = [0, 0, 0, 0, 0, 0, 0, 0]
var regs_hold = [0, 0, 0, 0, 0, 0, 0, 0]
var flag_values = []
var pc = 0
var callstack = []
var thread: Thread = null
var semaphore: Semaphore = null

func _ready():
	Engine.max_physics_steps_per_frame = 120000
	#Engine.max_fps = 120
	Engine.physics_ticks_per_second = 120000
	Engine.time_scale = 1
	flag_values = [false, false, false, false]
	
	for address in 256:
		ram_values.append("0")
	load_settings()
	thread = Thread.new()
	semaphore = Semaphore.new()
	
func update_settings():
	var settings = ConfigFile.new()
	settings.set_value("settings", "run_speed", speed_slider.value)
	settings.set_value("settings", "screen_wrap", screen_wrapping_check_button.button_pressed)
	settings.set_value("settings", "follow_program", follow_program_check_button.button_pressed)
	settings.set_value("settings", "signed_display", signed_number_display_button.button_pressed)
	settings.set_value("settings", "screen_size", port_manager.get_child(0).get_child(1).selected)
	var inputs = []
	for port in [1, 2, 6, 7]:
		for key in port_manager.Current_Inputs[port].keys():
			inputs.append([key, port_manager.Current_Inputs[port][key]])
		settings.set_value("inputs", str(port), inputs.duplicate())
		inputs.clear()
	var paths = []
	for button in %"top bar".fileButtons:
		var path = button.get_meta("FilePath")
		if path != "":
			paths.append(path)
	settings.set_value("files", "paths", paths)
	settings.save("user://settings.txt")

func load_settings():
	var settings = ConfigFile.new()
	var err = settings.load("user://settings.txt")
	if err != OK:
		return
	speed_input.value = settings.get_value("settings", "run_speed")
	screen_wrapping_check_button.button_pressed = settings.get_value("settings", "screen_wrap")
	follow_program_check_button.button_pressed = settings.get_value("settings", "follow_program")
	signed_number_display_button.button_pressed = settings.get_value("settings", "signed_display")
	var panel: Panel = port_manager.get_child(0).get_child(1)
	var selected = settings.get_value("settings", "screen_size")
	panel.check_list[selected].button_pressed = true
	panel._on_check_box_toggled(selected)
	for port in [1, 2, 6, 7]:
		for pair in settings.get_value("inputs", str(port)):
			port_manager.load_input(port, pair[0], pair[1])

func update_flags():
	var flag_text = ""
	flag_text += "[center]Overflow: [color=gray]%s[/color] | " % ("true  " if flag_values[0] else "false")
	flag_text += "Carry out: [color=gray]%s[/color]\n" % ("true  " if flag_values[1] else "false")
	flag_text += "MSB: [color=gray]%s[/color] | " % ("true  " if flag_values[2] else "false")
	flag_text += "Zero: [color=gray]%s[/color] [/center]" % ("true  " if flag_values[3] else "false")
	flags_label.text = flag_text

func update_ram():
	var ram_text = "[center]"
	for address in 256:
		ram_text += "%03d:[color=gray]%03d[/color]" % [address, ram_values[address]] 
		if fmod(address + 1, 4) == 0 and address != 0:
			ram_text += "\n"
		else:
			ram_text += " | "
	ram_text += "[/center]"
	ram_label.text = ram_text

func update_regs():
	var reg_text = "[center]"
	for address in 8:
		reg_text += "%03d:[color=gray]%03d[/color]" % [address, regs_values[address]] 
		if fmod(address + 1, 4) == 0 and address != 0:
			reg_text += "\n"
		else:
			reg_text += " | "
	reg_text += "[/center]"
	regs_label.text = reg_text

func _Start_Stop_Pressed() -> void:
	if not is_runnable:
		return
	if start_stop_button.text.contains("Start"):
		start_stop_button.text = "Stop"
		program_view.editable = false
		follow_program_check_button.disabled = true
		screen_wrapping_check_button.disabled = true
		signed_number_display_button.disabled = true
		%"EditInputs".disabled = true
		for button in %"top bar".fileButtons:
			button.disable(true)
		for button in %"top bar".get_child(0).get_child(0).get_child(0).get_child(0).get_children():
			button.disabled = true
		is_running = true
		if not thread.is_started():
			thread.start(threaded_run)
	else:
		start_stop_button.text = "Start"
		program_view.editable = true
		follow_program_check_button.disabled = false
		screen_wrapping_check_button.disabled = false
		signed_number_display_button.disabled = false
		%"EditInputs".disabled = false
		for button in %"top bar".fileButtons:
			button.disable(false)
		for button in %"top bar".get_child(0).get_child(0).get_child(0).get_child(0).get_children():
			button.disabled = false
		is_running = false
		if thread.is_alive():
			semaphore.post()
			thread.wait_to_finish()

func _Reset_Pressed() -> void:
	if start_stop_button.text.contains("Stop"):
		start_stop_button.text = "Start"
		program_view.editable = true
		follow_program_check_button.disabled = false
		screen_wrapping_check_button.disabled = false
		signed_number_display_button.disabled = false
		%"EditInputs".disabled = false
		for button in %"top bar".fileButtons:
			button.disable(false)
		for button in %"top bar".get_child(0).get_child(0).get_child(0).get_child(0).get_children():
			button.disabled = false
	regs_hold.map(func(_var): return 0)
	callstack.clear()
	
	for value in 256:
		ram_values[value] = 0
	for value in 8:
		regs_values[value] = 0
		%"PortManager".Current_Outputs[value] = 0
	for value in 4:
		flag_values[value] = false
	
	pc = 0
	is_running = false
	if thread.is_alive():
		semaphore.post()
		thread.wait_to_finish()
	block_instruction = 0
	
	update_ram()
	update_regs()
	update_flags()
	update_pc()
	
	screen.set_number_screen(0)
	screen.create_screen()
	
	for line in program_view.get_line_count():
		program_view.set_line_gutter_text(line, 1, "")
	if program_view.program.size() > 0:
		program_view.set_line_gutter_text(program_view.program[0][1], 1, ">")
	else:
		program_view.set_line_gutter_text(0, 1, " >")

func _Step_Pressed() -> void:
	if not is_runnable and not is_running:
		return
	Process_Instruction()
	update_ram()
	update_regs()
	update_flags()
	update_pc()

func update_pc():
	pc_label.text = "[center]PC = %04d[/center]" % pc

func _Follow_Program_Toggled(toggled_on: bool) -> void:
	follow_program = toggled_on

func _Speed_Slider_Change(value: float) -> void:
	ips = value
	speed_input.value = value

func _Speed_Input_Change(value: float) -> void:
	ips = value
	speed_slider.value = value
	
const REGISTERS = {"r0":0, "r1":1, "r2":2, "r3":3, "r4":4, "r5":5, "r6":6, "r7":7}
const CONDITIONS = {"novf": 0, "ovf": 1, "nc": 2, "c": 3, "nmsb": 4, "msb": 5, "nz": 6, "z": 7,
					"!overflow": 0, "overflow": 1, "!carry": 2, "carry": 3, "!msb": 4, "!zero": 6, "zero": 7,
					"!=": 6, "=": 7, "<": 2, ">=": 3, ">=0": 4, "<0": 5,
					"!ovf": 0, "!c": 2, "!z": 6, "eq": 7, "neq": 6, "!eq": 6}

func Parse_Literal(value: String):
	if value.to_lower() in program_view.definitions:
		value = program_view.definitions[value]
	if value.to_lower() in program_view.labels:
		return program_view.labels[value][1]
	if value in CONDITIONS:
		return CONDITIONS[value]
	if value in REGISTERS:
		return REGISTERS[value]
	if value.begins_with("0b"):
		return value.bin_to_int()
	if value.begins_with("0x"):
		return value.hex_to_int()
	if value.is_valid_int() and (value.length() == 1 or value[1] != "+"):
		return int(value)

func Bind_Literal(value: int):
	if value < 0:
		return 256 + value
	if value > 255:
		return value % 256
	return value
	
var block_instruction = 0

func Process_Instruction() -> void:
	var split_line
	var flag_save = flag_values.duplicate()
	flag_values[0] = false
	flag_values[1] = false
	flag_values[2] = false
	flag_values[3] = false
	
	if pc >= program_view.program.size():
		#split_line = "add r0 r0 r0"
		split_line = [0, 0, 0, 0]
	else:
		#split_line = program_view.program[pc][0].split(" ")
		split_line = program_view.program[pc][0]
	
	if block_instruction == 0:
		match split_line[0]:
			0:
				var regA = split_line[1]
				var regB = split_line[2]
				var c = 0
				var dest
				if split_line.size() == 5:
					c = split_line[3]
					dest = split_line[4]
				else:
					dest = split_line[3]
				var output = regs_values[regA] + regs_values[regB] + (1 if c == 1 and flag_save[1] else 0)
				flag_values[1] = output > 255
				output = Bind_Literal(output)
				regs_values[dest] = output
				var temp =  1 if c == 1 and flag_values[1] else 0
				var b71 = (128 > regs_values[regA] and regs_values[regA] > 63) or (256 > regs_values[regA] and regs_values[regA] > 191)
				var b72 = (128 > regs_values[regB] and regs_values[regB] > 63) or (256 > regs_values[regB] and regs_values[regB] > 191)
				var b71l = (128 > regs_values[regA] and regs_values[regA] > 62) or (256 > regs_values[regA] and regs_values[regA] > 190)
				var b72l = (128 > regs_values[regB] and regs_values[regB] > 62) or (256 > regs_values[regB] and regs_values[regB] > 190)
				flag_values[0] = flag_values[1] != (b71 and b72 if temp == 0 else (b71l and b72) or (b71 and b72l))
				flag_values[2] = output > 127
				flag_values[3] = output == 0
			1:
				var regA = split_line[1]
				var regB = split_line[2]
				var c = 0
				var dest
				if split_line.size() == 5:
					c = split_line[3]
					dest = split_line[4]
				else:
					dest = split_line[3]
				var output = Bind_Literal(regs_values[regA] - regs_values[regB] - (1 if c == 1 and not flag_save[1] else 0))
				regs_values[dest] = output
				flag_values[1] = regs_values[regA] > regs_values[regB]
				var temp = -1 if c == 1 and not flag_values[1] else 0
				var b71 = (128 > regs_values[regA] and regs_values[regA] > 63) or (256 > regs_values[regA] and regs_values[regA] > 191)
				var b72 = (128 > regs_values[regB] and regs_values[regB] > 63) or (256 > regs_values[regB] and regs_values[regB] > 191)
				var b71l = (128 > regs_values[regA] and regs_values[regA] > 62) or (256 > regs_values[regA] and regs_values[regA] > 190)
				var b72l = (128 > regs_values[regB] and regs_values[regB] > 62) or (256 > regs_values[regB] and regs_values[regB] > 190)
				flag_values[0] = flag_values[1] != (b71 and b72 if temp == 0 else (b71l and b72) or (b71 and b72l))
				flag_values[2] = output > 127
				flag_values[3] = output == 0
			2:
				var regB = split_line[2]
				var regA = split_line[1]
				var dest = split_line[3]
				regs_values[dest] = regs_values[regA] & regs_values[regB]
				flag_values[2] = regs_values[dest] > 127
				flag_values[3] = regs_values[dest] == 0
			3:
				var regA = split_line[1]
				var regB = split_line[2]
				var dest = split_line[3]
				regs_values[dest] = regs_values[regA] | regs_values[regB]
				flag_values[2] = regs_values[dest] > 127
				flag_values[3] = regs_values[dest] == 0
			4:
				var regA = split_line[1]
				var regB = split_line[2]
				var dest = split_line[3]
				regs_values[dest] = regs_values[regA] ^ regs_values[regB]
				flag_values[2] = regs_values[dest] > 127
				flag_values[3] = regs_values[dest] == 0
			5:
				var regA = split_line[1]
				var regB = split_line[2]
				var dir = split_line[3]
				var se = 0
				var dest
				if split_line.size() == 6:
					se = split_line[4]
					dest = split_line[5]
				else:
					dest = split_line[4]
				var output
				if dir == 0:
					if se == 0:
						output = regs_values[regA] >> (regs_values[regB] & 7)
						regs_values[dest] = output
						flag_values[1] = 255 >> regs_values[regB] & regs_values[regA] != 0
					else:
						output = Bind_Literal((regs_values[regA] >> (regs_values[regB] & 7)) + (65280 >> regs_values[regB] if regs_values[regA] / 128 == 1 else 0))
						regs_values[dest] = output
						flag_values[1] = 255 >> regs_values[regB] & regs_values[regA] != 0
				else:
					output = regs_values[regA] << (regs_values[regB] & 7)
					regs_values[dest] = Bind_Literal(output)
					flag_values[1] = output > 255
				flag_values[2] = output > 127
				flag_values[3] = output == 0
			6:
				var regA = split_line[1]
				var imm = 0
				var dest = split_line[2]
				if split_line.size() == 4:
					imm = split_line[2]
					dest = split_line[3]
				regs_values[dest] = ram_values[regs_values[regA] + imm] 
			7:
				var regA = split_line[1]
				var regB = split_line[2]
				var imm = 0
				if split_line.size() == 4:
					imm = split_line[3]
				ram_values[regs_values[regA] + imm] = regs_values[regB]
			8:
				pc = split_line[1] - 1
			9:
				callstack.append(pc + 1)
				pc = split_line[1] - 1
			10:
				pc = callstack.pop_at(0) - 1
			11:
				var l = 0
				if split_line.size() == 2:
					l = split_line[1]
				if l == 0:
					regs_hold = regs_values.duplicate()
					regs_values.map(func(_var): return 0)
				else:
					regs_values = regs_hold
			12:
				var cond = split_line[1]
				var m = 0
				if split_line.size() == 3:
					m = split_line[2]
				
				if flag_save[cond / 2] != (cond % 2 == 1):
					block_instruction = m + 1
			13:
				if is_running:
					threaded_stop()
					regs_values[0] = 0
					return
			14:
				var regA = split_line[1]
				var dir = split_line[2]
				var se = 0
				var imm
				if split_line.size() == 6:
					se = split_line[3]
					imm = split_line[4]
				else:
					imm = split_line[3]
				imm = imm & 7
				var output
				if dir == 0:
					if se == 0:
						output = regs_values[regA] >> imm
						flag_values[1] = 255 >> (8 - imm) & regs_values[regA] != 0
						regs_values[regA] = output
					else:
						output = Bind_Literal((regs_values[regA] >> imm) + (65280 >> imm if regs_values[regA] / 128 == 1 else 0))
						flag_values[1] = 255 >> (8 - imm) & regs_values[regA] != 0
						regs_values[regA] = output
				else:
					output = regs_values[regA] << imm
					regs_values[regA] = Bind_Literal(output)
					flag_values[1] = output > 255
				flag_values[2] = output > 127
				flag_values[3] = output == 0
			15:
				var regA = split_line[1]
				var imm = split_line[2]
				regs_values[regA] = regs_values[regA] & imm
				flag_values[2] = regs_values[regA] > 127
				flag_values[3] = regs_values[regA] == 0
			16:
				var regA = split_line[1]
				var imm = split_line[2]
				regs_values[regA] = regs_values[regA] | imm
				flag_values[2] = regs_values[regA] > 127
				flag_values[3] = regs_values[regA] == 0
			17:
				var regA = split_line[1]
				var imm = split_line[2]
				regs_values[regA] = regs_values[regA] ^ imm
				flag_values[2] = regs_values[regA] > 127
				flag_values[3] = regs_values[regA] == 0
			18:
				var regA = split_line[1]
				var imm = split_line[2]
				var output = regs_values[regA] & imm
				flag_values[2] = output > 127
				flag_values[3] = output == 0
			19:
				var regA = split_line[1]
				var imm = split_line[2]
				
				var output = regs_values[regA] + imm
				flag_values[1] = output > 255
				output = Bind_Literal(output)
				regs_values[regA] = output
				var b71 = (128 > regs_values[regA] and regs_values[regA] > 63) or (256 > regs_values[regA] and regs_values[regA] > 191)
				var b72 = (128 > imm and imm > 63) or (256 > imm and imm > 191)
				flag_values[0] = flag_values[1] != b71 and b72
				flag_values[2] = output > 127
				flag_values[3] = output == 0
			20:
				var dest = split_line[1]
				var imm = split_line[2]
				regs_values[dest] = imm
				flag_values[2] = regs_values[dest] > 127
				flag_values[3] = regs_values[dest] == 0
			21:
				var regA = split_line[1]
				var imm = split_line[2]
				port_manager.Write_Port(imm, regs_values[regA])
			22:
				var dest = split_line[1]
				var imm = split_line[2]
				regs_values[dest] = port_manager.Read_Port(imm)
			_:
				pass
	else:
		block_instruction -= 1
	regs_values[0] = 0
	pc += 1
	if pc >= program_view.program.size():
		return
	#program_view.set_line_gutter_text(program_view.program[pc][1], 1, " >")

var timer = 0
var count = 0
var second = 0

func threaded_run():
	Thread.set_thread_safety_checks_enabled(false)
	while true:
		semaphore.wait()
		if not is_running or program_view.program.size() == 0:
			return
		Process_Instruction()
		count += 1
		if program_view.get_line_gutter_icon(program_view.program[pc][1], 2) != null:
			threaded_stop()
			return

func threaded_stop():
	start_stop_button.text = "Start"
	program_view.editable = true
	follow_program_check_button.disabled = false
	screen_wrapping_check_button.disabled = false
	signed_number_display_button.disabled = false
	%"EditInputs".disabled = false
	for button in %"top bar".fileButtons:
		button.disable(false)
	for button in %"top bar".get_child(0).get_child(0).get_child(0).get_child(0).get_children():
		button.disabled = false
	is_running = false

var previous_pc = 0

func _process(_delta: float) -> void:
	#if not is_running and previous_pc != 0:
		#program_view.set_line_gutter_text(program_view.program[previous_pc][1], 1, "")
		#program_view.set_line_gutter_text(program_view.program[0][1], 1, " >")
		#previous_pc = 0
	update_ram()
	update_regs()
	update_flags()
	update_pc()
	#screen.update_screen()
	if previous_pc != pc:
		if previous_pc < program_view.get_line_count():
			program_view.set_line_gutter_text(program_view.program[previous_pc][1], 1, "")
		if pc < program_view.get_line_count():
			if program_view.program.size() != 0:
				program_view.set_line_gutter_text(program_view.program[pc][1], 1, " >")
			else:
				program_view.set_line_gutter_text(0, 1, " >")
	previous_pc = pc

func _physics_process(delta: float) -> void:
	if not is_running:
		if thread.is_started():
			thread.wait_to_finish()
		return
	second += delta
	if second >= 1:
		print(count)
		count = 0
		second = 0
	
	timer += delta
	if timer > 1.0 / ips:
		semaphore.post()
		timer = 0
		#print(timer, " ", delta, " ", 1.0 / ips)
		#return
	#Process_Instruction()
	#update_ram()
	#update_regs()
	#update_flags()
	#update_pc()
