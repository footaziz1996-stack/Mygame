extends Node2D

const CELL := 40
const WORLD_W := 120
const WORLD_H := 40
const RADIUS_X := 21
const RADIUS_Y := 12
const SPEED := 300.0
const JUMP_VELOCITY := -560.0
const GRAVITY := 1400.0
const BAR_Y := 600.0
const MAX_HP := 5
const REACH := 220.0

const ART_KNIGHT := "res://art/knight_sheet.png"
const ART_FOREST := "res://art/bg_forest.jpg"
const ART_CAVE := "res://art/bg_cave.jpg"
const KNIGHT_FRAMES := 6
const KNIGHT_FRAME_H := 78.0
const KNIGHT_SCALE := 0.8

var world := {}
var nodes := {}
var block_tex := {}
var heights := []
var spikes := []
var hearts := []
var player: CharacterBody2D
var psprite: Sprite2D
var sword: Sprite2D
var cam: Camera2D
var bg_forest: TextureRect
var bg_cave: TextureRect
var use_art_knight := false
var use_art_bg := false
var touches := {}
var build_mode := false
var inventory := 0
var gold := 0
var hp := MAX_HP
var kills := 0
var facing := 1
var invuln := 0.0
var attack_t := 0.0
var knock := 0.0
var anim_t := 0.0
var jumps_left := 1
var jump_prev := false
var last_cell := Vector2i(-9999, -9999)
var spawn_pos := Vector2.ZERO
var mode_label: Label
var info_label: Label


func _ready() -> void:
    RenderingServer.set_default_clear_color(Color(0.05, 0.05, 0.1))
    _make_block_textures()
    _generate()
    _build_background()
    _build_decor()
    _build_player()
    _build_ui()
    _spawn_enemies()
    _refresh()
    _update_labels()


func _make_tex(rows: Array, pal: Dictionary) -> ImageTexture:
    var h := rows.size()
    var first: String = rows[0]
    var w := first.length()
    var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
    for y in h:
        var row: String = rows[y]
        for x in w:
            var ch := row[x]
            if pal.has(ch):
                img.set_pixel(x, y, pal[ch])
    return ImageTexture.create_from_image(img)


func _circle_tex(r: int, col: Color) -> ImageTexture:
    var size := r * 2 + 1
    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    for y in size:
        for x in size:
            if Vector2(x - r, y - r).length() <= r + 0.3:
                img.set_pixel(x, y, col)
    return ImageTexture.create_from_image(img)


func _make_block_textures() -> void:
    var pal := {
        "g": Color(0.78, 0.62, 0.45),
        "G": Color(0.85, 0.45, 0.15),
        "d": Color(0.45, 0.28, 0.22),
        "D": Color(0.33, 0.2, 0.2),
        "s": Color(0.42, 0.36, 0.45),
        "S": Color(0.3, 0.25, 0.35),
        "b": Color(0.15, 0.1, 0.18),
        "B": Color(0.08, 0.05, 0.1),
        "y": Color(0.98, 0.82, 0.2)
    }
    var grass: Array = [
        "gggggggg",
        "gGgggGgg",
        "dGdddGdd",
        "dddDdddd",
        "dDdddddD",
        "dddddDdd",
        "ddDdddDd",
        "dddddddd"
    ]
    var dirt: Array = [
        "dddddddd",
        "dDdddddD",
        "dddDdddd",
        "ddddddDd",
        "dDdddddd",
        "dddddDdd",
        "ddDddddd",
        "dddddddd"
    ]
    var stone: Array = [
        "ssssssss",
        "sSsssSss",
        "ssssssss",
        "sssSssss",
        "ssssssSs",
        "sSssssss",
        "ssssSsss",
        "ssssssss"
    ]
    var bedrock: Array = [
        "bBbbBbbb",
        "bbbbbbBb",
        "BbbbbbbB",
        "bbBbbbbb",
        "bbbbbBbb",
        "bBbbbbbb",
        "bbbBbbbb",
        "bbbbBbbb"
    ]
    var ore: Array = [
        "ssssssss",
        "sSyysSss",
        "ssyyssss",
        "sssssyys",
        "ssSssyys",
        "yysssssS",
        "yysSssss",
        "ssssssss"
    ]
    block_tex[1] = _make_tex(grass, pal)
    block_tex[2] = _make_tex(dirt, pal)
    block_tex[3] = _make_tex(stone, pal)
    block_tex[4] = _make_tex(bedrock, pal)
    block_tex[5] = _make_tex(ore, pal)


