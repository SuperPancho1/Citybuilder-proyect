extends Node2D
class_name GraphManager

const pixels_per_meter: float = 16.0

var current_mouse_pos: Vector2 
var nodes: Dictionary = {} 
const SNAP_DIST: float = 24.0
var astar: AStar2D = AStar2D.new()
var start_node: RoadNode
var roads: Dictionary = {} 
var road_id: int = 0
const CHUNK_SIZE: float = 8192.0 
var chunks: Dictionary = {} 
var current_tool_mode: RoadToolMode
var straight_start_node: RoadNode = null
var clic_count: int = 0
enum RoadToolMode {
	STRAIGHT,
	CURVE,
	DELETE,
	CANCEL
}
var curve_step: int = 0  
var curve_start_node: RoadNode = null
var curve_control_pos: Vector2 = Vector2.ZERO

const MIN_HEIGHT: int = -15
const MAX_HEIGHT: int = 15

var current_height: int = 0
var visible_height: int = 0

func change_height(amount: int) -> void:
	current_height = clampi(
		current_height + amount,
		MIN_HEIGHT,
		MAX_HEIGHT
	)
	visible_height = current_height
	print("Altura actual: ", current_height, " m")
	queue_redraw()

func activate_straight_mode() -> void:
	current_tool_mode = RoadToolMode.STRAIGHT
	print("Modo seleccionado: STRAIGHT")

func activate_curve_mode() -> void:
	current_tool_mode = RoadToolMode.CURVE
	print("Modo seleccionado: CURVE")

func activate_delete_mode() -> void:
	current_tool_mode = RoadToolMode.DELETE
	print("Modo seleccionado: DELETE")

func handle_cancel_action() -> void:
	current_tool_mode = RoadToolMode.CANCEL
	print("Acción: CANCEL")

func _process(_delta: float) -> void:
	current_mouse_pos = get_global_mouse_position()
	if (current_tool_mode == RoadToolMode.CURVE and curve_step > 0) or \
	   (current_tool_mode == RoadToolMode.STRAIGHT and straight_start_node != null):
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				activate_straight_mode()
				reset_curve_state()
			KEY_F2:
				activate_curve_mode()
			KEY_F3:
				activate_delete_mode()
				reset_curve_state()
			KEY_F4:
				handle_cancel_action()
				reset_curve_state()
				straight_start_node = null
			KEY_R:
				change_height(1)
			KEY_F:
				change_height(-1)

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			handle_left_click()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			straight_start_node = null
			reset_curve_state()
			print("Selección de herramienta cancelada.")

func handle_left_click() -> void:
	match current_tool_mode:
		RoadToolMode.STRAIGHT:
			handle_straight_mode_click()
		RoadToolMode.CURVE:
			handle_curve_mode_click()
		RoadToolMode.DELETE:
			print("Modo delete aún no implementado en el clic.")
		RoadToolMode.CANCEL:
			print("Herramienta en estado cancelado.")

func handle_curve_mode_click() -> void:
	match curve_step:
		0:
			curve_start_node = get_or_create_node(current_mouse_pos)
			curve_step = 1
			print("Modo Curva: Nodo inicial fijado. Haz clic para el punto de control.")
		1:
			curve_control_pos = current_mouse_pos
			curve_step = 2
			print("Modo Curva: Punto de control fijado. Haz clic en el nodo de destino.")
		2:
			var curve_end_node = get_or_create_node(current_mouse_pos)
			
			if curve_start_node != curve_end_node:
				make_curve_roads(curve_start_node, curve_control_pos, curve_end_node)
				print("¡Calle curva creada!")
			else:
				print("No puedes conectar una curva al mismo nodo.")
				
			reset_curve_state()
			print("Listo para trazar otra curva.")

func reset_curve_state() -> void:
	curve_step = 0
	curve_start_node = null
	curve_control_pos = Vector2.ZERO

