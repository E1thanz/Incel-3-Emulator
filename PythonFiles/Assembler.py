import os
import sys


class BIN:
    @staticmethod
    def int_to_unsigned(bits: int, number: int) -> str:
        if bits <= 0:
            raise ValueError(f"the number of bits must be a positive integer")
        MAX_NUM = 2 ** bits
        if number > MAX_NUM - 1 or number < 0:
            raise ValueError(f"the number {number} cannot be both unsigned and contained in {bits} bits")
        return format(number, f'0{bits}b')

    @staticmethod
    def int_to_signed(bits: int, number: int) -> str:
        if bits <= 0:
            raise ValueError(f"the number of bits must be a positive integer")
        MAX_NUM = 2 ** (bits - 1)
        if number > MAX_NUM - 1 or number < -MAX_NUM:
            raise ValueError(f"the number {number} cannot be both signed and contained in {bits} bits")
        if number >= 0:
            return format(number, f'0{bits}b')
        number_as_binary = format(number + (MAX_NUM * 2), f'0{bits}b')
        return number_as_binary

    @staticmethod
    def is_binary(string, bits: int = 0) -> (bool, str):
        if bits == 0 or len(string.lstrip("0")) > bits:
            raise ValueError(f"the number {string} does not fit in {bits} bits")
        return all([character in ["0", "1"] for character in string.lstrip("0").rjust(8, "0")]), string.lstrip("0").rjust(8, "0")


REGISTERS = {f"r{i}": BIN.int_to_unsigned(3, i) for i in range(8)}
CONDITIONS = {"novf": "000", "ovf": "001", "nc": "010", "c": "011", "nmsb": "100", "msb": "101", "nz": "110",
              "z": "111",
              "!overflow": "000", "overflow": "001", "!carry": "010", "carry": "011", "!msb": "100", "!zero": "110",
              "zero": "111",
              "!=": "110", "=": "111", "<": "010", ">=": "011", ">=0": "100", "<0": "101",
              "!ovf": "000", "!c": "010", "!z": "110", "eq": "111", "neq": "110"}
LABELS = {}
DEFINITIONS = {}


class PARAMETERS:
    @staticmethod
    def parse_literal(value: str, bits: int, line: int, instruction: str, param_type: str) -> str:
        if value.startswith("0b"):
            try:
                if not (redid_value := BIN.is_binary(value[2:], bits))[0]:
                    exit(f"Error: non binary value given in a binary {param_type} literal on line {line} for instruction {instruction}, a binary number can only have 0s and 1s")
                return redid_value[1]
            except ValueError as exception:
                exit(f"Error: invalid binary {param_type} literal on line {line} for instruction {instruction}, error: \n{repr(exception)}")

        # if value is in hex form
        if value.startswith("0x"):
            hex_digits = ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f')

            # if any digit in the number is not a hex digit
            if any([digit.lower() not in hex_digits for digit in value[2:]]):
                exit(f"Error: non hexadecimal digit in a hexadecimal {param_type} literal on line {line} for instruction {instruction}, a hex number can only have: \n{hex_digits}")

            return BIN.int_to_unsigned(bits, int(value[2:], 16))

        # differentiate between positive and negative decimal numbers
        if value.startswith("-"):
            if not value[1:].isdigit():
                exit(f"Error: non decimal digit in a decimal {param_type} literal on line {line} for instruction {instruction}")
            conversion_function = BIN.int_to_signed
        else:
            if not value.isdigit():
                exit(f"Error: non decimal digit in a decimal {param_type} literal on line {line} for instruction {instruction}")
            conversion_function = BIN.int_to_unsigned

        try:
            return conversion_function(bits, int(value))
        except ValueError as exception:
            exit(f"Error: invalid decimal {param_type} literal on line {line} for instruction {instruction}, error: \n{repr(exception)}")

    @staticmethod
    def Register(value: str, line: int, instruction: str) -> str:
        if value in DEFINITIONS:
            if DEFINITIONS[value] in REGISTERS:
                return REGISTERS[DEFINITIONS[value]]
            return PARAMETERS.parse_literal(DEFINITIONS[value], 3, line, instruction, "register")
        elif value in REGISTERS:
            return REGISTERS[value]
        exit(f"Error: invalid register on line {line} for instruction {instruction}, possible registers are: \n{REGISTERS.keys()}")

    @staticmethod
    def Condition(value: str, line: int, instruction: str) -> str:
        if value in DEFINITIONS:
            if DEFINITIONS[value] in CONDITIONS:
                return CONDITIONS[DEFINITIONS[value]]
            return PARAMETERS.parse_literal(DEFINITIONS[value], 3, line, instruction, "condition")
        elif value in CONDITIONS:
            return CONDITIONS[value]
        exit(f"Error: invalid condition on line {line} for instruction {instruction}, possible conditions are: \n{CONDITIONS.keys()}")

    @staticmethod
    def Single(value: str, line: int, instruction: str) -> str:
        if not BIN.is_binary(value, 1)[0]:
            exit(f"Error: invalid single on line {line} for instruction {instruction}, a single is either a 0 or a 1")
        return value

    @staticmethod
    def Label(value: str, line: int, instruction: str) -> str:
        if value not in LABELS:
            exit(f"Error: invalid label on line {line} for instruction {instruction}")
        return LABELS[value][0]

    @staticmethod
    def Immediate(value: str, bits: int, line: int, instruction: str) -> str:
        if value in DEFINITIONS:
            value = DEFINITIONS[value]

        return PARAMETERS.parse_literal(value, bits, line, instruction, "immediate")