func _knight_tex() -> ImageTexture:
    var rows: Array = [
        "....rr....",
        "...kkkk...",
        "..kssssk..",
        "..ksffgk..",
        "..kkkkkk..",
        ".rkssgsgk.",
        ".rkssgsgk.",
        ".rkgsssgk.",
        "..kgssgk..",
        "..kkyykk..",
        "..kssgsk..",
        "..ksk.ksk.",
        "..ksk.ksk.",
        ".kkkk.kkkk"
    ]
    var pal := {
        "k": Color(0.1, 0.1, 0.15),
        "s": Color(0.8, 0.85, 0.9),
        "g": Color(0.5, 0.55, 0.65),
        "r": Color(0.85, 0.15, 0.2),
        "f": Color(0.95, 0.75, 0.55),
        "y": Color(0.95, 0.8, 0.2)
    }
    return _make_tex(rows, pal)


func _sword_tex() -> ImageTexture:
    var rows: Array = [
        "..kkkkkkkkk.",
        "yysssssssssk",
        "..kkkkkkkkk."
    ]
    var pal := {
        "k": Color(0.15, 0.15, 0.2),
        "y": Color(0.95, 0.8, 0.2),
        "s": Color(0.9, 0.95, 1.0)
    }
    return _make_tex(rows, pal)


func _heart_tex() -> ImageTexture:
    var rows: Array = [
        ".rr.rr.",
        "rhrrrrr",
        "rrrrrrr",
        ".rrrrr.",
        "..rrr..",
        "...r..."
    ]
    var pal := {
        "r": Color(0.85, 0.15, 0.2),
        "h": Color(1.0, 0.65, 0.65)
    }
    return _make_tex(rows, pal)


func _spike_tex() -> ImageTexture:
    var rows: Array = [
        ".o..o..o",
        ".o..o..o",
        "oo.oo.oo",
        "oo.oo.oo",
        "dddddddd"
    ]
    var pal := {
        "o": Color(0.95, 0.5, 0.1),
        "d": Color(0.4, 0.2, 0.12)
    }
    return _make_tex(rows, pal)


func _tree_tex(seed_v: int) -> ImageTexture:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_v
    var w := 24
    var h := 32
    var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
    var blobs: Array = [Vector3(12, 9, 8), Vector3(6, 13, 6), Vector3(18, 13, 6), Vector3(12, 15, 6)]
    for y in 24:
        for x in w:
            for b in blobs:
                var bv: Vector3 = b
                var d: float = Vector2(x, y).distance_to(Vector2(bv.x, bv.y))
                if d <= bv.z:
                    var c := Color(0.85, 0.6, 0.15)
                    if y < 10:
                        c = Color(1.0, 0.8, 0.3)
                    elif y > 16:
                        c = Color(0.6, 0.35, 0.1)
                    if rng.randf() < 0.12:
                        c = c.darkened(0.25)
                    img.set_pixel(x, y, c)
                    break
    for y in range(16, 32):
        img.set_pixel(11, y, Color(0.88, 0.85, 0.78))
        img.set_pixel(12, y, Color(0.75, 0.72, 0.65))
        if rng.randf() < 0.2:
            img.set_pixel(11, y, Color(0.2, 0.18, 0.2))
    return ImageTexture.create_from_image(img)


func _slime_tex() -> ImageTexture:
    var rows: Array = [
        "..kkkk..",
        ".kppppk.",
        "kpwbpwbk",
        "kppppppk",
        "kpdppdpk",
        ".kkkkkk."
    ]
    var pal := {
        "k": Color(0.2, 0.05, 0.1),
        "p": Color(0.9, 0.3, 0.35),
        "d": Color(0.65, 0.15, 0.25),
        "w": Color(1, 1, 1),
        "b": Color(0.1, 0.1, 0.15)
    }
    return _make_tex(rows, pal)


