extends TextureButton
@export var shared_state: road_button_states 
func _pressed() -> void:
	shared_state.state = road_button_states.states.off
	print("Modo cambiado a: off")
