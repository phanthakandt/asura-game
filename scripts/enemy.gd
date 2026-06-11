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
const ATTACK_DURATION = 1.4      # ยืดให้ครบ animation slash (15 frame) เพื่อให้ parry ได้ทั้ง 2 จังหวะ
const PARRY_FRAMES_1 = Vector2i(2, 4)    # ช่วง frame slash ที่ parry ได้ (จังหวะแรก)
const PARRY_FRAMES_2 = Vector2i(10, 12)  # ช่วง frame slash ที่ parry ได้ (จังหวะสอง)

var attack_timer: float = 1.0
var attack_active_timer: float = 0.0
var is_attacking: bool = false
var in_parry_window: bool = false  # ← ใหม่

@onready var hurtbox = $Hurtbox
@onready var hitbox = $HitboxAttack   # ← ต้องเพิ่มใน scene
@onready var animation = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var health_fill = $StatusBars/HealthFill
@onready var posture_fill = $StatusBars/PostureFill

const BAR_WIDTH = 28.0

func _ready() -> void:
	animation.play("idle")
	# รับสัญญาณเมื่อ player hitbox ชน hurtbox
	hurtbox.area_entered.connect(_on_hit)
	hitbox.monitoring  = false
	hitbox.monitorable = false
	_update_health_bar()
	_update_posture_bar()

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
		var parry_frame = _is_parry_frame(sprite.frame)
		in_parry_window = parry_frame
		# hitbox จะ "ออกดาบ" (ชนได้/parry ได้) เฉพาะช่วง frame ฟันจริงเท่านั้น
		hitbox.monitoring  = parry_frame
		hitbox.monitorable = parry_frame
		if attack_active_timer <= 0.0:
			_end_attack()
	else:
		attack_timer -= delta
		if attack_timer <= 0.0:
			_start_attack()

func _start_attack() -> void:
	animation.play("slash")
	is_attacking = true
	attack_active_timer = ATTACK_DURATION
	print("ศัตรูตี!")

func _is_parry_frame(frame: int) -> bool:
	return (frame >= PARRY_FRAMES_1.x and frame <= PARRY_FRAMES_1.y) \
		or (frame >= PARRY_FRAMES_2.x and frame <= PARRY_FRAMES_2.y)

func _end_attack() -> void:
	is_attacking = false
	attack_timer = ATTACK_COOLDOWN
	in_parry_window = false
	# ใช้ set_deferred เพราะอาจถูกเรียกระหว่าง area_entered signal กำลัง flush อยู่
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	animation.play("idle")

func _on_hit(area: Area2D) -> void:
	if is_dead or not area.get_parent().is_in_group("player"):
		return
	
	if is_stunned:
		# ผู้เล่นตีตอน stun = deathblow!
		print("DEATHBLOW!")
		die()
		return

	posture += 5.0
	_update_posture_bar()
	print("ศัตรูโดนฟัน! | posture: ", posture, "/", max_posture)

	if posture >= max_posture:
		_enter_stun()
	else:
		take_damage(15)

func take_damage(dmg: int) -> void:
	hp -= dmg
	_update_health_bar()
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

	_update_posture_bar()
	if posture >= max_posture:
		_enter_stun()

func die() -> void:
	is_dead = true
	print("ศัตรูตาย!")
	queue_free()

func _update_health_bar() -> void:
	health_fill.size.x = BAR_WIDTH * float(max(hp, 0)) / float(MAX_HP)

func _update_posture_bar() -> void:
	posture_fill.size.x = BAR_WIDTH * (min(posture, max_posture) / max_posture)
