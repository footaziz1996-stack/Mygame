extends Node2D

const CELL := 40
const WORLD_W := 264
const WORLD_H := 44
const RADIUS_X := 21
const RADIUS_Y := 12
const SPEED := 300.0
const JUMP_VELOCITY := -570.0
const GRAVITY := 1400.0
const BAR_Y := 600.0
const MAX_HP := 5
const REACH := 240.0
const SURF_ZONES := 11
const CAVE_ZONES := 5
const ARENA_HALF := 11
const BOSS_HP := 30
const KNIGHT_FRAMES := 6
const KNIGHT_FRAME_H := 78.0
const ART_KNIGHT := "res://art/knight_sheet.png"

var surf_names: Array = [
    "Firefly Glade", "Teal Hollow", "Shadow Woods", "Mossy Ruins",
    "Sunlit Grove", "Canopy Walk", "Moonlit Bridge", "Amber Dusk",
    "Starfall Woods", "Moon Forest", "Bloom Thicket"
]
var cave_names: Array = [
    "Stalactite Hall", "Crystal Cave", "Amethyst Hollow", "Blue Depths", "Starlit Cavern"
]

var world := {}
var nodes := {}
var block_tex := {}
var block_colors := {}
var heights := []
var spikes := []
var hearts := []
var surf_rects := []
var cave_rects := []

var tex_glow: ImageTexture
var tex_btn: ImageTexture
var tex_shadow: ImageTexture
var tex_slash: ImageTexture
var tex_frame: ImageTexture
var tex_crystal: ImageTexture
var tex_shroom: ImageTexture
var tex_slime: ImageTexture
var tex_bat_a: ImageTexture
var tex_bat_b: ImageTexture
var tex_heart: ImageTexture
var tex_spike: ImageTexture
var glow_mat: CanvasItemMaterial

var player: CharacterBody2D
var psprite: Sprite2D
var pglow: Sprite2D
var pshadow: Sprite2D
var slash: Sprite2D
var pdust: CPUParticles2D
var cam: Camera2D
var cursor: Sprite2D
var boss: Boss
var cave_root: Control
var vignette: TextureRect
var mode_label: Label
var info_label: Label
var upg_label: Label
var banner: Label
var boss_ui: Control
var boss_fg: ColorRect

var use_art_knight := false
var touches := {}
var build_mode := false
var inventory := 0
var gold := 0
var damage := 1
var hp := MAX_HP
var kills := 0
var facing := 1
var invuln := 0.0
var attack_t := 0.0
var knock := 0.0
var anim_t := 0.0
var jumps_left := 1
var jump_prev := false
var coyote := 0.0
var jump_buf := 0.0
var shake_t := 0.0
var banner_t := 0.0
var cursor_t := 0.0
var win_t := 0.0
var won := false
var last_zone := -1
var last_cell := Vector2i(-9999, -9999)
var spawn_pos := Vector2.ZERO


func _ready() -> void:
    RenderingServer.set_default_clear_color(Color(0.05, 0.05, 0.1))
    block_colors = {
        1: Color(0.3, 0.7, 0.45),
        2: Color(0.45, 0.25, 0.3),
        3: Color(0.35, 0.4, 0.55),
        4: Color(0.1, 0.1, 0.18),
        5: Color(0.98, 0.82, 0.2)
    }
    _make_block_textures()
    _make_fx_textures()
    _generate()
    _build_background()
    _build_decor()
    _build_props()
    _build_player()
    _build_ui()
    _spawn_enemies()
    _refresh()
    _update_labels()
    invuln = 2.0


func _hgt(x: int) -> int:
    return int(heights[x])


# ---------------------------------------------------------------- textures

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


func _glow_tex(r: int) -> ImageTexture:
    var size := r * 2
    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    for y in size:
        for x in size:
            var d := Vector2(x - r + 0.5, y - r + 0.5).length() / float(r)
            var a := clampf(1.0 - d, 0.0, 1.0)
            img.set_pixel(x, y, Color(1, 1, 1, a * a))
    return ImageTexture.create_from_image(img)


func _slash_tex() -> ImageTexture:
    var size := 24
    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    for y in size:
        for x in size:
            var v := Vector2(x - 11.5, y - 11.5)
            var d := v.length()
            var ang := absf(rad_to_deg(v.angle()))
            if d >= 7.0 and d <= 11.5 and ang <= 65.0:
                var a := 1.0 - (d - 7.0) / 4.5 * 0.5
                img.set_pixel(x, y, Color(1, 1, 1, a))
    return ImageTexture.create_from_image(img)


