class_name SMB2Mob
extends Node2D
## Enemies and throwable objects for the SMB2 level. Placeholder art is drawn
## in code until the enemy graphics banks are mapped.

enum Kind { SHYGUY, TWEETER, VEG }
enum Mode { WALK, THROWN, CARRIED, DEAD }

const GRAVITY := 900.0

var kind: Kind = Kind.SHYGUY
var mode: Mode = Mode.WALK
var vel := Vector2.ZERO
var dir := -1
var alive := true
var lvl: SMB2Level
var hop_timer := 0.6
var hop_count := 0

func half_w() -> float:
	return 5.0 if kind == Kind.VEG else 6.0

func height() -> float:
	return 10.0 if kind == Kind.VEG else 14.0

func rect() -> Rect2:
	return Rect2(position.x - half_w(), position.y - height(), half_w() * 2.0, height())

func kill(from_dir: int) -> void:
	mode = Mode.DEAD
	vel = Vector2(from_dir * 60.0, -200.0)

func step(dt: float) -> void:
	match mode:
		Mode.WALK:
			_walk(dt)
		Mode.THROWN:
			_thrown(dt)
		Mode.DEAD:
			vel.y += GRAVITY * dt
			position += vel * dt
			rotation += 10.0 * dt * signf(vel.x if vel.x != 0.0 else 1.0)
			if position.y > SMB2Level.H * SMB2Level.TILE + 64:
				alive = false
		Mode.CARRIED:
			pass
	queue_redraw()

func _walk(dt: float) -> void:
	vel.y += GRAVITY * dt
	if kind == Kind.SHYGUY:
		vel.x = 24.0 * dir
	else:
		hop_timer -= dt
		if hop_timer <= 0.0 and is_on_floor_cached:
			hop_count = (hop_count + 1) % 3
			vel.y = -230.0 if hop_count == 0 else -140.0
			hop_timer = 0.7
		vel.x = 30.0 * dir if not is_on_floor_cached else 0.0
	var r := lvl.move_box(position, half_w(), height(), vel, dt, true)
	position = r.pos
	vel = r.vel
	is_on_floor_cached = r.on_floor
	if r.hit_x:
		dir = -dir
	elif kind == Kind.SHYGUY and r.on_floor:
		# turn around at ledges
		var ahead_x := position.x + dir * (half_w() + 2.0)
		var tx := int(floor(ahead_x / SMB2Level.TILE))
		var ty := int(floor(position.y / SMB2Level.TILE))
		if not lvl.is_solid(tx, ty) and lvl.tile_at(tx, ty) != SMB2Level.CLOUD:
			dir = -dir
	if position.y > SMB2Level.H * SMB2Level.TILE + 32:
		alive = false

var is_on_floor_cached := false

func _thrown(dt: float) -> void:
	vel.y += 800.0 * dt
	var r := lvl.move_box(position, half_w(), height(), vel, dt, false)
	position = r.pos
	vel = r.vel
	# knock out anything we hit
	for m in lvl.mobs:
		if m != self and m.mode == Mode.WALK and m.rect().intersects(rect()):
			m.kill(signi(int(vel.x)) if vel.x != 0.0 else dir)
			alive = false
			return
	if r.hit_x or r.on_floor or r.hit_head or position.y > SMB2Level.H * SMB2Level.TILE + 32:
		alive = false

func _draw() -> void:
	var f := float(dir)
	match kind:
		Kind.SHYGUY:
			draw_rect(Rect2(-6, -14, 12, 11), Color8(200, 40, 40))
			draw_rect(Rect2(-6 if dir < 0 else 0, -12, 6, 7), Color8(250, 250, 250))
			draw_rect(Rect2(-4 if dir < 0 else 2, -10, 2, 2), Color.BLACK)
			draw_rect(Rect2(-6, -3, 5, 3), Color8(90, 30, 20))
			draw_rect(Rect2(1, -3, 5, 3), Color8(90, 30, 20))
		Kind.TWEETER:
			draw_circle(Vector2(0, -8), 7, Color8(236, 110, 160))
			draw_colored_polygon(PackedVector2Array([Vector2(f * 5, -9), Vector2(f * 11, -7), Vector2(f * 5, -5)]), Color8(250, 200, 60))
			draw_circle(Vector2(f * 2, -11), 1.5, Color.BLACK)
			draw_rect(Rect2(-4, -2, 3, 2), Color8(250, 200, 60))
			draw_rect(Rect2(1, -2, 3, 2), Color8(250, 200, 60))
		Kind.VEG:
			draw_circle(Vector2(0, -4), 5, Color8(250, 210, 220))
			draw_colored_polygon(PackedVector2Array([Vector2(-3, -8), Vector2(0, -12), Vector2(3, -8)]), Color8(60, 170, 40))
