extends TextureButton

@export var SharedRoadMode:RoadMode
func _on_pressed() -> void:
	SharedRoadMode.modes = SharedRoadMode.RoadModes.straight
	print("Modo cambio a recta")
