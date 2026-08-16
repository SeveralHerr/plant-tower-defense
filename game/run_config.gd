extends Node

## Autoload. The one thing that has to survive the title-screen -> game.tscn
## scene swap: which mode the player picked, plus the seed high scores, which by
## definition have to outlive any single run.
##
## `endless` is read once, by Game._ready() wiring it into WaveDirector; the
## title screen is the only writer. The scores are persisted to user:// so they
## are still there next launch, not just next scene.
##
## There are two scores because there are two games. The fixed campaign ends
## after WaveDirector's eight-wave table; endless never ends. A campaign total
## and an endless total are therefore not comparable in either direction, and
## sharing one number meant a single endless run permanently retired the campaign
## record — while the title screen labelled that number "Best endless run"
## whichever mode had actually set it.

const SAVE_PATH := "user://highscore.save"
## Bumped when the on-disk shape changes. Version 1 is the original single line.
const SAVE_VERSION: int = 2

var endless: bool = false
var campaign_high_score: int = 0
var endless_high_score: int = 0


func _ready() -> void:
	_load()


## The record for a mode. Takes the flag rather than reading `endless`, so the
## title screen can show both without having to lie about which mode is selected.
func best_for(for_endless: bool) -> int:
	return endless_high_score if for_endless else campaign_high_score


## Called once a run ends (win or lose). Only ever raises the record — a worse
## run than last time should not overwrite the number the player is proud of.
## Files against the mode that was actually played.
func record_score(seeds_earned: int) -> bool:
	if seeds_earned <= best_for(endless):
		return false
	if endless:
		endless_high_score = seeds_earned
	else:
		campaign_high_score = seeds_earned
	_save()
	return true


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("v%d" % SAVE_VERSION)
	f.store_line(str(campaign_high_score))
	f.store_line(str(endless_high_score))


## Reads either save shape. A version-1 file is a bare integer on one line.
##
## That legacy number is migrated into the ENDLESS slot, and the choice is not
## arbitrary: the title screen has always presented it as "Best endless run", so
## that is the record the player believes they hold, and endless totals dwarf
## campaign ones (eight waves against an unbounded run) — so a legacy value that
## did come from a campaign is merely a hard endless record, whereas the reverse
## migration would leave an unbeatable number sitting on the eight-wave mode.
func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var first: String = f.get_line().strip_edges()
	if not first.begins_with("v"):
		endless_high_score = int(first)
		campaign_high_score = 0
		# Rewrite immediately in the new shape, so the ambiguity is resolved once
		# rather than being re-guessed on every launch.
		_save()
		return
	campaign_high_score = int(f.get_line())
	endless_high_score = int(f.get_line())
