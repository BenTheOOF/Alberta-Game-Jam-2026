# PAY THE PRICE

**Alberta Game Jam 2026 — Everything Has a Price.**

Money is your health, ammunition, and stamina. Start with $100, survive a
procedural corporate gauntlet, defeat the CEO, and keep the difficulty's exit reserve to buy your freedom ($50 / $90 / $140 / $200).
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
| Left click / hold | Shoot current weapon | $1–$4 per trigger pull |
| Space | Dash with brief hit protection | $3 |
| E | Approve highlighted interaction | Disclosed before purchase |
| Escape | Pause / resume; close shop; return after a run | Free |
| R | Restart the entire account | Free |
| M | Mute / unmute music and effects | Free |

## Run structure

There are **15 areas: three tutorial rooms, ten standard departments, the CEO,
and the final exit**. The tutorial teaches movement, paid shooting, money as
health, dashing, and a $2 door. A clean tutorial leaves $88 before optional
equipment purchases. The third tutorial has an equipment desk before combat.

Standard departments combine eight authored layouts with seeded encounters.
Geometry is never assembled from arbitrary walls. Open office, cubicles, records
hall, central office, split accounts, risk grid, toll route, and executive floor
have authored cover, hazards, and spawn sockets. Names, compositions, elites,
and chest presence vary. Recent layouts and enemy types receive less weight.

| Standard department | Guaranteed feature |
| --- | --- |
| 1–2 | Gentle collector/runner introduction; second room has an ATM and a chest |
| 3 | Toll route, free detour, optional $15 encounter skip, optional loan |
| 4 | Full shop and optional overtime |
| 5 | Ranged encounter, $12 settlement |
| 6 | Inflation and warning floors, $15 settlement |
| 7 | Refund, loan access, advanced enemy combinations |
| 8 | Second shop and optional overtime |
| 9 | Final audit encounter, $20 settlement |
| 10 | Executive clearance, $18 settlement, optional overtime |
| CEO | Dedicated three-phase boss; victory unlocks the exit area |
| Exit | Difficulty-based fee; one last optional overtime terminal |

Each combat budget is `max(4, round((4 + standard_room * 2) * budget_scale))`.
The generator spends that budget using unlocked enemy definitions. Extra claims
wait in a queue instead of exceeding the simultaneous enemy cap. After a wave
dies, the next wave starts its visible arrival warnings within 0.15 seconds.
The first wave starts warnings after 0.4 seconds. Buying the shortcut skips
the room-clear score.

Normal rooms unlock on the next update once living enemies, pending arrivals,
and required waves are all gone. **ACCOUNT SETTLED / EXIT OPEN** and a sound
confirm the clear. The playtest delay was reproduced as legacy 70/80/90-second
minimum durations also controlling wave scheduling; those gates are removed.
`Game._objective_complete()` owns progression. Overtime alone in the current
route requires a visible survival clock; the CEO requires its defeat state.

Spawn warnings last at least 1.3 seconds. Sockets avoid walls, furniture,
hazards, paid props, the exit, and a 250-pixel radius around the player. Safety
is checked again when the enemy actually arrives; approaching a warning moves
it to another safe socket and warns again. Arrivals reserve cap slots and have
another 0.6 seconds of activation grace before moving or attacking.

Human run duration and weapon balance still need playtesting after these pacing
changes; automated progression checks do not establish a win rate.

## Equipment and shop

Press **E** at an equipment desk for a paused storefront with **Weapons**,
**Upgrades**, and **Utility** columns. Click a card or use **Tab + Enter**;
**Escape** returns to play. Cards show purchase price, current firing price,
fire rate, effect, and ownership. Purchases equip immediately. Owned weapons
can be re-equipped free at any desk; ownership resets on restart.

| Weapon | Buy | Fire per pull | Damage | Rate | Tradeoff |
| --- | ---: | ---: | --- | ---: | --- |
| Standard Issue | Included | $1 | 1 | 4.3/sec | Accurate, efficient, long range; one target |
| Spreadsheet | $18 | $3 | 5 pellets × 1 | 1.5/sec | Forgiving cone; short range, expensive misses |
| Microtransaction | $15 | $1 | 1 | 8.3/sec | Rapid corrections; loose aim, shorter range, fast spending |
| Capital Investment | $24 | $4 | 5, through up to 2 enemies | 1/sec | Wide projectile and strong knockback; slow, costly misses |

The table shows base prices. Inflation and an active audit each add $1 **once
per trigger pull**, including the spread weapon. The HUD and shop use the same
current price. Spending the final dollar still bankrupts the account.

