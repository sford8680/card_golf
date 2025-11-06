class_name Square extends RefCounted

enum TerrainType { FAIRWAY, ROUGH, GREEN, SAND, TREE, TEEBOX }

var x: int
var y: int
var terrain_type: TerrainType

func _init(x_val: int, y_val: int, type_val: TerrainType):
	x = x_val
	y = y_val
	terrain_type = type_val

func _to_string():
	return "Square(x:%d, y:%d, type:%s)" % [x, y, TerrainType.keys()[terrain_type]]
