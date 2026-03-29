extends Node2D
var drawing: bool = false
var start_key: Vector2 
var end_key: Vector2
var control_key: Vector2 = Vector2.ZERO
var current_mouse_pos: Vector2
var clic_count: int = 0
var roads: Array[RoadSegment] = [] 
var nodes: Dictionary = {} 
var astar:AStar2D = AStar2D.new()
var next_id: int = 0
const snap_dist: float = 16.0
@export var SharedRoadMode: RoadMode

func _unhandled_input(event: InputEvent) -> void:
	snap_mouse()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				if clic_count == 0:
					drawing = true
					start_key = current_mouse_pos
					clic_count = 1
					queue_redraw()
					return
				elif clic_count == 1:
					if SharedRoadMode.modes == SharedRoadMode.RoadModes. straight:
						drawing = false
						end_key = current_mouse_pos
						if start_key.distance_to(end_key) > snap_dist:
							make_roads(get_or_create_node(start_key), get_or_create_node(end_key))
						clic_count = 0
						queue_redraw()
						return
					else:
						drawing = true
						control_key = current_mouse_pos
						clic_count = 2
						queue_redraw()
						return
				elif clic_count == 2:
					drawing = false
					end_key = current_mouse_pos
					if start_key.distance_to(end_key) > snap_dist:
						make_curve(get_or_create_node(start_key),control_key, get_or_create_node(end_key))
					clic_count = 0
					queue_redraw()
					return
	if event is InputEventMouseMotion:
		if drawing:
			queue_redraw()

func get_or_create_node(pos: Vector2) -> RoadNode:
	var grid_pos:Vector2 = pos.snapped(Vector2(0.5, 0.5))
	if nodes.has(grid_pos):
		return nodes[grid_pos]
	var new_node:RoadNode = RoadNode.new()
	new_node.pos = grid_pos
	new_node.id = next_id 
	astar.add_point(new_node.id, grid_pos)
	next_id += 1
	nodes[grid_pos] = new_node
	return new_node

func create_segment(s_node:RoadNode, e_node:RoadNode) -> RoadSegment:
	if s_node == e_node or s_node.pos.distance_to(e_node.pos) < 1.0:
		return null
	for r in s_node.roads:
		if (r.start == s_node and r.end == e_node) or (r.start == e_node and r.end == s_node):
			return r
	var new_seg:RoadSegment = RoadSegment.new()
	new_seg.start = s_node
	new_seg.end = e_node
	s_node.roads.append(new_seg)
	e_node.roads.append(new_seg)
	roads.append(new_seg)
	astar.connect_points(s_node.id, e_node.id, true)
	return new_seg

func delete_segment(segment:RoadSegment) -> void:
	if segment == null: return
	if segment.start and segment.end:
		astar.disconnect_points(segment.start.id, segment.end.id)
	roads.erase(segment)
	if segment.start: segment.start.roads.erase(segment)
	if segment.end: segment.end.roads.erase(segment)

