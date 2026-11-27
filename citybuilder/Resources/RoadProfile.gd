extends Resource
class_name RoadProfile

@export var profile_name: String
@export var profile: Array[RoadPart] = []
@export var cost: float = 0.0
var width: float:
	get:
		var total: float = 0.0
		for p in profile:
			total += p.width_meters
		return total