func handle_straight_mode_click() -> void:
	if straight_start_node == null:
		straight_start_node = get_or_create_node(current_mouse_pos)
		print("Modo Recto: Nodo inicial fijado. Haz clic en el destino.")
	else:
		var end_node = get_or_create_node(current_mouse_pos)
		
		if straight_start_node != end_node:
			make_straight_roads(straight_start_node, end_node)
			print("¡Calle recta creada!")
		else:
			print("No puedes conectar una calle al mismo nodo.")
		
		straight_start_node = null
		print("Listo para trazar otra calle recta.")

func get_or_create_node(pos: Vector2) -> RoadNode:
	var existing_node = snap_to_nodes(pos)
	if existing_node != null:
		print("Reutilizando nodo existente ID: ", existing_node.id)
		return existing_node
	else:
		pos = snap_to_segments(pos)
	
	var new_node = RoadNode.new()
	new_node.pos = pos 
	var node_id = astar.get_available_point_id()
	new_node.id = node_id
	new_node.height = float(current_height)
	astar.add_point(node_id, new_node.pos)
	nodes[node_id] = new_node 
	print("Nuevo nodo creado con ID: ", node_id)
	return new_node

func snap_to_nodes(target_pos: Vector2 = current_mouse_pos) -> RoadNode:
	if astar.get_point_count() == 0:
		return null
	var closest_id: int 
	var closest: RoadNode = null
	var disconected: Array[int] = []
	while true:
		closest_id = astar.get_closest_point(target_pos)
		if closest_id == -1:
			break
		if nodes[closest_id].pos.distance_squared_to(target_pos) > SNAP_DIST*SNAP_DIST:
			break
		if nodes[closest_id].height != current_height:
			astar.set_point_disabled(closest_id, true)
			if not disconected.has(closest_id):
				disconected.append(closest_id)
		if nodes[closest_id].height == current_height:
			closest = nodes[closest_id]
			break
	for id in disconected:
		astar.set_point_disabled(id, false)
	return closest

func snap_to_segments(target_pos: Vector2) -> Vector2:
	var search_rect = Rect2(target_pos - Vector2(SNAP_DIST, SNAP_DIST), Vector2(SNAP_DIST * 2, SNAP_DIST * 2))
	var touched_chunks = get_chunks_covered_by_rect(search_rect)
	var visited_ids = {}
	
	var closest_point: Vector2 = target_pos
	var min_dist_sq: float = SNAP_DIST * SNAP_DIST
	
	for chunk_coord in touched_chunks:
		if not chunks.has(chunk_coord):
			continue
		
		for r_id in chunks[chunk_coord]:
			if visited_ids.has(r_id):
				continue
			visited_ids[r_id] = true
			
			var seg: RoadSegment = roads[r_id]
			if not seg or seg.points.is_empty():
				continue
				
			for p in range(seg.points.size() - 1):
				var c = seg.points[p]
				var d = seg.points[p + 1]
				var closest_pt = Geometry2D.get_closest_point_to_segment(target_pos, c, d)
				
				if closest_pt.distance_squared_to(seg.start.pos) <= SNAP_DIST * SNAP_DIST or \
				   closest_pt.distance_squared_to(seg.end.pos) <= SNAP_DIST * SNAP_DIST:
					continue
					
				var dist_sq = target_pos.distance_squared_to(closest_pt)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_point = closest_pt
					
	return closest_point

func create_segment(s_node: RoadNode, e_node: RoadNode) -> RoadSegment:
	if s_node == e_node:
		return null
	road_id += 1
	var new_seg: RoadSegment = RoadSegment.new()
	new_seg.start = s_node
	new_seg.end = e_node
	
	new_seg.points = [s_node.pos, e_node.pos]
	
	if new_seg.start.height != new_seg.end.height:
		new_seg.slope = RoadSegment.slope_types.ramp
	else:
		new_seg.slope = RoadSegment.slope_types.flat
		
	roads[road_id] = new_seg
	s_node.roads.append(new_seg)
	e_node.roads.append(new_seg)
	s_node.conections.append(e_node)
	e_node.conections.append(s_node)
	new_seg.id = road_id
	astar.connect_points(s_node.id, e_node.id, true)
	
	register_segment_in_chunks(new_seg)
	queue_redraw()
	return new_seg

