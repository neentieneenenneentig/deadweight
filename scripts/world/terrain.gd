extends RefCounted
## Highland terrain (W1): a seeded height field for a big open valley. Green meadows in the middle,
## two lakes, forest patches, and a ring of snowy mountains with green patches toward the edge. The
## edge of the field blends to EDGE_HEIGHT, where the level's outer plain continues it.
##
## Everything here is plain data and meshes; the level adds the nodes. Deterministic for a seed.
## Usage:
##   var land := Terrain.new(seed, size)
##   land.flatten(Vector2(0, 40), 24.0)        # optional flat spots, before build
##   land.generate()
##   var mesh: ArrayMesh = land.build_mesh()
##   var faces: PackedVector3Array = land.collision_faces()

const CELL := 5.0                    # metres between height samples
const EDGE_HEIGHT := 150.0           # the field's border height; the outer plain sits here
const EDGE_BLEND := 140.0            # metres over which the border blends to EDGE_HEIGHT
const WATER_Y := -1.5                # lake surface
const SNOW_LINE := 10.0              # metres; noise moves it up and down by SNOW_JITTER
const SNOW_JITTER := 9.0
const TREE_LINE := 98.0

# Cold alpine palette (vertex colours; the material adds a little light variation).
const MEADOW := Color("c1d1d8")
const MEADOW_LIGHT := Color("e3edf0")
const FOREST_FLOOR := Color("809aa9")
const SHORE := Color("94afc0")
const ROCK := Color("738597")
const ROCK_DARK := Color("465d74")
const SNOW := Color("e8f0f3")
const LAKE_BED := Color("35566d")
# Thawed hollows (V2b): muted, cold alpine turf and heather where the snow has gone.
const TURF := Color("62785a")
const TURF_LIGHT := Color("8a9a6c")
const HEATHER := Color("6e5a63")
const THAW := 0.32                   # _patches noise above this is bare of snow (soft edge below)

var size: float                      # metres per side, centred on the origin
var count: int                       # samples per side
var heights: PackedFloat32Array = PackedFloat32Array()
var _seed: int
var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _ridges := FastNoiseLite.new()
var _patches := FastNoiseLite.new()
var _flats: Array[Vector3] = []      # x, z, radius
var _lakes: Array[Vector3] = []      # x, z, radius
var _mounds: Array[Vector4] = []     # x, z, radius, height


func _init(seed_value: int, side: float) -> void:
	_seed = seed_value
	size = side
	count = int(round(side / CELL)) + 1
	_hills.seed = seed_value
	_hills.frequency = 0.0035
	_hills.fractal_octaves = 3
	_detail.seed = seed_value + 1
	_detail.frequency = 0.02
	_ridges.seed = seed_value + 2
	_ridges.frequency = 0.0042
	_ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridges.fractal_octaves = 3
	_patches.seed = seed_value + 3
	_patches.frequency = 0.012


## A flat spot (spawn, a pad, a camp). Heights inside radius ease to the height at its centre.
func flatten(center: Vector2, radius: float) -> void:
	_flats.append(Vector3(center.x, center.y, radius))


## A smooth round hill height metres tall (cosine profile, at most about 25 degrees for a radius
## four times the height), for a landmark that must stay walkable.
func mound(center: Vector2, radius: float, height: float) -> void:
	_mounds.append(Vector4(center.x, center.y, radius, height))


## A lake basin: the ground dips below WATER_Y inside radius.
func lake(center: Vector2, radius: float) -> void:
	_lakes.append(Vector3(center.x, center.y, radius))


func generate() -> void:
	heights.resize(count * count)
	for j in range(count):
		for i in range(count):
			heights[j * count + i] = _raw_height(_x(i), _x(j))
	# Flat spots take the raw height at their centre, so they sit naturally in the land.
	for flat: Vector3 in _flats:
		var level: float = _raw_height(flat.x, flat.y)
		var reach: float = flat.z * 1.6
		var i0: int = maxi(0, int((flat.x - reach + size * 0.5) / CELL))
		var i1: int = mini(count, int((flat.x + reach + size * 0.5) / CELL) + 2)
		var j0: int = maxi(0, int((flat.y - reach + size * 0.5) / CELL))
		var j1: int = mini(count, int((flat.y + reach + size * 0.5) / CELL) + 2)
		for j in range(j0, j1):
			for i in range(i0, i1):
				var d: float = Vector2(_x(i) - flat.x, _x(j) - flat.y).length()
				if d < flat.z * 1.6:
					var k: float = smoothstep(flat.z * 1.6, flat.z, d)
					heights[j * count + i] = lerpf(heights[j * count + i], level, k)


