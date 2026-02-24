extends Resource
class_name RoadPart

@export var color:Color = Color.GRAY
@export var width:float = 2.0
enum Type{Sidewalk, Trees, Lane, Parking}
@export var type:Type = Type.Sidewalk
@export var dir: int = 1
