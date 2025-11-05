extends Control

const Club = preload("res://scripts/club.gd")

func _on_quit_button_pressed():
	get_tree().quit()

func _on_start_button_pressed():
	var available_clubs = [
		# Name, Emoji, Max Distance, Accuracy (distance: [possible_deviations])
		["Driver", "🏌️‍♂️", 5, {1: [0], 2: [0, -1, 1], 3: [0, -1, 1], 4: [0, -2, -1, 0, 1, 2], 5: [0, -3, -2, -1, 0, 1, 2, 3]}],
		["Iron 7", "⛳", 3, {1: [0], 2: [0], 3: [0, -1, 1]}],
		["Putter", "⛳", 1, {1: [0]}],
		["Wedge", "🏌️‍♀️", 2, {1: [0], 2: [0, -1, 1]}],
		["Wood 3", "🌳", 4, {1: [0], 2: [0], 3: [0, -1, 1], 4: [0, -2, -1, 0, 1, 2]}],
	]

	var player_clubs = []
	for i in range(10):
		var club_data = available_clubs[randi() % available_clubs.size()]
		var new_club = Club.new(club_data[0], club_data[1], club_data[2], club_data[3])
		player_clubs.append(new_club)

	var game_screen_scene = load("res://game_screen.tscn")
	var game_screen_instance = game_screen_scene.instantiate()
	game_screen_instance.set_player_clubs(player_clubs)
	get_tree().root.add_child(game_screen_instance)
	get_tree().current_scene.queue_free()
