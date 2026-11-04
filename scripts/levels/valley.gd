extends "res://scripts/levels/highlands_base.gd"
## THE HIGHLANDS (practice preview): the open valley with no clock and no hostiles, to judge the
## look and the scale and to learn the ground dangers safely: the lakes' thin ice, a small field of
## teacup mines south of the spawn, and one marble on the eastern foothill.

const INFO := {
	"title": "THE HIGHLANDS",
	"zone": "highlands",
	"number": -2,
	"blurb": "Preview of the open world: meadows, forest, frozen lakes and snowy peaks. Bring the princess her duck.",
	"par_silver": 0.0,
	"par_gold": 0.0,
	"cases": 1,
	"bonus": 0,
	"enemies": false,
	"practice": true,
	"repeatable": true,
}


func _populate() -> void:
	# A practice minefield beside the spawn, east of the path north, with a sign at its edge.
	scatter_mines(Rect2(40.0, -60.0, 70.0, 90.0), 10, 55)
	_sign("TEACUP MINEFIELD\nTHEY BEEP, THEN THEY DO NOT\n(TRY THROWING THE WEIGHT IN)", _floor(Vector2(34.0, 30.0)), Vector2(5.6, 2.0))
	marble(TUB_XZ + Vector2(25.0, -25.0), 3.5, PAD_XZ + Vector2(-40.0, 40.0), 60.0, Vector3(-6.0, 0.0, 6.0))
