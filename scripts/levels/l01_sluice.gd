extends "res://scripts/level_base.gd"
## L01 SLUICE GATE: the original prototype course, ported onto the level framework.
## Canal yard, pump house, high gantry, relay yard, extraction. Everything needed is reachable on
## foot; the rod is the fast way. The two bonus caches are rod-only.

const INFO := {
	"title": "SLUICE GATE",
	"zone": "floodworks",
	"number": 1,
	"blurb": "Canal yard, pump house, high gantry, relay yard. Hounds on the ground, sentries on the rails.",
	"par_silver": 150.0,
	"par_gold": 95.0,
	"cases": 3,
	"bonus": 2,
	"enemies": true,
	"practice": false,
}


func _design() -> void:
	set_zone("floodworks")
	set_spawn(Vector3(0, 0, 14))
	_build_ground()
	_build_entrance()
	_build_pump_house()
	_build_gantry()
	_build_relay_yard()
	_build_extraction()
	_build_dressing()
	case_at(Vector3(-15, 2.4, -18), "01 / PUMP HOUSE")
	case_at(Vector3(14, 5.0, -54), "02 / HIGH GANTRY")
	case_at(Vector3(-13, 0, -91), "03 / RELAY YARD")
	bonus_at(Vector3(0, 8.2, -54), "RIGGING NEST")
	bonus_at(Vector3(-15, 5.4, -93), "RELAY ROOF")
	enemy("hound", Vector3(8, 0.1, -26))
	enemy("hound", Vector3(-7, 0.1, -61))
	enemy("hound", Vector3(6, 0.1, -96))
	enemy("sentry", Vector3(-22, 3.6, -46))
	enemy("sentry", Vector3(22, 2.8, -83))


func _build_ground() -> void:
	ground(Vector3(0, 0, -53), Vector2(58, 158), "concrete", 1.2)
	# Drainage channels are shallow, giving low cover without unavoidable death pits.
	for side: float in [-1.0, 1.0]:
		box(Vector3(side * 26, 0.025, -50), Vector3(2.8, 0.035, 144), "water", false)
		box(Vector3(side * 29, 3.0, -52), Vector3(1.2, 6.0, 160), "dark")
		for z in range(18, -130, -12):
			box(Vector3(side * 28.2, 3.1, float(z)), Vector3(1.1, 6.2, 1.2), "light_concrete")
			box(Vector3(side * 27.48, 2.0, float(z)), Vector3(0.06, 0.18, 1.5), "amber", false)
	box(Vector3(0, 3, 26), Vector3(58, 6, 1.3), "dark")
	box(Vector3(0, 5, -132), Vector3(58, 10, 1.3), "dark")
	# Long route seams and lane markings anchor the sensation of speed.
	for z in range(16, -125, -5):
		box(Vector3(0, 0.018, float(z)), Vector3(0.15, 0.025, 2.3), "yellow", false)
		box(Vector3(-5.8, 0.012, float(z)), Vector3(0.035, 0.02, 4.9), "dark", false)
		box(Vector3(5.8, 0.012, float(z)), Vector3(0.035, 0.02, 4.9), "dark", false)
	for z: float in [-4.0, -36.0, -73.0, -108.0]:
		box(Vector3(0, 0.035, z), Vector3(43, 0.05, 0.22), "yellow", false)
		for x in range(-20, 21, 2):
			box(Vector3(float(x), 0.045, z - 0.8), Vector3(0.8, 0.06, 1.0), "yellow", false)


func _build_entrance() -> void:
	# A heavy entrance frame silhouettes the first launch and establishes the title.
	for side: float in [-1.0, 1.0]:
		box(Vector3(side * 8.5, 5.5, 8), Vector3(1.5, 11, 2), "rust")
	box(Vector3(0, 10.4, 8), Vector3(18.5, 1.8, 2), "rust")
	box(Vector3(0, 10.3, 9.04), Vector3(15.2, 1.2, 0.1), "dark", false)
	label("D E A D W E I G H T", Vector3(0, 10.3, 9.12), 56, Color("e0cda6"), 0.012)
	label("FLOODWORKS  /  DEPARTMENT OF UNFINISHED GRAVITY", Vector3(0, 8.7, 8.9), 26, Color("ffc46b"), 0.011)
	signboard("01   PUMP HOUSE", Vector3(-10, 2.1, -2), "SALVAGE SIGNAL   /   LEFT RAMP")
	signboard("KEEP MOVING", Vector3(10, 2.1, 2), "CHARGE > CAST > LOCK > REEL")
	for side: float in [-1.0, 1.0]:
		crate(Vector3(side * 13.0, 0, 11), Vector3(3.0, 2.3, 3.0))
		crate(Vector3(side * 18.0, 0, 2), Vector3(4.8, 2.9, 3.4))
		barrier(Vector3(side * 5.5, 0, -8), 4.0)
	# A safe launch target makes the first movement experiment readable.
	label("CAST ABOVE THE GATE", Vector3(0, 6.7, -12), 34, Color("5ad6c8"), 0.014, true)


