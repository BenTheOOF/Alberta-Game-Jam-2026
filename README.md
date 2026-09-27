# PAY THE PRICE

**Alberta Game Jam 2026 — Everything Has a Price.**

Your money is your health, ammunition, stamina, and score. Start with $100,
pay your way through twelve departments, and keep $50 to buy your freedom.
Every choice has a price. The balance left after the exit payment is your score.

## Play

Import `project.godot` in **Godot 4.7 stable** and press **F5**. The main scene
is `scenes/main.tscn`. The game uses GDScript and the Compatibility renderer;
no plugins, C#, or manual scene setup are required.

- **Windows:** extract the ZIP, then run `PayThePrice.exe`.
- **Linux:** extract the ZIP, make `PayThePrice.x86_64` executable if necessary,
  and run it.
- **Web / itch.io:** upload the Web ZIP as an HTML5 game. `index.html` is at its
  root. To test locally, serve the extracted folder with
  `python -m http.server 8000`, then open `http://localhost:8000`.
  The Web export is single-threaded and needs a keyboard and mouse.

| Control | Action | Starting price |
| --- | --- | --- |
| WASD / arrows | Move | Free |
| Mouse | Aim | Free |
| Left click / hold | Shoot | $1 |
| Space | Dash with brief hit protection | $3 |
| E | Approve highlighted interaction | Displayed before purchase |
| Escape | Pause / resume; back after a run | Free |
| R | Restart the entire account | Free |
| M | Mute / unmute music and effects | Free |

## Progression and choices

The first three spaces teach movement, paid shooting, money as health,
dashing, and a $2 door purchase through play. Aim for roughly 30–60 seconds
on a first visit; a player who already knows the route can finish sooner.

| Department | Main decision / mechanic |
| --- | --- |
| 1. New Account | Walk through two checkpoints; movement is free |
| 2. Billable Violence | Shoot two harmless targets; a scanner demonstrates one $5 hit |
| 3. Expense Training | Dash through the barrier, then approve the $2 door fee |
| 4. Induction | Three shifts of collectors and fast collection agents |
| 5. Risk Management | $5 chests, a one-use ATM, and another combat shift |
| 6. The Cost of Choice | Free detour, $1 toll tiles, or a $15 encounter skip; optional loan |
| 7. Employee Benefits | Four optional upgrades |
| 8. Accounts Receivable | Ranged bankers; survive an 80-second transfer and clear claims |
| 9. Market Correction | Permanent inflation, warning floors, 70-second settlement |
| 10. Debt Restructuring | Capped percentage tax, a $10 refund, and emergency credit |
| 11. Final Audit | 90-second audit combining every enemy type |
| 12. Financial Freedom | Pay $50 to win; free-entry overtime if underfunded |

The first-playthrough pacing target is **8–15 minutes**, with staged encounters,
three timed objectives, and optional purchases. This is a tuning target, not a
measured human playtest result; repeat players and shortcut users can be faster.

## The small print

- **Money = life.** Any ordinary transaction reaching $0 immediately bankrupts
  the account. The final exit is atomic: exactly $50 wins with a $0 score.
- **Enemies:** red collectors need 3 hits and charge $5 on contact. Purple
  agents need 2 hits and charge $3. Gold tax men need 4 hits and take 20%,
  rounded up, with a $4 minimum and $20 maximum. Blue top-hat bankers need
  4 hits and fire $4 invoices. Walls and furniture block projectiles.
- **Damage:** 0.9 seconds of protection after a hit prevents repeated frame
  charges. A dash has a 0.8-second cooldown. Arrival squares warn before
  new enemies appear, away from the player's current position.
- **Chests:** pay $5 once; find $2, $4, $5, $7, $10, $15, or $20. Spending your
  final $5 loses before the payout. The lid opens, pixels burst, and the net
  profit/loss is shown.
- **ATM:** one $4 service fee, then one $15 withdrawal. Net +$11. Spending the
  last $4 still bankrupts the account before the withdrawal.
- **Toll tiles:** each gold tile charges $1 when entered, including during a
  dash. Standing still does not keep charging. Exiting and re-entering charges
  again. The longer route around the gold tiles is free.
- **Shop:** speed +20% ($15), dash cost -$1 ($20), cashback +$2 per kill ($25),
  or insurance ($15). Each benefit can be bought once. Insurance absorbs the
  next hit, including tax, and expires with “CLAIM APPROVED”.
- **Loan:** optional +$25 immediately; $5 interest once per new department.
  Only one loan per run. Revisiting the same department cannot double-charge
  interest. Interest can bankrupt you. The terms are shown at the terminal.
- **Inflation:** department 9 changes shots to $2 and dashes to $4 before the
  discount. It applies once and resets on a new run. Red hazard floors cost
  $5; gold telegraphs when they are about to activate.
- **Settlement bonuses:** clearing the transfer, market halt, and audit pays
  $12, $15, and $20 respectively, once each.
- **Overtime:** the last room offers a free-entry, 15-second survival shift
  paying $25 while your account is below $50. Temporary attackers disappear
  when it ends. It cannot be farmed once the exit is funded.
