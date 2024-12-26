extends TextEdit

const customCodeHighlighter = preload("res://scripts/CustomCodeHighlighter.gd")
var highlighter = customCodeHighlighter.new()

const REGISTERS = {"r0":"000", "r1":"001", "r2":"010", "r3":"011", "r4":"100", "r5":"101", "r6":"110", "r7":"111"}
const CONDITIONS = {"novf": "000", "ovf": "001", "nc": "010", "c": "011", "nmsb": "100", "msb": "101", "nz": "110", "z": "111",
					"!overflow": "000", "overflow": "001", "!carry": "010", "carry": "011", "!msb": "100", "!zero": "110", "zero": "111",
					"!=": "110", "=": "111", "<": "010", ">=": "011", ">=0": "100", "<0": "101",
					"!ovf": "000", "!c": "010", "!z": "110", "eq": "111", "neq": "110", "!eq": "110"}
					
const POSSIBLE_REGISTERS = ["r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7"]
const POSSIBLE_CONDITIONS = ["novf", "ovf", "nc", "c", "nmsb", "msb", "nz", "z", "!overflow", "overflow", "!carry", "carry", "!msb", "!zero", "zero",
							"!=", "=", "<", ">=", ">=0", "<0", "!ovf", "!c", "!z", "eq", "neq", "!eq"]

var definitions = {}
var labels = {}
var program = []

func Parse_Literal(value: String, bits: int, line: int, instruction: String, param_type: String):
	if value.begins_with("0b"):
		for character in value.substr(2):
			if character not in ["0", "1"]:
				return "Error: binary form %s literal with non binary digits given on line %s for instruction %s" % [param_type, line, instruction]
		var binaryOutput = value.substr(2)
		if binaryOutput.length() > bits:
			return "Error: binary form %s literal is too large to fit in %s bits on line %s for instruction %s" % [param_type, bits, line, instruction]
		#return "%0*s" % [bits, binaryOutput]
		return str(value.bin_to_int())
	if value.begins_with("0x"):
		if value.is_valid_hex_number(true):
			var binaryOutput = String.num_uint64(value.hex_to_int(), 2)
			if binaryOutput.length() > bits:
				return "Error: hex form %s literal is too large to fit in %s bits on line %s for instruction %s" % [param_type, bits, line, instruction]
			#return "%0*d" % [bits, binaryOutput]
			return str(value.hex_to_int())
		return "Error: hex form %s literal with non hex digits given on line %s for instruction %s" % [param_type, line, instruction]
	if value.is_valid_int() and (value.length() != 1 or value[0] != "+"):
		var int_value = value.to_int()
		var binaryOutput = ""
		if int_value < 0:
			binaryOutput = String.num_int64(int_value, 2)
		else:
			binaryOutput = String.num_uint64(int_value, 2)
		if binaryOutput.length() > bits:
			return "Error: decimal form %s literal is too large to fit in %s bits on line %s for instruction %s" % [param_type, bits, line, instruction]
		#return "%0*d" % [bits, binaryOutput]
		return value
	return "Error: %s literal on line %s for instruction %s is not in any recognizable form: 0b - binary, 0x - hex, otherwise decimal" % [param_type, line, instruction]

func Register(value: String, line: int, instruction: String) -> String:
	if value in definitions:
		if definitions[value] in REGISTERS:
			return str(REGISTERS[definitions[value]].bin_to_int())
		return Parse_Literal(definitions[value], 3, line, instruction, "register")
	if value in REGISTERS:
		return str(REGISTERS[value].bin_to_int())
	return "Error: invalid register on line %s for instruction %s, possible registers are: \n%s" % [line, instruction, POSSIBLE_REGISTERS]

func Condition(value: String, line: int, instruction: String) -> String:
	if value in definitions:
		if definitions[value] in CONDITIONS:
			return str(CONDITIONS[definitions[value]].bin_to_int())
		return Parse_Literal(definitions[value], 3, line, instruction, "condition")
	if value in CONDITIONS:
		return str(CONDITIONS[value].bin_to_int())
	return "Error: invalid condition on line %s for instruction %s, possible conditions are: \n%s" % [line, instruction, POSSIBLE_CONDITIONS]

