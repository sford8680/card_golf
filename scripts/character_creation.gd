extends Control

const Character = preload("res://scripts/character.gd")
const Club = preload("res://scripts/club.gd")
const GameScreenScene = preload("res://game_screen.tscn")
const TitleScreenScene = preload("res://title_screen.tscn")

var character: Character

# UI References - simplified sliders
@onready var power_slider = $CenterContainer/VBoxContainer/StatsSection/PowerSlider
@onready var accuracy_slider = $CenterContainer/VBoxContainer/StatsSection/AccuracySlider
@onready var stamina_slider = $CenterContainer/VBoxContainer/StatsSection/StaminaSlider
@onready var luck_slider = $CenterContainer/VBoxContainer/StatsSection/LuckSlider

@onready var power_label = $CenterContainer/VBoxContainer/StatsSection/PowerValue
@onready var accuracy_label = $CenterContainer/VBoxContainer/StatsSection/AccuracyValue
@onready var stamina_label = $CenterContainer/VBoxContainer/StatsSection/StaminaValue
@onready var luck_label = $CenterContainer/VBoxContainer/StatsSection/LuckValue

@onready var start_button = $CenterContainer/VBoxContainer/ButtonSection/StartButton
@onready var back_button = $CenterContainer/VBoxContainer/ButtonSection/BackButton

func _ready() -> void:
  character = Character.new()

  # Setup sliders
  for slider in [power_slider, accuracy_slider, stamina_slider, luck_slider]:
    slider.min_value = 8
    slider.max_value = 15
    slider.step = 1
    slider.value = 10
    slider.value_changed.connect(_on_slider_changed)

  _update_display()

func _on_slider_changed(_value: float) -> void:
  # Map sliders to character stats
  character.strength = int(power_slider.value)
  character.dexterity = int(accuracy_slider.value)
  character.constitution = int(stamina_slider.value)
  character.charisma = int(luck_slider.value)

  # Set wisdom and intelligence to average
  character.wisdom = 10
  character.intelligence = 10

  _update_display()

func _update_display() -> void:
  # Update value labels
  power_label.text = str(int(power_slider.value))
  accuracy_label.text = str(int(accuracy_slider.value))
  stamina_label.text = str(int(stamina_slider.value))
  luck_label.text = str(int(luck_slider.value))

func _on_start_button_pressed() -> void:
  character.character_name = "Golfer"

  # Generate clubs based on character stats
  var player_clubs = _generate_character_clubs()

  # Load game screen
  var game_screen_instance = GameScreenScene.instantiate()
  game_screen_instance.set_player_clubs(player_clubs)
  game_screen_instance.set_character(character) # Pass character to game
  get_tree().root.add_child(game_screen_instance)
  get_tree().current_scene = game_screen_instance
  queue_free()

func _on_back_button_pressed() -> void:
  var title_screen_instance = TitleScreenScene.instantiate()
  get_tree().root.add_child(title_screen_instance)
  get_tree().current_scene = title_screen_instance
  queue_free()

func _generate_character_clubs() -> Array[Club]:
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

  var player_clubs: Array[Club] = []
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