## Difficulty

Difficulty changes reactions, prediction, coordination, combat stats, rewards,
exit fees, and scoring. Ordinary service prices remain consistent. Easy retains
the previous basic enemy stats and mostly direct pursuit.

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
| CEO HP / cash reward | 60 / $30 | 75 / $45 | 95 / $70 | 120 / $100 |
| Exit fee | $50 | $90 | $140 | $200 |
| Settlement bonus scale | 1.0× | 1.2× | 1.4× | 1.6× |
| CEO summon cap | 2 | 3 | 4 | 5 |
| Reaction interval | 0.65s | 0.40s | 0.25s | 0.14s |
| Movement prediction | 0.10 | 0.35 | 0.65 | 0.90 |
| Overtime cash / base bonus | $30 / 650 | $50 / 1000 | $75 / 1500 | $110 / 2200 |

HP and damage round up. Elite rolls require spare budget, add two budget points,
and are disabled before standard department 5; their chance ramps toward the
listed value by department 8. A gold crown marks elites: 1.5× HP, 1.15× speed,
increased cash, and double enemy points.

## Enemies and management

| Enemy | First standard room | Cost | Base HP | Behavior |
| --- | ---: | ---: | ---: | --- |
| Collector | 1 | 1 | 3 | Pursues or flanks; $5 contact fee |
| Runner | 1 | 1 | 2 | Predicted, warned short burst; $3 contact fee |
| Banker | 3 | 2 | 4 | Approaches, retreats, strafes; warned $4 invoices |
| Tax Man | 5 | 3 | 4 | 20% balance hit, fixed $4–$20 clamp |
| Debt Drone | 5 | 2 | 2 | Orbits and fires weak $2 invoices |
| Auditor | 7 | 3 | 5 | Shelters behind allies; warned five-second +$1 mark |
| Enforcer | 7 | 4 | 8 | Warned charge, $12 contact fee, vulnerable recovery |
| Collection Clerk | 7 | 3 | 4 | Nearby enemies move 20% faster while supported |

Before an unseen type can act, a player-dismissed briefing shows its sprite,
ability, and counterplay. New types in the same roster share one screen. The
whole world, hazards, projectiles, and clocks pause until **E** or a click after
a short input debounce. Dismissal gives 0.75 seconds of protection and cannot
fire a paid shot. Briefings appear once per type per run and reset on restart.
Unseen overtime types are introduced before its 30-second clock starts.

Audit marks refresh without stacking. Clerk buffs are recomputed from living
clerk proximity, so killing the clerk removes the effect. Enemies navigate around
cover; swept projectiles stop at furniture and walls. Damage grants 0.9 seconds
of protection, and dashes have a 0.8-second cooldown.

`EnemySteering` samples visible movement after a mode-specific reaction delay.
Prediction is partial and capped at 215 pixels; burst and projectile directions
freeze at warning start. Actors accelerate into temporary direct, intercept,
left-flank, or right-flank roles and separate from nearby allies. Bankers alternate
direct/leading shots, with occasional warned spread on Hard/Brutal. Auditors can
be denied by leaving range or breaking sight. Persistent curved movement favors
interception and area control; it never directly damages or taxes the player.

The **CEO** uses one weighted scheduler, with no consecutive repeated major attack:

- **Performance Review**: fans, predicted invoice bursts, capped collectors.
- **Hostile Takeover**, at 65% HP: locked charge, marked fee zones, multiangle crossfire.
- **Liquidation**, at 30% HP: fixed sweeping arcs, rings with a marked escape gap,
  targeted hazards, and mixed summons including enforcers.

Phase changes cancel old hazards and provide 1.7 seconds of recovery plus a
sound, announcement, color change, and named HUD phase. Every attack has a warning
and a recovery window. Easy uses single attacks; other modes can pair charge/fan
or zones/invoice at disclosed 18% / 38% / 65% scheduler chances. Summons count both
living actors and reservations toward their separate difficulty cap. Defeat clears
all attackers, invoices, zones, and reservations, pays severance, awards 1,000 base
points, and opens the route to the final invoice.

## Overtime

Cleared shop, pre-boss, and exit rooms offer a free-entry **30-second survival
shift at any balance**. Each terminal permits one attempt per run. Leaving is
locked during the shift; killing every attacker is unnecessary.

- 0–8 seconds: collectors and runners.
- 8–16 seconds: bankers, drones, and runners.
- 16–24 seconds: enforcers and interceptors.
- 24–30 seconds: a dense mixed roster.

