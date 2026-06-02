extends CharacterBody2D

# --- stats ---
const MAX_HP      = 100
const GRAVITY     = 800.0

var hp            : int   = MAX_HP
var max_posture   : float = 100.0
var posture       : float = 0.0
var is_dead       : bool  = false

@onready var hurtbox = $Hurtbox

func _ready() -> void:
	# รับสัญญาณเมื่อ player hitbox ชน hurtbox
	hurtbox.area_entered.connect(_on_hit)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_handle_gravity(delta)
	_check_player_deflect()
	move_and_slide()

func _check_player_deflect() -> void:
	# หา player ใน scene
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if player.can_deflect:
		var dist = global_position.distance_to(player.global_position)
		if dist < 60.0:   # ระยะ deflect
			player.try_deflect(self)

func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

func _on_hit(area: Area2D) -> void:
	if is_dead:
		return
	if area.name != "HitboxAttack":
		return

	posture += 25.0
	print("ศัตรูโดนฟัน! | posture: ", posture, "/", max_posture)

	if posture >= max_posture:
		_posture_break()
	else:
		take_damage(15)

func take_damage(dmg: int) -> void:
	hp -= dmg
	print("ศัตรู HP: ", hp, "/", MAX_HP)
	if hp <= 0:
		die()

func _posture_break() -> void:
	posture = 0.0
	print("POSTURE BREAK! — deathblow!")
	take_damage(50)

func receive_deflect(is_focused: bool) -> void:
	if is_dead:
		return

	if is_focused:
	# focused deflect = posture เต็มทันที
		posture = max_posture
		print("FOCUSED DEFLECT! — posture เต็มทันที!")
	else:
		posture += 30.0
		print("deflect! | posture: ", posture, "/", max_posture)

	if posture >= max_posture:
		_posture_break()

func die() -> void:
	is_dead = true
	print("ศัตรูตาย!")
	queue_free()
