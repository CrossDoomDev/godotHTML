extends CharacterBody2D
## Player is an editable CharacterBody2D + AnimatedSprite2D + Camera2D scene.
## The authored world and collision shapes live in scenes/world/village.tscn.
signal interacted(target: Node)
signal struck(target: Node)

@export var walk_speed: float = 105.0
@export var attack_range: float = 54.0
@export var attack_cooldown: float = 0.9

@onready var art: AnimatedSprite2D = $AnimatedSprite2D
var direction: String = "down"
var route: Array[Vector2] = []
var attack_remaining: float = 0.0

func _ready() -> void:
    add_to_group("player")
    global_position = GameState.player_position
    update_animation(false)

func _physics_process(delta: float) -> void:
    attack_remaining = maxf(0.0, attack_remaining - delta)
    var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if input_vector != Vector2.ZERO:
        route.clear()
        velocity = input_vector.normalized() * walk_speed
    elif not route.is_empty():
        var delta_position := route[0] - global_position
        if delta_position.length() < 5.0:
            route.pop_front()
            velocity = Vector2.ZERO
        else:
            velocity = delta_position.normalized() * walk_speed
    else:
        velocity = Vector2.ZERO
    if velocity != Vector2.ZERO:
        face_vector(velocity)
    move_and_slide()
    if attack_remaining <= 0.0:
        update_animation(velocity.length() > 3.0)
    if Input.is_action_just_pressed("attack"):
        attack()
    if Input.is_action_just_pressed("use_potion"):
        GameState.drink_potion()
    if Input.is_action_just_pressed("interact"):
        interact_with_nearest()

func set_world_destination(target: Vector2) -> void:
    var world := get_tree().get_first_node_in_group("world")
    if world:
        route = world.find_walk_route(global_position, target)

func face_vector(value: Vector2) -> void:
    if absf(value.x) > absf(value.y):
        direction = "right" if value.x > 0 else "left"
    else:
        direction = "down" if value.y > 0 else "up"

func update_animation(moving: bool) -> void:
    var anim := ("walk_" if moving else "idle_") + direction
    if art.sprite_frames and art.sprite_frames.has_animation(anim):
        if art.animation != anim or not art.is_playing():
            art.play(anim)

func attack() -> void:
    if attack_remaining > 0.0:
        return
    var closest: Node2D = null
    var shortest := attack_range
    for enemy in get_tree().get_nodes_in_group("enemy"):
        if not enemy.visible:
            continue
        var distance := global_position.distance_to(enemy.global_position)
        if distance < shortest:
            closest = enemy
            shortest = distance
    if closest:
        # Face the target BEFORE choosing directional attack sprites.
        face_vector(closest.global_position - global_position)
    attack_remaining = attack_cooldown
    var anim := "attack_" + direction
    if art.sprite_frames and art.sprite_frames.has_animation(anim):
        art.play(anim)
    if closest:
        closest.receive_hit(17 + GameState.level * 3)
        struck.emit(closest)
    else:
        GameState.message.emit("Рядом нет противника.")

func interact_with_nearest() -> void:
    var best: Node = null
    var shortest := 53.0
    for group_name in ["npc", "herb"]:
        for entity in get_tree().get_nodes_in_group(group_name):
            if not entity.visible:
                continue
            var distance := global_position.distance_to(entity.global_position)
            if distance < shortest:
                best = entity
                shortest = distance
    if best:
        interacted.emit(best)
    else:
        GameState.message.emit("Рядом не с кем взаимодействовать.")

func return_to_spawn() -> void:
    route.clear()
    global_position = Vector2(560, 506)
    velocity = Vector2.ZERO

