extends Node2D
## Small scene coordinator; world composition stays editable in the .tscn.
@onready var player: CharacterBody2D = $Village/Actors/Player
@onready var hud: CanvasLayer = $HUD
var elapsed: float = 0.0

func _ready() -> void:
	player.interacted.connect(_on_interacted)
	get_window().title = "Тихолесье — Godot"
	GameState.message.emit("Добро пожаловать в Тихолесье!")

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 10.0:
		elapsed = 0.0
		GameState.player_position = player.global_position
		GameState.save_game()

func _on_interacted(target: Node) -> void:
	if target.has_method("interact"):
		target.interact()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(player):
			GameState.player_position = player.global_position
		GameState.save_game()
