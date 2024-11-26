class_name CustomCodeHighlighter extends SyntaxHighlighter

const REGISTERS = {"r0":"000", "r1":"001", "r2":"010", "r3":"011", "r4":"100", "r5":"101", "r6":"110", "r7":"111"}
const CONDITIONS = {"novf": "000", "ovf": "001", "nc": "010", "c": "011", "nmsb": "100", "msb": "101", "nz": "110", "z": "111",
					"!overflow": "000", "overflow": "001", "!carry": "010", "carry": "011", "!msb": "100", "!zero": "110", "zero": "111",
					"!=": "110", "=": "111", "<": "010", ">=": "011", ">=0": "100", "<0": "101",
					"!ovf": "000", "!c": "010", "!z": "110", "eq": "111", "neq": "110"}

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
	if value.is_valid_int() and value[0] != "+":
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

#var INSTRUCTIONS = ["add", "sub", "and", "or", "xor", "bsh", "mld", "mst", "jmp", "cal", "ret", "rdp", "prd", "hlt", "bsi", "ani", "ori", "xri", "tst", "adi", "ldi", "pst", "pld"]
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
							[func (value: String, line: int, instruction: String): return Immediate(value, 12, line, instruction)]],
					"cal": [[1],
							[func (value: String, line: int, instruction: String): return Immediate(value, 12, line, instruction)]],
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

func _get_name() -> String:
	return "Program View"

func _get_supported_languages() -> PackedStringArray:
	return ["TextFile"]

func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var color_map = {}
	var text_editor = get_text_edit()
	var prog_line = text_editor.get_line(line)
	var color_offset = 0
	for character in prog_line:
		if character in [" ", "\t"]:
			color_offset += 1
		else:
			break
	prog_line = prog_line.strip_edges().to_lower()
	
	var comment_index = -1
	for symbol in ["//", "#", ";"]:
		if prog_line.contains(symbol):
			comment_index = prog_line.find(symbol)
			prog_line = prog_line.split(symbol)[0].strip_edges()
				
	if prog_line.is_empty() and comment_index != -1:
		color_map[color_offset] = { "color": Color.hex(0x858585FF) }
		return color_map
		
	if prog_line.begins_with(">"):
		if not (prog_line.substr(1).is_valid_int() and prog_line[1] != "-" and prog_line[1] != "+"):
			return color_map
		color_map[color_offset] = { "color": Color.hex(0xC586C0FF)}
		if comment_index != -1:
			color_map[color_offset + comment_index] = { "color": Color.hex(0x858585FF) }
		return color_map
	
	if prog_line.begins_with("."):
		if prog_line.substr(1).contains(" "):
			return color_map
		color_map[color_offset] = { "color": Color.hex(0xE8E892FF)}
		if comment_index != -1:
			color_map[color_offset + comment_index] = { "color": Color.hex(0x858585FF) }
		return color_map
	
	var split_str = prog_line.split(" ")
	var split_dict = []
	var offset = 0
	for item in split_str:
		split_dict.append([item, offset])
		offset += item.length() + 1
		prog_line = prog_line.erase(0, offset)
		
	if split_dict[0][0] == "define":
		color_map[color_offset] = { "color": Color.hex(0xC56969FF) }
		color_map[color_offset + 6] = { "color": Color.hex(0xFFFFFFFF) }
		if split_dict.size() != 3:
			return color_map
		if split_dict[2][0].begins_with("0b"):
			if split_dict[2][0].length() == 2:
				return color_map
			for character in split_dict[2][0].substr(2):
				if character not in ["0", "1"]:
					return color_map
			color_map[color_offset + split_dict[2][1]] = { "color": Color.hex(0x4EC9B0FF) }
			#text_editor.definitions.append(split_dict[1][0]) # = split_dict[2][0].bin_to_int()
		elif split_dict[2][0].begins_with("0x"):
			if split_dict[2][0].length() == 2:
				return color_map
			if not split_dict[2][0].is_valid_hex_number(true):
				return color_map
			color_map[color_offset + split_dict[2][1]] = { "color": Color.hex(0x4EC9B0FF) }
			#text_editor.definitions.append(split_dict[1][0]) # = split_dict[2][0].hex_to_int()
		elif split_dict[2][0].is_valid_int():
			if split_dict[2][0].length() > 0 and split_dict[2][0][0] == "+":
				return color_map
			color_map[color_offset + split_dict[2][1]] = { "color": Color.hex(0x4EC9B0FF) }
			#text_editor.definitions.append(split_dict[1][0]) # = split_dict[2][0].to_int()
		elif split_dict[2][0] in REGISTERS:
			color_map[color_offset + split_dict[2][1]] = { "color": Color.hex(0x9CDCFEFF) }
			color_map[color_offset + split_dict[2][1] + 2] = { "color": Color.hex(0xFFFFFFFF) }
		elif split_dict[2][0] in CONDITIONS:
			color_map[color_offset + split_dict[2][1]] = { "color": Color.hex(0x8878D6FF) }
			color_map[color_offset + split_dict[2][1] + split_dict[2][0].length()] = { "color": Color.hex(0xFFFFFFFF) }
		else:
			return color_map
		if comment_index != -1:
			color_map[color_offset + comment_index] = { "color": Color.hex(0x858585FF) }
		return color_map
		
	if split_dict[0][0] in INSTRUCTIONS:
		color_map[color_offset] = { "color": Color.hex(0x569CD6FF) }
		color_map[color_offset + split_dict[0][0].length()] = { "color": Color.hex(0xFFFFFFFF) }
		
		var parameter_count = split_dict.size() - 1
		if parameter_count in INSTRUCTIONS[split_dict[0][0]][0]:
			var instruction_type = INSTRUCTIONS[split_dict[0][0]][0].find(parameter_count)
			for parameter in parameter_count:
				var index = parameter + 1
				#var func_output: String = INSTRUCTIONS[split_dict[0][0]][1 + instruction_type][parameter].call(split_str[index], line, split_str[0])
				
				if split_dict[index][0] in REGISTERS:
					color_map[color_offset + split_dict[index][1]] = { "color": Color.hex(0x9CDCFEFF) }
					color_map[color_offset + split_dict[index][1] + 2] = { "color": Color.hex(0xFFFFFFFF) }
				elif split_dict[index][0].begins_with("0b") or split_dict[index][0].begins_with("0x") or split_dict[index][0].is_valid_int():
					color_map[color_offset + split_dict[index][1]] = { "color": Color.hex(0x4EC9B0FF) }
					color_map[color_offset + split_dict[index][1] + split_dict[index][0].length()] = { "color": Color.hex(0xFFFFFFFF) }
				elif split_dict[index][0] in CONDITIONS:
					color_map[color_offset + split_dict[index][1]] = { "color": Color.hex(0x8878D6FF) }
					color_map[color_offset + split_dict[index][1] + split_dict[index][0].length()] = { "color": Color.hex(0xFFFFFFFF) }
				elif split_dict[index][0].begins_with("."):
					color_map[color_offset + split_dict[index][1]] = { "color": Color.hex(0xE8E892FF)}
					color_map[color_offset + split_dict[index][1] + split_dict[index][0].length()] = { "color": Color.hex(0xFFFFFFFF) }
				#elif func_output.substr(0, 5) == "Error":
						#return color_map
		
	if comment_index != -1:
		color_map[color_offset + comment_index] = { "color": Color.hex(0x858585FF) }
		
	return color_map
