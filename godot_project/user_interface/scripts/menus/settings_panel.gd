extends Panel

@onready var audio_tab_panel: Panel = $SettingsArea/VBoxContainer/AudioTabPanel
@onready var graphics_tab_panel: Panel = $SettingsArea/VBoxContainer/GraphicsTabPanel
@onready var general_tab_panel: Panel = $SettingsArea/VBoxContainer/GeneralTabPanel

func _on_audio_tab_button_pressed() -> void:
	audio_tab_panel.visible = true
	graphics_tab_panel.visible = false
	general_tab_panel.visible = false

func _on_graphics_tab_button_pressed() -> void:
	audio_tab_panel.visible = false
	graphics_tab_panel.visible = true
	general_tab_panel.visible = false


func _on_general_tab_button_pressed() -> void:
	audio_tab_panel.visible = false
	graphics_tab_panel.visible = false
	general_tab_panel.visible = true
