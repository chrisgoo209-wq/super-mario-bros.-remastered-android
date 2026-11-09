class_name SMB2Rom
extends RefCounted
## Loads a user-supplied Super Mario Bros. 2 (USA) NES ROM and rips the player
## graphics from it at runtime. No Nintendo data is shipped with this project.
## Offsets come from the Data Crystal ROM map; every offset is a FILE offset
## (iNES header included).

const ROM_NAME := "smb2.nes"
const EXPECTED_SIZE := 262160          # 16 header + 128K PRG + 128K CHR
const SIGNATURE_OFFSET := 0x1FE10      # sprite-set table for worlds 1-7
const SIGNATURE := [0x0C, 0x0D, 0x0C, 0x0E, 0x0C, 0x0D]
const CHR_FILE_OFFSET := 0x20010

## 2C02 master palette as RGB triples.
const NES_RGB: PackedByteArray = [84,84,84,0,30,116,8,16,144,48,0,136,68,0,100,92,0,48,84,4,0,60,24,0,32,42,0,8,58,0,0,64,0,0,60,0,0,50,60,0,0,0,0,0,0,0,0,0,152,150,152,8,76,196,48,50,236,92,30,228,136,20,176,160,20,100,152,34,32,120,60,0,84,90,0,40,114,0,8,124,0,0,118,40,0,102,120,0,0,0,0,0,0,0,0,0,236,238,236,76,154,236,120,124,236,176,98,236,228,84,236,236,88,180,236,106,100,212,136,32,160,170,0,116,196,0,76,208,32,56,204,108,56,180,204,60,60,60,0,0,0,0,0,0,236,238,236,168,204,236,188,188,236,212,178,236,236,174,236,236,174,212,236,180,176,228,196,144,204,210,120,180,222,120,168,226,144,152,226,180,160,214,228,160,162,160,0,0,0,0,0,0]

## Characters: byte offset of the 2KB CHR bank, tile offset inside it, and the
## three sprite colours (NES palette indices) from the ROM at 0x1443A+.
const CHARACTERS := {
	"mario": {"bank": 0x000, "tile": 0x00, "pal": [0x01, 0x16, 0x27], "name": "MARIO"},
	"luigi": {"bank": 0x000, "tile": 0x40, "pal": [0x01, 0x2A, 0x36], "name": "LUIGI"},
	"toad":  {"bank": 0x800, "tile": 0x40, "pal": [0x01, 0x30, 0x27], "name": "TOAD"},
	"peach": {"bank": 0x800, "tile": 0x00, "pal": [0x06, 0x25, 0x36], "name": "PEACH"},
}
const CHARACTER_ORDER := ["mario", "luigi", "toad", "peach"]

## Poses: four 8x16 sprites (top-left, top-right, bottom-left, bottom-right).
## Tile numbers are from the character animation table at 0x1F2F0. -1 = blank.
## Poses = the ROM's own pose table (frames 0-9, read from a screenshot of the sprite viewer).
## Each pose is 4 tile bytes: top-left, top-right, bottom-left, bottom-right (8x16 each).
## -1 = blank (the ROM uses $FB). The table is shared by all four characters; each character
## only has different graphics.
const POSES := {
	"stand":       [0x00, 0x02, 0x04, 0x06],   # frame 0
	"carry":       [0x0C, 0x0E, 0x10, 0x12],   # frame 1
	"walk":        [0x00, 0x02, 0x08, 0x0A],   # frame 2
	"carry_walk":  [0x0C, 0x0E, 0x14, 0x16],   # frame 3
	"duck":        [-1, -1, 0x2C, 0x2C],       # frame 4 (right half is the left half mirrored)
	"duck_carry":  [-1, -1, 0x2E, 0x2E],       # frame 5
	"jump":        [0x0C, 0x0E, 0x10, 0x12],   # frame 6 (fist up, same tiles as carry)
	"carry_jump":  [0x0C, 0x0E, 0x10, 0x12],
	"climb_a":     [0x30, 0x30, 0x32, 0x32],   # frame 7 (back view, right half mirrored)
	"climb_b":     [0x30, 0x30, 0x32, 0x32],   # frame 7 with the mirroring swapped
	"hurt":        [0x20, 0x22, 0x24, 0x26],   # frame 8
	"lift":        [0x00, 0x02, 0x28, 0x2A],   # frame 9 (reaching down to pull / pick up)
}
const POSE_FLIPS := {
	"duck": [false, false, false, true],
	"duck_carry": [false, false, false, true],
	"climb_a": [false, true, false, true],
	"climb_b": [true, false, true, false],
}