func _make_block_textures() -> void:
    var pal := {
        "g": Color(0.22, 0.5, 0.36),
        "G": Color(0.5, 0.82, 0.45),
        "d": Color(0.36, 0.2, 0.26),
        "D": Color(0.26, 0.14, 0.2),
        "s": Color(0.3, 0.35, 0.5),
        "S": Color(0.21, 0.25, 0.4),
        "b": Color(0.1, 0.1, 0.18),
        "B": Color(0.05, 0.05, 0.1),
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


func _make_fx_textures() -> void:
    tex_glow = _glow_tex(16)
    tex_btn = _circle_tex(14, Color(0.1, 0.1, 0.14, 0.6))
    tex_shadow = _circle_tex(8, Color(0, 0, 0, 0.35))
    tex_slash = _slash_tex()

    var frame_rows: Array = [
        "wwwwwwww",
        "w......w",
        "w......w",
        "w......w",
        "w......w",
        "w......w",
        "w......w",
        "wwwwwwww"
    ]
    tex_frame = _make_tex(frame_rows, {"w": Color(1, 1, 1, 0.9)})

    var crystal_rows: Array = [
        "...c...",
        "..cCc..",
        "..cCc..",
        ".ccCcc.",
        ".ccCcc.",
        ".cCCCc.",
        "ccCCCcc",
        "ddddddd"
    ]
    tex_crystal = _make_tex(crystal_rows, {
        "c": Color(0.45, 0.8, 0.95),
        "C": Color(0.85, 0.97, 1.0),
        "d": Color(0.2, 0.25, 0.4)
    })

    var shroom_rows: Array = [
        "..rrr..",
        ".rwrrr.",
        "rrrrwrr",
        "..sss..",
        "..sss..",
        "..sss.."
    ]
    tex_shroom = _make_tex(shroom_rows, {
        "r": Color(0.8, 0.2, 0.35),
        "w": Color(1, 1, 1),
        "s": Color(0.9, 0.85, 0.7)
    })

    var slime_rows: Array = [
        "..kkkk..",
        ".kppppk.",
        "kpwbpwbk",
        "kppppppk",
        "kpdppdpk",
        ".kkkkkk."
    ]
    tex_slime = _make_tex(slime_rows, {
        "k": Color(0.2, 0.05, 0.1),
        "p": Color(0.9, 0.3, 0.35),
        "d": Color(0.65, 0.15, 0.25),
        "w": Color(1, 1, 1),
        "b": Color(0.1, 0.1, 0.15)
    })

    var bat_up: Array = [
        "k......k",
        "kk.kk.kk",
        "kkkkkkkk",
        ".kwkkwk.",
        "..k..k.."
    ]
    var bat_down: Array = [
        "........",
        "..kkkk..",
        "kkkkkkkk",
        "kkwkkwkk",
        "k..kk..k"
    ]
    var bat_pal := {
        "k": Color(0.35, 0.18, 0.45),
        "w": Color(1.0, 0.9, 0.2)
    }
    tex_bat_a = _make_tex(bat_up, bat_pal)
    tex_bat_b = _make_tex(bat_down, bat_pal)

    var heart_rows: Array = [
        ".rr.rr.",
        "rhrrrrr",
        "rrrrrrr",
        ".rrrrr.",
        "..rrr..",
        "...r..."
    ]
    tex_heart = _make_tex(heart_rows, {
        "r": Color(0.85, 0.15, 0.2),
        "h": Color(1.0, 0.65, 0.65)
    })

    var spike_rows: Array = [
        ".o..o..o",
        ".o..o..o",
        "oo.oo.oo",
        "oo.oo.oo",
        "dddddddd"
    ]
    tex_spike = _make_tex(spike_rows, {
        "o": Color(0.95, 0.5, 0.1),
        "d": Color(0.4, 0.2, 0.12)
    })

    glow_mat = CanvasItemMaterial.new()
    glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _knight_fallback_tex() -> ImageTexture:
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
    return _make_tex(rows, {
        "k": Color(0.1, 0.1, 0.15),
        "s": Color(0.8, 0.85, 0.9),
        "g": Color(0.5, 0.55, 0.65),
        "r": Color(0.85, 0.15, 0.2),
        "f": Color(0.95, 0.75, 0.55),
        "y": Color(0.95, 0.8, 0.2)
    })


# ---------------------------------------------------------------- world

func _generate() -> void:
    var n := FastNoiseLite.new()
    n.seed = randi()
    n.frequency = 0.025
    var n2 := FastNoiseLite.new()
    n2.seed = randi()
    n2.frequency = 0.08
    var c := FastNoiseLite.new()
    c.seed = randi()
    c.frequency = 0.09
    for x in WORLD_W:
        var h := 14 + int(n.get_noise_1d(float(x)) * 7.0 + n2.get_noise_1d(float(x)) * 2.0)
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
    var mid := WORLD_W / 2
    for x in range(mid - ARENA_HALF, mid + ARENA_HALF + 1):
        for y in range(WORLD_H - 11, WORLD_H - 1):
            world.erase(Vector2i(x, y))


func _load_bg(path: String) -> Texture2D:
    if ResourceLoader.exists(path):
        return load(path) as Texture2D
    return null


func _bg_rect(tex: Texture2D) -> TextureRect:
    var r := TextureRect.new()
    r.texture = tex
    r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    r.size = Vector2(1408, 720)
    r.position = Vector2.ZERO
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return r


func _build_background() -> void:
    var layer := CanvasLayer.new()
    layer.layer = -101
    add_child(layer)
    for i in SURF_ZONES:
        var st := _load_bg("res://art/bg_s" + str(i) + ".jpg")
        if st != null:
            var sr := _bg_rect(st)
            layer.add_child(sr)
            surf_rects.append(sr)
    if surf_rects.is_empty():
        var grad := Gradient.new()
        grad.colors = PackedColorArray([Color(0.1, 0.12, 0.25), Color(0.3, 0.4, 0.5)])
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
        sky.size = Vector2(1280, 720)
        sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
        layer.add_child(sky)
        return
    var layer2 := CanvasLayer.new()
    layer2.layer = -100
    add_child(layer2)
    cave_root = Control.new()
    cave_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer2.add_child(cave_root)
    for i in CAVE_ZONES:
        var ct := _load_bg("res://art/bg_c" + str(i) + ".jpg")
        if ct != null:
            var cr := _bg_rect(ct)
            cave_root.add_child(cr)
            cave_rects.append(cr)


func _blend_rects(rects: Array, px: float, shift: float) -> void:
    var n := rects.size()
    if n == 0:
        return
    var p := clampf(px * float(n) - 0.5, 0.0, float(n - 1))
    var i := mini(int(p), maxi(n - 2, 0))
    var f := smoothstep(0.0, 1.0, p - float(i))
    for k in n:
        var r: TextureRect = rects[k]
        r.position.x = shift
        var a := 0.0
        if k == i:
            a = 1.0
        elif k == i + 1:
            a = f
        r.modulate.a = a
        r.visible = a > 0.01


func _update_background() -> void:
    if surf_rects.is_empty():
        return
    var span := float(WORLD_W * CELL)
    var px := clampf(player.position.x / span, 0.0, 1.0)
    var shift := -128.0 * px
    _blend_rects(surf_rects, px, shift)
    _blend_rects(cave_rects, px, shift)
    var cx := clampi(int(player.position.x / CELL), 0, WORLD_W - 1)
    var depth := player.position.y - float(_hgt(cx) * CELL)
    var cave_a := clampf((depth - 100.0) / 200.0, 0.0, 1.0)
    if cave_root != null:
        cave_root.modulate.a = cave_a
        cave_root.visible = cave_a > 0.01
    vignette.modulate.a = clampf((depth - 60.0) / 300.0, 0.0, 1.0)

    var zid := 0
    if cave_a > 0.5 and cave_rects.size() > 0:
        zid = 100 + mini(int(px * float(CAVE_ZONES)), CAVE_ZONES - 1)
    else:
        zid = mini(int(px * float(surf_rects.size())), surf_rects.size() - 1)
    if zid != last_zone:
        last_zone = zid
        if zid >= 100:
            _show_banner(str(cave_names[zid - 100]))
        else:
            _show_banner(str(surf_names[zid]))


func _build_decor() -> void:
    var dark := Polygon2D.new()
    var pts := PackedVector2Array()
    for x in WORLD_W:
        pts.append(Vector2(x * CELL, _hgt(x) * CELL))
        pts.append(Vector2((x + 1) * CELL, _hgt(x) * CELL))
    pts.append(Vector2(WORLD_W * CELL, WORLD_H * CELL))
    pts.append(Vector2(0, WORLD_H * CELL))
    dark.polygon = pts
    dark.color = Color(0.08, 0.05, 0.14, 0.45)
    dark.z_index = -2
    add_child(dark)

    var tries := 0
    while spikes.size() < 24 and tries < 600:
        tries += 1
        var sx := randi_range(6, WORLD_W - 6)
        if absi(sx - WORLD_W / 2) < 8:
            continue
        var sp := Vector2(sx * CELL + 20, _hgt(sx) * CELL - 12)
        var dup := false
        for o in spikes:
            var ov: Vector2 = o
            if absf(ov.x - sp.x) < 140.0:
                dup = true
        if dup:
            continue
        spikes.append(sp)
        var s := Sprite2D.new()
        s.texture = tex_spike
        s.scale = Vector2(5, 5)
        s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        s.position = sp
        add_child(s)


func _build_props() -> void:
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    for x in range(2, WORLD_W - 2):
        if rng.randf() < 0.1:
            var m := Sprite2D.new()
            m.texture = tex_shroom
            m.scale = Vector2(4, 4)
            m.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            m.position = Vector2(x * CELL + rng.randf_range(6.0, 34.0), _hgt(x) * CELL - 12)
            m.z_index = -1
            add_child(m)

    var cols: Array = [Color(0.4, 0.9, 1.0), Color(0.8, 0.5, 1.0), Color(1.0, 0.5, 0.8)]
    for x in range(1, WORLD_W - 1):
        for y in range(_hgt(x) + 6, WORLD_H - 1):
            var cell := Vector2i(x, y)
            if world.has(cell):
                continue
            if not world.has(Vector2i(x, y + 1)):
                continue
            if rng.randf() > 0.07:
                continue
            var col: Color = cols[rng.randi() % 3]
            var cr := Sprite2D.new()
            cr.texture = tex_crystal
            cr.scale = Vector2(4, 4)
            cr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            cr.self_modulate = col
            cr.position = Vector2(x * CELL + 20, (y + 1) * CELL - 16)
            cr.z_index = -1
            var gl := Sprite2D.new()
            gl.texture = tex_glow
            gl.material = glow_mat
            gl.scale = Vector2(0.55, 0.55)
            gl.modulate = Color(col.r, col.g, col.b, 0.6)
            cr.add_child(gl)
            add_child(cr)


# ---------------------------------------------------------------- player

func _build_player() -> void:
    var mid := WORLD_W / 2
    spawn_pos = Vector2(mid * CELL + 20, (_hgt(mid) - 3) * CELL)
    player = CharacterBody2D.new()
    player.collision_layer = 4
    player.collision_mask = 1
    player.position = spawn_pos
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(34, 68)
    shape.shape = rect
    player.add_child(shape)

    pshadow = Sprite2D.new()
    pshadow.texture = tex_shadow
    pshadow.scale = Vector2(3.2, 0.9)
    pshadow.position = Vector2(0, 33)
    player.add_child(pshadow)

    psprite = Sprite2D.new()
    if ResourceLoader.exists(ART_KNIGHT):
        var kt := load(ART_KNIGHT) as Texture2D
        if kt != null:
            psprite.texture = kt
            psprite.hframes = KNIGHT_FRAMES
            psprite.frame = 2
            psprite.position = Vector2(0.0, 34.0 - KNIGHT_FRAME_H / 2.0)
            psprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            use_art_knight = true
    if not use_art_knight:
        psprite.texture = _knight_fallback_tex()
        psprite.scale = Vector2(4, 4)
        psprite.position = Vector2(0.0, 6.0)
        psprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

    if use_art_knight:
        var gimg := psprite.texture.get_image()
        if gimg != null:
            gimg.convert(Image.FORMAT_RGBA8)
            for gy in gimg.get_height():
                for gx in gimg.get_width():
                    var gc := gimg.get_pixel(gx, gy)
                    if gc.a > 0.1:
                        gimg.set_pixel(gx, gy, Color(0.85, 0.8, 1.0, gc.a))
            pglow = Sprite2D.new()
            pglow.texture = ImageTexture.create_from_image(gimg)
            pglow.hframes = KNIGHT_FRAMES
            pglow.frame = 2
            pglow.scale = Vector2(1.08, 1.08)
            pglow.position = psprite.position + Vector2(0.0, -3.0)
            pglow.modulate = Color(1, 1, 1, 0.5)
            pglow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            player.add_child(pglow)
    player.add_child(psprite)

    slash = Sprite2D.new()
    slash.texture = tex_slash
    slash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    slash.visible = false
    player.add_child(slash)

    pdust = CPUParticles2D.new()
    pdust.position = Vector2(0, 32)
    pdust.amount = 10
    pdust.lifetime = 0.35
    pdust.direction = Vector2(0, -1)
    pdust.spread = 50.0
    pdust.initial_velocity_min = 20.0
    pdust.initial_velocity_max = 50.0
    pdust.gravity = Vector2.ZERO
    pdust.scale_amount_min = 2.0
    pdust.scale_amount_max = 4.0
    pdust.color = Color(0.8, 0.75, 0.7, 0.5)
    pdust.emitting = false
    player.add_child(pdust)

    cam = Camera2D.new()
    cam.limit_left = 0
    cam.limit_right = WORLD_W * CELL
    cam.limit_top = -400
    cam.limit_bottom = WORLD_H * CELL
    cam.position_smoothing_enabled = true
    player.add_child(cam)
    add_child(player)

    cursor = Sprite2D.new()
    cursor.texture = tex_frame
    cursor.scale = Vector2(5, 5)
    cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    cursor.z_index = 10
    cursor.visible = false
    add_child(cursor)


# ---------------------------------------------------------------- UI

func _add_label(parent: Node, text: String, pos: Vector2, size: int) -> Label:
    var l := Label.new()
    l.text = text
    l.position = pos
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    l.add_theme_constant_override("outline_size", 8)
    parent.add_child(l)
    return l


func _add_btn(parent: Node, text: String, center: Vector2, size: int) -> void:
    var c := Sprite2D.new()
    c.texture = tex_btn
    c.scale = Vector2(4, 4)
    c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    c.position = center
    parent.add_child(c)
    var l := _add_label(parent, text, center - Vector2(70, 45), size)
    l.size = Vector2(140, 90)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    var vg := Gradient.new()
    vg.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.85)])
    var vt := GradientTexture2D.new()
    vt.gradient = vg
    vt.fill = GradientTexture2D.FILL_RADIAL
    vt.fill_from = Vector2(0.5, 0.5)
    vt.fill_to = Vector2(1.0, 0.5)
    vt.width = 128
    vt.height = 72
    vignette = TextureRect.new()
    vignette.texture = vt
    vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    vignette.stretch_mode = TextureRect.STRETCH_SCALE
    vignette.size = Vector2(1280, 720)
    vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vignette.modulate.a = 0.0
    layer.add_child(vignette)

    var ramp := Gradient.new()
    ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
    ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
    var ff := CPUParticles2D.new()
    ff.position = Vector2(640, 360)
    ff.amount = 24
    ff.lifetime = 6.0
    ff.preprocess = 6.0
    ff.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    ff.emission_rect_extents = Vector2(640, 300)
    ff.direction = Vector2(0, -1)
    ff.spread = 180.0
    ff.gravity = Vector2.ZERO
    ff.initial_velocity_min = 8.0
    ff.initial_velocity_max = 25.0
    ff.scale_amount_min = 0.3
    ff.scale_amount_max = 0.7
    ff.texture = tex_glow
    ff.color = Color(0.9, 1.0, 0.5, 0.8)
    ff.color_ramp = ramp
    ff.material = glow_mat
    layer.add_child(ff)

    var bar := ColorRect.new()
    bar.position = Vector2(0, BAR_Y)
    bar.size = Vector2(1280, 120)
    bar.color = Color(0.05, 0.05, 0.08, 0.4)
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(bar)

    _add_btn(layer, "<", Vector2(95, 660), 56)
    _add_btn(layer, ">", Vector2(268, 660), 56)
    _add_btn(layer, "HIT", Vector2(768, 660), 34)
    _add_btn(layer, "JUMP", Vector2(1120, 660), 32)

    var mp := ColorRect.new()
    mp.position = Vector2(400, 630)
    mp.size = Vector2(210, 60)
    mp.color = Color(0.1, 0.1, 0.14, 0.6)
    mp.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(mp)
    mode_label = _add_label(layer, "", Vector2(412, 642), 30)

    var up := ColorRect.new()
    up.position = Vector2(1000, 12)
    up.size = Vector2(268, 64)
    up.color = Color(0.1, 0.1, 0.14, 0.6)
    up.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(up)
    upg_label = _add_label(layer, "", Vector2(1012, 24), 26)

    for i in MAX_HP:
        var hs := Sprite2D.new()
        hs.texture = tex_heart
        hs.scale = Vector2(5, 5)
        hs.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        hs.position = Vector2(40 + i * 46, 36)
        layer.add_child(hs)
        hearts.append(hs)
    info_label = _add_label(layer, "", Vector2(20, 66), 26)

    banner = _add_label(layer, "", Vector2(0, 110), 40)
    banner.size = Vector2(1280, 60)
    banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    banner.modulate.a = 0.0

    boss_ui = Control.new()
    boss_ui.position = Vector2(440, 20)
    boss_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    boss_ui.visible = false
    layer.add_child(boss_ui)
    var bbg := ColorRect.new()
    bbg.size = Vector2(400, 20)
    bbg.color = Color(0, 0, 0, 0.7)
    bbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    boss_ui.add_child(bbg)
    boss_fg = ColorRect.new()
    boss_fg.position = Vector2(2, 2)
    boss_fg.size = Vector2(396, 16)
    boss_fg.color = Color(0.85, 0.15, 0.25)
    boss_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    boss_ui.add_child(boss_fg)
    _add_label(boss_ui, "CAVE KING", Vector2(140, 20), 24)


