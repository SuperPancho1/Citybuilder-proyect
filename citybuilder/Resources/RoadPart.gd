extends Resource
class_name RoadPart

enum PartType {
	GENERAL_LANE,
	BUS_LANE,
	FREIGHT_LANE,
	FAST_LANE,

	TRAIN_TRACK,
	TRAM_TRACK,
	METRO_TRACK,

	SIDEWALK,
	BIKE_LANE,

	PARKING,
	MEDIAN,
	SHOULDER
}

@export var type: PartType = PartType.GENERAL_LANE
@export var width_meters: float = 3.5
@export var speed_limit_kmh: float = 50.0
@export var bidirectional: bool = false
@export var texture: Texture2D
