extends Control

var selected_index := 0

signal selected
signal cancelled
var active := false

@export var campaign_icons: Array[Texture2D] = []

var old_campaign := ""

@export var campaign := ["SMB1", "SMBLL", "SMBS", "SMBANN", "Custom"]

func _ready() -> void:
	update()
	Global.level_theme_changed.connect(update)
	get_starting_position()
	handle_visuals()

func update() -> void:
	for icon in campaign_icons:
		if icon is AtlasTexture:
			icon.atlas = $ResourceGetter.get_resource(icon.atlas)

func _process(_delta: float) -> void:
	if active:
		handle_input()
		handle_visuals()

func handle_visuals() -> void:
	set_icon(%Left, wrap(selected_index - 1, 0, campaign_icons.size()))
	set_icon(%Right, wrap(selected_index + 1, 0, campaign_icons.size()))
	set_icon(%Middle, selected_index)
	%BarLabel.text = generate_text()
	for i in %CampaignNames.get_child_count():
		%CampaignNames.get_child(i).visible = selected_index == i

func set_icon(rect: TextureRect, index: int) -> void:
	rect.texture = campaign_icons[index]
	# The SMB2 icon (index 5) is a high-res picture, so it needs smooth filtering. The others are pixel art.
	if index == 5:
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	else:
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func generate_text() -> String:
	var string := ""
	string += "◄"
	for i in campaign.size():
		if i == selected_index:
			string += "┼"
		else:
			string += "-"
	string += "►"
	return string

func open() -> void:
	old_campaign = Global.current_campaign
	Global.current_game_mode = Global.GameMode.NONE
	get_starting_position()
	handle_visuals()
	show()
	await get_tree().process_frame
	active = true
	await selected
	hide()

func get_starting_position() -> void:
	if CustomLevelMenu.has_entered or selected_index == 4:
		selected_index = 4
	else:
		selected_index = campaign.find(Global.current_campaign)

func handle_input() -> void:
	if Input.is_action_just_pressed("ui_left"):
		selected_index -= 1
	if Input.is_action_just_pressed("ui_right"):
		selected_index += 1
	selected_index = wrap(selected_index, 0, campaign.size())
	Global.current_campaign = campaign[selected_index]
	if Input.is_action_just_pressed("ui_accept"):
		select()
	elif Input.is_action_just_pressed("ui_back"):
		close()
		Global.current_campaign = old_campaign
		cancelled.emit()
		return

func select() -> void:
	CustomLevelMenu.has_entered = false
	if selected_index == 4:
		Global.current_campaign = "SMB1"
		Global.transition_to_scene("res://Scenes/Levels/CustomLevelMenu.tscn")
		return
	if selected_index == 5:
		# SMB2 entry. TODO: hook the SMB2 game scene in here.
		Global.current_campaign = old_campaign
		return
	active = false
	Settings.file.game.campaign = Global.current_campaign
	SaveManager.apply_save(SaveManager.load_save(campaign[selected_index]))
	if Global.current_campaign != "SMBANN":
		SpeedrunHandler.load_best_times()
	Settings.save_settings()
	selected.emit()
	hide()
	if old_campaign != Global.current_campaign:
		Global.freeze_screen()
		ResourceSetter.cache.clear()
		ResourceSetterNew.cache.clear()
		Global.level_theme_changed.emit()
		for i in 2:
			await get_tree().process_frame
		Global.close_freeze()

func close() -> void:
	CustomLevelMenu.has_entered = false
	active = false
	hide()
