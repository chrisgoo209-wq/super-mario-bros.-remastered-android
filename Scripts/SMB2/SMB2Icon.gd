class_name SMB2Icon
extends RefCounted
## Builds the 68x68 picture shown for SMB2 on the Select Game screen.
## It is drawn in code (a big "2"), and if the player's own SMB2 ROM has already been
## loaded the four playable characters are drawn along the bottom from that ROM.
## No Nintendo artwork is shipped with the project.

const SIZE := 68
const TWO := ["01110", "10001", "00001", "00010", "00100", "01000", "11111"]
const CHAR_ORDER := ["mario", "luigi", "toad", "peach"]

static func make() -> ImageTexture:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color8(16, 16, 16))
	img.fill_rect(Rect2i(1, 1, SIZE - 2, SIZE - 2), Color8(200, 44, 36))
	img.fill_rect(Rect2i(1, SIZE - 36, SIZE - 2, 35), Color8(252, 188, 60))
	_draw_two(img, 26, 8, 3)
	# Characters from the player's own ROM, only if it is already loaded.
	if not SMB2Rom.chr.is_empty():
		var x := 2
		for id in CHAR_ORDER:
			var tex := SMB2Rom.make_frame(id, SMB2Rom.POSES["stand"], [false, false, false, false])
			img.blend_rect(tex.get_image(), Rect2i(0, 0, 16, 32), Vector2i(x, SIZE - 34))
			x += 16
	return ImageTexture.create_from_image(img)

static func _draw_two(img: Image, ox: int, oy: int, scale: int) -> void:
	for pass_i in 2:
		var shadow := pass_i == 0
		var col := Color8(16, 16, 16) if shadow else Color8(255, 255, 255)
		var off := scale if shadow else 0
		for row in TWO.size():
			for column in 5:
				if TWO[row][column] == "1":
					img.fill_rect(Rect2i(ox + column * scale + off, oy + row * scale + off, scale, scale), col)
