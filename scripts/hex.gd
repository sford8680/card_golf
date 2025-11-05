class_name Hex extends RefCounted

enum TerrainType { FAIRWAY, ROUGH, GREEN }

var q: int # Axial coordinate q
var r: int # Axial coordinate r
var terrain_type: TerrainType

func _init(q_val: int, r_val: int, type_val: TerrainType):
	q = q_val
	r = r_val
	terrain_type = type_val

func _to_string():
	return "Hex(q:%d, r:%d, type:%s)" % [q, r, TerrainType.keys()[terrain_type]]
