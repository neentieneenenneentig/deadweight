extends "res://scripts/levels/highlands_base.gd"
## H01 THE PRINCESS'S DUCK (W2, W3): the first raid in the open highlands. Fetch the rubber duck
## from the far north-west forest and take it to Princess Capybara's hot tub on the eastern
## foothill. The meadows are mined, the lakes are thin ice over freezing water, marbles wait on the
## slopes above the duck and the tub, and porcelain hounds that outrun you hunt the valley floor.
## The moment the duck is picked up the meltwater starts to rise, so the way back is up high.

const INFO := {
	"title": "THE PRINCESS'S DUCK",
	"zone": "highlands",
	"number": 7,
	"blurb": "Princess Capybara will not leave her hot tub without her rubber duck. The meadows are mined, the lakes are thin ice, and the meltwater rises.",
	"par_silver": 330.0,
	"par_gold": 210.0,
	"cases": 1,
	"bonus": 0,
	"enemies": true,
	"practice": false,
}

## The flood rises from the lakes to this far above them once the duck is taken.
const FLOOD_RISE := 17.0
const FLOOD_SPEED := 0.18            # m/s: about 95 s from start to full
const HOUND_PACKS := [
	Vector2(-230.0, -290.0), Vector2(-280.0, -350.0), Vector2(-200.0, -360.0),
	Vector2(-60.0, -120.0), Vector2(20.0, -180.0), Vector2(90.0, -90.0),
	Vector2(230.0, -200.0), Vector2(200.0, -300.0),
]


func _populate() -> void:
	scatter_mines(Rect2(-380.0, -400.0, 760.0, 440.0), 45, 9071)
	marble(Vector2(-420.0, -430.0), 3.5, DUCK_XZ, 80.0, Vector3(5.0, 0.0, 3.0))
	marble(Vector2(300.0, -260.0) + Vector2(25.0, -25.0), 3.5, PAD_XZ + Vector2(-40.0, 40.0), 60.0, Vector3(-6.0, 0.0, 6.0))
	marble(Vector2(-60.0, -440.0), 3.0, Vector2(-80.0, -300.0), 70.0, Vector3(0.0, 0.0, 5.0))
	for spot: Vector2 in HOUND_PACKS:
		enemy("hound", _floor(spot) + Vector3.UP * 0.1)
	var half: float = SIZE * 0.5
	traps().flood(Rect2(-half, -half, SIZE, SIZE), Terrain.WATER_Y, Terrain.WATER_Y + FLOOD_RISE, FLOOD_SPEED)
	if not loot_collected.is_connected(_on_duck_taken):
		loot_collected.connect(_on_duck_taken)


func _on_duck_taken(kind: String, _value: int) -> void:
	if kind == "case":
		traps().start_flood()
