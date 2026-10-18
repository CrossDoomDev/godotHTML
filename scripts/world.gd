extends Node2D
## Godot-native world: painted TileMapLayers and hand-editable prop scene nodes.
## This script only handles path requests and proximity interactions.
const CELL_SIZE := 32
const MAP_WIDTH := 40
const MAP_HEIGHT := 30

@onready var ground: TileMapLayer = $Ground
@onready var roads: TileMapLayer = $Roads
@onready var water: TileMapLayer = $Water
@onready var bridge: TileMapLayer = $Bridge
@onready var player: CharacterBody2D = $Actors/Player
@onready var actors: Node2D = $Actors
var astar: AStarGrid2D = AStarGrid2D.new()

func _ready() -> void:
    add_to_group("world")
    build_walk_grid()

func build_walk_grid() -> void:
    astar.region = Rect2i(0, 0, MAP_WIDTH, MAP_HEIGHT)
    astar.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
    astar.offset = Vector2(CELL_SIZE / 2, CELL_SIZE / 2)
    astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    astar.update()
    for y in range(MAP_HEIGHT):
        for x in range(MAP_WIDTH):
            if x == 0 or y == 0 or x == MAP_WIDTH - 1 or y == MAP_HEIGHT - 1:
                astar.set_point_solid(Vector2i(x,y))
            elif water.get_cell_source_id(Vector2i(x,y)) != -1:
                astar.set_point_solid(Vector2i(x,y))
    # Objects are editor-owned nodes, not a coded list of obstacles.
    for obstacle in get_tree().get_nodes_in_group("world_obstacle"):
        var body := obstacle as CollisionObject2D
        if body == null:
            continue
        for shape in body.get_children():
            if not shape is CollisionShape2D:
                continue
            var collision := shape as CollisionShape2D
            if not collision.shape is RectangleShape2D:
                continue
            var half := (collision.shape as RectangleShape2D).size / 2.0
            var center := collision.global_position
            var begin := Vector2i(floori((center.x-half.x+2.0)/CELL_SIZE), floori((center.y-half.y+2.0)/CELL_SIZE))
            var end := Vector2i(floori((center.x+half.x-2.0)/CELL_SIZE), floori((center.y+half.y-2.0)/CELL_SIZE))
            for y in range(maxi(0,begin.y), mini(MAP_HEIGHT,end.y+1)):
                for x in range(maxi(0,begin.x), mini(MAP_WIDTH,end.x+1)):
                    astar.set_point_solid(Vector2i(x,y))
    # Initial spawn and common approaches must be traversable.
    for cell in [Vector2i(17,15),Vector2i(17,14),Vector2i(20,15),
                 Vector2i(21,16),Vector2i(25,16),Vector2i(12,15)]:
        astar.set_point_solid(cell,false)

func find_walk_route(from_world: Vector2, to_world: Vector2) -> Array[Vector2]:
    var start := Vector2i(floori(from_world.x/CELL_SIZE), floori(from_world.y/CELL_SIZE))
    var target := Vector2i(floori(to_world.x/CELL_SIZE), floori(to_world.y/CELL_SIZE))
    var result: Array[Vector2] = []
    if not astar.is_in_boundsv(start) or not astar.is_in_boundsv(target):
        return result
    if astar.is_point_solid(target):
        return result
    var ids: Array[Vector2i] = astar.get_id_path(start,target)
    for cell in ids:
        result.append(astar.get_point_position(cell))
    return result

func _unhandled_input(event: InputEvent) -> void:
    if not event is InputEventMouseButton:
        return
    var click := event as InputEventMouseButton
    if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
        return
    var place := get_global_mouse_position()
    var chosen: Node2D = null
    var nearest := 30.0
    for group_name in ["npc","enemy","herb"]:
        for obj in get_tree().get_nodes_in_group(group_name):
            if not obj is Node2D or not obj.visible:
                continue
            var distance := place.distance_to(obj.global_position)
            if distance < nearest:
                nearest = distance
                chosen = obj
    if chosen:
        if chosen.is_in_group("enemy"):
            if player.global_position.distance_to(chosen.global_position) < 60:
                player.attack()
            else:
                player.set_world_destination(chosen.global_position)
        elif player.global_position.distance_to(chosen.global_position) < 55:
            player.interacted.emit(chosen)
        else:
            player.set_world_destination(chosen.global_position + Vector2(0,30))
    else:
        player.set_world_destination(place)
