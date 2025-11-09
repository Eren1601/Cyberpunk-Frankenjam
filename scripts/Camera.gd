extends Camera2D

@export var player: Node2D
@export var viewport_size: Vector2 = Vector2(960,720)

func _process(_delta):
	if not player:
		return
	var pos = player.global_position
	pos.x = clamp(pos.x, 0 + viewport_size.x/2, 2000 - viewport_size.x/2) # Beispiel-Weltgrenzen
	pos.y = clamp(pos.y, 0 + viewport_size.y/2, 1500 - viewport_size.y/2)
	global_position = pos
