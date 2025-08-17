class_name SettingsMenu
extends Control

@export var auto_hide_delay: float = 2.0

@onready var panel: Panel = $Panel

func _on_close_button_pressed() -> void:
	MenuManager.hide_menu("SettingsMenu")

func _on_settings_button_pressed() -> void:
	if MenuManager.get_active_menu() == "settingsmenu":
		MenuManager.hide_menu("SettingsMenu")
	else:
		MenuManager.show_menu("SettingsMenu")