| Overtime modifier | Easy | Normal | Hard | Brutal |
| --- | ---: | ---: | ---: | ---: |
| Wave interval | 3.0s | 2.5s | 2.0s | 1.55s |
| HP multiplier | 2.0× | 2.15× | 2.30× | 2.50× |
| Speed multiplier | 1.65× | 1.90× | 2.15× | 2.40× |
| Damage multiplier | 1.10× | 1.15× | 1.20× | 1.25× |
| Attack-rate multiplier | 1.55× | 1.70× | 1.90× | 2.10× |
| Floor warning | 1.25s | 1.15s | 1.0s | 0.90s |

These modifiers only affect overtime actors, on top of difficulty/elite stats.
The cap is two higher than normal. Spawn selection favors safe sockets near the
observed route ahead while retaining the 250-pixel separation, 1.3-second arrival
warning, and 0.6-second activation grace. Small temporary zones start after eight
seconds; their count and area leave routes open. The sprint purchase keeps its
full 20% player bonus; shift enemies receive only a further 6% response to it.

The HUD says **JUST SURVIVE**, with a large final-five-second countdown and sound.
Kills award points but **no individual cash or cashback**. Survival earns the
listed cash/base bonus plus five points per second. At zero, cleanup disables
enemy/projectile/zone physics immediately, removes pending arrivals, and unlocks
the exit in the same update. No cleanup kills are required and no expired hazard
can charge a late fee. Bankruptcy gives no completion payout.

## Economy and score

Ordinary payments that reach $0 bankrupt the account. The final exit is atomic:
paying exactly the selected difficulty's fee still wins, with $0 remaining cash and the run's earned score intact.

- **Chests:** $5 once; find $2, $4, $5, $7, $10, $15, or $20. Spending the final
  $5 loses before the payout. Net profit/loss is displayed.
- **ATM:** pay $4, withdraw $15 once, net +$11. The fee can bankrupt you.
- **Tolls:** each gold tile costs $1 on entry, including while dashing. Standing
  still costs nothing; leaving and re-entering charges again. Detours are free.
- **Shop:** +20% movement ($15), dash discount -$1 ($20), cashback +$2 per normal
  kill ($25), or one-hit insurance ($15). Each benefit is bought once per run.
- **Loan:** +$25 now, then $5 interest once per new area. One contract per run.
  Revisits cannot double-charge, but interest can bankrupt you.
- **Inflation:** standard room 6 permanently adds $1 to each weapon's trigger
  price and changes dashes to $4 before discounts. Red floor hazards cost $5;
  gold is the warning.
- **Relief:** later low-balance rooms can include one visible $10 refund. This
  does not reduce hidden enemy stats or the encounter budget.
- **Rewards:** normal drops use the larger of scaled base cash or the cost of
  accurate shooting plus a small margin, scaled by mode. Misses, damage, service
  fees, optional upgrades, and the boss still consume money.
- **Doors:** required fees total $30 before the difficulty-based exit. Collect drops before
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

Code-drawn pixel sprites, Tiny5 throughout every UI surface, nearest filtering,
block particles, price signs, and short fades preserve the retro corporate style.
Uppercase copy, larger body sizes, spacing, and concise lines keep the pixel text
readable at both 1280×720 and 960×540. The sidebar shows the
current weapon and price, a short objective, and a contextual tip. Difficulty
stays visible during the CEO health bar and large overtime timer.

Each connected sprite part shares one snapped animation anchor. Hats, eyes,
accessories, and elite crowns move with the body; health bars sit above them.
Drones and training targets use distinct silhouettes without a human underneath.

`Sound` preserves the team's generated title music and **The Price of Living**,
an original 16-bar, 112 BPM gameplay loop (34.29 seconds). One music player
handles menu/game transitions, quieter pause, ending stingers, and restart.
There are 26 synthesized effects including boss, elite, and overtime cues.
M controls the master bus. `tools/make_music.py` reproduces the gameplay track.

