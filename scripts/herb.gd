extends Area2D
## Herbs are editable scene nodes. Only collection behavior needs scripting.
@export var herb_name: String = "Лесная трава"
@onready var art: Sprite2D = $Sprite2D

func _ready() -> void:
    add_to_group("herb")

func interact() -> void:
    if not visible:
        return
    GameState.pick_herb()
    visible = false
    monitoring = false
