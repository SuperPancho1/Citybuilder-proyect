extends Resource
class_name RoadSegment

var start: Nodes
var end: Nodes
var control_p:Vector2
var profiles:Array[RoadProfile] = []
var current_profile: RoadProfile
var start_level
var end_level