## Height of the ground at a world x/z (bilinear between samples).
func height_at(x: float, z: float) -> float:
	var fx: float = clampf((x + size * 0.5) / CELL, 0.0, float(count - 1))
	var fz: float = clampf((z + size * 0.5) / CELL, 0.0, float(count - 1))
	var i: int = mini(int(fx), count - 2)
	var j: int = mini(int(fz), count - 2)
	var tx: float = fx - float(i)
	var tz: float = fz - float(j)
	var a: float = lerpf(heights[j * count + i], heights[j * count + i + 1], tx)
	var b: float = lerpf(heights[(j + 1) * count + i], heights[(j + 1) * count + i + 1], tx)
	return lerpf(a, b, tz)


## Ground normal at x/z from the neighbouring samples.
func normal_at(x: float, z: float) -> Vector3:
	var e: float = CELL
	var dx: float = height_at(x + e, z) - height_at(x - e, z)
	var dz: float = height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


## 0 to 1: how much forest wants to grow here (used by the scatter and the ground colour).
func forest_at(x: float, z: float) -> float:
	return clampf(_patches.get_noise_2d(x * 0.6, z * 0.6) * 1.8 + 0.1, 0.0, 1.0)


func is_snow(x: float, z: float, h: float) -> bool:
	var line: float = SNOW_LINE + _detail.get_noise_2d(x * 0.3, z * 0.3) * SNOW_JITTER
	# Green patches survive in sheltered hollows below the peaks.
	return h > line and thaw_at(x, z, h) < 0.5


## 0 to 1: how bare of snow a sheltered hollow is. Ragged edges, none high on the mountains.
func thaw_at(x: float, z: float, h: float) -> float:
	if h > SNOW_LINE + 40.0 or h < WATER_Y + 1.4:
		return 0.0
	var n: float = _patches.get_noise_2d(x, z) + _detail.get_noise_2d(x * 2.3, z * 2.3) * 0.06
	return smoothstep(THAW - 0.05, THAW + 0.04, n) * (1.0 - smoothstep(SNOW_LINE + 25.0, SNOW_LINE + 40.0, h))


func _x(index: int) -> float:
	return float(index) * CELL - size * 0.5


func _raw_height(x: float, z: float) -> float:
	var half: float = size * 0.5
	var square: float = maxf(absf(x), absf(z)) / half
	var round_r: float = Vector2(x, z).length() / half
	var r: float = lerpf(square, round_r, 0.45)
	# Rolling meadows, flatter in the middle of the valley.
	var hills: float = _hills.get_noise_2d(x, z) * 22.0 + _detail.get_noise_2d(x, z) * 2.5
	hills *= lerpf(0.35, 1.0, smoothstep(0.05, 0.45, r))
	# A ring of ridged mountains toward the edge.
	var ridge: float = 1.0 - absf(_ridges.get_noise_2d(x, z))
	var rise: float = pow(smoothstep(0.45, 0.95, r), 1.6)
	var mountains: float = rise * (60.0 + ridge * ridge * 110.0)
	var h: float = 6.0 + hills + mountains
	for hill: Vector4 in _mounds:
		var t: float = Vector2(x - hill.x, z - hill.y).length() / hill.z
		if t < 1.0:
			h += hill.w * (0.5 + 0.5 * cos(PI * t))
	for basin: Vector3 in _lakes:
		var d: float = Vector2(x - basin.x, z - basin.y).length() / basin.z
		if d < 1.6:
			var depth: float = smoothstep(1.6, 0.6, d)
			h = lerpf(h, WATER_Y - 6.0, depth)
	# The border eases to EDGE_HEIGHT, so the outer plain meets it with no step.
	var to_edge: float = half - maxf(absf(x), absf(z))
	h = lerpf(EDGE_HEIGHT, h, smoothstep(0.0, EDGE_BLEND, to_edge))
	return h


