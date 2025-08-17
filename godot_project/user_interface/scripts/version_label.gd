class_name VersionDisplay
extends Control

func _ready() -> void:
	display_version()

func display_version() -> void:
	var version = ProjectSettings.get_setting("application/config/version")
	self.text = "v." + version
