extends Node2D
class_name MapManager
var nodes: Array = []
var roads: Array = [] 
var junction: Array[Vector2] = []
@export var shared_state: road_button_states 
var drawing: bool = false
var current_mouse_pos: Vector2 
const snap_dist = 16
var point1: bool = false
var c_point: bool = false
var start_key
var c_key
var current_level:levels = levels.grounded
enum levels{tunnel = -1, grounded = 0, bridge = 1}
var level_1
func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		print("Estado actual detectado: ", shared_state.state)
	if shared_state.state == road_button_states.states.off:
		return
	if shared_state.state == road_button_states.states.straight:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not point1:
				drawing = true
				snap_mouse()
				start_key = current_mouse_pos
				point1 = true
				level_1 = current_level
				queue_redraw()
			else:
				drawing = false
				snap_mouse()
				var end_key = current_mouse_pos
				if start_key.distance_to(end_key) >= snap_dist:
					straight_make_roads(get_or_create_node(start_key, level_1), get_or_create_node(end_key, current_level))
				point1 = false
				queue_redraw()
		if event is InputEventMouseMotion and drawing:
			snap_mouse()
			queue_redraw()
	elif shared_state.state == road_button_states.states.curve:
		if event is InputEventMouseMotion and drawing:
			snap_mouse()
			queue_redraw()
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not point1:
				snap_mouse()
				start_key = current_mouse_pos
				point1 = true
				drawing = true
				level_1 = current_level
				return
			if point1 and not c_point:
				snap_mouse()
				c_key = current_mouse_pos
				c_point = true
				return
			if point1 and c_point:
				snap_mouse()
				var end_key = current_mouse_pos
				if start_key.distance_to(end_key) >= snap_dist:
					var s_node = get_or_create_node(start_key, level_1)
					var e_node = get_or_create_node(end_key, current_level)
					curve_make_roads(s_node, c_key, e_node)
				point1 = false
				c_point = false
				drawing = false
				queue_redraw()
	if Input.is_action_pressed("cancel"):
		point1 = false
		c_point = false
		drawing = false
		c_key = false
		queue_redraw()
	if Input.is_action_just_pressed("change_level_up"):
			current_level = clampi(current_level + 1, levels.tunnel, levels.bridge) as levels
	if Input.is_action_just_pressed("change_level_down"):
			current_level = clampi(current_level - 1, levels.tunnel, levels.bridge) as levels

func straight_make_roads(s_node: Nodes, e_node: Nodes):
	if s_node.position.distance_to(e_node.position) < 2.0:
		return
	var temp_seg = RoadSegment.new()
	temp_seg.start = s_node
	temp_seg.end = e_node
	temp_seg.start.height_in_m = level_to_m(temp_seg.start)
	temp_seg.end.height_in_m = level_to_m(temp_seg.end)
	detect_junction(temp_seg)
	var current_juncs: Array = []
	for j in junction:
		if Geometry2D.get_closest_point_to_segment(j, s_node.position, e_node.position).distance_to(j) < 2.0:
			if not current_juncs.has(j):
				current_juncs.append(j)
	current_juncs.sort_custom(func(a, b):
		return a.distance_to(s_node.position) < b.distance_to(s_node.position)
	)
	var last_start_node = s_node
	for j_pos in current_juncs:
		# Creamos el nodo de la intersección
		var j_node = get_or_create_node(j_pos, s_node.level)
		j_node.height_in_m = get_height_at_point(temp_seg, j_pos)
		m_to_level(j_node)
		create_segment(last_start_node, j_node)
		last_start_node = j_node
	create_segment(last_start_node, e_node)
	_split_existing_roads_at_junctions(current_juncs)

func _split_existing_roads_at_junctions(current_juncs: Array):
	for j in current_juncs:
		var roads_to_split: Array = []
		for r in roads:
			if r.start.position == j or r.end.position == j: continue
			var closest = Geometry2D.get_closest_point_to_segment(j, r.start.position, r.end.position)
			if closest.distance_to(j) < 2.0:
				roads_to_split.append(r)
				
		for r in roads_to_split:
			var old_start = r.start
			var old_end = r.end
			# Limpiar referencias
			roads.erase(r)
			old_start.roads.erase(r)
			old_end.roads.erase(r)
			# Crear los dos nuevos tramos
			var j_node = get_or_create_node(j, old_start.level) 
			create_segment(old_start, j_node)
			create_segment(j_node, old_end)

func create_segment(n1:Nodes, n2:Nodes):
	if n1.position == n2.position: return
	for r in n1.roads:
		if (r.start == n1 and r.end == n2) or (r.start == n2 and r.end == n1): return
	var new_seg = RoadSegment.new()
	new_seg.start = n1
	new_seg.end = n2
	roads.append(new_seg)
	n1.roads.append(new_seg)
	n2.roads.append(new_seg)

func get_or_create_node(pos: Vector2, level):
	for n in nodes:
		if pos.distance_to(n.position) < 2.0:
			return n 
	var new_node = Nodes.new() 
	new_node.position = pos
	new_node.level = level
	nodes.append(new_node)
	return new_node