func _show_banner(text: String) -> void:
    banner.text = text
    banner_t = 2.5


func _update_labels() -> void:
    mode_label.text = "MODE: BUILD" if build_mode else "MODE: DIG"
    var cx := clampi(int(player.position.x / CELL), 0, WORLD_W - 1)
    var depth := maxi(0, int(player.position.y / CELL) - _hgt(cx))
    info_label.text = "Blocks " + str(inventory) + "   Gold " + str(gold) + "   Kills " + str(kills) + "   Depth " + str(depth)
    if damage >= 4:
        upg_label.text = "ATTACK MAX"
    else:
        upg_label.text = "ATK +1 : " + str(damage * 3) + " gold"
    for i in hearts.size():
        var hs: Sprite2D = hearts[i]
        if i < hp:
            hs.modulate = Color(1, 1, 1, 1)
        else:
            hs.modulate = Color(0.15, 0.15, 0.15, 0.6)


# ---------------------------------------------------------------- enemies

func _make_slime(pos: Vector2) -> void:
    var s := Slime.new()
    s.target = player
    s.hp = 3
    s.half = Vector2(16, 12)
    s.collision_layer = 2
    s.collision_mask = 1
    s.position = pos
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(32, 24)
    shape.shape = rect
    s.add_child(shape)
    var spr := Sprite2D.new()
    spr.texture = tex_slime
    spr.scale = Vector2(4, 4)
    spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    s.add_child(spr)
    s.spr = spr
    s.add_to_group("enemies")
    add_child(s)


