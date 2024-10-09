extends TextEdit

const customCodeHighlighter = preload("res://scripts/CustomCodeHighlighter.gd")
var highlighter = customCodeHighlighter.new()

const REGISTERS = {"r0":"000", "r1":"001", "r2":"010", "r3":"011", "r4":"100", "r5":"101", "r6":"110", "r7":"111"}
const CONDITIONS = {"novf": "000", "ovf": "001", "nc": "010", "c": "011", "nmsb": "100", "msb": "101", "nz": "110", "z": "111",
					"!overflow": "000", "overflow": "001", "!carry": "010", "carry": "011", "!msb": "100", "!zero": "110", "zero": "111",
					"!=": "110", "=": "111", "<": "010", ">=": "011", ">=0": "100", "<0": "101",
					"!ovf": "000", "!c": "010", "!z": "110", "eq": "111", "neq": "110"}

var definitions = []
var labels = []

func Register(value: String, line: int, instruction: String) -> String:
	if value in REGISTERS:
		#return REGISTERS[value]
		return ""
	return "Error: invalid register on line %s for instruction %s, possible registers are: \n%s" % [line, instruction, REGISTERS]

func Condition(value: String, line: int, instruction: String) -> String:
	if value in CONDITIONS:
		#return CONDITIONS[value]
		return ""
	return "Error: invalid condition on line %s for instruction %s, possible conditions are: \n%s" % [line, instruction, CONDITIONS]

func Single(value: String, line: int, instruction: String) -> String:
	if value in ["0", "1", "0b0", "0b1", "0x0", "0x1"]:
		return ""
	return "Error: invalid single on line %s for instruction %s, a single can be either a 0 or a 1" % [line, instruction]

func Label(value: String, line: int, instruction: String) -> String:
	if value in labels:
		return ""
	return "Error: invalid single on line %s for instruction %s, a single can be either a 0 or a 1" % [line, instruction]

func Immediate(value: String, bits: int, line: int, instruction: String) -> String:
	# if value is in binary form
	if value.begins_with("0b"):
		for character in value.substr(2):
			if character not in ["0", "1"]:
				return "Error: binary form immediate with non binary digits given on line %s for instruction %s" % [line, instruction]
		var binaryOutput = value.substr(2)
		if binaryOutput.length() > bits:
			return "Error: binary form immediate too large to fit in %s bits on line %s for instruction %s" % [bits, line, instruction]
		#return "%0*s" % [bits, binaryOutput]
		return ""
	if value.begins_with("0x"):
		if value.is_valid_hex_number(true):
			var binaryOutput = String.num_uint64(value.hex_to_int(), 2)
			if binaryOutput.length() > bits:
				return "Error: hex form immediate too large to fit in %s bits on line %s for instruction %s" % [bits, line, instruction]
			#return "%0*d" % [bits, binaryOutput]
			return ""
		return "Error: hex form immediate with non hex digits given on line %s for instruction %s" % [line, instruction]
	if value.is_valid_int() and value[1] != "+":
		var int_value = value.to_int()
		var binaryOutput = ""
		if int_value < 0:
			binaryOutput = String.num_int64(int_value, 2)
		else:
			binaryOutput = String.num_uint64(int_value, 2)
		if binaryOutput.length() > bits:
			return "Error: hex form immediate too large to fit in %s bits on line %s for instruction %s" % [bits, line, instruction]
		#return "%0*d" % [bits, binaryOutput]
		return ""
	return "Error: immediate on line %s for instruction %s is not in any recognizable form: 0b - binary, 0x - hex, otherwise decimal" % [line, instruction]

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

var available_pages = []

func _ready():
	syntax_highlighter = highlighter
	for i in 128:
		available_pages.append(i)
	
	#%"Program View".add_gutter(1)
	#%"Program View".set_gutter_width(1, 35)
	#%"Program View".set_gutter_type(1, TextEdit.GUTTER_TYPE_ICON)
	#%"Program View".set_line_gutter_icon(0, 1, preload("res://Resources/Red Circle.svg"))
	#set_gutter_custom_draw(1, get_error)
	#
#func get_error(line: int, gutter: int, Area: Rect2):
	#return 1

func _on_text_changed() -> void:
	var valid_line = 1
	for line in get_line_count():
		set_line_background_color(line, Color.hex(0x00000000))
		set_line_gutter_text(line, 0, "")
		var prog_line = get_line(line)
		prog_line = prog_line.strip_edges().to_lower()
		
		var comment_index = -1
		for symbol in ["//", "#", ";"]:
			if prog_line.contains(symbol):
				comment_index = prog_line.find(symbol)
				prog_line = prog_line.split(symbol)[0].strip_edges()
		
		if prog_line.is_empty() and comment_index != -1:
			continue
		
		if prog_line.begins_with(">"):
			if not (prog_line.substr(1).is_valid_int() and prog_line[1] != "-" and prog_line[1] != "+"):
				set_line_background_color(line, Color.hex(0xC5696966))
				continue
			set_line_background_color(line, Color.hex(0x00000000))
			
			continue
		
		if prog_line.begins_with("."):
			if prog_line.substr(1).contains(" "):
				set_line_background_color(line, Color.hex(0xC5696966))
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
				set_line_background_color(line, Color.hex(0xC5696966))
				continue
			if split_dict[2][0].begins_with("0b"):
				if split_dict[2][0].length() == 2:
					set_line_background_color(line, Color.hex(0xC5696966))
				for character in split_dict[2][0].substr(2):
					if character not in ["0", "1"]:
						set_line_background_color(line, Color.hex(0xC5696966))
				#definitions.append(split_dict[1][0]) # = split_dict[2][0].bin_to_int()
			elif split_dict[2][0].begins_with("0x"):
				if split_dict[2][0].length() == 2:
					set_line_background_color(line, Color.hex(0xC5696966))
				if not split_dict[2][0].is_valid_hex_number(true):
					set_line_background_color(line, Color.hex(0xC5696966))
				#definitions.append(split_dict[1][0]) # = split_dict[2][0].hex_to_int()
			elif split_dict[2][0].is_valid_int():
				if split_dict[2][0].length() > 0 and split_dict[2][0][0] == "+":
					set_line_background_color(line, Color.hex(0xC5696966))
				#definitions.append(split_dict[1][0]) # = split_dict[2][0].to_int()
			else:
				set_line_background_color(line, Color.hex(0xC5696966))
			continue
				
		if split_dict[0][0] in INSTRUCTIONS:
			var line_number = "%04d" % [valid_line]
			set_line_gutter_text(line, 0, line_number)
			set_line_gutter_item_color(line, 0, Color.hex(0x919191ff))
			valid_line += 1
			
			var parameter_count = split_dict.size() - 1
			if parameter_count in INSTRUCTIONS[split_dict[0][0]][0]:
				var instruction_type = INSTRUCTIONS[split_dict[0][0]][0].find(parameter_count)
				for parameter in parameter_count:
					var index = parameter + 1
					var func_output: String = INSTRUCTIONS[split_dict[0][0]][1 + instruction_type][parameter].call(split_str[index], line, split_str[0])
					
					if func_output.substr(0, 5) == "Error":
						set_line_background_color(line, Color.hex(0xC5696966))
						break
			else:
				set_line_background_color(line, Color.hex(0xC5696966))
				continue
		else:
			set_line_background_color(line, Color.hex(0xC5696966))
			continue
