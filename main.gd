extends Node2D

const SPEED := 300.0
const JUMP_VELOCITY := -550.0
const GRAVITY := 1400.0

var player: CharacterBody2D
var touches := {}


func _ready() -> void:
    var ground := StaticBody2D.new()
    ground.position = Vector2(640, 680)
    var gshape := CollisionShape2D.new()
    var grect := RectangleShape2D.new()
    grect.size = Vector2(1280, 80)
    gshape.shape = grect
    ground.add_child(gshape)
    var gvis := ColorRect.new()
    gvis.size = Vector2(1280, 80)
    gvis.position = Vector2(-640, -40)
    gvis.color = Color(0.3, 0.6, 0.3)
    ground.add_child(gvis)
    add_child(ground)

    player = CharacterBody2D.new()
    player.position = Vector2(200, 560)
    var pshape := CollisionShape2D.new()
    var prect := RectangleShape2D.new()
    prect.size = Vector2(40, 60)
    pshape.shape = prect
    player.add_child(pshape)
    var pvis := ColorRect.new()
    pvis.size = Vector2(40, 60)
    pvis.position = Vector2(-20, -30)
    pvis.color = Color(0.9, 0.8, 0.2)
    player.add_child(pvis)
    add_child(player)

    var layer := CanvasLayer.new()
    add_child(layer)
    _add_label(layer, "<", Vector2(100, 560))
    _add_label(layer, ">", Vector2(420, 560))
    _add_label(layer, "JUMP", Vector2(1000, 560))


func _add_label(parent: Node, text: String, pos: Vector2) -> void:
    var l := Label.new()
    l.text = text
    l.position = pos
    l.add_theme_font_size_override("font_size", 64)
    parent.add_child(l)


func _zone(pos: Vector2) -> String:
    var w := get_viewport_rect().size.x
    if pos.x < w * 0.25:
        return "left"
    if pos.x < w * 0.5:
        return "right"
    if pos.x > w * 0.7:
        return "jump"
    return ""


func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            touches[event.index] = _zone(event.position)
        else:
            touches.erase(event.index)
    elif event is InputEventScreenDrag:
        touches[event.index] = _zone(event.position)


func _physics_process(delta: float) -> void:
    var dir := 0.0
    var jump := false
    if Input.is_action_pressed("ui_left"):
        dir -= 1.0
    if Input.is_action_pressed("ui_right"):
        dir += 1.0
    if Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_up"):
        jump = true
    for z in touches.values():
        if z == "left":
            dir -= 1.0
        elif z == "right":
            dir += 1.0
        elif z == "jump":
            jump = true

    player.velocity.x = dir * SPEED
    if not player.is_on_floor():
        player.velocity.y += GRAVITY * delta
    elif jump:
        player.velocity.y = JUMP_VELOCITY
    player.move_and_slide()