func detect_junction(segment: RoadSegment):
	junction.clear()
	var temp_junctions:Array[Vector2]
	for r in roads:
		var hit = Geometry2D.segment_intersects_segment(segment.start.position, segment.end.position, r.start.position, r.end.position)
		if hit != null:
			if not temp_junctions.has(hit):
				temp_junctions.append(hit)
		var closest_start = Geometry2D.get_closest_point_to_segment(segment.start.position, r.start.position, r.end.position)
		var closest_end = Geometry2D.get_closest_point_to_segment(segment.end.position, r.start.position, r.end.position)
		if closest_start.distance_to(r.start.position) > snap_dist:
			if closest_start.distance_to(segment.start.position) < snap_dist:
				temp_junctions.append(closest_start)
		if closest_end.distance_to(r.end.position) > snap_dist:
			if closest_end.distance_to(segment.end.position) < snap_dist:
				temp_junctions.append(closest_end)
	for tj in temp_junctions:
		if not junction.has(tj):
			junction.append(tj)
	var clone_junctions = junction.duplicate()
	junction.clear()
	for j in clone_junctions:
		for r in roads:
			if abs(get_height_at_point(r, j) - get_height_at_point(segment, j)) <= 0.5:
				junction.append(j)
				break

func snap_mouse():
	current_mouse_pos = get_global_mouse_position().round()
	for n in nodes:
		if current_mouse_pos.distance_to(n.position) < snap_dist:
			current_mouse_pos = n.position
			current_level = n.level
			return
	for seg in roads:
		var closest = Geometry2D.get_closest_point_to_segment(current_mouse_pos, seg.start.position, seg.end.position)
		if current_mouse_pos.distance_to(closest) < snap_dist:
			current_mouse_pos = closest
			return

func _draw() -> void:
	# Previsualización mientras dibujas
	if drawing and start_key:
		if shared_state.state == road_button_states.states.curve and c_point:
			var prev_p = start_key
			for i in range(1, 11):
				var t = float(i) / 10
				var next_p = _quadratic_bezier(start_key, c_key, current_mouse_pos, t)
				var h = lerpf(level_to_m_value(start_key), level_to_m_value(current_mouse_pos), t)
				var color = height_to_color(h)
				draw_line(prev_p, next_p, color, 4)
				prev_p = next_p
		else:
			var color = height_to_color(level_to_m_value(start_key))
			draw_line(start_key, current_mouse_pos, color, 4)
	
	# Dibujar calles definitivas con degradado según altura
	for r in roads:
		var start_h = r.start.height_in_m
		var end_h = r.end.height_in_m
		var steps = int(r.start.position.distance_to(r.end.position) / 4)  # subdivide para degradado
		if steps < 1: steps = 1
		var last_p = r.start.position
		for i in range(1, steps + 1):
			var t = float(i) / steps
			var next_p = r.start.position.lerp(r.end.position, t)
			var color = height_to_color(lerpf(start_h, end_h, t))
			draw_line(last_p, next_p, color, 4)
			last_p = next_p

	# Dibujar nodos
	for n in nodes:
		var count = n.roads.size()
		var color = Color.RED
		if count == 0: color = Color.SKY_BLUE
		if count == 2: color = Color.BLUE
		if count >= 3: color = Color.GOLD 
		draw_circle(n.position, 10, color)


# Convierte altura en un valor numérico a color
func height_to_color(height: float) -> Color:
	# Ajusta valores según tu rango de alturas
	# Ejemplo: tunnel=-5, grounded=0, bridge=5
	var min_h = -5.0
	var max_h = 5.0
	var t = clamp((height - min_h) / (max_h - min_h), 0.0, 1.0)
	# Degradado: azul oscuro → gris → amarillo (puedes cambiarlo)
	var low_color = Color(0.1, 0.1, 0.3)   # azul oscuro
	var mid_color = Color(0.5, 0.5, 0.5)   # gris
	var high_color = Color(1, 1, 0.5)      # amarillo claro
	if t < 0.5:
		return low_color.lerp(mid_color, t * 2)
	else:
		return mid_color.lerp(high_color, (t - 0.5) * 2)

# Convierte un punto a valor de altura (para previsualización)
func level_to_m_value(pos: Vector2) -> float:
	for n in nodes:
		if n.position == pos:
			return n.height_in_m
	return 0.0

func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float):
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	var r = q0.lerp(q1, t)
	return r

func curve_make_roads(start_pos: Nodes, control: Vector2, end_pos: Nodes):
	if start_pos.position.distance_to(end_pos.position) < snap_dist:
		return
	var steps = int(start_pos.position.distance_to(end_pos.position)/16)
	var last_node = start_pos
	for i in range(1, steps +1):
		var t: float = float(i) / steps
		var current_pos = _quadratic_bezier(start_pos.position, control, end_pos.position, t)
		var current_height = lerpf(start_pos.height_in_m, end_pos.height_in_m, t)
		var t_node = get_or_create_node(current_pos, levels.grounded)
		t_node.height_in_m = current_height
		m_to_level(t_node)
		straight_make_roads(last_node, t_node)
		last_node = t_node

func level_to_m(node:Nodes):
	match node.level:
		levels.tunnel:
			node.height_in_m = -5.0
			return node.height_in_m
		levels.grounded:
			node.height_in_m = 0.0
			return node.height_in_m
		levels.bridge:
			node.height_in_m = 5.0
			return node.height_in_m

func m_to_level(node:Nodes):
	if abs(node.height_in_m) < 0.5:
		node.level = levels.grounded
		return node.level
	if node.height_in_m > 0.5:
		node.level = levels.bridge
		return node.level
	if node.height_in_m < -0.5:
		node.level = levels.tunnel
		return node.level

func get_height_at_point(segment: RoadSegment, point: Vector2):
	var a := segment.start.position
	var b := segment.end.position
	var ab := b - a
	var t := float(clamp((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0))
	return lerpf(segment.start.height_in_m, segment.end.height_in_m, t)
