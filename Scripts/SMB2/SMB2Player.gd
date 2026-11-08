class_name SMB2Player
extends Node2D
## Super Mario Bros. 2 style player: four characters, pull veggies, lift and
## throw enemies, climb vines. Position is the centre of the feet.

const CHAR_STATS := {
	"mario": {"jump": -390.0, "speed": 88.0, "pull": 0.30, "float": false},
	"luigi": {"jump": -470.0, "speed": 88.0, "pull": 0.30, "float": false},
	"toad":  {"jump": -350.0, "speed": 92.0, "pull": 0.10, "float": false},
	"peach": {"jump": -390.0, "speed": 80.0, "pull": 0.30, "float": true},
}
const GRAVITY := 1500.0
const HALF_W := 6.0
const STAND_H := 26.0
const DUCK_H := 14.0
const MAX_FLOAT := 1.2

var lvl: SMB2Level
var char_id := "mario"
var frames := {}
var stats: Dictionary

var vel := Vector2.ZERO
var facing := 1
var on_floor := false
var ducking := false
var climbing := false
var carried: SMB2Mob = null
var standing_on: SMB2Mob = null
var pull_time := 0.0
var float_time := 0.0
var anim_time := 0.0
var invuln := 0.0
var star := 0.0
var hearts := 2
var max_hearts := 2

func setup(level: SMB2Level, id: String) -> void:
	lvl = level
	char_id = id
	stats = CHAR_STATS[id]
	frames = SMB2Rom.build_frames(id)

func body_h() -> float:
	return DUCK_H if ducking else STAND_H

func rect() -> Rect2:
	return Rect2(position.x - HALF_W, position.y - body_h(), HALF_W * 2.0, body_h())

func step(dt: float) -> void:
	var left := Input.is_action_pressed("move_left_0")
	var right := Input.is_action_pressed("move_right_0")
	var up := Input.is_action_pressed("move_up_0")
	var down := Input.is_action_pressed("move_down_0")
	var jump_pressed := Input.is_action_just_pressed("jump_0")
	var jump_held := Input.is_action_pressed("jump_0")
	var act_pressed := Input.is_action_just_pressed("run_0") or Input.is_action_just_pressed("action_0")
	var axis := int(right) - int(left)

	invuln = maxf(invuln - dt, 0.0)
	star = maxf(star - dt, 0.0)
	anim_time += dt

	if climbing:
		_climb(dt, up, down, axis, jump_pressed)
		_finish(dt)
		return

	# --- ducking / pulling vegetables ---
	var want_duck := down and on_floor and carried == null
	if want_duck and not ducking:
		ducking = true
	elif not want_duck and ducking:
		var head_tile_y := int(floor((position.y - STAND_H) / SMB2Level.TILE))
		var tx := int(floor(position.x / SMB2Level.TILE))
		if not lvl.is_solid(tx, head_tile_y):
			ducking = false
	if ducking and carried == null:
		var tx := int(floor(position.x / SMB2Level.TILE))
		var ty := int(floor((position.y - 1.0) / SMB2Level.TILE))
		if lvl.tile_at(tx, ty) == SMB2Level.TUFT:
			pull_time += dt
			if pull_time >= stats.pull:
				pull_time = 0.0
				lvl.set_tile(tx, ty, SMB2Level.EMPTY)
				carried = lvl.spawn_mob(SMB2Mob.Kind.VEG, position)
				carried.mode = SMB2Mob.Mode.CARRIED
		else:
			pull_time = 0.0
	else:
		pull_time = 0.0

	# --- horizontal movement ---
	var speed: float = stats.speed
	if ducking:
		axis = 0
	var accel := 700.0 if on_floor else 450.0
	if axis != 0:
		facing = axis
		vel.x = move_toward(vel.x, axis * speed, accel * dt)
	else:
		vel.x = move_toward(vel.x, 0.0, (800.0 if on_floor else 150.0) * dt)

	# --- vine ---
	if up and not ducking:
		var vt := lvl.vine_at(position)
		if vt != Vector2i(-1, -1):
			climbing = true
			vel = Vector2.ZERO
			position.x = vt.x * SMB2Level.TILE + SMB2Level.TILE * 0.5
			_finish(dt)
			return

	# --- jumping / floating ---
	if jump_pressed and on_floor and not ducking:
		vel.y = stats.jump
		on_floor = false
	vel.y += GRAVITY * dt
	if stats["float"] and not on_floor and vel.y > 0.0 and jump_held and float_time < MAX_FLOAT:
		vel.y = 25.0
		float_time += dt
	if on_floor:
		float_time = 0.0

	# --- move ---
	var r := lvl.move_box(position, HALF_W, body_h(), vel, dt, true)
	position = r.pos
	vel = r.vel
	on_floor = r.on_floor

	# --- standing on enemies ---
	standing_on = null
	if vel.y >= 0.0 or on_floor:
		for m in lvl.mobs:
			if m.mode != SMB2Mob.Mode.WALK:
				continue
			var mr := m.rect()
			var overlap_x: bool = absf(m.position.x - position.x) < (HALF_W + m.half_w() - 1.0)
			if overlap_x and position.y >= mr.position.y - 2.0 and position.y <= mr.position.y + 8.0 and vel.y >= 0.0:
				position.y = mr.position.y
				vel.y = 0.0
				on_floor = true
				standing_on = m
				break

	# --- lift / throw ---
	if act_pressed:
		if carried != null:
			_throw(up)
		elif standing_on != null:
			carried = standing_on
			carried.mode = SMB2Mob.Mode.CARRIED
			standing_on = null

	# --- enemy contact ---
	if standing_on == null:
		for m in lvl.mobs:
			if m.mode == SMB2Mob.Mode.WALK and m.rect().intersects(rect()):
				if star > 0.0:
					m.kill(facing)
				else:
					_hurt()
				break

	_finish(dt)

