import mcschematic
import sys


def main():
    # Check if the correct number of arguments is provided
    if len(sys.argv) != 3:
        exit("Usage: python Assembler.py <assemblyFile>")  # Exit the program with an error code

    input_file = sys.argv[1]  # The first argument after the script name

    output_file = sys.argv[2]
    output_file = output_file.split("/")[-1]
    output_path = sys.argv[2].removesuffix("/" + output_file)
    output_file = output_file.removesuffix(".schem")

    schem = mcschematic.MCSchematic()
    # Now you can open and process the file
    try:
        with open(input_file, 'r') as assembly_file:
            lines = assembly_file.readlines()
            index = -1
            while index < len(lines):
                line = lines[index].strip()
                if line.startswith("//") or line.startswith("#") or line.startswith(";"):
                    index += 1
                    continue
                if line.startswith(">"):
                    page_number = int(line[1:])
                    page = ["0000000000000000" for _ in range(32)]
                    in_page_index = 0
                    index += 1
                    line = lines[index].strip()
                    while not line.startswith(">") and not line == "-":
                        if line.startswith("//") or line.startswith("#") or line.startswith(";"):
                            index += 1
                            line = lines[index].strip()
                            continue
                        if "//" in line:
                            line = line.split(" //")[0]
                        elif "#" in line:
                            line = line.split(" #")[0]
                        elif ";" in line:
                            line = line.split(" ;")[0]
                        page[in_page_index] = line
                        in_page_index += 1
                        index += 1
                        line = lines[index].strip()

                    x = 0 if page_number % 2 == 0 else -32
                    z = 2 * (page_number // 2)

                    for i in range(16):
                        compacted = [page[i+16][8:], page[i+16][:8], page[i][8:], page[i][:8]]
                        barrel_values = ["".join([compacted[j][i] for j in range(4)]) for i in range(8)]
                        for y in range(8):
                            schem.setBlock((x - 2*i, -y*2 - 1, z), "minecraft:magenta_concrete" if int(barrel_values[y], 2) == 0 else mcschematic.BlockDataDB.BARREL.fromSS(int(barrel_values[y], 2)))
                    continue
                index += 1
    except FileNotFoundError:
        exit(f"Error: file '{input_file}' not found")

    schem.save(output_path, output_file, mcschematic.Version.JE_1_20_PRE_RELEASE_4)


if __name__ == "__main__":
    main()