func _bat_tex() -> ImageTexture:
    var rows: Array = [
        "k......k",
        "kk.kk.kk",
        "kkkkkkkk",
        ".kwkkwk.",
        "..k..k.."
    ]
    var pal := {
        "k": Color(0.3, 0.15, 0.4),
        "w": Color(1.0, 0.9, 0.2)
    }
    return _make_tex(rows, pal)


func _generate() -> void:
    var n := FastNoiseLite.new()
    n.seed = randi()
    n.frequency = 0.03
    var c := FastNoiseLite.new()
    c.seed = randi()
    c.frequency = 0.09
    for x in WORLD_W:
        var h := 14 + int(n.get_noise_1d(float(x)) * 8.0)
        heights.append(h)
        for y in range(h, WORLD_H):
            var t := 2
            if y == h:
                t = 1
            elif y > h + 6:
                t = 3
            if t == 3 and randf() < 0.04:
                t = 5
            if y == WORLD_H - 1:
                t = 4
            elif y > h + 4 and c.get_noise_2d(float(x), float(y)) > 0.3:
                continue
            world[Vector2i(x, y)] = t


func _bg_rect(tex: Texture2D) -> TextureRect:
    var r := TextureRect.new()
    r.texture = tex
    r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    r.size = Vector2(1408, 720)
    r.position = Vector2.ZERO
    return r


func _build_background() -> void:
    if ResourceLoader.exists(ART_FOREST) and ResourceLoader.exists(ART_CAVE):
        var ft := load(ART_FOREST) as Texture2D
        var ct := load(ART_CAVE) as Texture2D
        if ft != null and ct != null:
            use_art_bg = true
            var layer := CanvasLayer.new()
            layer.layer = -101
            add_child(layer)
            bg_forest = _bg_rect(ft)
            layer.add_child(bg_forest)
            bg_cave = _bg_rect(ct)
            bg_cave.modulate.a = 0.0
            layer.add_child(bg_cave)
            return

    var bg := CanvasLayer.new()
    bg.layer = -101
    add_child(bg)
    var grad := Gradient.new()
    grad.colors = PackedColorArray([Color(0.3, 0.36, 0.48), Color(0.78, 0.8, 0.84)])
    var gt := GradientTexture2D.new()
    gt.gradient = grad
    gt.fill_from = Vector2(0.0, 0.0)
    gt.fill_to = Vector2(0.0, 1.0)
    gt.width = 8
    gt.height = 128
    var sky := TextureRect.new()
    sky.texture = gt
    sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    sky.stretch_mode = TextureRect.STRETCH_SCALE
    sky.position = Vector2.ZERO
    sky.size = Vector2(1280, 720)
    bg.add_child(sky)
    var moon := Sprite2D.new()
    moon.texture = _circle_tex(14, Color(0.93, 0.94, 0.96))
    moon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    moon.scale = Vector2(6, 6)
    moon.position = Vector2(300, 190)
    bg.add_child(moon)
    var pb := ParallaxBackground.new()
    add_child(pb)
    _ridge(pb, 0.08, 420.0, 40.0, Color(0.5, 0.55, 0.66), 0.3)
    _ridge(pb, 0.2, 520.0, 50.0, Color(0.33, 0.35, 0.47), 1.7)


func _ridge(parent: Node, scale_x: float, base: float, amp: float, col: Color, ph: float) -> void:
    var pl := ParallaxLayer.new()
    pl.motion_scale = Vector2(scale_x, 0.02)
    pl.motion_mirroring = Vector2(1280, 0)
    parent.add_child(pl)
    var pts := PackedVector2Array()
    var steps := 64
    for i in range(steps + 1):
        var x := 1280.0 * i / steps
        var a := TAU * x / 1280.0
        var y := base - amp * (0.6 * sin(a * 2.0 + ph) + 0.4 * sin(a * 5.0 + ph * 2.0))
        pts.append(Vector2(x, y))
    pts.append(Vector2(1280, 800))
    pts.append(Vector2(0, 800))
    var poly := Polygon2D.new()
    poly.polygon = pts
    poly.color = col
    pl.add_child(poly)