- **Forward-only doors:** collect drops before leaving. The required door fees
  total $30 before the final $50 exit. All purchases, debt, tutorial state,
  enemies, timers, upgrades, and inflation reset with R.

## Presentation and audio

The existing player, ledger, combat, room, HUD, and sound systems are extended,
not replaced. Characters are small code-drawn pixel sprites with different
silhouettes. Sharp font rendering, nearest filtering, block particles, price
signs, damage flashes, and short fades form one retro visual style.

`Sound` manages 20 original synthesized effects and **The Price of Living**,
an original 16-bar, 112 BPM looping chiptune (34.29 seconds). Gameplay music
continues across rooms, becomes quieter while paused, stops for ending stingers,
and restarts without adding another music player. M controls the master bus.
The reproducible music source is `tools/make_music.py`.

Tiny5 is by the Tiny5 Project Authors and is bundled under the SIL Open Font License;
see `assets/fonts/OFL.txt`. Godot's attribution notices are included in exports.
The team's existing `ground.tscn`, tilesets, and movement work are preserved;
conflict markers and broken asset paths were repaired. The game entry point
remains `scenes/main.tscn`.

## Edit and tune

| File | Responsibility |
| --- | --- |
| `scripts/ledger.gd` | Transactions, insurance, loan interest, upgrades, prices, atomic exit |
| `scripts/player.gd` | Movement, paid shots, dash, invulnerability |
| `scripts/rooms.gd` | Twelve authored room configs, waves, rewards, timed objectives |
| `scripts/room.gd` | Furniture, walls, warning floors, toll entry detection, tutorial signs |
| `scripts/enemy.gd`, `scripts/invoice.gd` | Four enemy types, dummy targets, hostile projectiles |
| `scripts/interactable.gd` | Doors, chests, shop, ATM, loan, overtime |
| `scripts/game.gd` | Room assembly, lesson goals, waves, transitions, reset, endings |
| `scripts/pixel_art.gd`, `scripts/palette.gd`, `scripts/hud.gd` | Sprites, colors, pixel font, receipt UI |
| `scripts/sound.gd`, `assets/audio/` | Music lifecycle and retro sound feedback |

Enemy config entries are `[x, y, kind, reward]`: 0 collector, 1 tax man,
2 runner, 3 banker, 4 harmless target. Reusable scenes remain in `scenes/player`,
`scenes/enemies`, `scenes/levels`, and `scenes/ui`. Physics layers: 1 player,
2 world, 3 enemies. Both projectile types use swept rays to avoid tunnelling.

## Validation and export

From the repository, with Godot 4.7 named `godot`:

```sh
godot --headless --editor --import --quit
godot --headless res://tests/test_runner.tscn
```

The suite reports **129 checks**, covering actual physics and tutorial shots,
movement, walls, damage limits, friendly/hostile projectiles, wave warnings,
timed goals, one-use transactions, every room transition, inflation, interest,
insurance, toll crossings, overtime, exact-$50 victory, bankruptcy, music state,
and restart during a fade. The full-route test advances encounter timers and
clears enemies to check progression; it is not a human difficulty or duration test.

Visual QA captures all departments and overlays using `tests/capture.tscn`
with a graphics display. The exported Web build was exercised in Chromium
with real keyboard/mouse input through the tutorial, pause, and restart,
with an active audio context and no browser errors. Windows is exported with
matching official templates; it has not been run on Windows in this environment.
Controller/touch controls and save files are outside this jam build's scope.

Install the **4.7 stable export templates**, create the output folders, then:

```sh
godot --headless --export-release "Windows Desktop" build/windows/PayThePrice.exe
godot --headless --export-release Web build/web/index.html
godot --headless --export-release Linux build/linux/PayThePrice.x86_64
```

Build output and `.godot/` are ignored by Git. Tests and tools are excluded
from exports. Keep `GODOT-LICENSE.txt`, `GODOT-COPYRIGHT.txt`, and the font
license alongside distributed builds.

## Setup

1. Install **Godot 4.x** and **GitHub Desktop**.
2. Clone this repository in GitHub Desktop.
3. In Godot, choose **Import** and select `project.godot`.
4. Before starting work, **Pull** the latest changes.
5. When finished with a small piece of work, **Commit** it with a clear message and **Push**.

## Team workflow

For a two-person game jam, keep the workflow simple:

**Pull → Work → Save → Commit → Push**

Try not to edit the same `.tscn` scene at the same time. Tell the other person which scene you are working on before making large scene changes.

Prefer small reusable scenes such as:

- `scenes/player/player.tscn`
- `scenes/enemies/`
- `scenes/levels/`
- `scenes/ui/`
- `scripts/`
- `assets/`

This reduces merge conflicts and lets both people work in parallel.

## Commit examples

- `Add player movement`
- `Add enemy chase behaviour`
- `Create level 1 layout`
- `Add title screen UI`
- `Fix player collision`

## Important

The `.godot/` folder is generated locally by Godot and should **not** be committed.

If someone is currently editing a major scene, coordinate before editing that same scene yourself.
