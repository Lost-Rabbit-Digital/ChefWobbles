class_name DumpsterSystem
extends Node3D
## Main dumpster controller that coordinates disposal and suction systems
##
## This is the primary interface that manages the overall dumpster behavior
## by delegating to specialized subsystems for suction, disposal, and audio.

## Signals for external systems
signal object_disposal_started(rigid_body: RigidBody3D)
signal object_disposal_completed(rigid_body: RigidBody3D)
signal disposal_failed(rigid_body: RigidBody3D, reason: String)

## Export settings
@export_group("System Settings")
@export var auto_setup_areas: bool = true
@export var debug_mode: bool = false

## Internal systems
@onready var disposal_handler: DisposalHandler = $DisposalHandler
@onready var suction_handler: SuctionHandler = $SuctionHandler
@onready var audio_manager: DumpsterAudioManager = $DumpsterAudioManager
@onready var trash_area: Area3D = $Base/TrashArea
@onready var suction_area: Area3D = $Base/SuctionArea

func _ready() -> void:
	_setup_systems()
	_connect_system_signals()
	_validate_setup()

func _setup_systems() -> void:
	"""Initialize all subsystems"""
	if auto_setup_areas:
		_setup_detection_areas()
	
	# Initialize subsystems with references they need
	if disposal_handler:
		disposal_handler.setup(trash_area, audio_manager)
	
	if suction_handler:
		suction_handler.setup(suction_area, trash_area, audio_manager)
	
	if audio_manager:
		audio_manager.setup()

func _setup_detection_areas() -> void:
	"""Configure Area3D nodes for detection"""
	if trash_area:
		trash_area.monitoring = true
		trash_area.monitorable = false
		trash_area.collision_mask = 1
		
	if suction_area:
		suction_area.monitoring = true
		suction_area.monitorable = false
		suction_area.collision_mask = 1

func _connect_system_signals() -> void:
	"""Connect signals between subsystems"""
	# Connect trash area to disposal handler
	if trash_area and disposal_handler:
		trash_area.body_entered.connect(disposal_handler.on_body_entered)
	
	# Connect suction area to suction handler
	if suction_area and suction_handler:
		suction_area.body_entered.connect(suction_handler.on_body_entered)
		suction_area.body_exited.connect(suction_handler.on_body_exited)
	
	# Connect disposal handler signals
	if disposal_handler:
		disposal_handler.disposal_started.connect(_on_disposal_started)
		disposal_handler.disposal_completed.connect(_on_disposal_completed)
		disposal_handler.disposal_failed.connect(_on_disposal_failed)
	
	# Connect suction to disposal (when object reaches trash area via suction)
	if suction_handler and disposal_handler:
		suction_handler.object_reached_target.connect(disposal_handler.force_dispose)

func _validate_setup() -> void:
	"""Validate system configuration"""
	var errors: Array[String] = []
	
	if not trash_area:
		errors.append("TrashArea node not found")
	if not disposal_handler:
		errors.append("DisposalHandler not found")
		
	if not suction_area and debug_mode:
		push_warning("SuctionArea not found - suction disabled")
	if not suction_handler and suction_area:
		errors.append("SuctionHandler not found but SuctionArea exists")
	if not audio_manager:
		errors.append("DumpsterAudioManager not found")
	
	for error in errors:
		push_error("DumpsterSystem: " + error)

## Signal handlers
func _on_disposal_started(rigid_body: RigidBody3D) -> void:
	# Stop any active suction when disposal begins
	if suction_handler:
		suction_handler.stop_suction(rigid_body)
	object_disposal_started.emit(rigid_body)

func _on_disposal_completed(rigid_body: RigidBody3D) -> void:
	object_disposal_completed.emit(rigid_body)

func _on_disposal_failed(rigid_body: RigidBody3D, reason: String) -> void:
	disposal_failed.emit(rigid_body, reason)

## Public API
func set_enabled(enabled: bool) -> void:
	"""Enable or disable the entire dumpster system"""
	if trash_area:
		trash_area.monitoring = enabled
	if suction_area:
		suction_area.monitoring = enabled

func is_enabled() -> bool:
	"""Check if the dumpster system is active"""
	return trash_area and trash_area.monitoring

func get_disposing_count() -> int:
	"""Get number of objects currently being disposed"""
	return disposal_handler.get_active_count() if disposal_handler else 0

func get_suctioned_count() -> int:
	"""Get number of objects currently being suctioned"""
	return suction_handler.get_active_count() if suction_handler else 0

func force_dispose_object(rigid_body: RigidBody3D) -> void:
	"""Force disposal of specific object"""
	if disposal_handler:
		disposal_handler.force_dispose(rigid_body)

func cancel_all_operations() -> void:
	"""Cancel all active disposal and suction operations"""
	if disposal_handler:
		disposal_handler.cancel_all()
	if suction_handler:
		suction_handler.cancel_all()

## Debug functions
func get_system_status() -> Dictionary:
	"""Get detailed status of all subsystems for debugging"""
	return {
		"enabled": is_enabled(),
		"disposing_count": get_disposing_count(),
		"suctioned_count": get_suctioned_count(),
		"has_disposal_handler": disposal_handler != null,
		"has_suction_handler": suction_handler != null,
		"has_audio_manager": audio_manager != null
	}
