class_name SMB2Level
extends Node2D
## SMB2-style World 1-1 recreation (original layout built from a reference map,
## NOT read from the ROM). Player sprites are ripped from the user's own ROM at
## runtime; everything else is placeholder art drawn in code for now.

const TILE := 16
const W := 132
const H := 15
const GROUND_ROW := 13
const TITLE_SCENE := "res://Scenes/Levels/TitleScreen.tscn"

# tile ids
const EMPTY := 0
const SAND := 1
const GRASS := 2
const LOG := 3
const CLOUD := 4
const WATER := 5
const VINE := 6
const TUFT := 7
const GOAL := 8

# Game states are plain ints on purpose: SMB2Level, SMB2Mob and SMB2Player reference each
# other, and Godot treats an enum declared here as two different types in that cycle.
const S_NO_ROM := 0
const S_SELECT := 1
const S_PLAY := 2
const S_DEAD := 3
const S_CLEAR := 4
const S_OVER := 5

const SKY := Color8(60, 188, 252)

var grid := PackedByteArray()
var state: int = S_NO_ROM
var state_time := 0.0
var select_index := 0
var lives := 3
var cherries := 0
var chosen := "mario"
var cherry_pos := {}          # Vector2i -> true

var player: SMB2Player
var mobs: Array[SMB2Mob] = []
var camera: Camera2D
var hud: Node2D
var preview_frames := {}      # char id -> stand texture
var picker = null             # Android file picker plugin, if present
var rom_error := ""
var rom_unverified := false
var _last_pick_ms := 0

const TUFT_COLUMNS := [4, 12, 16, 29, 36, 44, 52, 57, 62, 75, 81, 86, 101, 112]
const CHERRY_SPOTS := [[9, 9], [15, 10], [25, 8], [37, 9], [45, 9], [55, 8], [64, 9], [76, 7], [85, 10], [98, 6]]
const MOB_SPAWNS := [
	["shyguy", 7], ["shyguy", 14], ["shyguy", 22], ["tweeter", 28], ["shyguy", 44], ["shyguy", 47],
	["shyguy", 56], ["tweeter", 60], ["shyguy", 63], ["shyguy", 75], ["tweeter", 82], ["shyguy", 85],
	["shyguy", 99], ["tweeter", 120], ["shyguy", 124],
]

## Visible area in game pixels. The window stretches with aspect "expand", so on a phone
## or tablet this is wider than the 256x240 NES screen.
func view_size() -> Vector2:
	var s := get_viewport_rect().size
	return Vector2(maxf(s.x, 256.0), maxf(s.y, 240.0))

func _ready() -> void:
	if Global.has_node("GameHUD"):
		Global.get_node("GameHUD").hide()
	build_grid()
	camera = Camera2D.new()
	camera.position = Vector2(view_size().x * 0.5, 120)
	add_child(camera)
	camera.make_current()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = Node2D.new()
	hud.draw.connect(_draw_hud)
	layer.add_child(hud)
	get_window().files_dropped.connect(_on_files_dropped)
	var osc := get_node_or_null("/root/OnScreenControls")
	if osc:
		osc.set("should_show", true)
	_setup_picker.call_deferred()
	if SMB2Rom.find_rom() != "":
		enter_select()
	else:
		state = S_NO_ROM
		if osc:
			osc.set("should_show", false)

func _setup_picker() -> void:
	await get_tree().physics_frame
	if Engine.has_singleton("GodotFilePicker"):
		picker = Engine.get_singleton("GodotFilePicker")
		picker.file_picked.connect(_on_file_picked)

func _exit_tree() -> void:
	if Global.has_node("GameHUD"):
		Global.get_node("GameHUD").show()
	var osc := get_node_or_null("/root/OnScreenControls")
	if osc:
		osc.set("should_show", true)

# ---------------------------------------------------------------- level data
func set_tile(x: int, y: int, t: int) -> void:
	if x >= 0 and x < W and y >= 0 and y < H:
		grid[y * W + x] = t

