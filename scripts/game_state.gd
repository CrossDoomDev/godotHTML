extends Node
## Persistent RPG state. The map and its objects are scenes, not serialized here.
signal changed
signal message(text: String)

const SAVE_PATH := "user://tiholesye_godot_v1.json"
const SAVE_VERSION := 1

var level: int = 1
var xp: int = 0
var hp: int = 120
var max_hp: int = 120
var mana: int = 60
var coins: int = 0
var herbs: int = 0
var potions: int = 2
var wood: int = 0
var kills: int = 0
var quest_accepted: bool = false
var quest_reward: bool = false
var boss_defeated: bool = false
var player_position: Vector2 = Vector2(560, 506)

func _ready() -> void:
    load_game()

func experience_to_next_level() -> int:
    return 60 + level * 45

func add_experience(amount: int) -> void:
    xp += amount
    while xp >= experience_to_next_level():
        xp -= experience_to_next_level()
        level += 1
        max_hp += 15
        hp = max_hp
        message.emit("Новый уровень: %d!" % level)
    changed.emit()

func damage(amount: int) -> void:
    hp = maxi(0, hp - maxi(0, amount))
    if hp == 0:
        hp = max_hp
        player_position = Vector2(560, 506)
        message.emit("Тебя доставили обратно в деревню.")
        get_tree().call_group("player", "return_to_spawn")
    changed.emit()

func heal(amount: int) -> void:
    hp = mini(max_hp, hp + amount)
    changed.emit()

func drink_potion() -> void:
    if potions <= 0:
        message.emit("Зелья закончились.")
        return
    if hp >= max_hp:
        message.emit("Здоровье уже полное.")
        return
    potions -= 1
    heal(45)
    message.emit("Зелье восстановило здоровье.")
    save_game()

func pick_herb() -> void:
    herbs += 1
    message.emit("Получена лесная трава.")
    changed.emit()
    save_game()

func defeat_enemy(is_boss: bool, experience: int) -> void:
    kills += 1
    coins += 5 if not is_boss else 20
    wood += 1 if not is_boss else 3
    if is_boss:
        boss_defeated = true
        message.emit("Лесной страж побеждён!")
    else:
        message.emit("+5 монет, +1 древесина")
    add_experience(experience)
    save_game()

func quest_text() -> String:
    if quest_reward:
        return "Помощь деревне завершена!"
    if not quest_accepted:
        return "Поговори со старостой Ольгердом"
    return "Победи трёх лесных существ: %d / 3" % mini(kills, 3)

func interact_elder() -> String:
    if not quest_accepted:
        quest_accepted = true
        changed.emit()
        save_game()
        return "Староста Ольгерд: В лесу завелась нечисть. Победи трёх существ, помоги жителям."
    if quest_reward:
        return "Староста Ольгерд: Спасибо! Лес теперь немного спокойнее."
    if kills < 3:
        return "Староста Ольгерд: Осталось одолеть %d существ." % (3 - kills)
    quest_reward = true
    coins += 20
    potions += 2
    add_experience(35)
    save_game()
    return "Староста Ольгерд: Вот награда — 20 монет и два зелья!"

func buy(item: String, cost: int) -> bool:
    if coins < cost:
        message.emit("Недостаточно монет.")
        return false
    coins -= cost
    match item:
        "potion": potions += 1
        "herb": herbs += 1
        _:
            coins += cost
            return false
    changed.emit()
    save_game()
    message.emit("Покупка совершена.")
    return true

func sell_wood() -> void:
    if wood <= 0:
        message.emit("Нет древесины для продажи.")
        return
    coins += wood * 3
    wood = 0
    changed.emit()
    save_game()
    message.emit("Древесина продана.")

func save_game() -> void:
    var data := {
        "version": SAVE_VERSION,
        "level": level, "xp": xp, "hp": hp, "max_hp": max_hp,
        "mana": mana, "coins": coins, "herbs": herbs,
        "potions": potions, "wood": wood, "kills": kills,
        "quest_accepted": quest_accepted, "quest_reward": quest_reward,
        "boss_defeated": boss_defeated,
        "position": [player_position.x, player_position.y]
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "  "))
        file.close()

func load_game() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary or parsed.get("version") != SAVE_VERSION:
        return
    var data: Dictionary = parsed
    for key in ["level", "xp", "hp", "max_hp", "mana", "coins",
                "herbs", "potions", "wood", "kills"]:
        if data.get(key) is float or data.get(key) is int:
            set(key, maxi(0, int(data[key])))
    for key in ["quest_accepted", "quest_reward", "boss_defeated"]:
        if data.get(key) is bool:
            set(key, data[key])
    if data.get("position") is Array and data.position.size() == 2:
        player_position = Vector2(float(data.position[0]), float(data.position[1]))
    changed.emit()
