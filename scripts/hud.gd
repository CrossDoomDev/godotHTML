extends CanvasLayer
## Buttons and panels are Control nodes saved in the .tscn.
## Reposition them through Godot's 2D editor — no HTML/CSS involved.
@onready var stats_text: Label = find_child("StatsText", true, false)
@onready var quest_text: Label = find_child("QuestText", true, false)
@onready var health_bar: ProgressBar = find_child("HealthBar", true, false)
@onready var xp_bar: ProgressBar = find_child("ExperienceBar", true, false)
@onready var inventory_panel: PanelContainer = find_child("InventoryPanel", true, false)
@onready var inventory_text: RichTextLabel = find_child("InventoryText", true, false)
@onready var dialogue_panel: PanelContainer = find_child("DialoguePanel", true, false)
@onready var dialogue_title: Label = find_child("DialogueTitle", true, false)
@onready var dialogue_text: Label = find_child("DialogueText", true, false)
@onready var potion_purchase: Button = find_child("BuyPotion", true, false)
@onready var wood_sale: Button = find_child("SellWood", true, false)
@onready var rest_button: Button = find_child("RestButton", true, false)
@onready var toast: Label = find_child("ToastText", true, false)
@onready var toast_timer: Timer = find_child("ToastTimer", true, false)

func _ready() -> void:
    add_to_group("hud")
    find_child("InventoryButton",true,false).pressed.connect(toggle_inventory)
    find_child("CloseInventory",true,false).pressed.connect(toggle_inventory)
    find_child("QuestButton",true,false).pressed.connect(show_journal)
    find_child("PotionButton",true,false).pressed.connect(GameState.drink_potion)
    find_child("AttackButton",true,false).pressed.connect(_attack)
    find_child("SaveButton",true,false).pressed.connect(GameState.save_game)
    find_child("NightButton",true,false).pressed.connect(_toggle_night)
    find_child("CloseDialogue",true,false).pressed.connect(_close_dialogue)
    potion_purchase.pressed.connect(func(): GameState.buy("potion", 10); show_inventory_text())
    wood_sale.pressed.connect(func(): GameState.sell_wood(); show_inventory_text())
    rest_button.pressed.connect(func(): GameState.heal(1000); GameState.save_game(); _close_dialogue())
    toast_timer.timeout.connect(func(): toast.visible = false)
    GameState.changed.connect(refresh)
    GameState.message.connect(show_toast)
    refresh()
    inventory_panel.hide()
    dialogue_panel.hide()
    toast.hide()

func _attack() -> void:
    get_tree().call_group("player","attack")

func refresh() -> void:
    if stats_text == null:
        return
    stats_text.text = "Ур. %d  ·  Монеты: %d  ·  Зелья: %d" % [
        GameState.level, GameState.coins, GameState.potions]
    quest_text.text = GameState.quest_text()
    health_bar.max_value = GameState.max_hp
    health_bar.value = GameState.hp
    xp_bar.max_value = GameState.experience_to_next_level()
    xp_bar.value = GameState.xp
    if inventory_panel.visible:
        show_inventory_text()

func toggle_inventory() -> void:
    inventory_panel.visible = not inventory_panel.visible
    if inventory_panel.visible:
        show_inventory_text()
    if inventory_panel.visible:
        dialogue_panel.hide()

func show_inventory_text() -> void:
    inventory_text.text = (
        "[b]Рюкзак[/b]\n\n"
        + "🪙 Монеты: %d\n" % GameState.coins
        + "🌿 Травы: %d\n" % GameState.herbs
        + "🧪 Зелья: %d\n" % GameState.potions
        + "🪵 Древесина: %d\n\n" % GameState.wood
        + "Уровень: %d\n" % GameState.level
        + "Опыт: %d / %d\n\n" % [GameState.xp, GameState.experience_to_next_level()]
        + "Атака: %d\n" % (17 + GameState.level * 3)
        + "Здоровье: %d / %d\n" % [GameState.hp, GameState.max_hp]
        + "Посох — экипирован."
    )

func show_journal() -> void:
    _open_dialogue("📜 Журнал заданий", GameState.quest_text(), "", false, false, false)

func show_npc(npc: Node) -> void:
    var role: String = npc.role
    var name_text: String = npc.character_name
    match role:
        "elder":
            _open_dialogue(name_text, GameState.interact_elder(), "", false, false, false)
        "smith":
            _open_dialogue(name_text, "Кузнец Бран: Держи посох крепче. Хорошее оружие само себя не выкует!", "", false, false, false)
        "merchant":
            _open_dialogue(name_text, "Торговка Мира: Зелье — 10 монет. Древесину куплю по 3 монеты.", "", true, true, false)
        "herbalist":
            _open_dialogue(name_text, "Лина: Собирай травы на опушке. Осторожнее с моховиками!", "", false, false, false)
        "fisher":
            _open_dialogue(name_text, "Финн: В речке сегодня хороший клёв. А в лесу, говорят, тревожно.", "", false, false, false)

func show_inn() -> void:
    _open_dialogue("Таверна «Зелёный лист»", "Отдохни у огня и восстанови здоровье.", "", false, false, true)

func _open_dialogue(title: String, content: String, _icon: String, can_buy: bool,
                    can_sell: bool, can_rest: bool) -> void:
    inventory_panel.hide()
    dialogue_panel.show()
    dialogue_title.text = title
    dialogue_text.text = content
    potion_purchase.visible = can_buy
    wood_sale.visible = can_sell
    rest_button.visible = can_rest

func _close_dialogue() -> void:
    dialogue_panel.hide()

func show_toast(content: String) -> void:
    toast.text = content
    toast.show()
    toast_timer.start()

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_B: toggle_inventory()
            KEY_J: show_journal()
            KEY_ESCAPE:
                inventory_panel.hide()
                dialogue_panel.hide()

func _toggle_night() -> void:
    get_tree().call_group("world", "toggle_night")
