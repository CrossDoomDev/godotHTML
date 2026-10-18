extends Node2D
## Every NPC is an individually editable scene instance in the world editor.
@export var character_name: String = "Житель Тихолесья"
@export_enum("elder", "smith", "merchant", "herbalist", "fisher")
var role: String = "fisher"
@onready var art: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
    add_to_group("npc")
    if art.sprite_frames:
        art.play("idle_down")

func interact() -> void:
    var hud := get_tree().get_first_node_in_group("hud")
    if hud:
        hud.show_npc(self)
