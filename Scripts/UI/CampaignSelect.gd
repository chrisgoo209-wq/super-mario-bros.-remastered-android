extends Control

var selected_index := 0

signal selected
signal cancelled
var active := false

@export var campaign_icons: Array[Texture2D] = []

var old_campaign := ""

@export var campaign := ["SMB1", "SMBLL", "SMBS", "SMBANN", "Custom", "SMB1"]

## Index of the SMB2 entry (last in the list). It does not change the active campaign,
## it opens the separate SMB2 game.
const SMB2_INDEX := 5
const SMB2_SCENE := "res://Scenes/Levels/SMB2/SMB2Level.tscn"

func _ready() -> void:
	_refresh_smb2_icon()
	update()
	Global.level_theme_changed.connect(update)
	get_starting_position()
	handle_visuals()

func update() -> void:
	for icon in campaign_icons:
		var atlas_icon := icon as AtlasTexture
		if atlas_icon != null:
			atlas_icon.atlas = $ResourceGetter.get_resource(atlas_icon.atlas)

func _process(_delta: float) -> void:
	if active:
		handle_input()
		handle_visuals()

func handle_visuals() -> void:
	%Left.texture = campaign_icons[wrap(selected_index - 1, 0, campaign_icons.size())]
	%Right.texture = campaign_icons[wrap(selected_index + 1, 0, campaign_icons.size())]
	%Middle.texture = campaign_icons[selected_index]
	%BarLabel.text = generate_text()
	for i in %CampaignNames.get_child_count():
		%CampaignNames.get_child(i).visible = selected_index == i

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

## The SMB2 picture is built at runtime (it shows the characters once the player's own ROM is loaded).
func _refresh_smb2_icon() -> void:
	var icon := SMB2Icon.make()
	if campaign_icons.size() > SMB2_INDEX:
		campaign_icons[SMB2_INDEX] = icon
	else:
		campaign_icons.append(icon)

func open() -> void:
	_refresh_smb2_icon()
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
	if selected_index == SMB2_INDEX:
		Global.current_campaign = "SMB1"
		Global.transition_to_scene(SMB2_SCENE)
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
