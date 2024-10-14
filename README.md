# Incel 3 Godot Emulator

![Godot 4.3](https://img.shields.io/badge/Godot-4.3-blue?logo=godot-engine&logoColor=white)
![Python 3.12.6](https://img.shields.io/badge/Python-3.12.6-blue?logo=python&logoColor=white)

Welcome to the **Incel 3 Godot Emulator**! This is a Godot application designed for emulating the **Incel 3 CPU**. It comes packed with several powerful features to help you develop, debug, and emulate assembly programs on the Incel 3 architecture.

## Features

- **Built-in IDE**: The emulator includes a full-featured IDE with syntax highlighting and error reporting.
- **ROM Schematic Generator**: Automatically generate ROM schematics from your programs.
- **Program Emulation**: Emulate your Incel 3 CPU programs with:
  - **register and memory viewer** to see values in real-time.
  - **resizable display screen**.
  - **Customizable input controls**, allowing you to set custom keyboard inputs.

## Getting Started

### Requirement

Before using the Emulator make sure you have:
- #### Python version
```
Python 3.12.6
```
- #### Libraries
```
mcschematic 11.4.2
```
If you're attempting to edit this in Godot, make sure the godot version is 4.3

### Download

To get started, grab the latest release of the emulator from the [Releases Page](https://github.com/E1thanz/Incel-3-Emulator/releases). <!-- Replace with the actual link to the latest release -->

### Installation

1. Download the latest release as mentioned above.
2. Extract the files and open the executable.

## Example Code

Here's a simple example program with all the features in the IDE for the Incel 3 CPU:
<img src="https://github.com/user-attachments/assets/b4beb56c-b202-41c6-bcef-c181f1977fc2" alt="image" width="400"/>

As shown, the editor allows you to define literals, built-in registers, and conditions,
You can also manually define memory pages to align loops for cache optimization. 
The editor supports all standard features expected of a code editor, such as writing instructions, 
adding comments, and more. 
Additionally, it provides error highlighting, which alerts you if a line is incorrectly formatted or contains an issue.