INSTRUCTIONS = {"add": ((3, 4),
                        ("00000", PARAMETERS.Register, PARAMETERS.Register, "00", PARAMETERS.Register),
                        ("00000", PARAMETERS.Register, PARAMETERS.Register, PARAMETERS.Single, "0", PARAMETERS.Register)),
                "sub": ((3, 4),
                        ("00001", PARAMETERS.Register, PARAMETERS.Register, "00", PARAMETERS.Register),
                        ("00001", PARAMETERS.Register, PARAMETERS.Register, PARAMETERS.Single, "0", PARAMETERS.Register)),
                "and": ((3,),
                        ("00010", PARAMETERS.Register, PARAMETERS.Register, "00", PARAMETERS.Register)),
                "or": ((3,),
                       ("00011", PARAMETERS.Register, PARAMETERS.Register, "00", PARAMETERS.Register)),
                "xor": ((3,),
                        ("00100", PARAMETERS.Register, PARAMETERS.Register, "00", PARAMETERS.Register)),
                "bsh": ((4, 5),
                        (
                        "00101", PARAMETERS.Register, PARAMETERS.Register, PARAMETERS.Single, "0", PARAMETERS.Register),
                        ("00101", PARAMETERS.Register, PARAMETERS.Register, PARAMETERS.Single, PARAMETERS.Single,
                         PARAMETERS.Register)),
                "mld": ((2, 3),
                        ("00110", PARAMETERS.Register, "00000", PARAMETERS.Register),
                        ("00110", PARAMETERS.Register,
                         lambda value, line, instruction: PARAMETERS.Immediate(value, 5, line, instruction),
                         PARAMETERS.Register)),
                "mst": ((2, 3),
                        ("00111", PARAMETERS.Register, PARAMETERS.Register, "00000"),
                        ("00111", PARAMETERS.Register, PARAMETERS.Register,
                         lambda value, line, instruction: PARAMETERS.Immediate(value, 5, line, instruction))),
                "jmp": ((1,),
                        ("0100", PARAMETERS.Label)),
                "cal": ((1,),
                        ("0101", PARAMETERS.Label)),
                "ret": ((0,),
                        ("0110000000000000",)),
                "rdp": ((0, 1),
                        ("0110100000000000",),
                        ("011010000000000", PARAMETERS.Single)),
                "prd": ((1, 2),
                        ("01110", PARAMETERS.Condition, "00000000"),
                        ("01110", PARAMETERS.Condition, "0000000", PARAMETERS.Single)),
                "hlt": ((0,),
                        ("0111100000000000",)),
                "bsi": ((3, 4),
                        ("10000", PARAMETERS.Register, "000", PARAMETERS.Single, "0", lambda value, line, instruction: PARAMETERS.Immediate(value, 3, line, instruction)),
                        ("10000", PARAMETERS.Register, "000", PARAMETERS.Single, PARAMETERS.Single, lambda value, line, instruction: PARAMETERS.Immediate(value, 3, line, instruction))),
                "ani": ((2,),
                        ("10001", PARAMETERS.Register, lambda value, line, instruction: PARAMETERS.Immediate(value, 8, line, instruction))),
                "ori": ((2,),
                        ("10010", PARAMETERS.Register, lambda value, line, instruction: PARAMETERS.Immediate(value, 8, line, instruction))),
                "xri": ((2,),
                        ("10011", PARAMETERS.Register, lambda value, line, instruction: PARAMETERS.Immediate(value, 8, line, instruction))),
                "tst": ((2,),
                        ("10100", PARAMETERS.Register, lambda value, line, instruction: PARAMETERS.Immediate(value, 8, line, instruction))),
                "adi": ((2,),
                        ("10101", PARAMETERS.Register, lambda value, line, instruction: PARAMETERS.Immediate(value, 8, line, instruction))),
                "ldi": ((2,),
                        ("10110", PARAMETERS.Register, lambda value, line, instruction: PARAMETERS.Immediate(value, 8, line, instruction))),
                "pst": ((2,),
                        ("10111", PARAMETERS.Register, "000", lambda value, line, instruction: PARAMETERS.Immediate(value, 5, line, instruction))),
                "pld": ((2,),
                        ("11000", PARAMETERS.Register, "000", lambda value, line, instruction: PARAMETERS.Immediate(value, 5, line, instruction)))
                }


