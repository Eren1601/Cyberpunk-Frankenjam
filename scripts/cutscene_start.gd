extends Node2D

@export var anim : AnimatedSprite2D
@export var canvas: CanvasLayer
@export var world_scene: PackedScene

var can_pass = false

func _ready() -> void:
	anim.play()

func _on_animated_sprite_2d_animation_finished() -> void:
	pass # Replace with function body.

func _on_animated_sprite_2d_animation_looped() -> void:
	show_text()

func show_text():
	canvas.visible = true
	can_pass = true
	
func _process(delta: float) -> void:
	if can_pass and Input.is_anything_pressed():
		# go to world scene
		var err := get_tree().change_scene_to_packed(world_scene)
		if err != OK:
			push_error("Szene konnte nicht gewechselt werden: %s" % [err])
