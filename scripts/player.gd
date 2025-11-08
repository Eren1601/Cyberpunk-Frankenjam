extends CharacterBody2D

@export var speed: float = 200.0
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
func _ready() -> void:
	anim.play("idle")

func _physics_process(delta: float) -> void:
	var input_vector := Vector2.ZERO

	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	if input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized()
		velocity = input_vector * speed
		move_and_slide()

		# Animation wechseln zu "walk"
		if anim.animation != "walk":
			anim.play("walk")

		# Richtung spiegeln (optional)
		anim.flip_h = input_vector.x < 0
	else:
		velocity = Vector2.ZERO
		move_and_slide()

		# Animation wechseln zu "idle"
		if anim.animation != "idle":
			anim.play("idle")