func delete_segment(seg: RoadSegment) -> void:
	if seg:
		unregister_segment_from_chunks(seg)
		queue_redraw()
		seg.start.roads.erase(seg)
		seg.end.roads.erase(seg)
		seg.start.conections.erase(seg.end)
		seg.end.conections.erase(seg.start)
		roads.erase(seg.id)
		astar.disconnect_points(seg.start.id, seg.end.id)

func make_straight_roads(s_node: RoadNode, e_node: RoadNode) -> void:
	if s_node and e_node:
		if s_node.pos.distance_squared_to(e_node.pos) < SNAP_DIST * SNAP_DIST:
			return
	else:
		return
	var temp_seg: RoadSegment = create_segment(s_node, e_node)
	var segments = get_roads_in_bounding_box(temp_seg)
	var junctions := detect_junctions(temp_seg, segments)
	var raw_juncs: Array[Vector2] = []
	for j in junctions.keys():
		if s_node.pos.distance_squared_to(j) > SNAP_DIST * SNAP_DIST and e_node.pos.distance_squared_to(j) > SNAP_DIST * SNAP_DIST:
			raw_juncs.append(j)
	var sorted_juncs: Array[Vector2] = []
	for j in raw_juncs:
		var too_close = false
		for existing in sorted_juncs:
			if j.distance_squared_to(existing) <= SNAP_DIST * SNAP_DIST:
				too_close = true
				break
		if not too_close:
			sorted_juncs.append(j)
	sorted_juncs.sort_custom(func(a: Vector2, b: Vector2):
		return a.distance_squared_to(s_node.pos) < b.distance_squared_to(s_node.pos)
	)
	if not sorted_juncs.is_empty():
		split_segment_at_points(temp_seg, sorted_juncs)
	var grouped_junctions: Dictionary = {}
	for key in junctions.keys():
		for old_seg in junctions[key]:
			if roads.has(old_seg.id):
				if old_seg.start.pos.distance_squared_to(key) > SNAP_DIST * SNAP_DIST and old_seg.end.pos.distance_squared_to(key) > SNAP_DIST * SNAP_DIST:
					if !grouped_junctions.has(old_seg):
						grouped_junctions[old_seg] = Array([], TYPE_VECTOR2, "", null)
					grouped_junctions[old_seg].append(key)
	for old_seg in grouped_junctions.keys():
		split_segment_at_points(old_seg, grouped_junctions[old_seg])

func generate_quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, spacing: float = 10.0) -> Array[Vector2]:
	var estimated_length = 0.0
	var prev_pos = p0
	var approx_steps = 30 
	
	for i in range(1, approx_steps + 1):
		var t = float(i) / float(approx_steps)
		var pos = (1.0 - t) * (1.0 - t) * p0 + 2.0 * (1.0 - t) * t * p1 + t * t * p2
		estimated_length += prev_pos.distance_to(pos)
		prev_pos = pos

	var num_steps = max(1, round(estimated_length / spacing))

	var points: Array[Vector2] = []
	for i in range(num_steps + 1):
		var t = float(i) / float(num_steps)
		var pos = (1.0 - t) * (1.0 - t) * p0 + 2.0 * (1.0 - t) * t * p1 + t * t * p2
		points.append(pos)

	return points