Tiny5 is by the Tiny5 Project Authors under the SIL Open Font License; see
`assets/fonts/OFL.txt`. This font license and Godot notices accompany exports. Existing `ground.tscn`,
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
| `scripts/enemies/steering.gd` | Delayed observations, bounded prediction, circle recognition |
| `scripts/enemies/boss.gd`, `fee_zone.gd` | CEO state machine and short-lived fee warnings |
| `scripts/systems/overtime.gd` | Survival clock, staged pressure, completion request |
| `scripts/ledger.gd` | Money, debt, upgrades, weapon ownership, current prices, centralized score |
| `scripts/weapons/weapon_data.gd` | Four weapon definitions, tuning, and shop descriptions |
| `scripts/ui/shop.gd` | Organized cards, purchase feedback, keyboard/pointer navigation |
| `scripts/ui/threat_intro.gd` | Grouped briefings and ready input; Game owns world pause |
| `scripts/game.gd` | Scene assembly, capped spawn queue, progression and cleanup |
| `scripts/room.gd` | Solids, navigation, hazards, toll entry detection and tutorial signs |
| `scripts/player.gd`, `bullet.gd`, `invoice.gd` | Movement, paid actions, damage protection and swept projectiles |
| `scripts/interactable.gd` | Price prompts and single-use transaction requests |
| `scripts/pixel_art.gd`, `palette.gd`, `hud.gd` | Sprites, palette, font hierarchy, account UI |
| `scripts/sound.gd`, `assets/audio/` | Music lifecycle and sound feedback |

Add an enemy definition and reuse a behavior or register one handler in
`enemy.gd`; the generator automatically considers its unlock and cost. Training
target ID 4 stays excluded. Add geometry to `RoomTemplates.DATA`, then check
spawn sockets and reachable paths. Tune modes in `DifficultySettings.MODES`;
spawning, rewards, HUD, and score consume the same profile. Add room features as
config flags with one owner for their lifecycle rather than duplicating costs.
Add weapons in `WeaponData.DEFINITIONS`; the shop, HUD, player cooldown, and
projectile factory consume that definition. Ledger charges once per trigger.

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
godot --headless res://tests/polish_runner.tscn
godot --headless res://tests/combat_runner.tscn
```

The suites report **172 core + 56 polish + 161 combat checks (389 total)**. Generator coverage samples **100 seeds per
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

The polish suite separately exercises **400 live generated encounters: 100 each
on Easy, Normal, Hard, and Brutal**. It defeats actual actors, drains real spawn
queues, and verifies the exit within one update of the last required death,
including stale duration data. It also covers protected/once-per-run briefings,
CEO/overtime clock separation, early shop access, purchase and firing charges,
free re-equipping, restart, heavy-round width/piercing/walls, and sidebar fit.

The combat suite verifies all four atomic exit fees, disclosed reserve text,
reaction delay, bounded prediction, flanking, separation, locked shots/bursts,
audit counterplay, all boss phases/attack choices/gaps/caps/cleanup, overtime
stages/rewards/expiry, and preservation of normal stats and the sprint bonus.

A further 400 economy samples assume 80% accuracy, sprint plus heavy purchases
($39), $30 of dashes, $40 of damage, and sensible selection between owned standard
and heavy weapons. They require no chests, loan, ATM, or overtime. Minimum cash
remaining after reserving the exit is $78 / $196 / $344 / $726. This is a model
of disclosed costs and rewards, not a claim about human aim or survival.

Live 30-second physics trials drive a bot at the full upgraded 342 px/s without
shooting or dashing. A high balance keeps measurement trials alive:

| Route damage | Easy | Normal | Hard | Brutal |
| --- | ---: | ---: | ---: | ---: |
| Continuous circle | $46 | $70 | $73 | $198 |
| Perimeter loop | $16 | $25 | $72 | $164 |

A separate Brutal circle trial with the real $85 post-sprint balance goes bankrupt
before payout. These fixed-seed trials establish that rote movement is intercepted;
they do not replace human playtesting.

`tests/capture.tscn` captures the changed UI surfaces at both actual window sizes.
Set `PAY_THE_PRICE_CAPTURES` to an output directory, or use the default under the
OS cache directory. `tests/enemy_gallery.tscn` renders every normal and elite
enemy through animation and hit flash. Visual review covers those variants,
all areas, and overlays at 1280×720, plus the shop, briefings, weapon/objective
sidebar, CEO HUD, and overtime timer at actual 960×540.
The exported Web build is smoke-tested at both sizes with keyboard/mouse input
through the tutorial, equipment purchase, briefing, pause, and restart, including
difficulty and active audio. Windows is exported with official matching templates and has not been
executed on Windows in this environment. Human difficulty/pacing playtests remain
necessary. Controller/touch controls and save files are outside this jam build.

Install **4.7 stable export templates**, create output directories, then:

```sh
godot --headless --export-release "Windows Desktop" build/windows/PayThePrice.exe
godot --headless --export-release Web build/web/index.html
godot --headless --export-release Linux build/linux/PayThePrice.x86_64
```

Build output and `.godot/` are ignored. Tests/tools are excluded from exports.
Distribute `GODOT-LICENSE.txt`, `GODOT-COPYRIGHT.txt`, and the Tiny5 font license with
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
