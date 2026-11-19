extends RefCounted
## Rendering helper for the two 4x1 character atlases in this folder.
## Call from CanvasItem._draw only for an idle pose. No combat-time dependency.
const ROWS = [0.0,420.0,435.0,450.0,465.0,480.0,485.0,512.0]

static func read_profile(path: String) -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("schema")!=1:
		push_error("대기 호흡 설정 형식 오류: "+path)
		return {}
	for field in ["period_seconds","phase_cycles","amplitude_source_px","rigid_until_y","fixed_from_y","blend_seconds"]:
		if not (value.get(field) is int or value.get(field) is float):
			push_error("대기 호흡 수치 누락: "+field)
			return {}
	if not is_finite(float(value.period_seconds)) or float(value.period_seconds)<=0 or float(value.amplitude_source_px)<0 or float(value.rigid_until_y)>=float(value.fixed_from_y):
		push_error("대기 호흡 설정 범위 오류: "+path)
		return {}
	return value

static func offset_at(profile: Dictionary, source_y: float, seconds: float) -> Vector2:
	if not bool(profile.enabled): return Vector2.ZERO
	var weight := 1.0-smoothstep(float(profile.rigid_until_y),float(profile.fixed_from_y),source_y)
	var wave := (1.0-cos(TAU*(seconds/float(profile.period_seconds)+float(profile.phase_cycles))))*0.5
	return Vector2(0,-float(profile.amplitude_source_px)*wave*weight)

static func draw_idle(canvas: CanvasItem, texture: Texture2D, foot_position: Vector2, display_scale: float, seconds: float, profile: Dictionary, blend: float=1.0, tint: Color=Color.WHITE) -> void:
	if profile.is_empty(): return
	var cell := Vector2(float(profile.frame_size_px[0]),float(profile.frame_size_px[1]))
	var pivot := Vector2(float(profile.pivot_px[0]),float(profile.pivot_px[1]))
	var origin := foot_position-pivot*display_scale
	var source_x := float(profile.idle_frame)*cell.x
	var image_size := Vector2(texture.get_size())
	if not bool(profile.enabled) or blend<=0:
		canvas.draw_texture_rect_region(texture,Rect2(origin,cell*display_scale),Rect2(Vector2(source_x,0),cell),tint)
		return
	for row in range(ROWS.size()-1):
		var y0: float = ROWS[row]
		var y1: float = ROWS[row+1]
		var offset0 := offset_at(profile,y0,seconds)*clampf(blend,0,1)
		var offset1 := offset_at(profile,y1,seconds)*clampf(blend,0,1)
		var polygon := PackedVector2Array([origin+(Vector2(0,y0)+offset0)*display_scale,origin+(Vector2(cell.x,y0)+offset0)*display_scale,origin+(Vector2(cell.x,y1)+offset1)*display_scale,origin+(Vector2(0,y1)+offset1)*display_scale])
		var uv := PackedVector2Array([Vector2(source_x,y0)/image_size,Vector2(source_x+cell.x,y0)/image_size,Vector2(source_x+cell.x,y1)/image_size,Vector2(source_x,y1)/image_size])
		canvas.draw_polygon(polygon,PackedColorArray([tint,tint,tint,tint]),uv,texture)
