extends Control

const Character = preload("res://scripts/character.gd")
const Club = preload("res://scripts/club.gd")

var character: Character
var available_points: int = Character.POINT_BUY_TOTAL

# UI References (will be set up in scene)
@onready var name_input = $MarginContainer/VBoxContainer/NameSection/NameInput
@onready var class_option = $MarginContainer/VBoxContainer/ClassSection/ClassOption
@onready var points_remaining_label = $MarginContainer/VBoxContainer/PointsRemaining

# Ability score spinners
@onready var str_spinner = $MarginContainer/VBoxContainer/AbilitiesGrid/StrSpinner
@onready var dex_spinner = $MarginContainer/VBoxContainer/AbilitiesGrid/DexSpinner
@onready var con_spinner = $MarginContainer/VBoxContainer/AbilitiesGrid/ConSpinner
@onready var int_spinner = $MarginContainer/VBoxContainer/AbilitiesGrid/IntSpinner
@onready var wis_spinner = $MarginContainer/VBoxContainer/AbilitiesGrid/WisSpinner
@onready var cha_spinner = $MarginContainer/VBoxContainer/AbilitiesGrid/ChaSpinner

# Stat effect labels
@onready var str_effect_label = $MarginContainer/VBoxContainer/AbilitiesGrid/StrEffect
@onready var dex_effect_label = $MarginContainer/VBoxContainer/AbilitiesGrid/DexEffect
@onready var con_effect_label = $MarginContainer/VBoxContainer/AbilitiesGrid/ConEffect
@onready var int_effect_label = $MarginContainer/VBoxContainer/AbilitiesGrid/IntEffect
@onready var wis_effect_label = $MarginContainer/VBoxContainer/AbilitiesGrid/WisEffect
@onready var cha_effect_label = $MarginContainer/VBoxContainer/AbilitiesGrid/ChaEffect

@onready var start_button = $MarginContainer/VBoxContainer/ButtonSection/StartButton
@onready var back_button = $MarginContainer/VBoxContainer/ButtonSection/BackButton

func _ready():
	character = Character.new()
	_setup_class_options()
	_setup_ability_spinners()
	_apply_class_preset("Ranger") # Default class
	_update_display()

func _setup_class_options():
	class_option.clear()
	class_option.add_item("Warrior - High STR/CON, moderate accuracy")
	class_option.add_item("Ranger - Balanced distance and accuracy")
	class_option.add_item("Mage - High INT/WIS, previews shots")
	class_option.add_item("Rogue - High DEX/CHA, very accurate")
	class_option.select(1) # Ranger default
	class_option.item_selected.connect(_on_class_selected)

func _setup_ability_spinners():
	for spinner in [str_spinner, dex_spinner, con_spinner, int_spinner, wis_spinner, cha_spinner]:
		spinner.min_value = Character.MIN_ABILITY
		spinner.max_value = Character.MAX_ABILITY
		spinner.step = 1
		spinner.value_changed.connect(_on_ability_changed)

func _on_class_selected(index: int):
	var class_name = ["Warrior", "Ranger", "Mage", "Rogue"][index]
	_apply_class_preset(class_name)

func _apply_class_preset(class_name: String):
	character.character_class = class_name
	character.apply_class_defaults()

	# Update spinners without triggering signals
	str_spinner.set_value_no_signal(character.strength)
	dex_spinner.set_value_no_signal(character.dexterity)
	con_spinner.set_value_no_signal(character.constitution)
	int_spinner.set_value_no_signal(character.intelligence)
	wis_spinner.set_value_no_signal(character.wisdom)
	cha_spinner.set_value_no_signal(character.charisma)

	_update_display()

func _on_ability_changed(_value):
	character.strength = int(str_spinner.value)
	character.dexterity = int(dex_spinner.value)
	character.constitution = int(con_spinner.value)
	character.intelligence = int(int_spinner.value)
	character.wisdom = int(wis_spinner.value)
	character.charisma = int(cha_spinner.value)

	_update_display()

