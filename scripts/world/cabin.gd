extends RefCounted
## Cabin builder: spawns wall segments (collision + occluders + visuals)
## into a Y-sorted container. The west wall is split to leave a door gap.

const WallSegment := preload("res://scripts/world/wall_segment.gd")

var door_rect: Rect2


func build(parent: Node2D, rect: Rect2, wall_thickness: float = 22.0, door_gap: float = 54.0) -> Array[StaticBody2D]:
	var walls: Array[StaticBody2D] = []
	var cy := rect.get_center().y
	var gap_half := door_gap * 0.5
	var segs: Array = []
	# west wall, split around the door gap
	segs.append([Rect2(rect.position.x, rect.position.y, wall_thickness, cy - gap_half - rect.position.y), false])
	segs.append([Rect2(rect.position.x, cy + gap_half, wall_thickness, rect.position.y + rect.size.y - (cy + gap_half)), false])
	# east wall
	segs.append([Rect2(rect.position.x + rect.size.x - wall_thickness, rect.position.y, wall_thickness, rect.size.y), false])
	# north and south walls
	segs.append([Rect2(rect.position.x, rect.position.y, rect.size.x, wall_thickness), true])
	segs.append([Rect2(rect.position.x, rect.position.y + rect.size.y - wall_thickness, rect.size.x, wall_thickness), true])
	for s in segs:
		var r: Rect2 = s[0]
		var horiz: bool = s[1]
		if r.size.x < 2.0 or r.size.y < 2.0:
			continue
		var wall := WallSegment.new()
		wall.segment_size = r.size
		wall.logs_horizontal = horiz
		wall.position = r.get_center()
		parent.add_child(wall)
		walls.append(wall)
	door_rect = Rect2(Vector2(rect.position.x, cy - gap_half), Vector2(wall_thickness + 8.0, door_gap))
	return walls