func Single(value: String, line: int, instruction: String) -> String:
	if value in definitions:
		if definitions[value] in ["0", "0b0", "0x0"]:
			return "0"
		elif definitions[value] in ["1", "0b1", "0x1"]:
			return "1"
	if value in ["0", "0b0", "0x0"]:
		return "0"
	elif value in ["1", "0b1", "0x1"]:
		return "1"
	return "Error: invalid single on line %s for instruction %s, a single can be either a 0 or a 1" % [line, instruction]

func Label(value: String, line: int, instruction: String) -> String:
	if value in labels:
		return str(labels[value][1])
	return "Error: invalid label on line %s for instruction %s" % [line, instruction]

func Immediate(value: String, bits: int, line: int, instruction: String) -> String:
	if value in definitions:
		value = str(definitions[value])
	return Parse_Literal(value, bits, line, instruction, "immediate")

var INSTRUCTIONS = {"add": [[3, 4],
							[Callable(self, "Register"), Callable(self, "Register"), Callable(self, "Register")],
							[Callable(self, "Register"), Callable(self, "Register"), Callable(self, "Single"), Callable(self, "Register")]],
					"sub": [[3, 4],
							[Callable(self, "Register"), Callable(self, "Register"), Callable(self, "Register")],
							[Callable(self, "Register"), Callable(self, "Register"), Callable(self, "Single"), Callable(self, "Register")]],
					"and": [[3],
							[Callable(self, "Register"), Callable(self, "Register"), Callable(self, "Register")]],
					"or": [[3],
						   [Callable(self, "Register"), Callable(self, "Register"), Callable(self, "Register")]],
					"xor": [[3],
							[Callable(self, "Register"), Callable(self, "Register"), Callable(self, "Register")]],
					"bsh": [[4, 5],
							[Callable(self, "Register"), Callable(self, "Register"), Callable(self, "Single"), Callable(self, "Register")],
							[Callable(self, "Register"), Callable(self, "Register"), Callable(self, "Single"), Callable(self, "Single"), Callable(self, "Register")]],
					"mld": [[2, 3],
							[Callable(self, "Register"), Callable(self, "Register")],
							[Callable(self, "Register"), func (value: String, line: int, instruction: String): return Immediate(value, 5, line, instruction), Callable(self, "Register")]],
					"mst": [[2, 3],
							[Callable(self, "Register"), Callable(self, "Register")],
							[Callable(self, "Register"), Callable(self, "Register"), func (value: String, line: int, instruction: String): return Immediate(value, 5, line, instruction)]],
					"jmp": [[1],
							[Callable(self, "Label")]],
					"cal": [[1],
							[Callable(self, "Label")]],
					"ret": [[0],
							[]],
					"rdp": [[0, 1],
							[],
							[Callable(self, "Single")]],
					"prd": [[1, 2],
							[Callable(self, "Condition")],
							[Callable(self, "Condition"), Callable(self, "Single")]],
					"hlt": [[0],
							["0111100000000000",]],
					"bsi": [[3, 4],
							[Callable(self, "Register"), Callable(self, "Single"), func (value: String, line: int, instruction: String): return Immediate(value, 3, line, instruction)],
							[Callable(self, "Register"), Callable(self, "Single"), Callable(self, "Single"), func (value: String, line: int, instruction: String): return Immediate(value, 3, line, instruction)]],
					"ani": [[2],
							[Callable(self, "Register"), func (value: String, line: int, instruction: String): return Immediate(value, 8, line, instruction)]],
					"ori": [[2],
							[Callable(self, "Register"), func (value: String, line: int, instruction: String): return Immediate(value, 8, line, instruction)]],
					"xri": [[2],
							[Callable(self, "Register"), func (value: String, line: int, instruction: String): return Immediate(value, 8, line, instruction)]],
					"tst": [[2],
							[Callable(self, "Register"), func (value: String, line: int, instruction: String): return Immediate(value, 8, line, instruction)]],
					"adi": [[2],
							[Callable(self, "Register"), func (value: String, line: int, instruction: String): return Immediate(value, 8, line, instruction)]],
					"ldi": [[2],
							[Callable(self, "Register"), func (value: String, line: int, instruction: String): return Immediate(value, 8, line, instruction)]],
					"pst": [[2],
							[Callable(self, "Register"), func (value: String, line: int, instruction: String): return Immediate(value, 5, line, instruction)]],
					"pld": [[2],
							[Callable(self, "Register"), func (value: String, line: int, instruction: String): return Immediate(value, 5, line, instruction)]]}

