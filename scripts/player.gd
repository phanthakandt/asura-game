extends CharacterBody2D

# --- stats ---
const SPEED_RUN = 100.0
const SPEED_WALK = 20.0
const JUMP_FORCE = -300.0
const GRAVITY = 800.0
const DEFLECT_WINDOW = 0.15   # วินาทีที่กด deflect แล้วติด
var deflect_timer : float = 0.0
var can_deflect : bool  = false

# --- samadhi (สมาธิ) ---
const SAMADHI_FILL_RATE = 80.0   # per second ขณะ walk
const SAMADHI_DRAIN_RATE = 20.0   # per second ขณะไม่ walk
const SAMADHI_LOCK_TIME = 5.0   # วินาทีที่ lock หลังเต็ม

var samadhi : float = 0.0   # 0–100
var samadhi_locked : bool  = false
var samadhi_timer : float = 0.0
var is_focused : bool = false   # true = Focused state ใช้งานอยู่

var is_attacking : bool = false
var attack_timer : float = 0.0
const ATTACK_DURATION = 0.2   # วินาทีที่ hitbox เปิดอยู่

var enemies_in_hitbox : Array = []

@onready var hitbox = $HitboxAttack
@onready var hurtbox = $Hurtbox
@onready var sprite = $Sprite2D

func _ready() -> void:
	hitbox.monitoring  = false
	hitbox.monitorable = false
	hurtbox.area_entered.connect(_on_hurtbox_hit)

func _physics_process(delta: float) -> void:
	_handle_gravity(delta)
	_handle_samadhi(delta)
	_handle_movement()
	_handle_attack(delta)
	_handle_deflect(delta)
	move_and_slide()

func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

func _handle_movement() -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	var walking := Input.is_action_pressed("walk")  # Shift
	
	var speed := SPEED_WALK if walking else SPEED_RUN
	velocity.x = dir * speed
	
	if dir != 0:
		sprite.flip_h = dir < 0
		
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_FORCE

func _handle_samadhi(delta: float) -> void:
	var walking := Input.is_action_pressed("walk")
	if samadhi_locked:
	# กำลัง lock — นับ timer ถอยหลัง
		samadhi_timer -= delta
		if samadhi_timer <= 0.0:
			samadhi_locked = false
			is_focused = false
			samadhi = 0.0   # หมด lock แล้วเกจว่างเลย
	else:
		if walking:
			samadhi = min(samadhi + SAMADHI_FILL_RATE * delta, 100.0)
			print('ชาร์จ ', samadhi , " | fps: ", Engine.get_frames_per_second())
			if samadhi >= 100.0:
				_trigger_focus_lock()
		else:
			samadhi = max(samadhi - SAMADHI_DRAIN_RATE * delta, 0.0)
		is_focused = samadhi >= 100.0

func _trigger_focus_lock() -> void:
	samadhi_locked = true
	samadhi_timer = SAMADHI_LOCK_TIME
	is_focused = true
	print("FOCUSED — samadhi locked for ", SAMADHI_LOCK_TIME, "s")

func _handle_attack(delta: float) -> void:
	if Input.is_action_just_pressed("attack") and not is_attacking:
		is_attacking = true
		attack_timer = ATTACK_DURATION
		hitbox.monitoring = true
		hitbox.monitorable = true
		
		var facing := -1.0 if sprite.flip_h else 1.0
		hitbox.position.x = abs(hitbox.position.x) * facing
		print("ฟัน!")

	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false
			hitbox.monitoring = false
			hitbox.monitorable = false
			print("เลิกฟัน")

func _handle_deflect(delta: float) -> void:
	if Input.is_action_just_pressed("deflect"):
		can_deflect  = true
		deflect_timer = DEFLECT_WINDOW
		
		var facing := -1.0 if sprite.flip_h else 1.0
		hitbox.position.x = abs(hitbox.position.x) * facing
		print("parry!")

	if can_deflect:
		deflect_timer -= delta
		if deflect_timer <= 0.0:
			can_deflect = false

# ← จุดหลัก: enemy hitbox ชน hurtbox player
func _on_hurtbox_hit(area: Area2D) -> void:
	var enemy = area.get_parent()
	if not enemy.is_in_group("enemy"):
		return

	if can_deflect:
		# เช็คว่าอยู่ใน parry window ของ enemy ไหม
		var is_perfect = enemy.in_parry_window
		try_deflect(enemy, is_perfect)
	else:
		# โดนตีจริง — ใส่ take_damage ตรงนี้ในอนาคต
		print("โดนตี!")

func try_deflect(enemy: CharacterBody2D, is_perfect: bool) -> void:
	can_deflect = false
	if is_focused and samadhi_locked:
		enemy.receive_deflect(true)
		samadhi_timer = SAMADHI_LOCK_TIME
		print("FOCUSED DEFLECT!")
	else:
		enemy.receive_deflect(is_perfect)
