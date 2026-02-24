extends TextureButton
@export var shared_state: road_button_states 
func _pressed() -> void:
	shared_state.state = road_button_states.states.straight
	print("Modo cambiado a: STRAIGHT")
