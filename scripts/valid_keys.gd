extends Node

var VALID_KEYS = []
var KEY_NAMES = "abcdefghijklmnopqrstuvwxyz".split()

func _ready() -> void:
	for key in range(KEY_A, KEY_Z + 1):
		VALID_KEYS.append(key)
