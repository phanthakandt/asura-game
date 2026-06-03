extends CharacterBody2D

# --- stats ---
const MAX_HP = 100
const GRAVITY = 800.0

var hp: int   = MAX_HP
var max_posture: float = 100.0
var posture: float = 0.0
var is_dead: bool  = false
var is_stunned: bool  = false   # ← state ใหม่

# --- attack ---
const ATTACK_COOLDOWN = 2.0    # วินาทีระหว่างการตีแต่ละครั้ง
const ATTACK_DURATION = 0.3    # วินาทีที่ hitbox เปิดอยู่
var attack_timer: float = 1.0   # เริ่มต้นด้วย delay ก่อนตีครั้งแรก
var attack_active_timer: float = 0.0
var is_attacking: bool  = false

@onready var hurtbox = $Hurtbox
@onready var hitbox = $HitboxAttack   # ← ต้องเพิ่มใน scene

func _ready() -> void:
	# รับสัญญาณเมื่อ player hitbox ชน hurtbox
	hurtbox.area_entered.connect(_on_hit)
	hitbox.monitoring  = false
	hitbox.monitorable = false

func _physics_process(delta: float) -> void:
	if is_dead or is_stunned:
		return
	_handle_gravity(delta)
	_handle_attack(delta)
	move_and_slide()

func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

func _handle_attack(delta: float) -> void:
	# หยุดตีถ้า posture เต็ม
	if posture >= max_posture:
		if is_attacking:
			_end_attack()
		return

	if is_attacking:
		attack_active_timer -= delta
		if attack_active_timer <= 0.0:
			_end_attack()
	else:
		attack_timer -= delta
		if attack_timer <= 0.0:
			_start_attack()

func _start_attack() -> void:
	is_attacking = true
	attack_active_timer = ATTACK_DURATION
	hitbox.monitoring  = true
	hitbox.monitorable = true
	print("ศัตรูตี!")

func _end_attack() -> void:
	is_attacking = false
	attack_timer = ATTACK_COOLDOWN
	hitbox.monitoring  = false
	hitbox.monitorable = false

func _on_hit(area: Area2D) -> void:
	if is_dead or area.name != "HitboxAttack":
		return
	
	if is_stunned:
		# ผู้เล่นตีตอน stun = deathblow!
		print("DEATHBLOW!")
		die()
		return

	posture += 25.0
	print("ศัตรูโดนฟัน! | posture: ", posture, "/", max_posture)

	if posture >= max_posture:
		_enter_stun()
	else:
		take_damage(15)

func take_damage(dmg: int) -> void:
	hp -= dmg
	print("ศัตรู HP: ", hp, "/", MAX_HP)
	if hp <= 0:
		die()

func _enter_stun() -> void:
	is_stunned = true
	velocity   = Vector2.ZERO   # หยุดนิ่ง
	if is_attacking:
		_end_attack()
	print("POSTURE BREAK! — ศัตรูถูก stun รอ deathblow...")

func receive_deflect(is_focused: bool) -> void:
	if is_dead or is_stunned:
		return

	if is_focused:
	# focused deflect = posture เต็มทันที
		posture = max_posture
		print("FOCUSED DEFLECT! — posture เต็มทันที!")
	else:
		posture += 30.0
		print("deflect! | posture: ", posture, "/", max_posture)

	if posture >= max_posture:
		_enter_stun()

func die() -> void:
	is_dead = true
	print("ศัตรูตาย!")
	queue_free()