## The game's own pose table (4 tile bytes per frame: top-left, top-right, bottom-left,
## bottom-right), copied from the player's ROM at runtime. Used by the sprite viewer.
const POSE_TABLE_OFFSET := 0x1F2F4
const POSE_TABLE_BYTES := 0x100

static var chr := PackedByteArray()
static var pose_table := PackedByteArray()
static var rom_path := ""

static var signature_ok := true

## Returns "" when the file looks like an SMB2 (USA) ROM, otherwise a short reason.
## The data signature is only advisory: if size, header and mapper match, the ROM is
## accepted and signature_ok tells the UI to warn that the sprites may look wrong.
static func validate(data: PackedByteArray) -> String:
	if data.size() < 16:
		return "NOT A ROM FILE"
	if data[0] != 0x4E or data[1] != 0x45 or data[2] != 0x53 or data[3] != 0x1A:
		return "NOT AN NES ROM (.NES)"
	if data.size() != EXPECTED_SIZE:
		return "WRONG SIZE: %d BYTES (NEED %d)" % [data.size(), EXPECTED_SIZE]
	if data[4] != 8 or data[5] != 16 or (data[6] >> 4) != 4:
		return "NOT SUPER MARIO BROS. 2 (USA)"
	return ""

static func has_signature(data: PackedByteArray) -> bool:
	for i in SIGNATURE.size():
		if data[SIGNATURE_OFFSET + i] != SIGNATURE[i]:
			return false
	return true

static func is_valid(data: PackedByteArray) -> bool:
	return validate(data) == ""

static func load_from_path(path: String) -> bool:
	var data := FileAccess.get_file_as_bytes(path)
	if not is_valid(data):
		return false
	signature_ok = has_signature(data)
	chr = data.slice(CHR_FILE_OFFSET)
	pose_table = data.slice(POSE_TABLE_OFFSET, POSE_TABLE_OFFSET + POSE_TABLE_BYTES)
	rom_path = path
	return true

static func find_rom() -> String:
	if not chr.is_empty():
		return rom_path
	var candidates: Array[String] = []
	var args := OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "-smb2rom" and i + 1 < args.size():
			candidates.append(args[i + 1].replace("\\", "/"))
	candidates.append(Global.config_path.path_join(ROM_NAME))
	var exe_dir := OS.get_executable_path().get_base_dir()
	var dir := DirAccess.open(exe_dir)
	if dir:
		for f in dir.get_files():
			if f.to_lower().ends_with(".nes"):
				candidates.append(exe_dir.path_join(f))
	for c in candidates:
		if FileAccess.file_exists(c) and load_from_path(c):
			return c
	return ""

## Copies a dropped ROM next to the other game config so it is found next launch.
static func remember_rom(path: String) -> void:
	var dest := ProjectSettings.globalize_path(Global.config_path.path_join(ROM_NAME))
	DirAccess.copy_absolute(path, dest)

static func nes_color(index: int) -> Color:
	var i := (index & 0x3F) * 3
	return Color8(NES_RGB[i], NES_RGB[i + 1], NES_RGB[i + 2])

static func _blit_tile(img: Image, offset: int, ox: int, oy: int, pal: Array[Color], flip: bool) -> void:
	if offset < 0 or offset + 16 > chr.size():
		return
	for y in 8:
		var b0 := chr[offset + y]
		var b1 := chr[offset + y + 8]
		for x in 8:
			var bit := 7 - x
			var v := ((b0 >> bit) & 1) | (((b1 >> bit) & 1) << 1)
			if v > 0:
				var px := 7 - x if flip else x
				img.set_pixel(ox + px, oy + y, pal[v - 1])

static func make_frame(char_id: String, tiles: Array, flips: Array) -> ImageTexture:
	var def: Dictionary = CHARACTERS[char_id]
	var pal: Array[Color] = []
	for c in def.pal:
		pal.append(nes_color(c))
	var img := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	for k in 4:
		var t: int = tiles[k]
		if t < 0:
			continue
		var ox: int = (k % 2) * 8
		var oy: int = (k >> 1) * 16
		for half in 2:
			var offset: int = int(def.bank) + (t + int(def.tile) + half) * 16
			_blit_tile(img, offset, ox, oy + half * 8, pal, flips[k])
	return ImageTexture.create_from_image(img)

## Tile bytes of frame `index` from the ROM's pose table, or [] past the end.
static func table_frame(index: int) -> Array:
	var o := index * 4
	if o + 4 > pose_table.size():
		return []
	return [pose_table[o], pose_table[o + 1], pose_table[o + 2], pose_table[o + 3]]

static func build_frames(char_id: String) -> Dictionary:
	var frames := {}
	for pose in POSES:
		var flips: Array = POSE_FLIPS.get(pose, [false, false, false, false])
		frames[pose] = make_frame(char_id, POSES[pose], flips)
	return frames
