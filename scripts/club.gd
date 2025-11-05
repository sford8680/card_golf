class_name Club extends RefCounted

var max_distance: int
var accuracy: Dictionary
var name: String
var emoji: String

func _init(name_val: String, emoji_val: String, distance: int, acc: Dictionary):
	name = name_val
	emoji = emoji_val
	max_distance = distance
	accuracy = acc
