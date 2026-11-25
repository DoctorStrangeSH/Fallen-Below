extends RefCounted
## Sprite lookup. Drop a PNG into res://art/ named like the id (e.g. art/traveler_hunter.png)
## and the game uses it; otherwise callers fall back to primitive drawing.
## The full list of ids and prompts is in docs/ART.md.

static var _cache := {}


static func tex(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var path := "res://art/%s.png" % id
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_cache[id] = t
	return t


## Draws `id` centred at `center` with the given size. Returns false if no sprite exists.
static func draw(ci: CanvasItem, id: String, center: Vector2, size: float, modulate: Color = Color(1, 1, 1)) -> bool:
	var t := tex(id)
	if t == null:
		return false
	ci.draw_texture_rect(t, Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size)), false, modulate)
	return true