func tile_at(x: int, y: int) -> int:
	if x < 0 or x >= W:
		return SAND
	if y < 0 or y >= H:
		return EMPTY
	return grid[y * W + x]

func is_solid(x: int, y: int) -> bool:
	var t := tile_at(x, y)
	return t == SAND or t == GRASS or t == LOG

func vine_at(p: Vector2) -> Vector2i:
	var tx := int(floor(p.x / TILE))
	var ty := int(floor((p.y - 8.0) / TILE))
	if tile_at(tx, ty) == VINE:
		return Vector2i(tx, ty)
	return Vector2i(-1, -1)

func surface_row(x: int) -> int:
	for y in H:
		if is_solid(x, y):
			return y
	return H

func hill(x0: int, x1: int, top: int) -> void:
	for x in range(x0, x1 + 1):
		for y in range(top, GROUND_ROW):
			set_tile(x, y, GRASS)

func build_grid() -> void:
	grid.resize(W * H)
	grid.fill(EMPTY)
	for x in W:
		set_tile(x, GROUND_ROW, SAND)
		set_tile(x, GROUND_ROW + 1, SAND)
	# water gaps crossed by log bridges
	for gap in [[34, 39], [66, 70]]:
		for x in range(gap[0], gap[1] + 1):
			set_tile(x, GROUND_ROW, WATER)
			set_tile(x, GROUND_ROW + 1, WATER)
			set_tile(x, GROUND_ROW - 1, LOG)
	# hills
	hill(8, 10, 11)
	hill(18, 26, 11)
	hill(21, 24, 10)
	hill(31, 33, 11)
	hill(40, 43, 11)
	hill(41, 42, 10)
	hill(50, 53, 11)
	hill(54, 57, 10)
	hill(58, 61, 11)
	hill(72, 78, 11)
	hill(74, 77, 10)
	hill(75, 76, 9)
	hill(88, 92, 11)
	hill(90, 94, 10)
	hill(92, 106, 8)
	# vine up the side of the tall hill, cloud walkway, goal ledge
	for y in range(4, GROUND_ROW):
		set_tile(107, y, VINE)
	for x in range(108, 114):
		set_tile(x, 3, CLOUD)
	for x in range(115, 132):
		for y in range(4, GROUND_ROW):
			set_tile(x, y, GRASS)
	set_tile(127, 3, GOAL)
	# vegetable tufts sit on whatever surface is below them
	for x in TUFT_COLUMNS:
		var s := surface_row(x)
		if s > 0 and tile_at(x, s - 1) == EMPTY:
			set_tile(x, s - 1, TUFT)
	for c in CHERRY_SPOTS:
		cherry_pos[Vector2i(c[0], c[1])] = true

# ---------------------------------------------------------------- physics
## Axis-separated tile collision for a feet-anchored box.
func move_box(p: Vector2, half_w: float, h: float, v: Vector2, dt: float, oneway: bool) -> Dictionary:
	var on_floor := false
	var hit_x := false
	var hit_head := false
	# horizontal
	p.x += v.x * dt
	var ty0 := int(floor((p.y - h) / TILE))
	var ty1 := int(floor((p.y - 0.01) / TILE))
	if v.x > 0.0:
		var tx := int(floor((p.x + half_w) / TILE))
		for ty in range(ty0, ty1 + 1):
			if is_solid(tx, ty):
				p.x = tx * TILE - half_w - 0.001
				v.x = 0.0
				hit_x = true
				break
	elif v.x < 0.0:
		var tx := int(floor((p.x - half_w) / TILE))
		for ty in range(ty0, ty1 + 1):
			if is_solid(tx, ty):
				p.x = (tx + 1) * TILE + half_w + 0.001
				v.x = 0.0
				hit_x = true
				break
	# vertical
	var prev_bottom := p.y
	p.y += v.y * dt
	var tx0 := int(floor((p.x - half_w + 0.01) / TILE))
	var tx1 := int(floor((p.x + half_w - 0.01) / TILE))
	if v.y >= 0.0:
		var ty := int(floor(p.y / TILE))
		for tx in range(tx0, tx1 + 1):
			var landing := is_solid(tx, ty)
			if not landing and oneway and tile_at(tx, ty) == CLOUD and prev_bottom <= ty * TILE + 0.01:
				landing = true
			if landing:
				p.y = ty * TILE
				v.y = 0.0
				on_floor = true
				break
	else:
		var ty := int(floor((p.y - h) / TILE))
		for tx in range(tx0, tx1 + 1):
			if is_solid(tx, ty):
				p.y = (ty + 1) * TILE + h
				v.y = 0.0
				hit_head = true
				break
	return {"pos": p, "vel": v, "on_floor": on_floor, "hit_x": hit_x, "hit_head": hit_head}

