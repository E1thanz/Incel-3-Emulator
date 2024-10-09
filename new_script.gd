@tool
extends Node

func _process(delta: float) -> void:
	var pythonPath = "python"
	var pythonOut = []
	OS.execute(pythonPath, [".\\PythonFiles\\test.py"], pythonOut, true)
	print(pythonOut)
