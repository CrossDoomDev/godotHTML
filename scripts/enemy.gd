extends CharacterBody2D
## Reusable editor-placed enemy; tune stats in the Inspector.
@export var display_name: String = "Моховик"
@export var max_health: int = 32
@export var attack_damage: int = 8
@export var experience_reward: int = 18
@export var is_boss: bool = false
@export var notice_radius: float = 150.0
@export var leash_radius: float = 205.0
@export var walk_speed: float = 48.0

@onready var art: AnimatedSprite2D = $AnimatedSprite2D
@onready var respawn_timer: Timer = $RespawnTimer
@onready var health_bar: ProgressBar = $HealthBar
var health: int
var spawn_at: Vector2
var attack_timer: float = 0.0

func _ready() -> void:
    add_to_group("enemy")
    spawn_at = global_position
    health = max_health
    health_bar.max_value = max_health
    health_bar.value = health
    respawn_timer.timeout.connect(_respawn)
    if is_boss and GameState.boss_defeated:
        visible = false
        set_physics_process(false)
        return
    if art.sprite_frames:
        art.play("idle_down")

func _physics_process(delta: float) -> void:
    if not visible:
        return
    attack_timer = maxf(0.0, attack_timer - delta)
    var player := get_tree().get_first_node_in_group("player") as Node2D
    if player == null:
        return
    var player_dist := global_position.distance_to(player.global_position)
    var home_dist := global_position.distance_to(spawn_at)
    var target_position := global_position
    if home_dist > leash_radius:
        target_position = spawn_at
    elif player_dist < notice_radius:
        target_position = player.global_position
        if player_dist < 28.0:
            if attack_timer == 0.0:
                attack_timer = 1.4
                GameState.damage(attack_damage)
            velocity = Vector2.ZERO
            move_and_slide()
            return
    elif home_dist > 7.0:
        target_position = spawn_at
    var toward := target_position - global_position
    velocity = toward.normalized() * walk_speed if toward.length() > 7.0 else Vector2.ZERO
    move_and_slide()
    if velocity.length() > 1.0 and art.sprite_frames and art.sprite_frames.has_animation("walk_down"):
        art.play("walk_down")
    elif art.sprite_frames and art.sprite_frames.has_animation("idle_down"):
        art.play("idle_down")

func receive_hit(amount: int) -> void:
    if not visible:
        return
    health -= maxi(0, amount)
    health_bar.value = maxi(health, 0)
    if health <= 0:
        visible = false
        velocity = Vector2.ZERO
        set_physics_process(false)
        GameState.defeat_enemy(is_boss, experience_reward)
        if not is_boss:
            respawn_timer.start()
    else:
        if art.sprite_frames and art.sprite_frames.has_animation("hit_down"):
            art.play("hit_down")

func _respawn() -> void:
    health = max_health
    health_bar.value = health
    global_position = spawn_at
    visible = true
    set_physics_process(true)
    if art.sprite_frames:
        art.play("idle_down")
