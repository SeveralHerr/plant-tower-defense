class_name Sunflower
extends Plant

## The third plant — an economy pick, not a combat one, so a rare packet has
## something worth pulling for besides "a slightly better Corn". It fires
## nothing and grabs nothing; it just pays out seeds on a clock, which makes
## the cell it stands on a real trade-off against a lane tile.

signal grew_seeds(amount: int)

const INTERVAL: float = 6.0
const YIELD: int = 3

var _timer: float = 0.0


func _act(delta: float, _pests: Array[Pest]) -> void:
	_timer += delta
	if _timer < INTERVAL:
		return
	_timer -= INTERVAL
	grew_seeds.emit(YIELD)
	_bloom()


func seconds_until_next_yield() -> float:
	return maxf(0.0, INTERVAL - _timer)


func _bloom() -> void:
	if _sprite == null or not is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2(1.16, 1.16), 0.10)
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.18)