func get_roads_in_bounding_box(new_seg: RoadSegment) -> Array[RoadSegment]:
	var candidate_roads: Array[RoadSegment] = []
	if not new_seg or new_seg.points.is_empty():
		return candidate_roads

	var new_rect := get_segment_bounds(new_seg)
	var touched_chunks := get_chunks_covered_by_rect(new_rect)
	var visited_ids := {}

	for chunk_coord in touched_chunks:
		if not chunks.has(chunk_coord):
			continue

		for r_id in chunks[chunk_coord]:
			if r_id == new_seg.id or visited_ids.has(r_id):
				continue
			
			visited_ids[r_id] = true
			var existing_seg: RoadSegment = roads[r_id]
			
			if not existing_seg or existing_seg.points.is_empty():
				continue

			var existing_rect := get_segment_bounds(existing_seg)
			if new_rect.intersects(existing_rect):
				candidate_roads.append(existing_seg)

	return candidate_roads

func detect_junctions(seg: RoadSegment, segments: Array[RoadSegment]) -> Dictionary:
	var junctions: Array[Vector2] = []
	var junc_road: Dictionary = {}
	for i in range(0, seg.points.size() - 1):
		var a = seg.points[i]
		var b = seg.points[i + 1]
		for r in segments:
			for p in range(0, r.points.size() - 1):
				var c = r.points[p]
				var d = r.points[p + 1]
				var closest_s = Geometry2D.get_closest_point_to_segment(seg.start.pos, c, d)
				var closest_e = Geometry2D.get_closest_point_to_segment(seg.end.pos, c, d)
				var intersection_point = Geometry2D.segment_intersects_segment(a, b, c, d)
				
				if closest_s.distance_squared_to(r.start.pos) > SNAP_DIST * SNAP_DIST and closest_s.distance_squared_to(r.end.pos) > SNAP_DIST * SNAP_DIST:
					if closest_s.distance_squared_to(seg.start.pos) < SNAP_DIST * SNAP_DIST:
						if r.slope == RoadSegment.slope_types.flat:
							if seg.start.height == r.start.height:
								if not junctions.has(closest_s):
									junctions.append(closest_s)
									junc_road[closest_s] = []
								if not junc_road[closest_s].has(r):
									junc_road[closest_s].append(r)
							
				if closest_e.distance_squared_to(r.start.pos) > SNAP_DIST * SNAP_DIST and closest_e.distance_squared_to(r.end.pos) > SNAP_DIST * SNAP_DIST:
					if closest_e.distance_squared_to(seg.end.pos) < SNAP_DIST * SNAP_DIST:
						if r.slope == RoadSegment.slope_types.flat:
							if seg.end.height == r.start.height:
								if not junctions.has(closest_e):
									junctions.append(closest_e)
									junc_road[closest_e] = []
								if not junc_road[closest_e].has(r):
									junc_road[closest_e].append(r)
							
				if intersection_point != null:
					if intersection_point.distance_squared_to(r.start.pos) > SNAP_DIST * SNAP_DIST and intersection_point.distance_squared_to(r.end.pos) > SNAP_DIST * SNAP_DIST:
						if seg.slope == RoadSegment.slope_types.flat and r.slope == RoadSegment.slope_types.flat:
							if seg.start.height == r.start.height:
								if not junctions.has(intersection_point):
									junctions.append(intersection_point)
									junc_road[intersection_point] = []
								if not junc_road[intersection_point].has(r):
									junc_road[intersection_point].append(r)
							
	return junc_road

func sort_points_along_segment(points: Array[Vector2], seg: RoadSegment) -> Array[Vector2]:
	var sorted_points = points.duplicate()
	var start_pos = seg.start.pos
	
	sorted_points.sort_custom(func(a: Vector2, b: Vector2):
		return start_pos.distance_squared_to(a) < start_pos.distance_squared_to(b)
	)
	return sorted_points

func sort_junctions(seg:RoadSegment, junctions: Array[Vector2]) -> Array[Vector2]:
	var sorted_juncs:Array[Vector2] = []
	for i in range(0, seg.points.size()-1):
		var a:Vector2 = seg.points[i]
		var b:Vector2 = seg.points[i+1]
		for j in junctions:
			if Geometry2D.get_closest_point_to_segment(j, a, b).distance_to(j) < 1.0:
				if not sorted_juncs.has(j):
					sorted_juncs.append(j)
	return sorted_juncs

