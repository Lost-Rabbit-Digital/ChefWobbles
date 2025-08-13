class_name DumpsterSystem
extends Node3D
## Main dumpster controller that coordinates disposal and suction systems
##
## This is the primary interface that manages the overall dumpster behavior
## by delegating to specialized subsystems for suction, disposal, and audio.

## Signals for external systems
signal object_entered_suction(rigid_body: RigidBody3D)
signal object_dropped_in_dumpster(rigid_body: RigidBody3D)
signal object_disposal_started(rigid_body: RigidBody3D)
signal object_disposal_completed(rigid_body: RigidBody3D)
signal disposal_failed(rigid_body: RigidBody3D, reason: String)
signal dumpster_opened()
signal dumpster_closed()

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
	# Connect trash area to disposal handler (for direct drops)
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
		disposal_handler.object_dropped_in_dumpster.connect(_on_object_dropped)
	
	# Connect suction handler signals
	if suction_handler:
		suction_handler.suction_started.connect(_on_suction_started)
		suction_handler.object_reached_target.connect(disposal_handler.force_dispose)
		suction_handler.dumpster_opened.connect(_on_dumpster_opened)
		suction_handler.dumpster_closed.connect(_on_dumpster_closed)

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
func _on_suction_started(rigid_body: RigidBody3D) -> void:
	"""Handle when object enters suction"""
	object_entered_suction.emit(rigid_body)
	if debug_mode:
		print("DumpsterSystem: Object entered suction - ", rigid_body.name)

func _on_object_dropped(rigid_body: RigidBody3D) -> void:
	"""Handle when object is dropped in dumpster (waiting for disposal)"""
	object_dropped_in_dumpster.emit(rigid_body)
	if debug_mode:
		print("DumpsterSystem: Object dropped in dumpster - ", rigid_body.name)

func _on_disposal_started(rigid_body: RigidBody3D) -> void:
	"""Handle when disposal animation begins"""
	# Stop any active suction when disposal begins
	if suction_handler:
		suction_handler.stop_suction(rigid_body)
	
	object_disposal_started.emit(rigid_body)
	if debug_mode:
		print("DumpsterSystem: Disposal started - ", rigid_body.name)

func _on_disposal_completed(rigid_body: RigidBody3D) -> void:
	"""Handle when disposal is completed"""
	object_disposal_completed.emit(rigid_body)
	if debug_mode:
		print("DumpsterSystem: Disposal completed - ", rigid_body.name)

func _on_disposal_failed(rigid_body: RigidBody3D, reason: String) -> void:
	"""Handle when disposal fails"""
	disposal_failed.emit(rigid_body, reason)
	if debug_mode:
		print("DumpsterSystem: Disposal failed - ", rigid_body.name, " Reason: ", reason)

func _on_dumpster_opened() -> void:
	"""Handle when dumpster opens (lids removed)"""
	dumpster_opened.emit()
	if debug_mode:
		print("DumpsterSystem: Dumpster opened - suction enabled")

func _on_dumpster_closed() -> void:
	"""Handle when dumpster closes (lids present)"""
	dumpster_closed.emit()
	if debug_mode:
		print("DumpsterSystem: Dumpster closed - suction disabled")

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

func get_pending_disposal_count() -> int:
	"""Get number of objects waiting to be disposed"""
	return disposal_handler.get_pending_count() if disposal_handler else 0

func get_suctioned_count() -> int:
	"""Get number of objects currently being suctioned"""
	return suction_handler.get_active_count() if suction_handler else 0

func is_dumpster_open() -> bool:
	"""Check if dumpster is open (no lids blocking suction)"""
	return suction_handler.is_dumpster_open() if suction_handler else true

func get_lid_count() -> int:
	"""Get number of lids currently in suction area"""
	return suction_handler.get_lid_count() if suction_handler else 0

func get_lids_in_area() -> Array[RigidBody3D]:
	"""Get array of lids currently in suction area"""
	return suction_handler.get_lids_in_area() if suction_handler else []

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

func force_dumpster_state(open: bool) -> void:
	"""Force dumpster open/closed state (for testing/special cases)"""
	if suction_handler:
		suction_handler.force_dumpster_state(open)

func refresh_lid_detection() -> void:
	"""Manually refresh lid detection (useful after scene changes)"""
	if suction_handler:
		suction_handler.refresh_lid_detection()

## Configuration
func set_disposal_wait_time(min_time: float, max_time: float) -> void:
	"""Configure the wait time range before disposal starts"""
	if disposal_handler:
		disposal_handler.min_wait_time = min_time
		disposal_handler.max_wait_time = max_time

func set_plop_timing(timing: float) -> void:
	"""Set when the plop sound plays (0.0 to 1.0 of disposal animation)"""
	if disposal_handler:
		disposal_handler.plop_sound_timing = clamp(timing, 0.0, 1.0)

## Debug functions
func get_system_status() -> Dictionary:
	"""Get detailed status of all subsystems for debugging"""
	return {
		"enabled": is_enabled(),
		"dumpster_open": is_dumpster_open(),
		"lid_count": get_lid_count(),
		"disposing_count": get_disposing_count(),
		"pending_disposal_count": get_pending_disposal_count(),
		"suctioned_count": get_suctioned_count(),
		"has_disposal_handler": disposal_handler != null,
		"has_suction_handler": suction_handler != null,
		"has_audio_manager": audio_manager != null,
		"total_active_objects": get_disposing_count() + get_pending_disposal_count() + get_suctioned_count()
	}

func get_flow_summary() -> String:
	"""Get a summary of the current dumpster flow state"""
	var suctioned = get_suctioned_count()
	var pending = get_pending_disposal_count()
	var disposing = get_disposing_count()
	var status = "OPEN" if is_dumpster_open() else "CLOSED"
	
	return "Dumpster: %s | Suction: %d | Waiting: %d | Disposing: %d" % [status, suctioned, pending, disposing]

func get_lid_status_summary() -> String:
	"""Get detailed lid status for debugging"""
	if not suction_handler:
		return "No suction handler available"
	
	var lid_names: Array[String] = []
	for lid in get_lids_in_area():
		lid_names.append(lid.name if lid else "Invalid")
	
	var status = "OPEN" if is_dumpster_open() else "CLOSED"
	return "Dumpster %s - %d lids: [%s]" % [status, get_lid_count(), ", ".join(lid_names)]