func _make_bat(pos: Vector2) -> void:
    var b := Bat.new()
    b.target = player
    b.hp = 1
    b.half = Vector2(14, 8)
    b.tex_a = tex_bat_a
    b.tex_b = tex_bat_b
    b.collision_layer = 2
    b.collision_mask = 1
    b.position = pos
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(28, 16)
    shape.shape = rect
    b.add_child(shape)
    var spr := Sprite2D.new()
    spr.texture = tex_bat_a
    spr.scale = Vector2(4, 4)
    spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    b.add_child(spr)
    b.spr = spr
    b.add_to_group("enemies")
    add_child(b)


func _spawn_enemies() -> void:
    var mid := WORLD_W / 2
    for i in 26:
        var x := randi_range(4, WORLD_W - 5)
        if absi(x - mid) < 12:
            continue
        _make_slime(Vector2(x * CELL + 20, (_hgt(x) - 2) * CELL))
    for i in 14:
        var bx := randi_range(8, WORLD_W - 8)
        if absi(bx - mid) < 16:
            continue
        _make_bat(Vector2(bx * CELL + 20, (_hgt(bx) - 6) * CELL))
    var tries := 0
    var placed := 0
    while placed < 14 and tries < 500:
        tries += 1
        var cx := randi_range(4, WORLD_W - 5)
        var cy := randi_range(_hgt(cx) + 7, WORLD_H - 3)
        if absi(cx - mid) < 4:
            continue
        if not world.has(Vector2i(cx, cy)):
            _make_bat(Vector2(cx * CELL + 20, cy * CELL + 20))
            placed += 1

    boss = Boss.new()
    boss.target = player
    boss.hp = BOSS_HP
    boss.half = Vector2(44, 34)
    boss.collision_layer = 2
    boss.collision_mask = 1
    boss.position = Vector2(mid * CELL + 20, (WORLD_H - 4) * CELL)
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(88, 64)
    shape.shape = rect
    boss.add_child(shape)
    var spr := Sprite2D.new()
    spr.texture = tex_slime
    spr.scale = Vector2(12, 12)
    spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    spr.self_modulate = Color(0.7, 0.45, 1.0)
    boss.add_child(spr)
    boss.spr = spr
    boss.add_to_group("enemies")
    add_child(boss)


