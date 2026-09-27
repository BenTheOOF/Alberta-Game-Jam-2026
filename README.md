# PAY THE PRICE

**Alberta Game Jam 2026 — Everything Has a Price.**

Money is your health, ammunition, and stamina. Start with $100, survive a
procedural corporate gauntlet, defeat the CEO, and keep $50 to buy your freedom.
Score tracks your performance separately. Optional overtime offers extra cash
and points at the cost of thirty dangerous seconds.

## Play

Import `project.godot` in **Godot 4.7 stable** and press **F5**. The entry scene
is `scenes/main.tscn`. GDScript and the Compatibility renderer need no plugins,
C#, or manual scene setup.

- **Windows:** extract the ZIP and run `PayThePrice.exe`.
- **Linux:** extract the ZIP, make `PayThePrice.x86_64` executable if needed,
  and run it.
- **Web / itch.io:** upload the Web ZIP as an HTML5 game; `index.html` is at
  the root. Locally, serve the extracted folder with `python -m http.server 8000`
  and open `http://localhost:8000`. Keyboard and mouse are required.

Choose Easy, Normal, Hard, or Brutal with the mouse or left/right arrows before
opening the account. Easy is the default. Restart retains your selected mode.

| Control | Action | Starting price |
| --- | --- | --- |
| WASD / arrows | Move | Free |
| Mouse | Aim | Free |
| Left click / hold | Shoot | $1 |
| Space | Dash with brief hit protection | $3 |
| E | Approve highlighted interaction | Disclosed before purchase |
| Escape | Pause / resume; return after a run | Free |
| R | Restart the entire account | Free |
| M | Mute / unmute music and effects | Free |

## Run structure

There are **15 areas: three tutorial rooms, ten standard departments, the CEO,
and the final exit**. The tutorial teaches movement, paid shooting, money as
health, dashing, and a $2 door. A clean tutorial leaves $88.

Standard departments combine eight authored layouts with seeded encounters.
Geometry is never assembled from arbitrary walls. Open office, cubicles, records
hall, central office, split accounts, risk grid, toll route, and executive floor
have authored cover, hazards, and spawn sockets. Names, compositions, elites,
and chest presence vary. Recent layouts and enemy types receive less weight.

| Standard department | Guaranteed feature |
| --- | --- |
| 1–2 | Gentle collector/runner introduction; second room has an ATM and a chest |
| 3 | Toll route, free detour, optional $15 encounter skip, optional loan |
| 4 | First shop and optional overtime |
| 5 | 80-second transfer, ranged enemies, $12 settlement |
| 6 | Inflation and warning floors; 70-second halt, $15 settlement |
| 7 | Refund, loan access, advanced enemy combinations |
| 8 | Second shop and optional overtime |
| 9 | 90-second audit, $20 settlement |
| 10 | Executive clearance, $18 settlement, optional overtime |
| CEO | Dedicated three-phase boss; victory unlocks the exit area |
| Exit | $50 to leave; one last optional overtime terminal |

Each combat budget is `max(4, round((4 + standard_room * 2) * budget_scale))`.
The generator spends that budget using unlocked enemy definitions. Extra claims
wait in a queue instead of exceeding the simultaneous enemy cap. Timed rooms
release the queue throughout the objective. Clear all claims and any timer to
leave. Buying the shortcut skips the room-clear score.

Spawn warnings last at least 1.3 seconds. Sockets avoid walls, furniture,
hazards, paid props, the exit, and a 250-pixel radius around the player. Safety
is checked again when the enemy actually arrives; approaching a warning moves
it to another safe socket and warns again. Arrivals reserve cap slots.

The human pacing target is **10–20 minutes**, depending on mode and choices.
This is a tuning target, not a measured human playtest result or a win-rate claim.

## Difficulty

Difficulty changes combat, rewards, and scoring; ordinary service prices remain
consistent. Easy retains the previous basic enemy stats.

| Setting | Easy | Normal | Hard | Brutal |
| --- | ---: | ---: | ---: | ---: |
| Enemy HP | 1.00× | 1.20× | 1.50× | 2.00× |
| Enemy speed | 1.00× | 1.10× | 1.20× | 1.35× |
| Financial damage | 1.00× | 1.00× | 1.25× | 1.50× |
| Attack rate | 1.00× | 1.10× | 1.20× | 1.35× |
| Projectile speed | 1.00× | 1.10× | 1.20× | 1.30× |
| Budget scale | 0.80× | 1.00× | 1.30× | 1.70× |
| Maximum concurrent enemies | 6 | 8 | 10 | 12 |
| Late-run elite chance | 4% | 10% | 19% | 30% |
| Reward scale | 1.00× | 1.15× | 1.30× | 1.50× |
| Final score multiplier | 1.00× | 1.50× | 2.00× | 3.00× |
| CEO HP / cash reward | 60 / $30 | 75 / $35 | 95 / $40 | 120 / $45 |
| Overtime cash / base bonus | $25 / 500 | $30 / 750 | $40 / 1100 | $50 / 1600 |

