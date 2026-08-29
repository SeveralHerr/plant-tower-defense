---
name: screenshot-the-game
description: Take a real screenshot of the running game and look at it. Use whenever you need to SEE the UI or the world rather than read its code — reflecting on UI, checking a visual change landed, or before claiming anything looks right.
---

Godot's Movie Maker writes one PNG per frame. No bridge, no code change.

```bash
"$GODOT" --path . --write-movie <scratchpad>/shot.png --fixed-fps 2 --quit-after 1
```

`Read` `<scratchpad>/shot00000000.png`. MEASURED 2026-08-29: 1.7 s, and the title screen is up.

That first frame is MID-FADE — panel labels faint, buttons translucent, camera still settling — so it answers "is it there", not "does it look right". For a settled screen use `--quit-after 6` and read the LAST png (`shot00000005.png`, 2 s).

`$GODOT` is `godot_bin` in **`tools/gates_config.json`**. IN A WORKTREE, SPELL THE PATH OUT: a
shell variable or a `$(...)` that reads the config is refused by the isolation check with
"this command is too complex to verify that it stays inside the worktree", which says
nothing about git and does not mention the variable (MEASURED 2026-08-29, `moving-in-eglw`).
Real window, not headless — that is the point, and it is also the only way to see anything
gated on `GardenTheme.animations_enabled()`, which is FALSE under `--headless`. Steamworks
and leaked-RID warnings are normal; a stray `shot.wav` is too — delete it, it is unwanted.

## That command only ever photographs the title screen

The title card is what the main scene boots into and nothing in this repo drives input, so
the board itself — a plant placed, a pest mid-swing, a HUD chip in a refused state — is out
of reach that way. Pass a scene of your own as the first positional argument and Movie Maker
records THAT instead. Two throwaway files under `tools/` (exempt from the `.uid` lint),
deleted afterwards:

```
tools/_shot_x.tscn      [gd_scene load_steps=2 format=3]
                        [ext_resource type="Script" path="res://tools/_shot_x.gd" id="1_x"]
                        [node name="Shot" type="Node"]
                        script = ExtResource("1_x")
```

```bash
"<godot>" --path . res://tools/_shot_x.tscn --write-movie <scratchpad>/x.png \
    --fixed-fps 30 --quit-after 120
```

### Staging a piece of the BOARD, not a Control

A widget scene needs a backdrop and the widget. A gameplay scene needs three more things,
and the third one costs a whole render cycle if you get it wrong.

```gdscript
# tools/_shot_x.gd
extends Node
func _ready() -> void:
    var bg := ColorRect.new()                       # a mid ground, not black: contrast test
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.42, 0.35, 0.26)
    add_child(bg)

    var stage := Node2D.new()
    add_child(stage)
    var eye := Camera2D.new()                       # ZOOM WITH THIS. See below.
    eye.zoom = Vector2(3.4, 3.4)
    eye.position = Vector2(122, 230)
    stage.add_child(eye)
    eye.make_current()

    var plant := CornCobbler.new()
    plant.setup(PlantCatalog.CORN, Vector2i(0, 0), null)   # `null` board is fine
    plant.position = Vector2(140, 200)
    stage.add_child(plant)                          # `setup` also joins the "plants" group

    var pest := Pest.new()
    pest.setup(Pest.BEETLE, PackedVector2Array([Vector2(95, 264), Vector2(600, 264)]))
    pest.position = Vector2(95, 264)
    pest.apply_mutation(Pest.MUTATION_HUNGRY)
    stage.add_child(pest)
```

**ZOOM WITH A `Camera2D`, NEVER BY SCALING A PARENT.** Every proximity rule in this game is
a distance between `global_position`s — `Pest._adjacent_plant` (`EAT_RADIUS`),
`Pest._blocking_plant` (`Bramble.STOP_RADIUS`), `ChompFlower._nearest_free_pest`
(`grab_radius`). A stage scaled 3.4x multiplies every one of those distances by 3.4, so the
pest walks straight past a plant it would have engaged in the real game and the recording
shows nothing happening at all, with no error. MEASURED 2026-08-29 (`plant-tower-defense-ulf1`,
first render cycle, wasted). A camera's zoom is not in any node's transform and changes none
of them.

**`print()` the state you are photographing, every frame, from `_process`.** The log is what
tells you which png holds which beat, and it is also how you find out the scene is doing
nothing without opening a single image:

```gdscript
func _process(_d: float) -> void:
    _frame += 1
    print("frame %d phase %.3f health %.2f" % [_frame, _pest.swing_phase(), _health()])
```

`--fixed-fps 30` makes every `delta` exactly 1/30 s, so the frame number IS a clock — count
seconds into frames to know how long to run, and note that the first `_process` call is
frame 1 while the first png is `x00000000.png`.

## Putting specific plants on the REAL board, in a state the game would take minutes to reach