func _color_at(x: float, z: float, h: float, n: Vector3) -> Color:
	var slope: float = 1.0 - n.y
	var vary: float = _detail.get_noise_2d(x * 1.7, z * 1.7) * 0.5 + 0.5
	if h < WATER_Y - 0.6:
		return LAKE_BED
	if h < WATER_Y + 1.4:
		return SHORE
	if slope > 0.42 or h > TREE_LINE + 25.0:
		return ROCK.lerp(ROCK_DARK, vary)
	var frost: Color = SNOW.lerp(Color("b3ccdf"), vary * 0.5)
	if not is_snow(x, z, h) or slope >= 0.38:
		frost = MEADOW.lerp(MEADOW_LIGHT, vary).lerp(FOREST_FLOOR, forest_at(x, z) * 0.8)
	var thaw: float = thaw_at(x, z, h)
	if thaw <= 0.0:
		return frost
	var turf: Color = TURF.lerp(TURF_LIGHT, vary).lerp(HEATHER, smoothstep(0.55, 0.9, _detail.get_noise_2d(x * 0.9, z * 0.9) * 0.5 + 0.5))
	return frost.lerp(turf, thaw)


## One mesh, vertex coloured. Shared vertices on a regular grid.
func build_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	vertices.resize(count * count)
	normals.resize(count * count)
	colors.resize(count * count)
	for j in range(count):
		for i in range(count):
			var x: float = _x(i)
			var z: float = _x(j)
			var h: float = heights[j * count + i]
			var n: Vector3 = normal_at(x, z)
			var k: int = j * count + i
			vertices[k] = Vector3(x, h, z)
			normals[k] = n
			colors[k] = _color_at(x, z, h, n)
	var indices := PackedInt32Array()
	indices.resize((count - 1) * (count - 1) * 6)
	var w: int = 0
	for j in range(count - 1):
		for i in range(count - 1):
			var a: int = j * count + i
			var b: int = a + 1
			var c: int = a + count
			var d: int = c + 1
			indices[w] = a; indices[w + 1] = b; indices[w + 2] = c
			indices[w + 3] = b; indices[w + 4] = d; indices[w + 5] = c
			w += 6
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A coarser triangle soup for the navmesh bake, every `step` samples, inside a box.
func nav_faces(bounds: AABB, step: int) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var i0: int = maxi(0, int((bounds.position.x + size * 0.5) / CELL))
	var i1: int = mini(count - 1 - step, int((bounds.end.x + size * 0.5) / CELL))
	var j0: int = maxi(0, int((bounds.position.z + size * 0.5) / CELL))
	var j1: int = mini(count - 1 - step, int((bounds.end.z + size * 0.5) / CELL))
	for j in range(j0, j1 + 1, step):
		for i in range(i0, i1 + 1, step):
			var a := Vector3(_x(i), heights[j * count + i], _x(j))
			var b := Vector3(_x(i + step), heights[j * count + i + step], _x(j))
			var c := Vector3(_x(i), heights[(j + step) * count + i], _x(j + step))
			var d := Vector3(_x(i + step), heights[(j + step) * count + i + step], _x(j + step))
			faces.append_array(PackedVector3Array([a, b, c, b, d, c]))
	return faces


## Triangle soup for a ConcavePolygonShape3D, matching build_mesh() exactly.
func collision_faces() -> PackedVector3Array:
	var faces := PackedVector3Array()
	faces.resize((count - 1) * (count - 1) * 6)
	var w: int = 0
	for j in range(count - 1):
		for i in range(count - 1):
			var a := Vector3(_x(i), heights[j * count + i], _x(j))
			var b := Vector3(_x(i + 1), heights[j * count + i + 1], _x(j))
			var c := Vector3(_x(i), heights[(j + 1) * count + i], _x(j + 1))
			var d := Vector3(_x(i + 1), heights[(j + 1) * count + i + 1], _x(j + 1))
			faces[w] = a; faces[w + 1] = b; faces[w + 2] = c
			faces[w + 3] = b; faces[w + 4] = d; faces[w + 5] = c
			w += 6
	return faces