func _update_display():
	# Calculate points spent
	var points_spent = 0
	for score in [character.strength, character.dexterity, character.constitution,
				  character.intelligence, character.wisdom, character.charisma]:
		points_spent += Character.get_point_cost(score)

	available_points = Character.POINT_BUY_TOTAL - points_spent
	points_remaining_label.text = "Points Remaining: %d / %d" % [available_points, Character.POINT_BUY_TOTAL]

	# Update effect labels with actual gameplay impact
	str_effect_label.text = "+%d max distance" % character.get_distance_bonus()
	dex_effect_label.text = "-%d deviation" % character.get_accuracy_bonus()
	con_effect_label.text = "+%d hand size" % character.get_hand_size_bonus()
	int_effect_label.text = "Preview: %s" % ("Yes" if character.can_preview_shots() else "No")
	wis_effect_label.text = "-%d terrain penalty" % character.get_terrain_penalty_reduction()
	cha_effect_label.text = "+%d%% rare clubs" % int(character.get_rare_club_chance() * 100)

	# Enable start button only if point buy is valid
	start_button.disabled = not character.is_valid_point_buy()

	# Color the points label
	if available_points < 0:
		points_remaining_label.add_theme_color_override("font_color", Color.RED)
	elif available_points > 0:
		points_remaining_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		points_remaining_label.add_theme_color_override("font_color", Color.GREEN)

func _on_start_button_pressed():
	if not character.is_valid_point_buy():
		return

	# Set character name
	character.character_name = name_input.text if name_input.text != "" else "Adventurer"

	# Generate clubs based on character stats
	var player_clubs = _generate_character_clubs()

	# Load game screen
	var game_screen_scene = load("res://game_screen.tscn")
	var game_screen_instance = game_screen_scene.instantiate()
	game_screen_instance.set_player_clubs(player_clubs)
	game_screen_instance.set_character(character) # Pass character to game
	get_tree().root.add_child(game_screen_instance)
	get_tree().current_scene.queue_free()

func _on_back_button_pressed():
	var title_screen_scene = load("res://title_screen.tscn")
	var title_screen_instance = title_screen_scene.instantiate()
	get_tree().root.add_child(title_screen_instance)
	get_tree().current_scene.queue_free()

func _generate_character_clubs() -> Array:
	var available_clubs = [
		# [Name, Emoji, Base Distance, Base Accuracy]
		["Driver", "🏌️‍♂️", 5, {1: [0], 2: [0, -1, 1], 3: [0, -1, 1], 4: [0, -2, -1, 0, 1, 2], 5: [0, -3, -2, -1, 0, 1, 2, 3]}],
		["3-Wood", "⛳", 4, {1: [0], 2: [0], 3: [0, -1, 1], 4: [0, -2, -1, 0, 1, 2]}],
		["5-Wood", "⛳", 4, {1: [0], 2: [0, -1, 1], 3: [0, -1, 1], 4: [0, -2, -1, 1, 2]}],
		["4-Iron", "⛳", 4, {1: [0], 2: [0], 3: [0, -1, 1], 4: [0, -2, -1, 0, 1, 2]}],
		["5-Iron", "⛳", 4, {1: [0], 2: [0, -1, 1], 3: [0, -1, 1], 4: [0, -1, 1]}],
		["6-Iron", "⛳", 3, {1: [0], 2: [0], 3: [0, -1, 1]}],
		["7-Iron", "⛳", 3, {1: [0], 2: [0], 3: [0, -1, 1]}],
		["Wedge", "🏌️‍♀️", 2, {1: [0], 2: [0, -1, 1]}],
		["Putter", "⛳", 1, {1: [0]}],
	]

	var player_clubs = []
	var base_hand_size = 10 + character.get_hand_size_bonus()
	var rare_chance = character.get_rare_club_chance()

	for i in range(base_hand_size):
		var club_data = available_clubs[randi() % available_clubs.size()].duplicate(true)

		# Apply STR bonus to distance
		var distance_bonus = character.get_distance_bonus()
		club_data[2] += distance_bonus

		# Apply DEX bonus to accuracy (reduce deviation)
		var accuracy_bonus = character.get_accuracy_bonus()
		if accuracy_bonus > 0:
			var improved_accuracy = {}
			for dist in club_data[3].keys():
				var deviations = club_data[3][dist].duplicate()
				# Reduce deviation array size based on DEX
				var new_deviations = []
				for dev in deviations:
					if abs(dev) <= (3 - accuracy_bonus): # Cap maximum deviation
						new_deviations.append(dev)
				if new_deviations.is_empty():
					new_deviations = [0]
				improved_accuracy[dist] = new_deviations
			club_data[3] = improved_accuracy

		# Charisma: chance to upgrade club quality (better accuracy)
		if randf() < rare_chance:
			club_data[1] = "✨" # Rare club emoji
			# Rare clubs have perfect accuracy
			for dist in club_data[3].keys():
				club_data[3][dist] = [0]

		var new_club = Club.new(club_data[0], club_data[1], club_data[2], club_data[3])
		player_clubs.append(new_club)

	return player_clubs