HP and damage round up. Elite rolls require spare budget, add two budget points,
and are disabled before standard department 5; their chance ramps toward the
listed value by department 8. A gold crown marks elites: 1.5× HP, 1.15× speed,
increased cash, and double enemy points.

## Enemies and management

| Enemy | First standard room | Cost | Base HP | Behavior |
| --- | ---: | ---: | ---: | --- |
| Collector | 1 | 1 | 3 | Chases; $5 contact fee |
| Runner | 1 | 1 | 2 | Fast chase; $3 contact fee |
| Banker | 3 | 2 | 4 | Keeps medium range; fires $4 invoices |
| Tax Man | 5 | 3 | 4 | 20% balance hit, $4–$20 before difficulty scaling |
| Debt Drone | 5 | 2 | 2 | Orbits and fires weak $2 invoices |
| Auditor | 7 | 3 | 5 | Marks for five seconds: shots and dashes +$1 |
| Enforcer | 7 | 4 | 8 | Warned charge, $12 contact fee, vulnerable recovery |
| Collection Clerk | 7 | 3 | 4 | Nearby enemies move 20% faster while supported |

Audit marks refresh without stacking. Clerk buffs are recomputed from living
clerk proximity, so killing the clerk removes the effect. Enemies navigate around
cover; swept projectiles stop at furniture and walls. Damage grants 0.9 seconds
of protection, and dashes have a 0.8-second cooldown.

The **CEO** fires readable invoice fans and summons capped collectors. At 65% HP,
management adds runners/bankers, a warned charge, and temporary service surcharges.
At 30%, denser fans and warned floor fee zones raise the pressure. Defeat removes
remaining boss attackers/projectiles/zones, pays severance, awards 1,000 base
points, and unlocks the exit. The final $50 invoice still applies.

## Overtime

Cleared shop, pre-boss, and exit rooms offer a free-entry **30-second survival
shift at any balance**. Each terminal permits one attempt per run. Leaving is
locked during the shift; killing every attacker is unnecessary.

- 0–10 seconds: collectors and runners.
- 10–20 seconds: bankers, tax men, and runners.
- 20–30 seconds: heavy mixed pressure and elites.

Waves arrive every 3.6 / 3.0 / 2.5 / 2.0 seconds by mode, with a cap two higher
than normal. Overtime enemies receive another 1.75× HP, 1.35× speed, 1.25× damage,
and 1.30× attack rate on top of difficulty and any elite modifiers. They award
kill points but **no individual cash or cashback**. Surviving earns the table's
cash and base-point bonus plus five points per second survived. At expiry all
overtime actors, invoices, and pending arrivals disappear. Bankruptcy ends the
run without a completion payout.

## Economy and score

Ordinary payments that reach $0 bankrupt the account. The final exit is atomic:
exactly $50 still wins, with $0 remaining cash and the run's earned score intact.

- **Chests:** $5 once; find $2, $4, $5, $7, $10, $15, or $20. Spending the final
  $5 loses before the payout. Net profit/loss is displayed.
- **ATM:** pay $4, withdraw $15 once, net +$11. The fee can bankrupt you.
- **Tolls:** each gold tile costs $1 on entry, including while dashing. Standing
  still costs nothing; leaving and re-entering charges again. Detours are free.
- **Shop:** +20% movement ($15), dash discount -$1 ($20), cashback +$2 per normal
  kill ($25), or one-hit insurance ($15). Each benefit is bought once per run.
- **Loan:** +$25 now, then $5 interest once per new area. One contract per run.
  Revisits cannot double-charge, but interest can bankrupt you.
- **Inflation:** standard room 6 permanently changes shots to $2 and dashes to
  $4 before discounts. Red floor hazards cost $5; gold is the warning.
- **Relief:** later low-balance rooms can include one visible $10 refund. This
  does not reduce hidden enemy stats or the encounter budget.
- **Rewards:** normal drops use the larger of scaled base cash or the cost of
  accurate shooting plus a small margin, scaled by mode. Misses, damage, service
  fees, optional upgrades, and the boss still consume money.
- **Doors:** required fees total $30 before the $50 exit. Collect drops before
  leaving. Restart clears debt, upgrades, inflation, timers, actors, and score.

`Ledger` owns the score formula:

```text
base = remaining cash + enemy points + cleared areas * 100
       + (CEO defeated ? 1000 : 0) + overtime completion bonuses
       + floor(total overtime seconds) * 5
final = round(base * difficulty score multiplier)
```

Enemy points are 10–50 by type, doubled for elites. Tutorials and the final exit
count as cleared areas. Overtime kills already contribute enemy points and are
not counted twice. Results show difficulty, remaining cash, base/final score,
clears, kills, CEO status, overtime shifts/kills, account totals, seed, and time.

## Presentation and audio

Code-drawn pixel sprites, Tiny5 type, nearest filtering, block particles, price
signs, and short fades preserve the existing retro corporate style. Fixed HUD
labels sit outside the playable arena. The difficulty stays visible during the
CEO health bar and large overtime timer.

