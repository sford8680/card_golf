class_name Character extends RefCounted

# D&D-style ability scores (3-18 range, 10 is average)
var strength: int = 10      # Affects max distance of all clubs
var dexterity: int = 10     # Reduces accuracy deviation
var constitution: int = 10  # Increases starting hand size
var intelligence: int = 10  # Reveals power shot outcomes before hitting
var wisdom: int = 10        # Reduces terrain penalties
var charisma: int = 10      # Improves club rarity/quality

# Character identity
var character_name: String = "Golfer"
var character_class: String = "Ranger" # Ranger, Warrior, Mage, Rogue

# Point buy system - players get 27 points to distribute
const POINT_BUY_TOTAL = 27
const MIN_ABILITY = 8
const MAX_ABILITY = 15

func _init(name: String = "Golfer", char_class: String = "Ranger"):
	character_name = name
	character_class = char_class

# Calculate ability modifier using D&D rules: (score - 10) / 2
func get_ability_modifier(score: int) -> int:
	return (score - 10) / 2

# Distance bonus from Strength: +1 distance per +2 modifier
func get_distance_bonus() -> int:
	var modifier = get_ability_modifier(strength)
	return max(0, modifier / 2)

# Accuracy bonus from Dexterity: reduces deviation by modifier amount
func get_accuracy_bonus() -> int:
	return max(0, get_ability_modifier(dexterity))

# Hand size from Constitution: +1 club per +3 modifier
func get_hand_size_bonus() -> int:
	var modifier = get_ability_modifier(constitution)
	return max(0, modifier / 3)

# Reveals outcomes from Intelligence: show exact landing spots if INT >= 12
func can_preview_shots() -> bool:
	return intelligence >= 12

# Terrain penalty reduction from Wisdom: -1 penalty per +2 modifier
func get_terrain_penalty_reduction() -> int:
	var modifier = get_ability_modifier(wisdom)
	return max(0, modifier / 2)

# Club quality from Charisma: affects rare club chance
func get_rare_club_chance() -> float:
	var modifier = get_ability_modifier(charisma)
	return 0.1 + (modifier * 0.05) # 10% base + 5% per modifier

# Get ability point cost (for point buy system)
static func get_point_cost(score: int) -> int:
	match score:
		8: return 0
		9: return 1
		10: return 2
		11: return 3
		12: return 4
		13: return 5
		14: return 7
		15: return 9
		_: return 0

# Validate that point buy is legal
func is_valid_point_buy() -> bool:
	var total_cost = 0
	for score in [strength, dexterity, constitution, intelligence, wisdom, charisma]:
		if score < MIN_ABILITY or score > MAX_ABILITY:
			return false
		total_cost += get_point_cost(score)
	return total_cost == POINT_BUY_TOTAL

# Get character summary for display
func get_summary() -> String:
	return "%s the %s\nSTR:%d DEX:%d CON:%d INT:%d WIS:%d CHA:%d" % [
		character_name, character_class,
		strength, dexterity, constitution, intelligence, wisdom, charisma
	]

# Class-based starting arrays (following D&D standard array pattern)
static func get_class_default_stats(char_class: String) -> Dictionary:
	match char_class:
		"Warrior": # Strong, tough, less accurate
			return {"str": 15, "dex": 10, "con": 14, "int": 8, "wis": 12, "cha": 9}
		"Ranger": # Balanced distance and accuracy
			return {"str": 12, "dex": 15, "con": 10, "int": 10, "wis": 14, "cha": 8}
		"Mage": # Intelligent, previews shots, fragile
			return {"str": 8, "dex": 12, "con": 9, "int": 15, "wis": 14, "cha": 10}
		"Rogue": # Highly accurate, lucky, low distance
			return {"str": 9, "dex": 15, "con": 10, "int": 12, "wis": 8, "cha": 14}
		_:
			return {"str": 10, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 10}

func apply_class_defaults():
	var stats = get_class_default_stats(character_class)
	strength = stats["str"]
	dexterity = stats["dex"]
	constitution = stats["con"]
	intelligence = stats["int"]
	wisdom = stats["wis"]
	charisma = stats["cha"]