func show_error(error_message: String):
	if not %"Error Bottom Tab".visible:
		%"Emulator".is_runnable = false
		%"Error Bottom Tab".visible = true
		%"Error Bottom Tab".get_child(0).get_child(0).text = error_message

func hide_error():
	%"Error Bottom Tab".visible = false

func _ready():
	syntax_highlighter = highlighter
	#%"Program View".add_gutter(1)
	#%"Program View".set_gutter_width(1, 35)
	#%"Program View".set_gutter_type(1, TextEdit.GUTTER_TYPE_ICON)
	#%"Program View".set_line_gutter_icon(0, 1, preload("res://Resources/Red Circle.svg"))
	#set_gutter_custom_draw(1, get_error)
	#
#func get_error(line: int, gutter: int, Area: Rect2):
	#return 1

func _on_text_changed() -> void:
	hide_error()
	definitions.clear()
	labels.clear()
	program.clear()
	var available_pages = []
	for i in 128:
		available_pages.append(i)
	var in_page_line = 1
	%"Emulator".is_runnable = true
	
	var valid_line = 0
	
	for line in get_line_count():
		set_line_background_color(line, Color.hex(0x00000000))
		var prog_line = get_line(line).strip_edges().to_lower()
		
		var comment_index = -1
		for symbol in ["//", "#", ";"]:
			if prog_line.contains(symbol):
				comment_index = prog_line.find(symbol)
				prog_line = prog_line.split(symbol)[0].strip_edges()
		
		if prog_line.is_empty() or (prog_line.is_empty() and comment_index != -1):
			continue
		
		if prog_line.begins_with(">"):
			if prog_line.substr(1).is_valid_int() and prog_line[1] != "-" and prog_line[1] != "+":
				var temp_index = available_pages.find(prog_line.substr(1).to_int())
				if temp_index == -1:
					set_line_background_color(line, Color.hex(0xC5696966))
					show_error("Error: duplicate page number on line %s" % line)
				else:
					available_pages.remove_at(temp_index)
				continue
				
		if prog_line.begins_with("."):
			if not prog_line.substr(1).contains(" ") and not prog_line.substr(1).contains("\t"):
				if prog_line in labels:
					set_line_background_color(line, Color.hex(0xC5696966))
					set_line_background_color(labels[prog_line][0], Color.hex(0xC5696966))
					show_error("Error: duplicate label on lines %s and %s" % [line, labels[prog_line][0]])
				else:
					labels[prog_line] = [line, valid_line]
			continue
		
		var split_str = prog_line.split(" ")
		var split_dict = []
		var offset = 0
		for item in split_str:
			if item.begins_with("//") or item.begins_with(";") or item.begins_with("#"):
				break
			split_dict.append([item, offset])
			offset += item.length() + 1
			prog_line = prog_line.erase(0, offset)
			
		if split_dict[0][0] == "define":
			if split_dict.size() != 3:
				continue
			if split_dict[2][0].begins_with("0b"):
				if split_dict[2][0].length() > 2:
					var binary = true
					for character in split_dict[2][0].substr(2):
						if character not in ["0", "1"]:
							binary = false
							break
					if binary:
						definitions[split_dict[1][0]] = split_dict[2][0] #.bin_to_int()
			elif split_dict[2][0].begins_with("0x"):
				if split_dict[2][0].length() > 2 and split_dict[2][0].is_valid_hex_number(true):
					definitions[split_dict[1][0]] = split_dict[2][0] #.hex_to_int()
			elif split_dict[2][0].is_valid_int():
				if not (split_dict[2][0].length() > 0 and split_dict[2][0][0] == "+"):
					definitions[split_dict[1][0]] = split_dict[2][0] #.to_int()
			elif split_dict[2][0] in REGISTERS or split_dict[2][0] in CONDITIONS:
				definitions[split_dict[1][0]] = split_dict[2][0]
			continue
		
		if split_str[0] in INSTRUCTIONS:
			valid_line += 1
			if valid_line > 4096:
				set_line_background_color(line, Color.hex(0xC5696966))
				show_error("Error: program is larger than 4096 instructions, please shorten the program")
	
	for line in get_line_count():
		var line_number = "%04d" % [line]
		set_line_gutter_text(line, 0, line_number)
		set_line_gutter_item_color(line, 0, Color.hex(0x919191ff))
		var prog_line = get_line(line).strip_edges().to_lower()
		
		var comment_index = -1
		for symbol in ["//", "#", ";"]:
			if prog_line.contains(symbol):
				comment_index = prog_line.find(symbol)
				prog_line = prog_line.split(symbol)[0].strip_edges()
		
		if prog_line.is_empty() or (prog_line.is_empty() and comment_index != -1):
			continue
		
		if prog_line.begins_with(">"):
			if prog_line.substr(1).is_valid_int() and prog_line[1] != "-" and prog_line[1] != "+":
				if get_line_background_color(line) == Color.hex(0x00000000):
					in_page_line = 1
			continue
		
		if in_page_line > 32:
			if available_pages.size() == 0:
				set_line_background_color(line, Color.hex(0xC5696966))
				show_error("Error: with currently declared pages there are no more pages left to fit instruction on line %s please restructure the program" % line)
			else:
				available_pages.pop_at(0)
				in_page_line = 0
		
		if prog_line.begins_with("."):
			if prog_line.substr(1).contains(" ") or prog_line.substr(1).contains("\t"):
				set_line_background_color(line, Color.hex(0xC5696966))
				show_error("Error: label name cannot contain spaces or tabs on line %s" % line)
			elif prog_line.substr(1).to_lower() in REGISTERS or prog_line.substr(1).to_lower() in CONDITIONS:
				set_line_background_color(line, Color.hex(0xC5696966))
				show_error("Error: label name cannot be named after a preset definition on line %s" % line)
			continue
		
		var split_str = prog_line.split(" ")
			
		if split_str[0] == "define":
			if split_str.size() != 3:
				set_line_background_color(line, Color.hex(0xC5696966))
				show_error("Error: definition missing parameters on line %s" % line)
				continue
			if split_str[2].begins_with("0b"):
				if split_str[2].length() <= 2:
					set_line_background_color(line, Color.hex(0xC5696966))
					show_error("Error: definition with empty binary literal on line %s" % line)
				for character in split_str[2].substr(2):
					if character not in ["0", "1"]:
						set_line_background_color(line, Color.hex(0xC5696966))
						show_error("Error: definition with invalid binary literal on line %s" % line)
						break
				#definitions.append(split_dict[1][0]) # = split_dict[2][0].bin_to_int()
			elif split_str[2].begins_with("0x"):
				if split_str[2].length() <= 2:
					set_line_background_color(line, Color.hex(0xC5696966))
					show_error("Error: definition with empty hex literal on line %s" % line)
				if not split_str[2].is_valid_hex_number(true):
					set_line_background_color(line, Color.hex(0xC5696966))
					show_error("Error: definition with invalid hex literal on line %s" % line)
				#definitions.append(split_dict[1][0]) # = split_dict[2][0].hex_to_int()
			elif split_str[2].is_valid_int():
				if split_str[2].length() > 0 and split_str[2][0] == "+":
					set_line_background_color(line, Color.hex(0xC5696966))
					show_error("Error: definition with invalid decimal literal on line %s" % line)
				#definitions.append(split_dict[1][0]) # = split_dict[2][0].to_int()
			elif split_str[2] not in REGISTERS and split_str[2] not in CONDITIONS:
				set_line_background_color(line, Color.hex(0xC5696966))
				show_error("Error: definition with invalid value on line %s" % line)
			continue
				
		if split_str[0] in INSTRUCTIONS:
			#var line_number = "%04d" % [valid_line]
			#set_line_gutter_text(line, 0, line_number)
			#set_line_gutter_item_color(line, 0, Color.hex(0x919191ff))
			in_page_line += 1
			
			var parameter_count = split_str.size() - 1
			if parameter_count in INSTRUCTIONS[split_str[0]][0]:
				var instruction_type = INSTRUCTIONS[split_str[0]][0].find(parameter_count)
				var parsed = [INSTRUCTIONS.keys().find(split_str[0])]
				for parameter in parameter_count:
					var index = parameter + 1
					
					var func_output: String = INSTRUCTIONS[split_str[0]][1 + instruction_type][parameter].call(split_str[index], line, split_str[0])
					
					if func_output.substr(0, 5) == "Error":
						set_line_background_color(line, Color.hex(0xC5696966))
						show_error("Error: encountered an error parsing instruction on line %s: %s" % [line, func_output])
						break
					else:
						parsed.append(func_output.to_int())
				#var temp_line = get_line(line).strip_edges().to_lower()
				program.append([parsed, line])
				#if comment_index == -1:
					#program.append([temp_line, line])
				#else:
					#program.append([temp_line.erase(comment_index, temp_line.length() - prog_line.length()).strip_edges(), line, parsed])
			else:
				set_line_background_color(line, Color.hex(0xC5696966))
				show_error("Error: unrecognized parameter count for instruction on line %s" % line)
				continue
		else:
			set_line_background_color(line, Color.hex(0xC5696966))
			show_error("Error: unrecognized instruction on line %s" % line)
			continue
	%Emulator._Reset_Pressed()

