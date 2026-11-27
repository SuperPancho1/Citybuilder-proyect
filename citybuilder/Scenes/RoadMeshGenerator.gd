extends Node2D
class_name RoadMeshGenerator
@onready var pixels_per_meter:float = get_parent().pixels_per_meter
@export var texture_tile_meters: float = 2.0

var road_meshes: Dictionary = {}
