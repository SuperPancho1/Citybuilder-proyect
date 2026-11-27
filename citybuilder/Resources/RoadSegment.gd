extends Resource
class_name RoadSegment

var start:RoadNode
var end:RoadNode
enum slope_types {ramp, flat}
var slope:slope_types = slope_types.flat
var id:int
var points:Array[Vector2] = []
var profile: RoadProfile