func _build_decor() -> void:
    var dark := Polygon2D.new()
    var pts := PackedVector2Array()
    for x in WORLD_W:
        pts.append(Vector2(x * CELL, heights[x] * CELL))
        pts.append(Vector2((x + 1) * CELL, heights[x] * CELL))
    pts.append(Vector2(WORLD_W * CELL, WORLD_H * CELL))
    pts.append(Vector2(0, WORLD_H * CELL))
    dark.polygon = pts
    if use_art_bg:
        dark.color = Color(0.08, 0.05, 0.14, 0.5)
    else:
        dark.color = Color(0.16, 0.1, 0.19)
    dark.z_index = -2
    add_child(dark)

    if not use_art_bg:
        var ttex: Array = [_tree_tex(1), _tree_tex(2), _tree_tex(3)]
        var tx := 4
        while tx < WORLD_W - 4:
            var t := Sprite2D.new()
            t.texture = ttex[randi() % 3]
            t.scale = Vector2(5, 5)
            t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            t.position = Vector2(tx * CELL + 20, heights[tx] * CELL - 80)
            t.z_index = -1
            add_child(t)
            tx += randi_range(5, 9)

    var stex := _spike_tex()
    var tries := 0
    while spikes.size() < 12 and tries < 300:
        tries += 1
        var sx := randi_range(6, WORLD_W - 6)
        if absi(sx - WORLD_W / 2) < 6:
            continue
        var sp := Vector2(sx * CELL + 20, heights[sx] * CELL - 12)
        var dup := false
        for o in spikes:
            var ov: Vector2 = o
            if absf(ov.x - sp.x) < 120.0:
                dup = true
        if dup:
            continue
        spikes.append(sp)
        var s := Sprite2D.new()
        s.texture = stex
        s.scale = Vector2(5, 5)
        s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        s.position = sp
        add_child(s)


func _build_player() -> void:
    var mid := WORLD_W / 2
    spawn_pos = Vector2(mid * CELL + 20, (heights[mid] - 3) * CELL)
    player = CharacterBody2D.new()
    player.collision_layer = 4
    player.collision_mask = 1
    player.position = spawn_pos
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(36, 56)
    shape.shape = rect
    player.add_child(shape)

    psprite = Sprite2D.new()
    if ResourceLoader.exists(ART_KNIGHT):
        var kt := load(ART_KNIGHT) as Texture2D
        if kt != null:
            psprite.texture = kt
            psprite.hframes = KNIGHT_FRAMES
            psprite.frame = 2
            psprite.scale = Vector2(KNIGHT_SCALE, KNIGHT_SCALE)
            psprite.position = Vector2(0.0, 28.0 - KNIGHT_FRAME_H * KNIGHT_SCALE / 2.0)
            psprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
            use_art_knight = true
    if not use_art_knight:
        psprite.texture = _knight_tex()
        psprite.scale = Vector2(4, 4)
        psprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    player.add_child(psprite)

    sword = Sprite2D.new()
    sword.texture = _sword_tex()
    sword.offset = Vector2(6, 0)
    sword.scale = Vector2(4, 4)
    sword.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sword.visible = false
    player.add_child(sword)
    cam = Camera2D.new()
    cam.limit_left = 0
    cam.limit_right = WORLD_W * CELL
    cam.limit_top = -600
    cam.limit_bottom = WORLD_H * CELL
    cam.position_smoothing_enabled = true
    player.add_child(cam)
    add_child(player)