func _build_pump_house() -> void:
	box(Vector3(-15, 1.1, -19), Vector3(15, 2.2, 14), "dark")
	box(Vector3(-15, 2.3, -19), Vector3(15.4, 0.2, 14.4), "light_concrete")
	ramp(Vector3(-15, 0, 2), Vector3(-15, 2.4, -12), 5.5)
	for x: float in [-21.0, -9.0]:
		box(Vector3(x, 4.4, -24), Vector3(0.45, 4.0, 0.45), "rust")
	box(Vector3(-15, 6.3, -24), Vector3(13, 0.45, 0.6), "rust")
	box(Vector3(-21.7, 3.1, -20), Vector3(0.35, 1.4, 10), "rust")
	box(Vector3(-15, 3.3, -25.8), Vector3(14.2, 1.8, 0.35), "rust")
	for x: float in [-19.0, -11.0]:
		cylinder(Vector3(x, 3.1, -23), 0.65, 1.4, "yellow")
	label("P U M P  /  0 1", Vector3(-15, 4.5, -25.5), 36, Color("dce0c9"), 0.018)
	box(Vector3(9, 2.5, -21), Vector3(9, 5, 10), "rust")
	for y: float in [1.2, 2.4, 3.6]:
		box(Vector3(9, y, -15.95), Vector3(8.2, 0.05, 0.04), "yellow", false)
	label("09 / TOMORROW", Vector3(9, 3, -15.88), 42, Color("f1ddc4"), 0.025)
	barrier(Vector3(0, 0, -24), 5.0)
	crate(Vector3(19, 0, -31), Vector3(6, 3, 4))
	signboard("02   HIGH GANTRY", Vector3(6, 2.1, -33), "LOOK UP   /   CAST OVER COVER")


func _build_gantry() -> void:
	# Tall traversal landmark with an accessible long ramp along the right edge.
	for x: float in [-16.0, 14.0]:
		for z: float in [-48.0, -60.0]:
			box(Vector3(x, 4, z), Vector3(0.9, 8, 0.9), "rust")
	box(Vector3(0, 7.5, -49), Vector3(32, 0.8, 1), "rust")
	box(Vector3(0, 7.5, -59), Vector3(32, 0.8, 1), "rust")
	box(Vector3(14, 4.7, -54), Vector3(9, 0.6, 15), "dark")
	box(Vector3(14, 5.02, -54), Vector3(9.4, 0.06, 15.4), "light_concrete", false)
	ramp(Vector3(21, 0, -28), Vector3(21, 5.0, -49), 4.5)
	box(Vector3(18.7, 4.72, -50), Vector3(5, 0.56, 4), "dark")
	box(Vector3(0, 4.7, -59), Vector3(25, 0.6, 4), "dark")
	for x in range(-12, 19, 3):
		box(Vector3(float(x), 5.6, -61), Vector3(0.1, 1.2, 0.1), "yellow")
	box(Vector3(1, 6.15, -61), Vector3(28, 0.12, 0.12), "yellow")
	box(Vector3(18.5, 5.7, -56), Vector3(0.2, 1.4, 10), "rust")
	box(Vector3(14, 5.6, -61.2), Vector3(9, 1.2, 0.2), "rust")
	label("GANTRY  /  02", Vector3(1, 6.7, -48.4), 45, Color("e8d6a8"), 0.018)
	box(Vector3(-22, 1.8, -46), Vector3(6, 3.6, 7), "light_concrete")
	label("SENTRY", Vector3(-22, 2, -42.45), 30, Color("ef654e"), 0.02)
	for x: float in [-7.0, 2.0]:
		cylinder(Vector3(x, 1.7, -48), 2.1, 3.4, "rust")
		cylinder(Vector3(x, 3.45, -48), 2.25, 0.18, "dark", false)
	barrier(Vector3(-7, 0, -38), 6)
	barrier(Vector3(-2, 0, -64), 5)
	crate(Vector3(-18, 0, -66), Vector3(4, 3.2, 6))
	crate(Vector3(16, 0, -69), Vector3(6, 2.8, 4))
	signboard("03   RELAY YARD", Vector3(-8, 2.1, -72), "LAST SIGNAL   /   THEN EXTRACT")
	# Rod-only bonus: a small nest laid across both crossbeams.
	platform(Vector3(0, 8.2, -54), Vector2(6, 10), "dark", false)