func _climb(dt: float, up: bool, down: bool, axis: int, jump_pressed: bool) -> void:
	var vy := (-1 if up else 0) + (1 if down else 0)
	position.y += vy * 55.0 * dt
	var vt := lvl.vine_at(position - Vector2(0, 2))
	if vt == Vector2i(-1, -1) and vy < 0:
		# reached the top of the vine: hop off
		climbing = false
		vel = Vector2((axis if axis != 0 else 1) * 60.0, -330.0)
		return
	if jump_pressed:
		climbing = false
		facing = axis if axis != 0 else facing
		vel = Vector2(axis * 70.0, stats.jump * 0.7)
		return
	if down and lvl.is_solid(int(floor(position.x / SMB2Level.TILE)), int(floor(position.y / SMB2Level.TILE))):
		climbing = false

func _throw(up: bool) -> void:
	var m := carried
	carried = null
	m.mode = SMB2Mob.Mode.THROWN
	m.dir = facing
	m.position = position + Vector2(facing * 8.0, -STAND_H)
	m.vel = Vector2(facing * 150.0, -260.0 if up else -140.0)

func _hurt() -> void:
	if invuln > 0.0:
		return
	hearts -= 1
	invuln = 2.0
	vel = Vector2(-facing * 90.0, -200.0)
	on_floor = false
	if hearts <= 0:
		lvl.player_died()

func _finish(dt: float) -> void:
	if carried != null:
		carried.position = position + Vector2(0, -STAND_H)
	if position.y > SMB2Level.H * SMB2Level.TILE + 24:
		lvl.player_died()
	queue_redraw()

func _pose() -> String:
	var holding := carried != null
	if ducking:
		return "duck"
	if climbing:
		return "carry_jump" if int(anim_time * 6.0) % 2 == 0 else "jump"
	if not on_floor:
		return "carry_jump" if holding else "jump"
	if absf(vel.x) > 8.0:
		var alt := int(anim_time * 10.0) % 2 == 0
		if holding:
			return "carry_walk" if alt else "carry"
		return "walk" if alt else "stand"
	return "carry" if holding else "stand"

func _draw() -> void:
	if frames.is_empty():
		return
	if invuln > 0.0 and int(invuln * 20.0) % 2 == 0:
		return
	var tex: Texture2D = frames[_pose()]
	if facing < 0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	draw_texture(tex, Vector2(-8, -32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if star > 0.0:
		draw_rect(Rect2(-8, -32, 16, 32), Color(1, 1, 0.4, 0.25))
