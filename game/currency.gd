class_name Currency
extends RefCounted

## Every meta-currency the Shop spends, what each one is called, and the one arithmetic
## a wallet supports (plant-tower-defense-il1y).
##
## This is the pure data and the rule, the same split `Skins` already draws against
## `RunConfig`: `Currency` answers "what can be earned, what is it called, does this
## wallet cover this price", `RunConfig.wallet` is the persisted balance, and
## `RunConfig.grant()` / `RunConfig.buy_skin()` are its two writers. Nothing here
## touches a save file and nothing here is mutable — every function is `static` and
## takes the wallet it works on as an argument, so the whole rule is assertable with no
## RunConfig, no Game and no Control, exactly as `Skins.is_owned` is.
##
## ---------------------------------------------------------------------------
## WHY THREE, AND WHY THEY ARE EARNED THREE DIFFERENT WAYS
##
## Until this file there was ONE currency — petals — and one price: five for a plant
## skin, three for a pest. A campaign pays 27 petals for its 27 waves and 10 more per
## first-time milestone, so the entire wardrobe was about two runs' work and the Shop
## had nothing left to want by the third. The fix is not "multiply the petal price",
## because a single number scaled up is a single grind lengthened: whichever way a
## player already earns fastest is the way they would earn all of it.
##
## So a skin costs THREE things, and the three are earned by three different kinds of
## play:
##
##   petals     one per wave cleared, MILESTONE_PETALS per first-time milestone.
##              Time at the board. Endless pays this fastest.
##   compost    one per COMPOST_PER_PESTS pests defeated in a banked run.
##              Volume. A defensive run that lets nothing through pays most.
##   heartwood  one per first-time milestone and one per campaign WON.
##              Finishing. Nothing else pays it, so no amount of endless grinding
##              substitutes for actually clearing the campaign.
##
## The prices (`Skins.PRICES`) are set so that all three run out at about the same
## number of campaigns rather than one binding long before the others — see that table
## for the arithmetic. A price whose scarcest term is four times its cheapest is a
## price with one real number in it and two decorations.
##
## ---------------------------------------------------------------------------
## A WALLET IS A DICTIONARY, AND EVERY ID IN IT IS A KEY OF THIS TABLE
##
## `id -> int`, never negative, and `empty_wallet()` is what a fresh save carries: every
## id present at 0 rather than an empty Dictionary, so a reader never has to distinguish
## "no compost" from "this build had no compost". `amount_in()` answers 0 for an id this
## build does not know, which is the tolerance `RunConfig.parse_wallet_line` needs — a
## save from a LATER build names a currency that does not exist here, it is kept on disk
## verbatim, and it buys nothing.
##
## ---------------------------------------------------------------------------
## A PRICE IS THE SAME SHAPE AS A WALLET
##
## `covers()` and `spend()` take one, and both are total: a price naming an unknown
## currency is never covered (there is no balance that could pay it) rather than being
## silently skipped, because the alternative hands out a free skin the moment a save
## carries a price this build cannot read.

## The three ids. StringNames, and spelled as constants rather than as `&"petals"` at
## every call site for the reason `Skins.DEFAULT_SKIN` is: these are SAVE KEYS, so a
## typo at one of a dozen sites is a currency that silently reads as zero.
const PETALS := &"petals"
const COMPOST := &"compost"
const HEARTWOOD := &"heartwood"

## Pests a run must defeat to be worth one compost. Twenty against a campaign that
## sends about 715 of them, so a full campaign clear is worth roughly 35 — the same
## order as the 27 petals its waves pay, which is what makes the two terms of a price
## run out together instead of one being decoration on the other.
##
## FLOORED, not rounded (`compost_for`): a run that defeated nineteen pests is worth
## nothing, and that is the honest reading of a rate. Rounding up would make a
## twenty-second quit-out worth the same as a wave.
const COMPOST_PER_PESTS: int = 20

## Heartwood a first-time milestone is worth, and heartwood a WON campaign is worth.
##
## One apiece, and they are the only two sources. Seven milestones exist, so a player
## who has done everything once has seven heartwood banked and every one after that
## costs a campaign victory — which is the scarcity this currency exists to create.
## Endless pays none of it at all, deliberately: a run with no end cannot be won, and
## a currency any run could farm would not be a third term.
const MILESTONE_HEARTWOOD: int = 1
const VICTORY_HEARTWOOD: int = 1

## One row per currency: the id a save spells, the word the Shop draws, the mark it
## draws beside a number when the font can draw it, and where the currency comes from.
##
## `source` IS DRAWN, not a comment. It is the last column of the Shop's currency
## table, read straight off this row rather than transcribed into that screen, so a
## currency added here explains itself where it is spent with nothing there to edit
## (`.claude/skills/derive-the-list`). A row whose `source` said one thing while the
## screen said another is the drift this shape exists to make impossible — and it is the
## drift that was live here, because "where petals come from" used to be a sentence
## typed into `ShopScreen.NOTE_TEXT`.
##
## KEEP IT SHORT ENOUGH TO BE A COLUMN. `ShopScreen.source_column_width()` measures the
## widest of these and `panel_width()` widens the paper to fit it, so a long sentence
## does not clip — it makes the whole screen wider, and past
## `OverlayScreen.design_width()` the containment sweep fails the build. A clause, not a
## paragraph.
##
## The three marks are `✿`, `❖` and `❂` in that order, and they are written out here so
## a reader of this table can see what a row draws without opening two other files —
## `Glyphs.TABLE` is still where each one's MEANING lives, and the rows below take them
## from that file by name rather than repeating the characters as data.
##
## `glyph` is taken from `Glyphs` rather than spelled here for the reason `ShopScreen`
## already takes its check mark: the character a screen draws and the row that says what
## that character MEANS cannot be allowed to become two different characters. All three
## are Dingbats, which this project's shipped font is not guaranteed to carry, so the
## drawing site asks `Font.has_char()` first and drops the mark when the answer is no —
## see `ShopScreen.currency_label()`, where the currency's own WORD is always beside it
## and the mark is decoration rather than the unit.
const TABLE: Array[Dictionary] = [
	{
		"id": PETALS,
		"title": "Petals",
		"glyph": Glyphs.PETAL,
		"source": "one for every wave cleared, ten for a milestone",
	},
	{
		"id": COMPOST,
		"title": "Compost",
		"glyph": Glyphs.COMPOST,
		"source": "one for every %d pests defeated" % COMPOST_PER_PESTS,
	},
	{
		"id": HEARTWOOD,
		"title": "Heartwood",
		"glyph": Glyphs.HEARTWOOD,
		"source": "one for a milestone, one for a campaign won",
	},
]