func _draw() -> void:
	for r: RoadSegment in roads:
		draw_line(r.start.pos, r.end.pos, Color.GRAY, 10.0)
	var default_font: Font = ThemeDB.get_fallback_font()
	var font_size: int = 16
	var gray_circle_color: Color = Color(0.5, 0.5, 0.5, 0.6)
	for pos: Vector2 in nodes:
		var node: RoadNode = nodes[pos]
		var road_count: int = node.roads.size()
		if road_count == 2:
			draw_circle(node.pos, 3.0, gray_circle_color)
		else:
			var text: String = str(road_count)
			var text_pos: Vector2 = node.pos + Vector2(10, -10)
			draw_circle(node.pos, 5.0, Color.YELLOW)
			draw_string(default_font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	if drawing:
		if clic_count == 1:
			draw_line(start_key, current_mouse_pos, Color(0.5, 0.5, 1.0, 0.7), 10.0)
			draw_circle(start_key, 6.0, Color.WHITE)
		elif clic_count == 2:
			var preview_curve: Curve2D = setup_curve(start_key, control_key, current_mouse_pos)
			var preview_points: PackedVector2Array = preview_curve.get_baked_points()
			if preview_points.size() > 1:
				draw_polyline(preview_points, Color(0.5, 1.0, 0.5, 0.7), 10.0)
			draw_circle(start_key, 6.0, Color.WHITE)
			draw_circle(control_key, 4.0, Color.ORANGE)
			draw_circle(current_mouse_pos, 6.0, Color.WHITE)

func make_roads(s_node:RoadNode, e_node:RoadNode) -> void:
	var temp_seg:RoadSegment = RoadSegment.new()
	temp_seg.start = s_node
	temp_seg.end = e_node
	var current_junctions:Array[Vector2] = detect_junctions(temp_seg)
	if current_junctions.is_empty():
		var New_Seg:RoadSegment = create_segment(s_node, e_node)
	else:
		current_junctions.sort_custom(func(a:Vector2,b:Vector2) -> bool:
			return a.distance_to(s_node.pos) < b.distance_to(s_node.pos)
		)
		var last_end:RoadNode = s_node
		for j: Vector2 in current_junctions:
			var roads_to_split_now: Array[RoadSegment] = []
			
			for r: RoadSegment in roads.duplicate():
				var closest: Vector2 = Geometry2D.get_closest_point_to_segment(j, r.start.pos, r.end.pos)
				if closest.distance_to(j) < 1.0:
					if not roads_to_split_now.has(r):
						roads_to_split_now.append(r)
			for r in roads_to_split_now:
				split_roads(r, j)
			var j_node:RoadNode = get_or_create_node(j)
			if last_end != j_node:
				create_segment(last_end, j_node)
				last_end = j_node
		create_segment(last_end, e_node)

func snap_mouse() -> void:
	var mouse_pos:Vector2 = get_global_mouse_position()
	var closest_id:int = astar.get_closest_point(mouse_pos)
	if closest_id != -1:
		var node_pos:Vector2 = astar.get_point_position(closest_id)
		if mouse_pos.distance_to(node_pos) <= snap_dist:
			current_mouse_pos = node_pos
			return 
	current_mouse_pos = mouse_pos 
	for r:RoadSegment in roads:
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(current_mouse_pos, r.start.pos, r.end.pos)
		if closest.distance_to(mouse_pos) <= snap_dist:
			current_mouse_pos = closest

func detect_junctions(segment: RoadSegment) -> Array:
	var junctions:Array[Vector2] = []
	var temp_juncs:Array[Vector2] = []
	for r:RoadSegment in roads:
		var stoo_close:bool = false
		var etoo_close:bool = false
		var X_hit:Variant = Geometry2D.segment_intersects_segment(r.start.pos, r.end.pos, segment.start.pos, segment.end.pos)
		if X_hit != null:
			if not temp_juncs.has(X_hit):
				temp_juncs.append(X_hit)
				continue
		var closest_start:Vector2 = Geometry2D.get_closest_point_to_segment(segment.start.pos, r.start.pos, r.end.pos)
		if closest_start.distance_to(r.start.pos) < snap_dist or closest_start.distance_to(r.end.pos) < snap_dist:
			stoo_close = true
		var closest_end:Vector2 = Geometry2D.get_closest_point_to_segment(segment.end.pos, r.start.pos, r.end.pos)
		if closest_end.distance_to(r.start.pos) < snap_dist or closest_end.distance_to(r.end.pos) < snap_dist:
			etoo_close = true
		if closest_start.distance_to(segment.start.pos) <= 1.0 and !stoo_close:
			if not temp_juncs.has(closest_start):
				temp_juncs.append(closest_start)
		if closest_end.distance_to(segment.end.pos) <= 1.0 and !etoo_close:
			if not temp_juncs.has(closest_end):
				temp_juncs.append(closest_end)
	for j in temp_juncs:
		if not junctions.has(j):
			junctions.append(j)
	return junctions

func split_roads(segment: RoadSegment, point: Vector2) -> void:
	var seg_length: float = segment.start.pos.distance_to(segment.end.pos)
	var dynamic_limit: float = snap_dist if seg_length > (snap_dist * 2.0) else 2.0
	
	if point.distance_to(segment.start.pos) < dynamic_limit or point.distance_to(segment.end.pos) < dynamic_limit:
		return
		
	create_segment(segment.start, get_or_create_node(point))
	create_segment(get_or_create_node(point), segment.end)
	delete_segment(segment)

func get_curve_point(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var curve:Curve2D = Curve2D.new()
	curve.add_point(p0)
	var relative_control:Vector2 = p1 - p2 
	curve.add_point(p2, relative_control)
	var total_dist:Variant = curve.get_baked_length()
	return curve.sample_baked(t * total_dist)

func make_curve(start: RoadNode, control: Vector2, end: RoadNode) -> void:
	var mi_curva: Curve2D = setup_curve(start.pos, control, end.pos)
	var points: PackedVector2Array = mi_curva.get_baked_points()
	var last_node: RoadNode = start
	for i: int in range(1, points.size()):
		var current_point: Vector2 = points[i]
		if i == points.size() - 1:
			current_point = end.pos
		var new_node: RoadNode = get_or_create_node(current_point)
		make_roads(last_node, new_node)
		last_node = new_node

func setup_curve(start: Vector2, control: Vector2, end: Vector2) -> Curve2D:
	var c:Curve2D = Curve2D.new()
	c.add_point(start)
	c.add_point(end, control - end, Vector2.ZERO)
	c.bake_interval = 16
	return c