def parse_for_comments(line: str) -> (str, str):
    if '//' in line:
        line = line.split('//')
        comment = "//" + line[1]
        return line[0].strip(), comment
    if '#' in line:
        line = line.split('#')
        comment = "#" + line[1]
        return line[0].strip(), comment
    if ';' in line:
        line = line.split(';')
        comment = ";" + line[1]
        return line[0].strip(), comment
    return line, ""


def pre_parse_program(input_file) -> list:
    # total amount of pages
    available_pages = [page for page in range(128)]
    true_index = 0
    for index, line in enumerate(input_file):
        # this will just remove \n at the end and any trailing spaces
        line = line.strip().lower()

        # parse the line for comments
        line, comment = parse_for_comments(line)

        # if the line is empty or is just a comment
        if not line:
            continue

        if line.startswith("define"):
            if len(value := line.split(" ")) != 3:
                exit(f"Error: invalid define declaration on line {index}")
            DEFINITIONS[value[1]] = value[2]
            # if value[2].startswith("0b"):
            #     if not BIN.is_binary(value[2][2:], len(value[2][2:]))[0]:
            #         exit(f"Error: binary definition constant has non binary characters on line {index}, a binary number can only have 0s and 1s")
            #     DEFINITIONS[value[1]] = str(int(value[2][2:], 2))
            #     continue
            # if value[2].startswith("0x"):
            #     hex_digits = ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f')
            #     # if any digit in the number is not a hex digit
            #     if any([digit.lower() not in hex_digits for digit in value[2][2:]]):
            #         exit(f"Error: hex definition constant has non hex characters on line {index}, a hex number can only have: \n{hex_digits}")
            #     DEFINITIONS[value[1]] = str(int(value[2][2:], 16))
            #     continue
            # if value[2].startswith("-"):
            #     if value[2][1:].isdigit():
            #         DEFINITIONS[value[1]] = value[2]
            #         continue
            # elif value[2].isdigit():
            #     DEFINITIONS[value[1]] = value[2]
            #     continue
            # exit(f"Error: decimal definition constant has a non decimal character on line {index}")

        # if line is a page declaration
        if line.startswith(">"):
            if not line[1:].isdigit():
                exit(f"Error: page declaration with a non decimal page number on line {index}")
            available_pages.remove(int(line[1:]))
            # 32 instructions per page
            true_index = int(line[1:]) * 32
            continue

        # if there is a label
        if line.startswith("."):
            if line in LABELS:
                exit(f"Error: duplicate label declared on lines {LABELS[line][1]} and {index}")
            else:
                LABELS[line] = (BIN.int_to_unsigned(12, true_index), index)
                continue

        true_index += 1
    input_file.seek(0)
    return available_pages


