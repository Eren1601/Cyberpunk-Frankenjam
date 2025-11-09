extends Control

@onready var play_button: Button = $CenterContainer/VBoxContainer/Play
@onready var quit_button: Button = $CenterContainer/VBoxContainer/Quit
@onready var suprise_button: Button = $"CenterContainer/VBoxContainer/?"
func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	suprise_button.pressed.connect(_on_suprised_pressed)
	

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/cutscene_start.tscn")

func _on_suprised_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/job.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