A backdrop scene is right for one widget. When what you need is a plant *in the garden* —
against the grass and road it will actually sit on, with the HUD beside it — host
`game.tscn` and plant into it. Every planting path returns a **refusal string**, so print
it: a cell the game says no to leaves an empty board, and an empty board photographs
perfectly.

```gdscript
# tools/_shot_sport.gd — deleted afterwards; tools/ is exempt from the .uid lint
extends Node
var _frame: int = 0
var _game: Node = null
func _ready() -> void:
	_game = load("res://game/game.tscn").instantiate()
	add_child(_game)
func _process(_d: float) -> void:
	_frame += 1
	if _frame == 12:                                  # not frame 1 — see below
		print("corn (2,2): %s" % _game.place_plant(PlantCatalog.CORN, Vector2i(2, 2)))
		print("sport (3,2): %s" % _game._sprout_sport(PlantCatalog.SUNFLOWER, Vector2i(3, 2)))
	if _frame >= 12:
		print("frame %d: plants=%d" % [_frame, _game._plants.size()])
```

```bash
"<godot>" --path . res://tools/_shot_sport.tscn --write-movie <scratchpad>/sp.png --fixed-fps 12 --quit-after 30
```

MEASURED 2026-08-29 (plant-tower-defense-cbbi): two sports on the board, badges and all,
in about four seconds of recording.

Three things that cost a run each:

- **`add_child` in `_ready` errors with `Parent node is busy setting up children`.** It
  still works — the node is added — so the recording is fine and the line is noise. Do not
  chase it. `add_child.call_deferred` is the clean form if it bothers you.
- **Plant from `_process`, not `_ready`.** `Game`'s own `@onready` wiring has not run
  during your `_ready`, so `board` is null and every placement is refused.
- **Row 1 of the shipped board is ROAD.** `place_plant(CORN, Vector2i(2, 1))` returns
  `"pests walk there — try the grass"` and plants nothing. Print the return value and you
  see that immediately; skip the print and you get a beautiful photograph of an empty
  garden. `_sprout_sport` refuses on the same rule (`Board.is_buildable_for`), so a road
  plant like the Barrier Bramble is the opposite case — it wants the road and refuses
  grass.

`_sprout_sport(kind, cell)` is also the only way to photograph a **mutated** plant: the
real mechanic rolls one about every 240 s of play (`CrossBreeder.CHANCE_PER_TICK`), which
no recording is going to sit through.

## Shoot at the zoom the game is PLAYED at before you call an animation legible

A zoomed capture flatters a subtle animation, and this is the failure mode most likely to
send you away satisfied with a change nobody can see. MEASURED 2026-08-29 (`-ulf1`): a
pest's chop read perfectly as a wind-up and a strike at `zoom = 3.4`, and at `zoom = 1.0` —
the size a player actually sees — the same beat was a twitch. The travel constants had to
roughly triple. Take the zoomed frames to understand the motion if you like; take the 1x
frames before you decide it is finished.

## Finding WHICH frame holds a transient beat — measure the pngs, do not browse them

A punch, a flash or a pop lasts a fraction of a second, and at `--fixed-fps 30` that is
one or two frames out of seventy. Reading images one at a time will not find it, and the
frame you happen to pick is almost always a resting frame that looks exactly like every
other resting frame — which reads as "the effect never played".

Measure every frame in one pass instead, on one row of pixels through the thing you care
about, and let the numbers say where the beat is. Pillow is installed:

```python
from PIL import Image
for p in sorted(glob.glob(os.path.join(sd, "pop*.png"))):
    px = Image.open(p).convert("RGB").load()
    dark = sum(1 for x in range(200) if sum(px[x, 20]) < 200)   # width of a dark pill on row 20
    print(os.path.basename(p), dark)
```

MEASURED 2026-08-29 on the stat pill's placement pop (`UiJuice.pop_accent`, `PUNCH_TIME`
0.26 s, captured at `--fixed-fps 30`): the row read `92, 92, ..., 92, 97, 93, 92, 92, ...`.
Two frames. The 97 is the whole effect, and `Read`ing frame 29 or frame 33 would have shown
a pill identical to the one in every other frame.

Two things this also settles that a still cannot. **Whether the beat repeats** — fire it on
a `Timer` and the number spikes once per period, so a spike at 30 and at 60 is proof the
effect is re-armed rather than a one-off. And **which direction it moves**: a width that
goes UP is a stretch, one that goes down is a squash, and on a left-anchored element you
can put a second probe on the left edge column to see whether the element grew in place or
walked sideways.

**Pick the probe's colour band against a real pixel, not against your idea of one.** A
predicate guessed from the palette can match the BACKGROUND, and then every frame reports
the same number and the beat looks flat — indistinguishable from an animation that never
played. If the numbers are identical across all frames, suspect the probe before the code:
print one known pixel and check the band contains it. A per-frame `print()` from the scene
(above) is the cheaper way to get the same answer, so prefer it when the value you want is
one the game already computes.

If you did not Read a png, you did not see the UI. Say so.