# ---------------------------------------------------------------- blocks

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
    _update_labels()


func _burst(pos: Vector2, col: Color, count: int) -> void:
    var p := CPUParticles2D.new()
    p.position = pos
    p.one_shot = true
    p.amount = count
    p.lifetime = 0.5
    p.explosiveness = 1.0
    p.direction = Vector2(0, -1)
    p.spread = 180.0
    p.initial_velocity_min = 80.0
    p.initial_velocity_max = 180.0
    p.gravity = Vector2(0, 700)
    p.scale_amount_min = 3.0
    p.scale_amount_max = 5.0
    p.color = col
    add_child(p)
    p.emitting = true
    get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func _world_tap(pos: Vector2) -> void:
    var wp := get_canvas_transform().affine_inverse() * pos
    var cell := Vector2i(floori(wp.x / CELL), floori(wp.y / CELL))
    cursor.position = Vector2(cell.x * CELL + CELL / 2.0, cell.y * CELL + CELL / 2.0)
    cursor_t = 0.25
    if wp.distance_to(player.position) > REACH:
        cursor.modulate = Color(1.0, 0.3, 0.3, 0.9)
        return
    cursor.modulate = Color(1, 1, 1, 0.9)
    if cell.x < 0 or cell.x >= WORLD_W or cell.y < 0 or cell.y >= WORLD_H:
        return
    var center := cursor.position
    if build_mode:
        if world.has(cell) or inventory <= 0:
            return
        var rect := Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL))
        var prect := Rect2(player.position - Vector2(17, 34), Vector2(34, 68))
        if rect.intersects(prect):
            return
        world[cell] = 2
        _load_cell(cell)
        inventory -= 1
        _burst(center, block_colors[2], 5)
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
            _burst(center, block_colors[t], 8)
    _update_labels()