## Every currency id, in TABLE order — which is the order the Shop draws its purse and
## its prices in. The order is the table's, not a copy of it kept anywhere else.
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for row: Dictionary in TABLE:
		out.append(StringName(row["id"]))
	return out


## The TABLE row for an id, or `{}` for one this build does not know — which a save
## from a newer build can carry, the same tolerance `Skins.family()` extends to a
## foreign family id.
static func row(id: StringName) -> Dictionary:
	for entry: Dictionary in TABLE:
		if StringName(entry["id"]) == id:
			return entry
	return {}


static func has(id: StringName) -> bool:
	return not row(id).is_empty()


## The word the Shop draws. Falls back to the raw id, the same choice
## `Skins.title_of` makes, so a currency from a newer build's save never renders blank.
static func title_of(id: StringName) -> String:
	var entry: Dictionary = row(id)
	return String(entry["title"]) if entry.has("title") else String(id)


## The mark drawn beside a number, or "" for an id this build does not know. Whether
## the font can actually DRAW it is a separate question and belongs to the drawing
## site — see `ShopScreen.currency_label()`.
static func glyph_of(id: StringName) -> String:
	return String(row(id).get("glyph", ""))


## Where this currency comes from, as the Shop's note says it. "" for an unknown id, so
## a composed note simply omits a currency it cannot explain.
static func source_of(id: StringName) -> String:
	return String(row(id).get("source", ""))


## A wallet holding nothing: every id this build knows, at zero.
##
## EVERY ID PRESENT, not an empty Dictionary, so nothing downstream has to tell "this
## player has no compost" apart from "this build has no compost". `RunConfig`'s reset
## and a fresh save both start here.
static func empty_wallet() -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in ids():
		out[String(id)] = 0
	return out


## What `wallet` holds of `id`. Zero for a currency the wallet has never seen and zero
## for one this build does not know, so a caller never branches on absence.
##
## KEYED BY STRING, because that is what the save line parses to and what
## `empty_wallet()` writes: a Dictionary mixing String and StringName keys answers
## `has()` false for the spelling it was not written with, and would do it silently.
static func amount_in(wallet: Dictionary, id: StringName) -> int:
	var value: Variant = wallet.get(String(id), 0)
	if not (value is int or value is float):
		return 0
	return maxi(0, int(value))


## Whether `wallet` can pay `price` in full — every currency the price names, at once.
##
## ALL OR NOTHING. A skin is one purchase, so a wallet that covers two of the three
## terms buys nothing and spends nothing; part-paying would leave a player with a
## balance drained into a skin they do not own.
##
## A price naming a currency this build does not know is NEVER covered, rather than
## being skipped as unpriceable: `amount_in` answers 0 for it, so the comparison is
## `0 >= n`, which is false for any real price. That is the safe direction — the unsafe
## one hands out a free skin the day a save from a newer build is read.
static func covers(wallet: Dictionary, price: Dictionary) -> bool:
	for key: Variant in price.keys():
		if amount_in(wallet, StringName(key)) < int(price[key]):
			return false
	return true


## `wallet` with `price` taken out of it, as a NEW Dictionary — the caller decides
## whether to keep it, which is what lets `RunConfig.buy_skin` run every refusal before
## anything is mutated.
##
## Never below zero, and never asked to be: `buy_skin` checks `covers()` first. The
## clamp is here anyway because a wallet that went negative would be refused by the
## save's own validator and would kill every write for the rest of the session
## silently — the failure `RunConfig.grant`' own header describes.
static func spend(wallet: Dictionary, price: Dictionary) -> Dictionary:
	var out: Dictionary = wallet.duplicate(true)
	for key: Variant in price.keys():
		var id := StringName(key)
		out[String(id)] = maxi(0, amount_in(wallet, id) - int(price[key]))
	return out


## `wallet` with `count` more of `id`, as a new Dictionary. A count at or below zero is
## a no-op for the reason `RunConfig.grant` gives, and an unknown id is refused rather
## than added: a save is not a place to invent a currency.
static func add(wallet: Dictionary, id: StringName, count: int) -> Dictionary:
	var out: Dictionary = wallet.duplicate(true)
	if count <= 0 or not has(id):
		return out
	out[String(id)] = amount_in(wallet, id) + count
	return out


## The compost a run that defeated `pests` is worth. Floored — see COMPOST_PER_PESTS.
static func compost_for(pests: int) -> int:
	if pests <= 0 or COMPOST_PER_PESTS <= 0:
		return 0
	return pests / COMPOST_PER_PESTS
