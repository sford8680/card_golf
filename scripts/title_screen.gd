extends Control

const CharacterCreationScene = preload("res://character_creation.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_start_button_pressed() -> void:
	# Load character creation screen instead of going directly to game
	var char_creation_instance = CharacterCreationScene.instantiate()
	get_tree().root.add_child(char_creation_instance)
	get_tree().current_scene = char_creation_instance
	queue_free()
