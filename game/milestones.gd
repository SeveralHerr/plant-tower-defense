class_name Milestones
extends RefCounted

## The things a run can be the first to do, and the rule that decides each one.
##
## Every number below was already on the post-mortem card and already thrown away
## the instant the title screen loaded: RunSummary.summary_rows() reads waves,
## pests defeated, threat, beds lost and compost straight out of Game's own
## counters, and nothing outlives the scene except two high scores. A milestone is
## the cheapest thing that changes that — a flag, set once, against a number the
## run is already holding.
##
## TWO RULES, and both are about not growing the game to feed this file:
##
##   1. **No new gameplay counters.** Every condition here is answered by a key
##      `Game.summary_stats()` already exports. If a milestone idea needs a number
##      nobody counts yet, it is a gameplay change wearing an achievement's hat and
##      it belongs in its own issue.
##   2. **Per-run, never cumulative.** "Your 1000th pest" reads well and costs a
##      second persisted integer with its own overflow, migration and merge
##      semantics — and a lifetime tally that a corrupt save resets to zero is a
##      number the player cannot ever re-earn, which is precisely what run_config's
##      own RULE OF THIS FILE exists to prevent. A flag is idempotent: the worst a
##      lost one costs is one more good run.
##
## The evaluation is static and pure — it takes the stats Dictionary and returns
## ids — so the whole table is assertable as data with no Game, no save file and no
## Control, the same way `Hud.threat_color` is.

## A pest count one determined campaign can reach; the campaign's eight waves put
## roughly this many on the board.
const HUNDRED: int = 100
## And one a campaign cannot: this is an endless-run number.
const FIVE_HUNDRED: int = 500
## Deep endless. WaveDirector.threat_level is a logarithm, so wave 40 is a long way
## past where the fixed campaign stops rather than five more waves of the same.
const ENDLESS_DEEP_WAVE: int = 40
## The level at which Hud.threat_color is fully red — the top of the tint ramp, so
## the milestone and the colour agree about what "runaway threat" means.
const THREAT_PEAK: int = 12
## A sweep is only a sweep if there was something to sweep. Without a floor, the
## run that drops no husks at all sweeps 0 of 0 and earns "every husk swept" for
## having never been near one.
const SWEEP_FLOOR: int = 10

## Id, the line the card prints, and the sentence under it. Ids are the on-disk
## representation (see RunConfig.SAVE_VERSION 3), so they are lowercase ASCII with
## underscores and **never renamed** — a rename silently un-earns the milestone for
## everyone who has it. Add to the end; the order here is the order the card lists.
const TABLE: Array[Dictionary] = [
	{
		"id": "campaign_cleared",
		"title": "The garden holds",
		"note": "Cleared the fixed campaign",
	},
	{
		"id": "unbroken_garden",
		"title": "Not one bed lost",
		"note": "Cleared it without an escape",
	},
	{
		"id": "hundred_pests",
		"title": "A hundred turned back",
		"note": "100 pests defeated in one run",
	},
	{
		"id": "five_hundred_pests",
		"title": "Five hundred turned back",
		"note": "500 pests defeated in one run",
	},
	{
		"id": "endless_deep",
		"title": "Deep in the endless",
		"note": "Reached wave 40 with no end in sight",
	},
	{
		"id": "threat_peak",
		"title": "Everything they had",
		"note": "Faced threat level 12",
	},
	{
		"id": "clean_sweep",
		"title": "Nothing left on the ground",
		"note": "Swept every husk a run produced",
	},
]


## Every id this run satisfies, in TABLE order. Says nothing about which of them
## are new — that is RunConfig's question, because it is the half that needs the
## save file.
static func earned_by(stats: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in TABLE:
		var id: String = String(entry["id"])
		if is_met(id, stats):
			out.append(id)
	return out


## Does this run satisfy one milestone?
##
## A `match` over ids rather than a Callable stored in TABLE, because a `const`
## Array cannot hold a Callable and a parallel Dictionary of lambdas is a second
## table to keep in step with the first. `test_every_milestone_id_has_a_rule`
## walks TABLE and fails on an id this function does not answer, which is the
## thing the split risks.
##
## An unknown id is false, not an error: a save from a build that knew more
## milestones than this one hands us ids with no rule, and the honest reading of
## "is this run earning it" is no.
static func is_met(id: String, stats: Dictionary) -> bool:
	match id:
		"campaign_cleared":
			return bool(stats.get("victory", false))
		"unbroken_garden":
			return bool(stats.get("victory", false)) and int(stats.get("lives_lost", 0)) <= 0
		"hundred_pests":
			return int(stats.get("pests_defeated", 0)) >= HUNDRED
		"five_hundred_pests":
			return int(stats.get("pests_defeated", 0)) >= FIVE_HUNDRED
		"endless_deep":
			return bool(stats.get("endless", false)) and int(stats.get("wave", 0)) >= ENDLESS_DEEP_WAVE
		"threat_peak":
			return int(stats.get("threat_level", 1)) >= THREAT_PEAK
		"clean_sweep":
			var resolved: int = int(stats.get("compost_resolved", 0))
			return resolved >= SWEEP_FLOOR and int(stats.get("compost_total", 0)) >= resolved
	return false


## The TABLE row for an id, or `{}`. Returns a row rather than a title so a caller
## that wants both lines does not have to look the id up twice.
static func entry(id: String) -> Dictionary:
	for row: Dictionary in TABLE:
		if String(row["id"]) == id:
			return row
	return {}


## The card's line for an id. Falls back to the raw id rather than to "" — an id
## from a newer build has no title here, and printing nothing would leave a blank
## row on the post-mortem with no way to tell it from a layout bug.
static func title_of(id: String) -> String:
	var row: Dictionary = entry(id)
	return String(row["title"]) if row.has("title") else id


static func note_of(id: String) -> String:
	var row: Dictionary = entry(id)
	return String(row["note"]) if row.has("note") else ""