def main():
    # Check if the correct number of arguments is provided
    if len(sys.argv) != 2:
        exit("Usage: python Assembler.py <programFile>")  # Exit the program with an error code

    input_file = sys.argv[1]  # The first argument after the script name

    # Now you can open and process the file
    try:
        with open(input_file, 'r') as program_file:
            dir_path = os.path.dirname(os.path.realpath(__file__))
            with open(os.path.join(dir_path, "assemblyFile.txt"), 'w') as assembly_file:
                available_pages = pre_parse_program(program_file)
                in_page_index = 0
                true_index = 0
                index = 0
                offset = 0
                line = program_file.readline().strip()
                while line.startswith("//") or line.startswith(";") or line.startswith("#") or line.startswith("define") or line.startswith("."):
                    index = program_file.tell()
                    offset += 1
                    line = program_file.readline().strip()
                if not line.startswith(">"):
                    assembly_file.write(f">{available_pages.pop(0)}\n")
                program_file.seek(index)
                for index, line in enumerate(program_file):
                    line = line.strip()
                    # parse for comments:
                    line, _ = parse_for_comments(line)

                    if not line:
                        # assembly_file.write(comment + '\n')
                        continue

                    if line.startswith(".") or line.startswith('define'):
                        continue

                    if line.startswith('>'):
                        assembly_file.write(line)
                        # if comment:
                        #     assembly_file.write(" " + comment)
                        assembly_file.write('\n')
                        in_page_index = 0
                        continue

                    line = line.split()

                    instruction, parameters = line[0], line[1:]

                    # if there is an unrecognized instruction
                    if instruction not in INSTRUCTIONS:
                        exit(f"Error: invalid instruction {instruction} on line {index + offset}")

                    instruction_information = INSTRUCTIONS[instruction]
                    possible_parameter_counts, assembled_parameters = instruction_information[
                        0], instruction_information[1:]

                    # if we're over the limit for the in page index
                    if in_page_index == 32:
                        if not available_pages:
                            exit(f"Error: with currently declared pages and automated pages the program cannot fit.\nplease restructure the program so that instructions after line {index} fit into a page")
                        assembly_file.write(f'>{available_pages.pop(0)}\n')
                        in_page_index = 0
                        continue

                    if len(parameters) not in possible_parameter_counts:
                        exit(f"Error: incorrect number of parameters on line {index + offset} for instruction {instruction}")

                    current_parameter_index = 0
                    for assembled_parameter in assembled_parameters[possible_parameter_counts.index(len(parameters))]:
                        if callable(assembled_parameter):
                            assembly_file.write(assembled_parameter(parameters[current_parameter_index].lower(), index + offset, instruction))
                            current_parameter_index += 1
                        else:
                            assembly_file.write(assembled_parameter)
                    # if comment:
                    #     assembly_file.write(" " + comment)
                    assembly_file.write('\n')
                    true_index += 1
                    in_page_index += 1
                for remaining_page in available_pages:
                    assembly_file.write(f">{remaining_page}\n")
                assembly_file.write(f"-")
    except FileNotFoundError:
        exit(f"Error: File '{input_file}' not found")
    # print(f"Assembling file: {input_file}")


if __name__ == "__main__":
    main()