# ---------------------------------------------------------------- flow
func _on_files_dropped(files: PackedStringArray) -> void:
	if state != S_NO_ROM:
		return
	for f in files:
		if _try_rom(f):
			return

func _on_file_picked(temp_path: String, _mime: String) -> void:
	if state == S_NO_ROM:
		_try_rom(temp_path)
	DirAccess.remove_absolute(temp_path)

## Checks a candidate file, stores it for next launch and moves on to character select.
func _try_rom(path: String) -> bool:
	var data := FileAccess.get_file_as_bytes(path)
	var why := SMB2Rom.validate(data)
	if why != "":
		rom_error = why
		return false
	if not SMB2Rom.load_from_path(path):
		rom_error = "COULD NOT READ THAT FILE"
		return false
	SMB2Rom.remember_rom(path)
	rom_error = ""
	enter_select()
	return true

func _input(event: InputEvent) -> void:
	if state != S_NO_ROM or picker == null:
		return
	# touch also emulates a mouse click, so debounce to avoid opening the picker twice
	var tapped: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)
	if tapped and Time.get_ticks_msec() - _last_pick_ms > 1500:
		_last_pick_ms = Time.get_ticks_msec()
		picker.openFilePicker("*/*")

func enter_select() -> void:
	state = S_SELECT
	lives = 3
	rom_unverified = not SMB2Rom.signature_ok
	var osc := get_node_or_null("/root/OnScreenControls")
	if osc:
		osc.set("should_show", true)
	for id in SMB2Rom.CHARACTER_ORDER:
		preview_frames[id] = SMB2Rom.build_frames(id)["stand"]

func start_play(id: String) -> void:
	chosen = id
	cherries = 0
	reset_stage()

func reset_stage() -> void:
	for m in mobs:
		m.queue_free()
	mobs.clear()
	if player:
		player.queue_free()
	player = SMB2Player.new()
	add_child(player)
	player.setup(self, chosen)
	player.position = Vector2(2 * TILE + 8, GROUND_ROW * TILE)
	for s in MOB_SPAWNS:
		var kind := SMB2Mob.Kind.SHYGUY if s[0] == "shyguy" else SMB2Mob.Kind.TWEETER
		var x: int = s[1]
		spawn_mob(kind, Vector2(x * TILE + 8, surface_row(x) * TILE))
	state = S_PLAY
	state_time = 0.0

func spawn_mob(kind: SMB2Mob.Kind, pos: Vector2) -> SMB2Mob:
	var m := SMB2Mob.new()
	m.kind = kind
	m.lvl = self
	m.position = pos
	add_child(m)
	mobs.append(m)
	return m

func player_died() -> void:
	if state != S_PLAY:
		return
	lives -= 1
	state = S_DEAD if lives > 0 else S_OVER
	state_time = 0.0