func _build_relay_yard() -> void:
	box(Vector3(-15, 2.6, -95), Vector3(18, 5.2, 1), "dark")
	box(Vector3(-23, 2.6, -88), Vector3(1, 5.2, 14), "dark")
	box(Vector3(-7, 2.6, -92), Vector3(1, 5.2, 7), "dark")
	box(Vector3(-15, 5.2, -93), Vector3(18, 0.4, 5), "rust")
	label("R E L A Y  /  0 3", Vector3(-15, 3.7, -94.42), 40, Color("c5d0bc"), 0.017)
	box(Vector3(-19, 1.35, -92.8), Vector3(3, 2.7, 1.4), "light_concrete")
	for x: float in [-19.7, -19.0, -18.3]:
		box(Vector3(x, 1.6, -92.05), Vector3(0.1, 0.7, 0.04), "cyan", false)
	box(Vector3(22, 1.4, -83), Vector3(7, 2.8, 8), "light_concrete")
	crate(Vector3(5, 0, -82), Vector3(6.3, 2.6, 4.0))
	crate(Vector3(-3, 0, -98), Vector3(4, 2.3, 5))
	barrier(Vector3(12, 0, -98), 5)
	barrier(Vector3(-16, 0, -105), 5)
	signboard("EXTRACTION   >", Vector3(0, 2.1, -108), "SECURE THREE CASES   /   HOLD SIX SECONDS", "cyan")
	# Tall comms mast is a distant orientation point.
	box(Vector3(-24, 12, -115), Vector3(0.75, 24, 0.75), "rust")
	for y: float in [8.0, 14.0, 20.0]:
		box(Vector3(-24, y, -115), Vector3(6, 0.18, 0.18), "dark", false)
		cylinder(Vector3(-24, y + 0.5, -115), 0.35, 0.45, "amber", false)


func _build_extraction() -> void:
	extraction(Vector3(16, 0, -116))
	for x: float in [11.0, 21.0]:
		box(Vector3(x, 3, -122), Vector3(0.6, 6, 0.6), "rust")
	box(Vector3(16, 5.8, -122), Vector3(11, 0.65, 0.7), "dark")
	label("E X T R A C T I O N", Vector3(16, 5.8, -121.5), 38, Color("5ad6c8"), 0.012)
	label("BANK SALVAGE  /  HOLD POSITION", Vector3(16, 4.7, -121.5), 24, Color("d8dfca"), 0.011)
	box(Vector3(7, 1.6, -116), Vector3(2.5, 3.2, 8), "light_concrete")
	box(Vector3(24, 1.6, -116), Vector3(2.5, 3.2, 8), "light_concrete")


func _build_dressing() -> void:
	# Static silhouette skyline: no expensive imported assets or dynamic lights.
	var rng := RandomNumberGenerator.new()
	rng.seed = 90421
	for side: float in [-1.0, 1.0]:
		for i in range(12):
			var height: float = rng.randf_range(6.0, 13.0)
			var x: float = side * rng.randf_range(36, 55)
			var z: float = 20.0 - float(i) * 14.0
			box(Vector3(x, height * 0.5 - 4, z), Vector3(rng.randf_range(8, 15), height, rng.randf_range(7, 12)), "dark", false)
			if i % 3 == 0:
				cylinder(Vector3(x, height + 1, z), 1.4, 5, "rust", false)
		for z: float in [-14.0, -45.0, -78.0, -109.0]:
			box(Vector3(side * 25.6, 5.6, z), Vector3(0.25, 11.2, 0.25), "rust")
			box(Vector3(side * 24.2, 11, z), Vector3(3.0, 0.22, 0.3), "dark", false)
			box(Vector3(side * 23, 10.8, z), Vector3(1.1, 0.12, 0.5), "amber", false)
	# A suspended pipe threads the whole map; strong parallax during flight.
	for side: float in [-1.0, 1.0]:
		pipe(Vector3(side * 24.3, 7.3, 20), Vector3(side * 24.3, 7.3, -122), 0.42, "rust", false)
	for z: float in [-8.0, -34.0, -70.0, -104.0]:
		for side: float in [-1.0, 1.0]:
			cylinder(Vector3(side * 23, 0.6, z), 0.45, 1.2, "yellow")