func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    var snow := CPUParticles2D.new()
    snow.position = Vector2(640, -10)
    snow.amount = 70
    snow.lifetime = 12.0
    snow.preprocess = 12.0
    snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    snow.emission_rect_extents = Vector2(700, 4)
    snow.direction = Vector2(0.2, 1.0)
    snow.spread = 15.0
    snow.gravity = Vector2(0, 0)
    snow.initial_velocity_min = 40.0
    snow.initial_velocity_max = 70.0
    snow.scale_amount_min = 2.0
    snow.scale_amount_max = 4.0
    snow.color = Color(1, 1, 1, 0.8)
    layer.add_child(snow)

    var bar := ColorRect.new()
    bar.position = Vector2(0, BAR_Y)
    bar.size = Vector2(1280, 120)
    bar.color = Color(0.05, 0.05, 0.08, 0.4)
    layer.add_child(bar)

    var ctex := _circle_tex(12, Color(0.1, 0.1, 0.14, 0.55))
    for cx in [110.0, 350.0, 800.0, 1100.0]:
        var c := Sprite2D.new()
        c.texture = ctex
        c.scale = Vector2(4, 4)
        c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        c.position = Vector2(cx, 660)
        layer.add_child(c)

    _add_label(layer, "<", Vector2(92, 620), 64)
    _add_label(layer, ">", Vector2(332, 620), 64)
    mode_label = _add_label(layer, "", Vector2(420, 642), 32)
    _add_label(layer, "HIT", Vector2(764, 636), 40)
    _add_label(layer, "JUMP", Vector2(1056, 638), 36)

    var htex := _heart_tex()
    for i in MAX_HP:
        var hs := Sprite2D.new()
        hs.texture = htex
        hs.scale = Vector2(5, 5)
        hs.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        hs.position = Vector2(40 + i * 46, 36)
        layer.add_child(hs)
        hearts.append(hs)
    info_label = _add_label(layer, "", Vector2(20, 66), 30)


func _add_label(parent: Node, text: String, pos: Vector2, size: int) -> Label:
    var l := Label.new()
    l.text = text
    l.position = pos
    l.add_theme_font_size_override("font_size", size)
    parent.add_child(l)
    return l


func _update_labels() -> void:
    mode_label.text = "MODE: BUILD" if build_mode else "MODE: DIG"
    info_label.text = "Blocks: " + str(inventory) + "   Gold: " + str(gold) + "   Kills: " + str(kills)
    for i in hearts.size():
        var hs: Sprite2D = hearts[i]
        if i < hp:
            hs.modulate = Color(1, 1, 1, 1)
        else:
            hs.modulate = Color(0.15, 0.15, 0.15, 0.6)


func _spawn_enemies() -> void:
    var stex := _slime_tex()
    for i in 10:
        var x := randi_range(3, WORLD_W - 4)
        if absi(x - WORLD_W / 2) < 6:
            continue
        var s := Slime.new()
        s.target = player
        s.collision_layer = 2
        s.collision_mask = 1
        s.position = Vector2(x * CELL + 20, (heights[x] - 2) * CELL)
        var shape := CollisionShape2D.new()
        var rect := RectangleShape2D.new()
        rect.size = Vector2(32, 24)
        shape.shape = rect
        s.add_child(shape)
        var spr := Sprite2D.new()
        spr.texture = stex
        spr.scale = Vector2(4, 4)
        spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        s.add_child(spr)
        s.add_to_group("enemies")
        add_child(s)

    var btex := _bat_tex()
    for i in 8:
        var bx := randi_range(8, WORLD_W - 8)
        if absi(bx - WORLD_W / 2) < 8:
            continue
        var b := Bat.new()
        b.target = player
        b.collision_layer = 2
        b.collision_mask = 1
        b.position = Vector2(bx * CELL + 20, (heights[bx] - 6) * CELL)
        var bshape := CollisionShape2D.new()
        var brect := RectangleShape2D.new()
        brect.size = Vector2(28, 16)
        bshape.shape = brect
        b.add_child(bshape)
        var bspr := Sprite2D.new()
        bspr.texture = btex
        bspr.scale = Vector2(4, 4)
        bspr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        b.add_child(bspr)
        b.add_to_group("enemies")
        add_child(b)


