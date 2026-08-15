extends Node

## Autoload. The one thing that has to survive the title-screen -> game.tscn
## scene swap: which mode the player picked, plus the seed high score, which
## by definition has to outlive any single run.
##
## `endless` is read once, by Game._ready() wiring it into WaveDirector; the
## title screen is the only writer. `high_score` is persisted to user:// so it
## is still there next time the game launches, not just next scene.

const SAVE_PATH := "user://highscore.save"

var endless: bool = false
var high_score: int = 0


func _ready() -> void:
	_load()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	high_score = int(f.get_line())


## Called once a run ends (win or lose). Only ever raises the record — a worse
## run than last time should not overwrite the number the player is proud of.
func record_score(seeds_earned: int) -> bool:
	if seeds_earned <= high_score:
		return false
	high_score = seeds_earned
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_line(str(high_score))
	return true