func split_segment_at_points(seg: RoadSegment, split_points: Array[Vector2]) -> Array[RoadSegment]:
	if split_points.is_empty():
		return [seg]
		
	var sorted_splits = sort_junctions(seg, split_points)
	var original_points = seg.points.duplicate()
	delete_segment(seg)

	var new_segments: Array[RoadSegment] = []
	var current_sub_points: Array[Vector2] = [original_points[0]]
	var current_start_node = seg.start
	
	var split_index = 0
	for i in range(original_points.size() - 1):
		var p_start = original_points[i]
		var p_end = original_points[i + 1]
		
		while split_index < sorted_splits.size():
			var cut_pos = sorted_splits[split_index]
			var closest = Geometry2D.get_closest_point_to_segment(cut_pos, p_start, p_end)
			if cut_pos.distance_squared_to(closest) < 1.0: 
				current_sub_points.append(cut_pos)
				var cut_node = get_or_create_node(cut_pos)
				
				var sub_seg = create_segment(current_start_node, cut_node)
				if sub_seg:
					unregister_segment_from_chunks(sub_seg)
					sub_seg.points = current_sub_points.duplicate()
					register_segment_in_chunks(sub_seg)
					new_segments.append(sub_seg)
				
				current_start_node = cut_node
				current_sub_points = [cut_pos]
				split_index += 1
			else:
				break

		current_sub_points.append(p_end)
		
	if current_sub_points.size() >= 2:
		var final_sub_seg = create_segment(current_start_node, seg.end)
		if final_sub_seg:
			unregister_segment_from_chunks(final_sub_seg)
			final_sub_seg.points = current_sub_points.duplicate()
			register_segment_in_chunks(final_sub_seg)
			new_segments.append(final_sub_seg)

	return new_segments

func make_curve_roads(s_node: RoadNode, control: Vector2, e_node: RoadNode) -> void:
	if s_node and e_node:
		if s_node.pos.distance_squared_to(e_node.pos) < SNAP_DIST * SNAP_DIST:
			return
	else:
		return
		
	var temp_seg: RoadSegment = create_segment(s_node, e_node)
	var points := generate_quadratic_bezier(s_node.pos, control, e_node.pos, 64)
	unregister_segment_from_chunks(temp_seg)
	temp_seg.points = points
	register_segment_in_chunks(temp_seg)
	var segments = get_roads_in_bounding_box(temp_seg)
	var junctions := detect_junctions(temp_seg, segments)
	var raw_juncs: Array[Vector2] = []
	for j in junctions.keys():
		if s_node.pos.distance_squared_to(j) > SNAP_DIST * SNAP_DIST and e_node.pos.distance_squared_to(j) > SNAP_DIST * SNAP_DIST:
			raw_juncs.append(j)
			
	var sorted_juncs: Array[Vector2] = []
	for j in raw_juncs:
		var too_close = false
		for existing in sorted_juncs:
			if j.distance_squared_to(existing) <= SNAP_DIST * SNAP_DIST:
				too_close = true
				break
		if not too_close:
			sorted_juncs.append(j)
	sorted_juncs = sort_junctions(temp_seg, sorted_juncs)
	
	if not sorted_juncs.is_empty():
		split_segment_at_points(temp_seg, sorted_juncs)
	
	var grouped_junctions: Dictionary = {}
	for key in junctions.keys():
		for old_seg in junctions[key]:
			if roads.has(old_seg.id):
				if old_seg.start.pos.distance_squared_to(key) > SNAP_DIST * SNAP_DIST and old_seg.end.pos.distance_squared_to(key) > SNAP_DIST * SNAP_DIST:
					if !grouped_junctions.has(old_seg):
						grouped_junctions[old_seg] = Array([], TYPE_VECTOR2, "", null)
					grouped_junctions[old_seg].append(key)
	for old_seg in grouped_junctions.keys():
		split_segment_at_points(old_seg, grouped_junctions[old_seg])

