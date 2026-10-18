extends SceneTree

var passed: bool = true

func _initialize() -> void:
    call_deferred("_run")

func check(truth: bool, label: String) -> void:
    if not truth:
        passed = false
        push_error("[SMOKE] FAILED: " + label)
    else:
        print("[SMOKE] PASS " + label)

func _run() -> void:
    var state: Node = root.get_node_or_null("GameState")
    if state == null:
        state = load("res://scripts/game_state.gd").new()
        state.name = "GameState"
        root.add_child(state)
    var scene: PackedScene = load("res://scenes/main.tscn")
    check(scene != null, "main scene parsed")
    if scene == null:
        quit(1)
        return
    var main := scene.instantiate()
    root.add_child(main)
    await process_frame
    var world: Node2D = main.get_node("Village")
    var tiles: TileMapLayer = world.get_node("Ground")
    check(tiles.get_used_cells().size() == 1200, "grass authored as 1,200 editor tile cells")
    check(world.get_node("ForestFloor").get_used_cells().size() > 50,
        "forest undergrowth is a paintable editor TileMapLayer")
    check(world.get_node("Roads").get_used_cells().size() > 60, "roads are editor TileMapLayer")
    check(world.get_node("Water").get_used_cells().size() > 0, "water editor TileMapLayer")
    check(world.get_node("Bridge").get_used_cells().size() > 0, "bridge editor TileMapLayer")
    check(world.get_node("Actors/Buildings").get_child_count() == 5, "all five original building nodes")
    check(world.get_node("Actors/Trees").get_child_count() > 10, "original tree objects transferred")
    check(world.get_node("Actors/NPCs").get_child_count() == 5, "five editable NPC instances")
    check(world.get_node("Actors/Enemies").get_child_count() == 5, "five editable enemy instances")
    check(world.get_node("Actors/Herbs").get_child_count() == 6, "six herbs preserved")
    var player := world.get_node("Actors/Player")
    check(player is CharacterBody2D, "native CharacterBody2D player")
    var frame_library: SpriteFrames = player.get_node("AnimatedSprite2D").sprite_frames
    for side in ["down","up","left","right"]:
        check(frame_library.has_animation("walk_"+side), "authored SpriteFrames walk_"+side)
    check(main.get_node("HUD") is CanvasLayer, "editable native HUD")
    var char_art: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
    check(char_art.scale == Vector2(0.625,0.625), "original Blender hero source mode")
    var old_hero: String = state.hero_model
    player.toggle_hero_model()
    check(state.hero_model != old_hero, "editable 2D / 3D character switch")
    player.toggle_hero_model()
    var ambience: CanvasModulate = world.get_node("CanvasModulate")
    world.toggle_night()
    check(ambience.color != Color.WHITE, "native CanvasModulate night mode")
    world.toggle_night()
    var foe: CharacterBody2D = world.get_node("Actors/Enemies").get_child(0)
    foe.receive_hit(3)
    check(foe.get_node("HealthBar").value == foe.max_health-3,
        "enemy ProgressBar reflects health")

    check(world.find_walk_route(player.global_position, player.global_position+Vector2(32,0)).size() > 0,
        "pathfinding on editor-authored terrain")
    var old_xp: int = state.xp
    state.add_experience(12)
    check(state.xp == old_xp + 12 or state.level > 1, "XP progression")
    state.hp = 45
    state.potions = 2
    state.drink_potion()
    check(state.hp == 90 and state.potions == 1, "healing potion")
    var old_coins: int = state.coins
    state.coins = 20
    check(state.buy("potion",10), "merchant purchase")
    check(state.coins == 10, "merchant payment")
    state.coins = old_coins
    for i in range(40):
        await physics_frame
    print("[SMOKE] All node / map / gameplay checks completed")
    if passed:
        print("[SMOKE] OK")
    quit(0 if passed else 1)