func _physics_process(dt: float) -> void:
	state_time += dt
	# START (pause) leaves the level. Do NOT use ui_back / ui_cancel: the on-screen B button
	# presses ui_back, and B is also lift/throw.
	if Input.is_action_just_pressed("pause"):
		Global.transition_to_scene(TITLE_SCENE)
		return
	match state:
		S_SELECT:
			_select_input()
		S_PLAY:
			_play(dt)
		S_DEAD:
			if state_time > 1.5:
				player.hearts = player.max_hearts
				reset_stage()
		S_OVER, S_CLEAR:
			if state_time > 1.0 and (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump_0")):
				if state == S_OVER:
					enter_select()
				else:
					Global.transition_to_scene(TITLE_SCENE)
	_update_camera()
	queue_redraw()
	hud.queue_redraw()

func _select_input() -> void:
	if Input.is_action_just_pressed("ui_left"):
		select_index = wrapi(select_index - 1, 0, 4)
	if Input.is_action_just_pressed("ui_right"):
		select_index = wrapi(select_index + 1, 0, 4)
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump_0"):
		start_play(SMB2Rom.CHARACTER_ORDER[select_index])

func _play(dt: float) -> void:
	player.step(dt)
	for m in mobs:
		m.step(dt)
	for i in range(mobs.size() - 1, -1, -1):
		if not mobs[i].alive:
			if player.carried == mobs[i]:
				player.carried = null
			mobs[i].queue_free()
			mobs.remove_at(i)
	# cherries
	var pc := Vector2i(int(floor(player.position.x / TILE)), int(floor((player.position.y - 12.0) / TILE)))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c := pc + Vector2i(dx, dy)
			if cherry_pos.has(c):
				var centre := Vector2(c.x * TILE + 8, c.y * TILE + 8)
				if centre.distance_to(player.position - Vector2(0, 12)) < 12.0:
					cherry_pos.erase(c)
					cherries += 1
					if cherries % 5 == 0:
						player.star = 10.0
	# goal
	if tile_at(int(floor(player.position.x / TILE)), int(floor((player.position.y - 8.0) / TILE))) == GOAL:
		state = S_CLEAR
		state_time = 0.0

func _update_camera() -> void:
	var vw := view_size().x
	var cx := 0.0
	if state == S_PLAY or state == S_DEAD or state == S_OVER or state == S_CLEAR:
		if player:
			cx = clampf(player.position.x - vw * 0.5, 0.0, maxf(W * TILE - vw, 0.0))
	camera.position = Vector2(cx + vw * 0.5, 120.0)

# ---------------------------------------------------------------- drawing
func _draw() -> void:
	var vs := view_size()
	var cam_x := camera.position.x - vs.x * 0.5 if camera else 0.0
	draw_rect(Rect2(cam_x, 120.0 - vs.y * 0.5, vs.x, vs.y), SKY)
	var x0 := maxi(int(floor(cam_x / TILE)), 0)
	var x1 := mini(x0 + int(ceil(vs.x / TILE)) + 1, W - 1)
	for x in range(x0, x1 + 1):
		for y in H:
			var t := tile_at(x, y)
			if t != EMPTY:
				_draw_tile(t, x, y)
	for c in cherry_pos:
		var p := Vector2(c.x * TILE + 8, c.y * TILE + 8)
		if p.x > cam_x - 16 and p.x < cam_x + vs.x + 16:
			draw_circle(p + Vector2(-2, 2), 3.5, Color8(220, 30, 40))
			draw_circle(p + Vector2(3, 3), 3.5, Color8(220, 30, 40))
			draw_line(p + Vector2(-2, -1), p + Vector2(1, -6), Color8(60, 130, 30), 1.0)
			draw_line(p + Vector2(3, 0), p + Vector2(1, -6), Color8(60, 130, 30), 1.0)

func _is_grass(x: int, y: int) -> bool:
	return tile_at(x, y) == GRASS or tile_at(x, y) == SAND

func _draw_tile(t: int, x: int, y: int) -> void:
	var r := Rect2(x * TILE, y * TILE, TILE, TILE)
	match t:
		SAND:
			if y == GROUND_ROW:
				draw_rect(r, Color8(228, 156, 60))
				draw_rect(Rect2(r.position, Vector2(TILE, 4)), Color8(60, 170, 40))
				draw_rect(Rect2(r.position + Vector2(0, 4), Vector2(TILE, 1)), Color8(30, 100, 20))
			else:
				draw_rect(r, Color8(176, 110, 40))
				draw_rect(Rect2(r.position + Vector2(4, 6), Vector2(2, 2)), Color8(140, 84, 30))
				draw_rect(Rect2(r.position + Vector2(11, 11), Vector2(2, 2)), Color8(140, 84, 30))
		GRASS:
			draw_rect(r, Color8(56, 176, 36))
			for i in 4:
				draw_line(r.position + Vector2(i * 5 - 2, TILE), r.position + Vector2(i * 5 + 6, TILE - 8), Color8(30, 120, 24), 1.0)
			var dark := Color8(10, 60, 10)
			if not _is_grass(x, y - 1):
				draw_rect(Rect2(r.position, Vector2(TILE, 1)), dark)
			if not _is_grass(x - 1, y):
				draw_rect(Rect2(r.position, Vector2(1, TILE)), dark)
			if not _is_grass(x + 1, y):
				draw_rect(Rect2(r.position + Vector2(TILE - 1, 0), Vector2(1, TILE)), dark)
		LOG:
			draw_rect(r, Color8(190, 60, 40))
			draw_rect(Rect2(r.position + Vector2(0, 5), Vector2(TILE, 2)), Color8(120, 30, 20))
			draw_rect(Rect2(r.position + Vector2(0, 11), Vector2(TILE, 2)), Color8(120, 30, 20))
		CLOUD:
			draw_rect(Rect2(r.position, Vector2(TILE, 6)), Color.WHITE)
			draw_rect(Rect2(r.position + Vector2(0, 6), Vector2(TILE, 1)), Color8(180, 200, 240))
		WATER:
			draw_rect(r, Color8(40, 70, 220))
			if tile_at(x, y - 1) != WATER:
				for i in 4:
					draw_rect(Rect2(r.position + Vector2(i * 4, 0), Vector2(2, 2)), Color.WHITE)
		VINE:
			draw_line(r.position + Vector2(8, 0), r.position + Vector2(8, TILE), Color8(40, 130, 30), 2.0)
			draw_rect(Rect2(r.position + Vector2(9, 4), Vector2(4, 3)), Color8(60, 170, 40))
			draw_rect(Rect2(r.position + Vector2(3, 10), Vector2(4, 3)), Color8(60, 170, 40))
		TUFT:
			var g := Color8(20, 110, 20)
			draw_line(r.position + Vector2(4, 16), r.position + Vector2(3, 10), g, 2.0)
			draw_line(r.position + Vector2(8, 16), r.position + Vector2(8, 9), g, 2.0)
			draw_line(r.position + Vector2(12, 16), r.position + Vector2(13, 10), g, 2.0)
		GOAL:
			draw_rect(Rect2(r.position + Vector2(2, 0), Vector2(12, 16)), Color8(150, 40, 190))
			draw_rect(Rect2(r.position + Vector2(4, 2), Vector2(8, 14)), Color8(40, 0, 60))
			draw_circle(r.position + Vector2(10, 9), 1.0, Color8(255, 220, 80))

func _text(s: String, y: float, size := 8, col := Color.WHITE) -> void:
	hud.draw_string(ThemeDB.fallback_font, Vector2(0, y), s, HORIZONTAL_ALIGNMENT_CENTER, view_size().x, size, col)

func _draw_heart(p: Vector2, full: bool) -> void:
	var c := Color8(240, 40, 60) if full else Color8(60, 20, 30)
	hud.draw_circle(p + Vector2(-2, 0), 2.6, c)
	hud.draw_circle(p + Vector2(2, 0), 2.6, c)
	hud.draw_colored_polygon(PackedVector2Array([p + Vector2(-4.6, 1), p + Vector2(4.6, 1), p + Vector2(0, 6)]), c)

func _draw_hud() -> void:
	var vs := view_size()
	match state:
		S_NO_ROM:
			hud.draw_rect(Rect2(0, 0, vs.x, vs.y), Color.BLACK)
			_text("SUPER MARIO BROS. 2", 80, 12)
			if OS.has_feature("android"):
				_text("TAP THE SCREEN TO CHOOSE YOUR", 120, 8)
				_text("SMB2 (USA) .NES ROM", 132, 8)
			else:
				_text("DROP YOUR SMB2 (USA) .NES ROM", 120, 8)
				_text("ONTO THIS WINDOW", 132, 8)
			if rom_error != "":
				_text(rom_error, 150, 8, Color8(255, 90, 90))
			_text("(NO ROM DATA IS INCLUDED IN THIS GAME)", 170, 8, Color(0.6, 0.6, 0.6))
			_text("START / ESC: BACK", 200, 8, Color(0.6, 0.6, 0.6))
		S_SELECT:
			var ox := (vs.x - 256.0) * 0.5
			hud.draw_rect(Rect2(0, 0, vs.x, vs.y), Color.BLACK)
			_text("CHOOSE YOUR CHARACTER", 50, 10)
			for i in 4:
				var id: String = SMB2Rom.CHARACTER_ORDER[i]
				var x := ox + 40.0 + i * 56.0
				var tex: Texture2D = preview_frames[id]
				hud.draw_texture(tex, Vector2(x, 100))
				var col := Color.WHITE if i == select_index else Color(0.45, 0.45, 0.45)
				var nm: String = SMB2Rom.CHARACTERS[id].name
				var nw := ThemeDB.fallback_font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
				hud.draw_string(ThemeDB.fallback_font, Vector2(x + 8.0 - nw * 0.5, 150), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
				if i == select_index:
					hud.draw_colored_polygon(PackedVector2Array([Vector2(x + 4, 90), Vector2(x + 12, 90), Vector2(x + 8, 96)]), Color.YELLOW)
			_text("LEFT / RIGHT + JUMP", 190, 8, Color(0.7, 0.7, 0.7))
			_text("START: BACK", 204, 8, Color(0.5, 0.5, 0.5))
			if rom_unverified:
				_text("ROM NOT RECOGNISED", 220, 8, Color8(255, 200, 80))
				_text("SPRITES MAY LOOK WRONG", 232, 8, Color8(255, 200, 80))
		_:
			if player == null:
				return
			hud.draw_string(ThemeDB.fallback_font, Vector2(8, 14), "%s  x%d" % [SMB2Rom.CHARACTERS[chosen].name, lives], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
			for i in player.max_hearts:
				_draw_heart(Vector2(16 + i * 12, 26), i < player.hearts)
			hud.draw_string(ThemeDB.fallback_font, Vector2(0, 14), "CHERRIES %d" % cherries, HORIZONTAL_ALIGNMENT_RIGHT, vs.x - 8.0, 8, Color.WHITE)
			hud.draw_string(ThemeDB.fallback_font, Vector2(0, 26), "WORLD 1-1", HORIZONTAL_ALIGNMENT_RIGHT, vs.x - 8.0, 8, Color.WHITE)
			if state == S_PLAY and state_time < 6.0:
				_text("DOWN ON GRASS: PULL VEGGIE", 200, 8, Color(1, 1, 1, 0.9))
				_text("B: LIFT / THROW   UP: VINE", 212, 8, Color(1, 1, 1, 0.9))
				_text("START: EXIT", 224, 8, Color(1, 1, 1, 0.9))
			if state == S_DEAD:
				_text("TRY AGAIN", 120, 10)
			if state == S_OVER:
				_text("GAME OVER", 110, 12)
				_text("PRESS JUMP", 130, 8)
			if state == S_CLEAR:
				_text("COURSE CLEAR!", 110, 12, Color.YELLOW)
				_text("PRESS JUMP", 130, 8)
