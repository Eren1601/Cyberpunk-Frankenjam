extends CharacterBody2D

@export var speed: float = 300.0
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@export var Pilz: PackedScene = preload("res://scenes/Pilz.tscn")
@onready var mushroom_time: Timer = $mushroom_time
@export var Can: PackedScene = preload("res://scenes/watering_can.tscn")
@onready var can_cd : Timer =$can_cd

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

	# Pilz platzieren
	if Input.is_action_just_pressed("plant_mushroom") and mushroom_time.time_left ==0:
		_place_mushroom()
		mushroom_time.start()
		
	if Input.is_action_just_pressed("use_watering_can") and can_cd.time_left ==0:
		_place_watering_can()
		can_cd.start()
		
func _place_mushroom():
	var mushroom = Pilz.instantiate()
	mushroom.position = position
	mushroom.z_index = self.z_index
	get_tree().current_scene.add_child(mushroom)
	

func _place_watering_can():
	var can = Can.instantiate()
	can.position = position
	can.z_index = self.z_index
	get_tree().current_scene.add_child(can)
	