`Sound` preserves the team's generated title music and **The Price of Living**,
an original 16-bar, 112 BPM gameplay loop (34.29 seconds). One music player
handles menu/game transitions, quieter pause, ending stingers, and restart.
There are 26 synthesized effects including boss, elite, and overtime cues.
M controls the master bus. `tools/make_music.py` reproduces the gameplay track.

Tiny5 is by the Tiny5 Project Authors under the SIL Open Font License; see
`assets/fonts/OFL.txt`. Godot notices accompany exports. Existing `ground.tscn`,
tilesets, teammate movement work, and useful comments are preserved. Startup
conflict markers and invalid asset paths were repaired.

## Extend and tune

| File | Owns |
| --- | --- |
| `scripts/generation/difficulty.gd` | Central combat, reward, boss, overtime, and score tuning |
| `scripts/enemies/enemy_data.gd` | Stable type IDs, stats, unlocks, budget costs, sustainable rewards |
| `scripts/generation/room_templates.gd` | Authored geometry, sockets, placement safety |
| `scripts/generation/encounter_generator.gd` | One run RNG, cached layouts/compositions, budget allocation |
| `scripts/rooms.gd` | Tutorial and fixed story/shop/boss/exit milestones |
| `scripts/enemy.gd` | Data-driven ordinary actors and behavior dispatch |
| `scripts/enemies/boss.gd`, `fee_zone.gd` | CEO state machine and short-lived fee warnings |
| `scripts/systems/overtime.gd` | Survival clock, staged pressure, completion request |
| `scripts/ledger.gd` | Money, debt, upgrades, temporary audit prices, centralized score |
| `scripts/game.gd` | Scene assembly, capped spawn queue, progression and cleanup |
| `scripts/room.gd` | Solids, navigation, hazards, toll entry detection and tutorial signs |
| `scripts/player.gd`, `bullet.gd`, `invoice.gd` | Movement, paid actions, damage protection and swept projectiles |
| `scripts/interactable.gd` | Price prompts and single-use transaction requests |
| `scripts/pixel_art.gd`, `palette.gd`, `hud.gd` | Sprites, palette, pixel font, account UI |
| `scripts/sound.gd`, `assets/audio/` | Music lifecycle and sound feedback |

Add an enemy definition and reuse a behavior or register one handler in
`enemy.gd`; the generator automatically considers its unlock and cost. Training
target ID 4 stays excluded. Add geometry to `RoomTemplates.DATA`, then check
spawn sockets and reachable paths. Tune modes in `DifficultySettings.MODES`;
spawning, rewards, HUD, and score consume the same profile. Add room features as
config flags with one owner for their lifecycle rather than duplicating costs.

The generator seeds once per run and caches each room. For reproducible debug
runs call `game.start_run(1729)` after choosing a difficulty. Generate rooms in
route order. The same seed/mode gives the same geometry and composition; low-cash
refunds depend on account state, and individual chest payouts are separate rolls.
The score screen exposes the seed, and generated room configs expose the budget.

Reusable scenes remain under `scenes/player`, `scenes/enemies`, `scenes/levels`,
and `scenes/ui`. Physics layers are 1 player, 2 world, and 3 enemies.

## Validation and export

From the repository, with Godot 4.7 named `godot`:

```sh
godot --headless --editor --import --quit
godot --headless res://tests/test_runner.tscn
```

The suite reports **172 checks**. Generator coverage samples **100 seeds per
mode: 400 runs and 3,200 procedural combat rooms**, checking exact budgets,
safe sockets, unlocks, determinism, varied layouts/compositions, and a viable
accurate-shooting economy through the CEO and final exit. Sample mean combat
budgets are 11.75 / 14.75 / 19.12 / 25.12 for Easy / Normal / Hard / Brutal.

Integration checks cover real physics, paid tutorial shots, walls, tolls,
projectiles, waves, timed objectives, all transitions, one-use economy rules,
difficulty retention, scoring once, boss phases/cleanup, overtime start/expiry/
cleanup/payout, bankruptcy, audit expiry, clerk buffs, and restart during fades.
Full-route tests advance timers and defeat actors to validate progression;
they do not measure human survival rates or run length.

`tests/capture.tscn` captures all areas and overlays with a graphics display.
Set `PAY_THE_PRICE_CAPTURES` to an output directory, or use the default under the
OS cache directory. The exported Web build is smoke-tested with keyboard/mouse
input through the tutorial, pause, and restart, including difficulty and active
audio. Windows is exported with official matching templates and has not been
executed on Windows in this environment. Human difficulty/pacing playtests remain
necessary. Controller/touch controls and save files are outside this jam build.

Install **4.7 stable export templates**, create output directories, then:

```sh
godot --headless --export-release "Windows Desktop" build/windows/PayThePrice.exe
godot --headless --export-release Web build/web/index.html
godot --headless --export-release Linux build/linux/PayThePrice.x86_64
```

Build output and `.godot/` are ignored. Tests/tools are excluded from exports.
Distribute `GODOT-LICENSE.txt`, `GODOT-COPYRIGHT.txt`, and the font license with
the builds. This development pass is on **codex/pay-the-price** only.

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