# ---------------------------------------------------------------- combat

func _on_kill(e: Enemy) -> void:
    kills += 1
    _burst(e.position, Color(0.9, 0.3, 0.4), 12)
    if e is Boss:
        boss = null
        gold += 10
        _win()
    elif e is Slime:
        if randf() < 0.35:
            gold += 1
        inventory += 1
    else:
        inventory += 1
    if hp < MAX_HP and randf() < 0.3:
        hp += 1
    _update_labels()


func _attack() -> void:
    if attack_t > 0.0:
        return
    attack_t = 0.2
    for node in get_tree().get_nodes_in_group("enemies"):
        var e := node as Enemy
        if e == null:
            continue
        var dx: float = (e.position.x - player.position.x) * facing
        var dy: float = absf(e.position.y - player.position.y)
        if dx > -20.0 and dx < 100.0 + e.half.x and dy < 60.0 + e.half.y:
            e.velocity.y = -220.0
            if e.hit(damage):
                e.remove_from_group("enemies")
                e.queue_free()
                _on_kill(e)


func _hurt() -> void:
    hp -= 1
    invuln = 1.0
    shake_t = 0.25
    _burst(player.position, Color(0.9, 0.2, 0.3), 10)
    if hp <= 0:
        hp = MAX_HP
        player.position = spawn_pos
        player.velocity = Vector2.ZERO
        last_cell = Vector2i(-9999, -9999)
        _refresh()
        _show_banner("You fell... back to the start")
    _update_labels()