var previous_caret_line = null

func _on_caret_changed() -> void:
	var current_caret_line = get_caret_line()
	if previous_caret_line != null:
		if current_caret_line == previous_caret_line + 1 and get_line(current_caret_line).is_empty() and Input.is_key_pressed(KEY_ENTER):
			var current_line = get_line(previous_caret_line)
			if current_line.begins_with("\t") or current_line.begins_with(" "):
				var line_prefix = ""
				for character in current_line:
					if character in [" ", "\t"]:
						line_prefix += character
					else:
						break
				set_line(current_caret_line, line_prefix)
				set_caret_column(line_prefix.length())
	previous_caret_line = current_caret_line

var break_point = preload("res://Resources/Red Circle.svg")

func _on_gutter_clicked(line: int, gutter: int) -> void:
	if gutter == 2:
		if get_line_gutter_icon(line, gutter) == break_point:
			set_line_gutter_icon(line, gutter, null)
		else:
			var prog_line : String = get_line(line).strip_edges().to_lower()
			if get_line_background_color(line) != Color.hex(0x00000000):
				return
			for symbol in ["//", ";", "#", ".", ">", "define"]:
				if prog_line.begins_with(symbol):
					return
			set_line_gutter_icon(line, gutter, break_point)
			
func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ENTER and event.is_pressed():
			pass
		elif event.keycode == KEY_SLASH and event.ctrl_pressed and event.is_pressed():
			var _range = get_line_ranges_from_carets()[0]
			_range.y = _range.y + 1
			var comment = not get_line(_range.x).begins_with("// ")
			var caret = Vector2(get_caret_column(), get_caret_line())
			var selection_start = get_selection_origin_column()
			for line in _range:
				var current_line: String = get_line(line)
				if comment:
					set_line(line, "// " + current_line)
				else:
					set_line(line, current_line.right(-3))
			
			var new_caret = Vector2((0 if caret.x == 0 else caret.x + 3) if comment else (caret.x - 3 if caret.x > 3 else 0), caret.y)
			var new_selection_start = (0 if selection_start == 0 else selection_start + 3) if comment else (selection_start - 3 if selection_start > 3 else 0)
			select(_range.y - 1 if _range.x == caret.y else _range.x, new_selection_start, new_caret.y, new_caret.x)
		elif event.keycode == KEY_TAB:
			var caret = Vector2(get_caret_column(), get_caret_line())
			var selection_start = get_selection_origin_column()
			if has_selection():
				accept_event()
				if event.is_pressed():
					var _range = get_line_ranges_from_carets()[0]
					_range.y = _range.y + 1
					if event.shift_pressed:
						for line in _range:
							var current_line: String = get_line(line)
							if current_line.begins_with("\t"):
								set_line(line, current_line.right(-1))
					else:
						for line in _range:
							set_line(line, "\t" + get_line(line))
					
					var new_caret = Vector2((0 if caret.x == 0 else caret.x + 1) if event.shift_pressed else (caret.x - 1 if caret.x > 1 else 0), caret.y)
					var new_selection_start = (0 if selection_start == 0 else selection_start + 1) if event.shift_pressed else (selection_start - 1 if selection_start > 1 else 0)
					select(_range.y - 1 if _range.x == caret.y else _range.x, new_selection_start, new_caret.y, new_caret.x)
