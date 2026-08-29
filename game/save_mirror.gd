class_name SaveMirror
extends RefCounted

## A copy of the finished save in the browser's `localStorage`, so "the wardrobe
## persists on the web build" is a claim this project can actually make.
##
## WHY THIS EXISTS AT ALL. `user://` on a Web export is an IDBFS mount, and whether it
## is flushed to IndexedDB before the tab closes is the engine's business, not this
## project's. Nothing here had ever tested it, and nothing here could: the whole web
## half sits behind `OS.has_feature("web")`, a branch no gate in this repo can open.
## Until the shop, that was a tolerable unknown — a lost save cost a high score. Now it
## costs a wardrobe the player spent whole campaigns earning.
##
## A COPY, NEVER A SECOND SOURCE OF TRUTH, and that is the whole design. There is
## exactly one writer (`RunConfig._save`, after the temp file has been validated by the
## loader's own parser and renamed into place) and exactly one reader
## (`RunConfig._load`, only when `save_path` and its `.tmp` are BOTH absent, and even
## then it writes the bytes to `save_path` and parses that). So the mirror never gets
## its own parser, its own validator or its own migration path, and a mirror this build
## cannot read is refused by the same code that refuses a file it cannot read.
##
## The alternative considered was mirroring the FIELDS — a JSON blob of scores and
## purchases written beside the save. Rejected: that is a second format, with a second
## version number, that can disagree with the first. Mirroring the bytes means the two
## can only ever agree or be absent.

## The one key this project owns in the host page's storage. Versioned in the name
## rather than in the value, so a future format that cannot be read forward can simply
## be given a new key instead of teaching this class to migrate — see the class header
## for why migration must not live here.
const KEY := "plant_td_save_v1"

## The engine singleton this class talks to, named as a STRING and reached through
## `Engine.get_singleton`.
##
## Not `JavaScriptBridge.eval(...)` written out, which is the obvious spelling and does
## not compile on desktop: that singleton is registered only in a Web export, so a bare
## reference is an unresolved identifier that fails the whole file on every other
## platform — including every gate this project runs.
const BRIDGE_SINGLETON := "JavaScriptBridge"

## TEST SEAM. Headless has no JavaScriptBridge, so a test that wants to exercise the
## mirror path sets this to a Dictionary and the backend writes there instead.
##
## See `.claude/skills/extract-a-testable-seam`: without it the entire web half sits
## behind `OS.has_feature("web")`, a gate nothing in this project can ever open, and
## "the save is mirrored" would be an assertion about code that no run has executed.
##
## `Variant` and not `Dictionary`, because `null` is the state that means "not
## overridden" and an empty Dictionary is a legitimate empty store. A test MUST put it
## back to `null`, or every later `_save()` in the process mirrors into a stale
## dictionary and every later `_load()` over a missing file reads one back.
static var force_store: Variant = null


## Whether there is anywhere to mirror to. False on a desktop build with no override,
## which is the normal case and the reason `RunConfig` asks before it writes.
static func active() -> bool:
	return force_store != null or OS.has_feature("web")


## Stores `text` under KEY. Returns whether it landed.
##
## The browser half is wrapped in its own try/catch INSIDE the evaluated JavaScript
## rather than checked afterwards, because a browser that refuses storage — private
## mode, a quota, a user who blocked site data — throws from `setItem` rather than
## returning a failure, and a throw crossing the bridge is not something GDScript can
## catch. So the script answers 1 or 0 and this returns that, and a refusal is a false
## rather than an exception nobody is positioned to handle.
static func write(text: String) -> bool:
	if force_store != null:
		(force_store as Dictionary)[KEY] = text
		return true
	var bridge: Object = _bridge()
	if bridge == null:
		return false
	var script: String = ("(function(){try{window.localStorage.setItem(%s,%s);return 1;}"
		+ "catch(e){return 0;}})()") % [JSON.stringify(KEY), JSON.stringify(text)]
	return int(bridge.call("eval", script, true)) == 1


## What is stored under KEY, or "" when there is nothing there.
##
## "" for absent AND for a browser that refuses to read, deliberately: both mean "this
## mirror has nothing for you", and the only caller — `RunConfig._load` on a missing
## save — treats them identically by falling through to `load_status = "absent"`.
## Distinguishing them would offer a caller a decision it has no way to act on.
static func read() -> String:
	if force_store != null:
		return String((force_store as Dictionary).get(KEY, ""))
	var bridge: Object = _bridge()
	if bridge == null:
		return ""
	var script: String = ("(function(){try{var v=window.localStorage.getItem(%s);"
		+ "return v===null?'':v;}catch(e){return '';}})()") % [JSON.stringify(KEY)]
	var result: Variant = bridge.call("eval", script, true)
	return "" if result == null else String(result)


## Throws the mirror away. Used by tests and by nothing in the game: the game only ever
## replaces the mirror, because a save that failed to write is not a reason to destroy
## the last one that succeeded.
static func erase() -> void:
	if force_store != null:
		(force_store as Dictionary).erase(KEY)
		return
	var bridge: Object = _bridge()
	if bridge == null:
		return
	var script: String = ("(function(){try{window.localStorage.removeItem(%s);}"
		+ "catch(e){}})()") % [JSON.stringify(KEY)]
	bridge.call("eval", script, true)


## The engine's JavaScript bridge, or null on a platform that has none. See
## BRIDGE_SINGLETON for why this is a string lookup rather than a name.
static func _bridge() -> Object:
	if not Engine.has_singleton(BRIDGE_SINGLETON):
		return null
	return Engine.get_singleton(BRIDGE_SINGLETON)