func _try_upgrade() -> void:
    if damage >= 4:
        _show_banner("Attack is already maxed")
        return
    var cost := damage * 3
    if gold >= cost:
        gold -= cost
        damage += 1
        _show_banner("Attack upgraded!")
    else:
        _show_banner("Need " + str(cost) + " gold")
    _update_labels()


func _win() -> void:
    won = true
    win_t = 1.0
    var layer := CanvasLayer.new()
    layer.layer = 50
    add_child(layer)
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.6)
    dim.size = Vector2(1280, 720)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(dim)
    var t1 := _add_label(layer, "VICTORY!", Vector2(0, 190), 96)
    t1.size = Vector2(1280, 120)
    t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var t2 := _add_label(layer, "The Cave King is defeated\nKills " + str(kills) + "   Gold " + str(gold) + "\n\nTap to play again", Vector2(0, 330), 38)
    t2.size = Vector2(1280, 260)
    t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# ---------------------------------------------------------------- input

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
            if won:
                if win_t <= 0.0:
                    get_tree().reload_current_scene()
                return
            if event.position.y >= BAR_Y:
                var z := _zone(event.position)
                if z == "mode":
                    build_mode = not build_mode
                    _update_labels()
                elif z == "hit":
                    _attack()
                else:
                    touches[event.index] = z
            elif event.position.x >= 1000.0 and event.position.y <= 90.0:
                _try_upgrade()
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


# ---------------------------------------------------------------- main loop

