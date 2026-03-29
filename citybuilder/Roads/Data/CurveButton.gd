extends TextureButton

@export var SharedRoadMode:RoadMode
func _pressed() -> void:
	print("Modo cambiado a: CURVE")
	SharedRoadMode.modes = SharedRoadMode.RoadModes.curve