func _load_cell(cell: Vector2i) -> void:
    if nodes.has(cell) or not world.has(cell):
        return
    var b := StaticBody2D.new()
    b.position = Vector2(cell.x * CELL + CELL / 2.0, cell.y * CELL + CELL / 2.0)
    var s := CollisionShape2D.new()
    var r := RectangleShape2D.new()
    r.size = Vector2(CELL, CELL)
    s.shape = r
    b.add_child(s)
    var v := Sprite2D.new()
    v.texture = block_tex[world[cell]]
    v.scale = Vector2(5, 5)
    v.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    b.add_child(v)
    add_child(b)
    nodes[cell] = b


func _refresh() -> void:
    var pc := Vector2i(int(player.position.x / CELL), int(player.position.y / CELL))
    if pc == last_cell:
        return
    last_cell = pc
    for x in range(pc.x - RADIUS_X, pc.x + RADIUS_X + 1):
        for y in range(pc.y - RADIUS_Y, pc.y + RADIUS_Y + 1):
            _load_cell(Vector2i(x, y))
    for cell in nodes.keys():
        if absi(cell.x - pc.x) > RADIUS_X + 2 or absi(cell.y - pc.y) > RADIUS_Y + 2:
            nodes[cell].queue_free()
            nodes.erase(cell)


func _world_tap(pos: Vector2) -> void:
    var wp := get_canvas_transform().affine_inverse() * pos
    if wp.distance_to(player.position) > REACH:
        return
    var cell := Vector2i(floori(wp.x / CELL), floori(wp.y / CELL))
    if cell.x < 0 or cell.x >= WORLD_W or cell.y < 0 or cell.y >= WORLD_H:
        return
    if build_mode:
        if world.has(cell) or inventory <= 0:
            return
        var rect := Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL))
        var prect := Rect2(player.position - Vector2(18, 28), Vector2(36, 56))
        if rect.intersects(prect):
            return
        world[cell] = 2
        _load_cell(cell)
        inventory -= 1
    else:
        if world.has(cell) and world[cell] != 4:
            var t: int = world[cell]
            world.erase(cell)
            if nodes.has(cell):
                nodes[cell].queue_free()
                nodes.erase(cell)
            if t == 5:
                gold += 1
            else:
                inventory += 1
    _update_labels()


func _on_kill() -> void:
    kills += 1
    inventory += 1
    if hp < MAX_HP and randf() < 0.3:
        hp += 1
    _update_labels()


func _attack() -> void:
    if attack_t > 0.0:
        return
    attack_t = 0.2
    sword.position = Vector2(14.0 * facing, 0.0)
    sword.scale = Vector2(4.0 * facing, 4.0)
    for e in get_tree().get_nodes_in_group("enemies"):
        var dx: float = (e.position.x - player.position.x) * facing
        var dy: float = absf(e.position.y - player.position.y)
        if dx > -10.0 and dx < 90.0 and dy < 50.0:
            e.hp -= 1
            e.velocity = Vector2(0.0, -250.0)
            if e.hp <= 0:
                e.remove_from_group("enemies")
                e.queue_free()
                _on_kill()
    _update_labels()


func _hurt() -> void:
    hp -= 1
    invuln = 1.0
    if hp <= 0:
        hp = MAX_HP
        player.position = spawn_pos
        player.velocity = Vector2.ZERO
        last_cell = Vector2i(-9999, -9999)
        _refresh()
    _update_labels()


func _zone(pos: Vector2) -> String:
    var w := get_viewport_rect().size.x
    if pos.x < w * 0.14:
        return "left"
    if pos.x < w * 0.28:
        return "right"
    if pos.x < w * 0.5:
        return "mode"
    if pos.x < w * 0.7:
        return "hit"
    if pos.x > w * 0.75:
        return "jump"
    return ""


func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if event.position.y >= BAR_Y:
                var z := _zone(event.position)
                if z == "mode":
                    build_mode = not build_mode
                    _update_labels()
                elif z == "hit":
                    _attack()
                else:
                    touches[event.index] = z
            else:
                _world_tap(event.position)
        else:
            touches.erase(event.index)
    elif event is InputEventScreenDrag:
        if touches.has(event.index):
            if event.position.y >= BAR_Y:
                touches[event.index] = _zone(event.position)
            else:
                touches.erase(event.index)


