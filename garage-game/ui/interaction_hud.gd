class_name InteractionHUD
extends CanvasLayer

@export var interaction: InteractionController
@export var debug_enabled: bool = false

@onready var title_label: Label = $Layout/Title
@onready var detail_label: Label = $Layout/Detail
@onready var hint_label: Label = $Layout/Hint
@onready var held_label: Label = $Layout/Held
@onready var crosshair: Label = $Layout/Crosshair
@onready var debug_label: Label = $Layout/Debug
@onready var notice_label: Label = $Layout/Notice
@onready var engine_status_label: Label = $Layout/EngineStatus

var _notice_until: int = 0
var _vehicle_debug: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	interaction.context_changed.connect(_on_context_changed)
	interaction.action_feedback.connect(notify)


func _process(_delta: float) -> void:
	notice_label.visible = Time.get_ticks_msec() < _notice_until


func notify(message: String) -> void:
	notice_label.text = message
	_notice_until = Time.get_ticks_msec() + 2500


func set_engine_status(message: String, visible: bool) -> void:
	engine_status_label.text = message
	engine_status_label.visible = visible


func set_vehicle_debug(message: String) -> void:
	_vehicle_debug = message


func _on_context_changed(context: Dictionary) -> void:
	title_label.text = context.get("title", "")
	detail_label.text = context.get("detail", "")
	hint_label.text = context.get("hint", "")
	held_label.text = context.get("held", "")
	debug_label.visible = debug_enabled
	var target_debug: String = context.get("debug", "Sem alvo")
	debug_label.text = target_debug + ("\n\n" + _vehicle_debug if not _vehicle_debug.is_empty() else "")
	var color := Color(0.3, 0.95, 0.6) if context.get("available", false) else Color(0.94, 0.94, 0.91)
	crosshair.modulate = color
	hint_label.modulate = color
