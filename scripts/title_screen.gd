extends Control

func _on_quit_button_pressed():
	get_tree().quit()

func _on_start_button_pressed():
	# Load character creation screen instead of going directly to game
	var char_creation_scene = load("res://character_creation.tscn")
	var char_creation_instance = char_creation_scene.instantiate()
	get_tree().root.add_child(char_creation_instance)
	get_tree().current_scene.queue_free()