func get_segment_bounds(seg: RoadSegment) -> Rect2:
	var rect := Rect2(seg.points[0], Vector2.ZERO)
	for i in range(1, seg.points.size()):
		rect = rect.expand(seg.points[i])
	return rect

func world_to_chunk_coords(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / CHUNK_SIZE)),
		int(floor(world_pos.y / CHUNK_SIZE))
	)

func get_chunks_covered_by_rect(rect: Rect2) -> Array[Vector2i]:
	var covered: Array[Vector2i] = []
	var min_chunk := world_to_chunk_coords(rect.position)
	var max_chunk := world_to_chunk_coords(rect.position + rect.size)

	for x in range(min_chunk.x, max_chunk.x + 1):
		for y in range(min_chunk.y, max_chunk.y + 1):
			covered.append(Vector2i(x, y))
			
	return covered

func register_segment_in_chunks(seg: RoadSegment) -> void:
	var rect := get_segment_bounds(seg)
	var target_chunks := get_chunks_covered_by_rect(rect)

	for chunk_coord in target_chunks:
		if not chunks.has(chunk_coord):
			chunks[chunk_coord] = []
		if not chunks[chunk_coord].has(seg.id):
			chunks[chunk_coord].append(seg.id)

func unregister_segment_from_chunks(seg: RoadSegment) -> void:
	var rect := get_segment_bounds(seg)
	var target_chunks := get_chunks_covered_by_rect(rect)

	for chunk_coord in target_chunks:
		if chunks.has(chunk_coord):
			chunks[chunk_coord].erase(seg.id)
			if chunks[chunk_coord].is_empty():
				chunks.erase(chunk_coord)


func _draw() -> void:
	for seg in roads.values():
		if not is_segment_visible(seg):
			continue

		if seg.points.size() >= 2:
			for i in range(seg.points.size() - 1):
				draw_line(
					seg.points[i], seg.points[i + 1], Color.GRAY, 6.0, true)

	if current_tool_mode == RoadToolMode.STRAIGHT and straight_start_node != null:
		draw_line(straight_start_node.pos, current_mouse_pos, Color.GRAY, 6.0, true)
		draw_circle(current_mouse_pos, 6.0, Color.YELLOW_GREEN)

	if current_tool_mode == RoadToolMode.CURVE:
		if curve_step == 1 and curve_start_node:
			draw_line(curve_start_node.pos, current_mouse_pos, Color.YELLOW_GREEN, 3.0, true)
			draw_circle(current_mouse_pos, 6.0, Color.YELLOW_GREEN)
		elif curve_step == 2 and curve_start_node:
			var preview_points = generate_quadratic_bezier(curve_start_node.pos, curve_control_pos, current_mouse_pos, 16)
			for i in range(preview_points.size() - 1):
				draw_line(preview_points[i], preview_points[i + 1], Color.ORANGE, 4.0, true)
			draw_circle(curve_control_pos, 6.0, Color.CYAN)

	var font = ThemeDB.fallback_font
	var font_size = 14
	
	for node in nodes.values():
		if not is_equal_approx(
			node.height,
			float(visible_height)
		):
			continue

		draw_circle(node.pos, 8.0, Color.GOLD)
		var text = str(node.roads.size())
		var text_pos = node.pos + Vector2(-4, 5) 
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK)

func is_segment_visible(seg: RoadSegment) -> bool:
	if seg.slope == RoadSegment.slope_types.ramp:
		return (
			visible_height >= minf(seg.start.height, seg.end.height)
			and visible_height <= maxf(seg.start.height, seg.end.height)
		)

	return is_equal_approx(
		seg.start.height,
		float(visible_height)
	)
