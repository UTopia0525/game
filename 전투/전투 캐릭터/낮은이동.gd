extends RefCounted
## A presentation sampler for the reviewed 4x1 move atlases, not a combat engine.
static func read_profile(path: String) -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("schema")!=1:
		push_error("낮은 이동 설정 형식 오류: "+path)
		return {}
	for key in ["anticipation_seconds","flight_seconds","landing_seconds","height_in_cells","settle_switch_fraction"]:
		if not (value.get(key) is int or value.get(key) is float) or not is_finite(float(value[key])) or float(value[key])<0:
			push_error("낮은 이동 설정 수치 오류: "+key)
			return {}
	if float(value.flight_seconds)<=0:
		push_error("낮은 이동 공중 시간이 필요합니다.")
		return {}
	return value

static func duration(profile: Dictionary) -> float:
	return float(profile.anticipation_seconds)+float(profile.flight_seconds)+float(profile.landing_seconds)

static func sample(profile: Dictionary, start_foot: Vector2, end_foot: Vector2, cell_height: float, elapsed_seconds: float, head_room: float=INF) -> Dictionary:
	var anticipate: float = profile.anticipation_seconds
	var flight: float = profile.flight_seconds
	var landing: float = profile.landing_seconds
	if elapsed_seconds>=duration(profile):
		return {"ground":end_foot,"lift":0.0,"pose":-1,"air":0.0,"finished":true}
	if elapsed_seconds<anticipate:
		return {"ground":start_foot,"lift":0.0,"pose":int(profile.anticipation_pose),"air":0.0,"finished":false}
	if elapsed_seconds>=anticipate+flight:
		var settle := elapsed_seconds-anticipate-flight
		return {"ground":end_foot,"lift":0.0,"pose":int(profile.landing_pose) if settle<landing*float(profile.settle_switch_fraction) else int(profile.settle_pose),"air":0.0,"finished":false}
	var u := clampf((elapsed_seconds-anticipate)/flight,0.0,1.0)
	var arc := 4.0*u*(1.0-u)
	var height := minf(cell_height*float(profile.height_in_cells),maxf(0.0,head_room))
	return {"ground":start_foot.lerp(end_foot,smoothstep(0.0,1.0,u)),"lift":height*arc,"pose":int(profile.flight_pose),"air":arc,"finished":false}

static func draw_pose(canvas: CanvasItem, texture: Texture2D, foot_position: Vector2, display_scale: float, pose: int, profile: Dictionary, tint: Color=Color.WHITE) -> void:
	if pose<0: return
	var cell := Vector2(float(profile.frame_size_px[0]),float(profile.frame_size_px[1]))
	var pivot := Vector2(float(profile.pivot_px[0]),float(profile.pivot_px[1]))
	canvas.draw_texture_rect_region(texture,Rect2(foot_position-pivot*display_scale,cell*display_scale),Rect2(Vector2(pose*cell.x,0),cell),tint)