func _physics_process(delta: float) -> void:
    invuln = maxf(invuln - delta, 0.0)
    attack_t = maxf(attack_t - delta, 0.0)
    shake_t = maxf(shake_t - delta, 0.0)
    banner_t = maxf(banner_t - delta, 0.0)
    win_t = maxf(win_t - delta, 0.0)
    cursor_t = maxf(cursor_t - delta, 0.0)
    banner.modulate.a = clampf(banner_t, 0.0, 1.0)
    cursor.visible = cursor_t > 0.0
    if shake_t > 0.0:
        cam.offset = Vector2(randf_range(-7.0, 7.0), randf_range(-7.0, 7.0))
    else:
        cam.offset = Vector2.ZERO

    slash.visible = attack_t > 0.0
    if slash.visible:
        var prog := 1.0 - attack_t / 0.2
        slash.position = Vector2(34.0 * facing, -6.0)
        slash.scale = Vector2(3.0 * facing, 3.0) * (0.8 + 0.5 * prog)
        slash.modulate.a = 1.0 - prog

    var vis := 1.0
    if invuln > 0.0 and int(invuln * 12.0) % 2 == 0:
        vis = 0.35
    psprite.modulate.a = vis

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
        coyote = 0.1
    else:
        coyote = maxf(coyote - delta, 0.0)
        player.velocity.y += GRAVITY * delta
    if jump and not jump_prev:
        jump_buf = 0.12
    if jump_prev and not jump and player.velocity.y < -150.0:
        player.velocity.y *= 0.5
    jump_buf = maxf(jump_buf - delta, 0.0)
    if jump_buf > 0.0:
        if coyote > 0.0:
            player.velocity.y = JUMP_VELOCITY
            jump_buf = 0.0
            coyote = 0.0
        elif jumps_left > 0 and not player.is_on_floor():
            jumps_left -= 1
            player.velocity.y = JUMP_VELOCITY
            jump_buf = 0.0
    jump_prev = jump
    player.move_and_slide()
    player.position.x = clampf(player.position.x, 20.0, WORLD_W * CELL - 20.0)
    if player.position.y > WORLD_H * CELL + 300.0:
        player.position = spawn_pos
        player.velocity = Vector2.ZERO
    _refresh()
    _update_background()
    pdust.emitting = absf(dir) > 0.0 and player.is_on_floor()

    if use_art_knight:
        var f := 2
        if attack_t > 0.0:
            f = 3
        elif not player.is_on_floor():
            f = 4 if player.velocity.y < 0.0 else 2
        elif absf(dir) > 0.0:
            anim_t += delta * 10.0
            f = 1 + (int(anim_t) % 5)
        psprite.frame = f
        if pglow != null:
            pglow.frame = f
            pglow.flip_h = psprite.flip_h
            pglow.modulate.a = 0.5 * vis
    else:
        if absf(dir) > 0.0 and player.is_on_floor():
            anim_t += delta * 14.0
            psprite.position.y = 6.0 - absf(sin(anim_t)) * 3.0
        else:
            psprite.position.y = 6.0

    if boss != null and is_instance_valid(boss):
        var bd := player.position.distance_to(boss.position)
        boss_ui.visible = bd < 900.0
        boss_fg.size.x = 396.0 * clampf(float(boss.hp) / float(BOSS_HP), 0.0, 1.0)
    else:
        boss_ui.visible = false

    if invuln <= 0.0:
        for node in get_tree().get_nodes_in_group("enemies"):
            var e := node as Enemy
            if e == null:
                continue
            var dx: float = e.position.x - player.position.x
            var dy: float = e.position.y - player.position.y
            if absf(dx) < e.half.x + 17.0 and absf(dy) < e.half.y + 34.0:
                knock = -signf(dx) * 350.0
                player.velocity.y = -250.0
                _hurt()
                break

    if invuln <= 0.0:
        var prect := Rect2(player.position - Vector2(17, 34), Vector2(34, 68))
        for sp in spikes:
            var spv: Vector2 = sp
            var srect := Rect2(spv - Vector2(18, 10), Vector2(36, 22))
            if prect.intersects(srect):
                player.velocity.y = -380.0
                _hurt()
                break


# ---------------------------------------------------------------- enemy classes

class Enemy extends CharacterBody2D:
    var hp := 3
    var half := Vector2(16, 12)
    var flash := 0.0
    var t := 0.0
    var spr: Sprite2D

    func hit(dmg: int) -> bool:
        hp -= dmg
        flash = 0.15
        return hp <= 0

    func update_flash(delta: float) -> void:
        flash = maxf(flash - delta, 0.0)
        if spr != null:
            if flash > 0.0:
                spr.modulate = Color(1.0, 0.35, 0.35)
            else:
                spr.modulate = Color(1, 1, 1)


class Slime extends Enemy:
    var target: CharacterBody2D
    var dirn := 1.0

    func _physics_process(delta: float) -> void:
        t += delta
        update_flash(delta)
        if spr != null:
            var sq := sin(t * 6.0) * 0.25
            spr.scale = Vector2(4.0 + sq, 4.0 - sq)
        if target == null:
            return
        if absf(target.position.x - position.x) > 700.0 or absf(target.position.y - position.y) > 420.0:
            return
        var d := target.position.x - position.x
        var chasing := absf(d) < 380.0
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


class Bat extends Enemy:
    var target: CharacterBody2D
    var tex_a: Texture2D
    var tex_b: Texture2D

    func _physics_process(delta: float) -> void:
        t += delta
        update_flash(delta)
        if spr != null and tex_a != null and tex_b != null:
            if int(t * 8.0) % 2 == 0:
                spr.texture = tex_a
            else:
                spr.texture = tex_b
        if target == null:
            return
        var to := target.position - position
        if to.length() > 380.0:
            velocity = Vector2.ZERO
            return
        velocity = to.normalized() * 95.0 + Vector2(0.0, sin(t * 6.0) * 60.0)
        move_and_slide()


class Boss extends Enemy:
    var target: CharacterBody2D
    var cooldown := 1.0

    func _physics_process(delta: float) -> void:
        t += delta
        update_flash(delta)
        if target == null:
            return
        var d := target.position.x - position.x
        if absf(d) > 900.0 or absf(target.position.y - position.y) > 360.0:
            return
        if not is_on_floor():
            velocity.y += 1400.0 * delta
        else:
            velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
            velocity.y = 0.0
            if absf(d) < 800.0:
                cooldown -= delta
                if cooldown <= 0.0:
                    cooldown = 1.1
                    velocity.y = -620.0
                    velocity.x = signf(d) * 220.0
        move_and_slide()
        if spr != null:
            var sq := clampf(velocity.y / 2500.0, -0.25, 0.25)
            spr.scale = Vector2(12.0 * (1.0 - sq), 12.0 * (1.0 + sq))
