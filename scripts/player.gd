extends CharacterBody2D

@export var speed: float = 300.0
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

@export var Pilz: PackedScene = preload("res://scenes/Pilz.tscn")
@onready var mushroom_time: Timer = $mushroom_time

@export var Can: PackedScene = preload("res://scenes/watering_can.tscn")
@onready var can_cd : Timer = $can_cd

var is_hacking: bool = false  # Status, ob der Spieler gerade hackt

func _ready() -> void:
	anim.play("idle")
	anim.animation_finished.connect(_on_anim_finished)

	

func _physics_process(delta: float) -> void:
	# --- Hack-Logik ---
	if is_hacking:
		# 1️⃣ Hack abbrechen durch Bewegung
		var move_vec = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if move_vec != Vector2.ZERO:
			is_hacking = false
			anim.play("idle")
			return
		
		# 2️⃣ Hack abbrechen durch erneuten Tastendruck
		if Input.is_action_just_pressed("use_axe"):
			is_hacking = false
			anim.play("idle")
			return
		
		# Solange keine Bedingung erfüllt, Hack läuft weiter
		return

	# --- Bewegung ---
	var input_vector := Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	if input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized()
		velocity = input_vector * speed
		move_and_slide()

		if anim.animation != "walk":
			anim.play("walk")

		anim.flip_h = input_vector.x < 0
	else:
		velocity = Vector2.ZERO
		move_and_slide()

		if anim.animation != "idle":
			anim.play("idle")

	# --- Pilz pflanzen ---
	if Input.is_action_just_pressed("plant_mushroom") and mushroom_time.time_left == 0:
		_place_mushroom()
		mushroom_time.start()
		
	# --- Gießkanne nutzen ---
	if Input.is_action_just_pressed("use_watering_can") and can_cd.time_left == 0:
		_place_watering_can()
		can_cd.start()
		
	# --- Axt nutzen ---
	if Input.is_action_just_pressed("use_axe") and not is_hacking:
		_start_hack()
		return  # verhindert, dass Idle/Walk direkt Hack überschreibt

func _start_hack():
	is_hacking = true
	anim.play("Hack")
	velocity = Vector2.ZERO
 # beim Hacken stehen bleiben

func _on_anim_finished():
	# Wenn Hack-Animation fertig ist → automatisch Idle
	if anim.animation == "Hack":
		is_hacking = false
		anim.play("idle")

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
	