func _update_background() -> void:
    var span := float(WORLD_W * CELL)
    var shift := -128.0 * clampf(player.position.x / span, 0.0, 1.0)
    bg_forest.position.x = shift
    bg_cave.position.x = shift
    var cx := clampi(int(player.position.x / CELL), 0, WORLD_W - 1)
    var surf := float(heights[cx] * CELL)
    var depth := player.position.y - surf
    bg_cave.modulate.a = clampf((depth - 80.0) / 200.0, 0.0, 1.0)


func _physics_process(delta: float) -> void:
    invuln = maxf(invuln - delta, 0.0)
    attack_t = maxf(attack_t - delta, 0.0)
    sword.visible = attack_t > 0.0
    if sword.visible:
        var prog := 1.0 - attack_t / 0.2
        sword.rotation = (-0.9 + 1.6 * prog) * facing
    psprite.modulate.a = 0.4 if invuln > 0.0 else 1.0

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
    if dir > 0.0:
        facing = 1
    elif dir < 0.0:
        facing = -1
    psprite.flip_h = facing < 0

    player.velocity.x = dir * SPEED + knock
    knock = move_toward(knock, 0.0, 1500.0 * delta)
    if player.is_on_floor():
        jumps_left = 1
    else:
        player.velocity.y += GRAVITY * delta
    if jump and not jump_prev:
        if player.is_on_floor():
            player.velocity.y = JUMP_VELOCITY
        elif jumps_left > 0:
            jumps_left -= 1
            player.velocity.y = JUMP_VELOCITY
    jump_prev = jump
    player.move_and_slide()
    player.position.x = clampf(player.position.x, 20.0, WORLD_W * CELL - 20.0)
    _refresh()
    if use_art_bg:
        _update_background()

    if use_art_knight:
        if not player.is_on_floor():
            psprite.frame = 4
        elif dir != 0.0:
            anim_t += delta * 10.0
            psprite.frame = 1 + (int(anim_t) % 5)
        else:
            psprite.frame = 2
    else:
        if dir != 0.0 and player.is_on_floor():
            anim_t += delta * 14.0
            psprite.position.y = -absf(sin(anim_t)) * 3.0
        else:
            psprite.position.y = 0.0

    if invuln <= 0.0:
        for node in get_tree().get_nodes_in_group("enemies"):
            var dx: float = node.position.x - player.position.x
            var dy: float = node.position.y - player.position.y
            if absf(dx) < 34.0 and absf(dy) < 40.0:
                knock = -signf(dx) * 350.0
                player.velocity.y = -250.0
                _hurt()
                break

    if invuln <= 0.0:
        var prect := Rect2(player.position - Vector2(18, 28), Vector2(36, 56))
        for sp in spikes:
            var spv: Vector2 = sp
            var srect := Rect2(spv - Vector2(18, 10), Vector2(36, 22))
            if prect.intersects(srect):
                player.velocity.y = -380.0
                _hurt()
                break


class Slime extends CharacterBody2D:
    var hp := 2
    var target: CharacterBody2D
    var dirn := 1.0

    func _physics_process(delta: float) -> void:
        if target == null:
            return
        if absf(target.position.x - position.x) > 700.0 or absf(target.position.y - position.y) > 420.0:
            return
        var d := target.position.x - position.x
        var chasing := absf(d) < 500.0
        if chasing:
            dirn = signf(d)
        velocity.x = dirn * 90.0
        if not is_on_floor():
            velocity.y += 1400.0 * delta
        else:
            velocity.y = 0.0
            if is_on_wall():
                if chasing:
                    velocity.y = -420.0
                else:
                    dirn = -dirn
        move_and_slide()


class Bat extends CharacterBody2D:
    var hp := 1
    var target: CharacterBody2D
    var t := 0.0

    func _physics_process(delta: float) -> void:
        if target == null:
            return
        t += delta
        var to := target.position - position
        if to.length() > 600.0:
            velocity = Vector2.ZERO
            return
        velocity = to.normalized() * 110.0 + Vector2(0.0, sin(t * 6.0) * 60.0)
        move_and_slide()
