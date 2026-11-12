# Level-by-Level QA (final pass, 2026-11-12)

Every one of the 24 levels: what the final pass added, what makes the level its own, and what
was tested, with the result of each automated check for that level. No level was skipped.

**Read this first.** Two kinds of evidence exist and they are kept apart:

- **Automated**: run by tests in the real game code with real input and physics, headless,
  plus real-window renders and screenshots of changed places. This proves that each level
  loads, can be completed with base stats, that its mechanisms, pickups and saves work, and
  that the co-op edge cases behave. It does **not** prove that a level is fun, clear or fair
  to people.
- **Manual**: two people playing. **No level has been played by people since the overhaul or
  this pass.** The "Manual" column says so for every level.

## How each level was tested

| Check | Test | What it does in every level |
|---|---|---|
| Probe (20 checks) | `test_level_validation` (`LevelProbe`) | Load; both spawns; both knights move and jump; ladders; one-way drops; knight collision; camera bounds, split and merge; every enemy moves and none falls out; a real attack lands; every spike and hot strip costs exactly 1 health; every stash, fruit and jar is collected and does what its type says; every tile gives a timed effect; every gate and platform controller is solved the way knights would and opens; arenas are fought and open; exit loads the next level; progression saved; save mid-level and resume |
| Route | `test_campaign_routes` (`RouteValidator`) | The real knight makes every jump of the cheapest spawn→exit route with real input, base stats, no upgrades and no boss |
| Optional routes | `test_optional_routes` | The real knight makes every jump, spring, wind and crumbling stone to each new optional reward (19 routes in 17 levels) |
| Timing | `test_platform_timing` | Every blinking chain is recorded for 30 s and can be crossed with 0.55 s hops and at least 0.25 s on each stone |
| Static | `test_campaign_levels` | Analyzer: exit, every collectible, plate and switch reachable; no lock needs three knights; no boss needed for the exit; **no reachable place is a trap** |
| Spawns | `test_campaign_flow` | Both knights stand unhurt at the spawn for 45 frames; no enemy within 48 px |
| Solo exit | `test_final_coop` | One knight alone at the exit (Player One on odd levels, Player Two on even) completes the level while the partner is more than 400 px away; both arrive at the next spawn with their health unchanged |
| Death | `test_final_coop` | A knight dies in the level (alternating): exactly one team wipe, a new run at level 1, nothing kept, only the fresh run on disk |
| Quit and reopen | `test_final_coop` | With venom, haste and a recharging ward running: the window's close request saves and quits; loading resumes in the same level with the same timers, ward, coins and positions; nobody died |

Cross-level checks that do not need every level (both knights on one jar in one frame, a
pickup far from the partner, death under effects, both dying in one frame, a death during a
transition, four slots) are in `docs/FINAL_TEST_REPORT.md`.

## Results per level

| Level | Probe | Route | Optional | Timing | Solo exit | Death | Quit and reopen | Manual |
|---|---|---|---|---|---|---|---|---|
| l01 The Mossy Path | 18/18 PASS | PASS (7/7 jumps) | PASS (1) | N/A (no chain) | PASS (P1) | PASS (P1 dies) | PASS | NOT TESTED |
| l02 Rootway Hollows | 18/18 PASS | PASS (2/2 jumps) | PASS (1) | N/A (no chain) | PASS (P2) | PASS (P2 dies) | PASS | NOT TESTED |
| l03 Old Watchtrees | 18/18 PASS | PASS (9/9 jumps) | PASS (1) | N/A (no chain) | PASS (P1) | PASS (P1 dies) | PASS | NOT TESTED |
| l04 Heart of the Grove | 18/18 PASS | PASS (2/2 jumps) | see notes | N/A (no chain) | PASS (P2) | PASS (P2 dies) | PASS | NOT TESTED |
| l05 Crystal Descent | 17/17 PASS | PASS (9/9 jumps) | PASS (2) | N/A (no chain) | PASS (P1) | PASS (P1 dies) | PASS | NOT TESTED |
| l06 Echoing Shafts | 16/16 PASS | PASS (8/8 jumps) | PASS (2) | PASS (slack 3.20 s) | PASS (P2) | PASS (P2 dies) | PASS | NOT TESTED |
| l07 Brood Caverns | 19/19 PASS | PASS (3/3 jumps) | PASS (2) | N/A (no chain) | PASS (P1) | PASS (P1 dies) | PASS | NOT TESTED |
| l08 The Sunless Lift | 19/19 PASS | PASS (1/1 jumps) | PASS (1) | N/A (no chain) | PASS (P2) | PASS (P2 dies) | PASS | NOT TESTED |
| l09 Sunken Gatehouse | 17/17 PASS | PASS (2/2 jumps) | PASS (1) | N/A (no chain) | PASS (P1) | PASS (P1 dies) | PASS | NOT TESTED |
| l10 Hall of Echoes | 19/19 PASS | PASS (2/2 jumps) | PASS (1) | N/A (no chain) | PASS (P2) | PASS (P2 dies) | PASS | NOT TESTED |
| l11 Twin Sanctums | 19/19 PASS | PASS (2/2 jumps) | see notes | N/A (no chain) | PASS (P1) | PASS (P1 dies) | PASS | NOT TESTED |
| l12 The Gilded Seal | 19/19 PASS | PASS (1/1 jumps) | see notes | N/A (no chain) | PASS (P2) | PASS (P2 dies) | PASS | NOT TESTED |
| l13 Ashen Steps | 19/19 PASS | PASS (8/8 jumps) | PASS (1) | N/A (no chain) | PASS (P1) | PASS (P1 dies) | PASS | NOT TESTED |
| l14 Cinder Bridges | 18/18 PASS | PASS (10/10 jumps) | PASS (1) | PASS (slack 1.92 s) | PASS (P2) | PASS (P2 dies) | PASS | NOT TESTED |
| l15 Forge of Embers | 19/19 PASS | PASS (6/6 jumps) | PASS (1) | N/A (no chain) | PASS (P1) | PASS (P1 dies) | PASS | NOT TESTED |
| l16 Heart of the Mountain | 18/18 PASS | PASS (13/13 jumps) | see notes | PASS (slack 2.05 s) | PASS (P2) | PASS (P2 dies) | PASS | NOT TESTED |
| l17 Iron Gate Keep | 19/19 PASS | PASS (1/1 jumps) | see notes | N/A (no chain) | PASS (P1) | PASS (P1 dies) | PASS | NOT TESTED |
| l18 Clockwork Halls | 19/19 PASS | PASS (4/4 jumps) | PASS (1) | N/A (no chain) | PASS (P2) | PASS (P2 dies) | PASS | NOT TESTED |
| l19 Broken Towers | 19/19 PASS | PASS (10/10 jumps) | PASS (1) | N/A (no chain) | PASS (P1) | PASS (P1 dies) | PASS | NOT TESTED |
| l20 The Black Bastion | 19/19 PASS | PASS (7/7 jumps) | see notes | N/A (no chain) | PASS (P2) | PASS (P2 dies) | PASS | NOT TESTED |
| l21 Frost Causeway | 19/19 PASS | PASS (17/17 jumps) | PASS (1) | PASS (slack 3.22 s) | PASS (P1) | PASS (P1 dies) | PASS | NOT TESTED |
| l22 Spire of Silence | 20/20 PASS | PASS (11/11 jumps) | PASS (1) | PASS (slack 3.40 s) | PASS (P2) | PASS (P2 dies) | PASS | NOT TESTED |
| l23 Warden's Vault | 19/19 PASS | PASS (5/5 jumps) | see notes | N/A (no chain) | PASS (P1) | PASS (P1 dies) | PASS | NOT TESTED |
| l24 Crown of Dawn | 19/19 PASS | PASS (7/7 jumps) | see notes | PASS (slack 1.65 s) | PASS (P2) | PASS (P2 dies) | PASS | NOT TESTED |

Column key: **Probe** = number of the 20 checks that passed / that apply to the level (the
rest are N/A because the level has no such element, for example no ladder). **Route** = jumps
made / jumps on the main route. **Optional** = new optional routes replayed in that level by the real knight; "see notes"
means the level's additions are on the main route, are co-op mechanisms with their own test,
or need a lantern bounce (described under the level).
**Solo exit / Death / Quit** = the three per-level co-op checks.

## World 1: Ancient Forest (teaches)

### l01 The Mossy Path

- **Identity:** the first steps; the charged slash.
- **Added:** a second spring from the canopy ledge onto the **roof of the old tree** (two
  step ledges, coins, a shield fruit) — a high road past the cracked wall, so a pair that has
  not understood the charged slash can still go on; the **first spikes**, between the plate
  and its gate.
- **Co-op:** the secret room above the cracked wall still needs a partner's boost.
- **Tested:** probe, route, optional route to the roof fruit, static, spawns, solo exit (P1),
  death, quit and reopen. Real-window render checked.
- **Not replayed automatically:** the boost into the secret room (KI-120).

### l02 Rootway Hollows

- **Identity:** going down into the roots; the first two-knight lock.
- **Added:** a **crumbling root bridge** from the spring ledge over the lift's pit (one knight
  can take it while the other rides the lift); a **root tunnel** behind the hollow with a
  slime, coins and a green fruit.
- **Tested:** all per-level checks; optional route to the tunnel fruit.

### l03 Old Watchtrees

- **Identity:** the vertical climb; the lift that needs a holder; spirit lanterns.
- **Added:** a slime on the first branch; a spring on the orc's branch up to a **nest** (coins,
  a green fruit).
- **Tested:** all per-level checks; optional route to the nest. Both knights on the green jar
  in the same frame: exactly one gets it.
- **Not replayed automatically:** the lantern chain to the green jar (KI-120).

### l04 Heart of the Grove

- **Identity:** the first ambush; the split (one above, one below).
- **Added:** two **spirit lanterns over the rafts** to an islet with a venom fruit, placed
  before the level's orcs.
- **Tested:** all per-level checks. A knight taking the venom fruit far from the partner: only
  the taker's blade is venomous.
- **Not replayed automatically:** the two lantern bounces (KI-120).

## World 2: Underground Caves (darkness, wind)

### l05 Crystal Descent

- **Identity:** a descent in the dark; crystal rooms behind cracked stone.
- **Added:** a **crystal room in the first cliff** (shield fruit); a bat and a **chasm crossed
  on crumbling crystal** in the lowest chamber (it replaces a lone spike and an orc); the
  yellow jar now waits behind a **door that opens only while the partner holds the stone
  below** — the level's first co-op mechanism.
- **Recoverable:** the door never shuts on a knight in the niche; the holder can always come
  back.
- **Tested:** all per-level checks; optional routes to the cliff room and to the jar;
  `test_l05_jar_door_opens_only_while_the_partner_holds_the_stone`.

### l06 Echoing Shafts

- **Identity:** riding the wind upward; two roads.
- **Added:** the **low road**: five crumbling stones over the abyss to an island (coins, purple
  fruit) and a second wind up to the middle shelf. The high road (wind, bat, blinking bridge)
  is unchanged, so each knight can choose.
- **Found and fixed:** the first version of the island wind did not set the knight down on
  the shelf (KI-117).
- **Tested:** all per-level checks; optional routes to the island and from the island up to
  the shelf; timing of the blinking bridge.

### l07 Brood Caverns

- **Identity:** many small enemies; the Brood Mother below.
- **Added:** a **gallery** above the first hall (a spring up, a bat over it, a shield fruit at
  its end — it replaces a fruit that lay on the floor); a **brood nest** sunk in the floor
  (slimes, coins) under a three-tile bridge; a second bat pillar; venom on the coin ledge
  before the boss.
- **Tested:** all per-level checks, including the arena fight; optional routes to the gallery
  fruit and the nest.

### l08 The Sunless Lift

- **Identity:** two lifts and three keys in the dark; the World 2 arena.
- **Added:** a **hidden room beside the first lift** (cracked wall; blue jar, coins); spikes and
  a purple slime on the top road.
- **Tested:** all per-level checks; optional route to the blue jar.

## World 3: Abandoned Ruins (communication)

### l09 Sunken Gatehouse

- **Identity:** the first shieldbearer and archer; "strike as one".
- **Added:** a **cistern under the courtyard** (a cracked flagstone to strike from above, or
  the ladder; coins and venom for the guard hall that follows).
- **Tested:** all per-level checks, including the arena; optional route to the cistern.

### l10 Hall of Echoes

- **Identity:** order and memory: three targets in the order the sign gives.
- **Added:** the yellow jar moved from the floor to a **ledge swept by a saw** (a spring leads
  up; the jar is at the far end).
- **Tested:** all per-level checks; optional route to the jar (the saw is removed for the
  route check; its damage is covered by `test_mechanisms`).

### l11 Twin Sanctums

- **Identity:** two roads that open each other's doors.
- **Added:** a saw and a second orc in the crypt (the orc closes in on whoever holds the
  plate); a **reunion hall** where the roads meet: it locks on both knights until a
  shieldbearer between two archers falls. The level is 20 tiles longer.
- **Tested:** all per-level checks, including the new arena. The feast on the roof heals the
  eater 3 and the far partner 1.

### l12 The Gilded Seal

- **Identity:** three locks, then the Orc Warchief.
- **Added:** a saw under the twin targets; an archer at the end of the gallery (the ordered
  switches are now struck under fire); a **feast and a venom fruit** in front of the seal.
- **Tested:** all per-level checks, including the Warchief's arena.

## World 4: Lava Kingdom (lava ends the run)

### l13 Ashen Steps

- **Identity:** the first lava; hot air.
- **Added:** a **steam vent** beside the first pit (jump in, rise to a ledge of coins over the
  lava) with the clue "Hot air rises."; a **terrace** two tiles high for the brute.
- **Tested:** all per-level checks; optional route through the vent. A knight with three
  shield hits and a ready ward still dies in lava, and nothing survives the wipe.

### l14 Cinder Bridges

- **Identity:** thin bridges over a lava sea.
- **Added:** two **blades swinging through the bridge**; a **rock shelf under the first
  bridge** (a ladder down; coins, a shield fruit).
- **Tested:** all per-level checks; optional route to the shelf; timing of the seven-stone
  chain.

### l15 Forge of Embers

- **Identity:** the forge; the Magma Heart above.
- **Added:** a **cellar under the first floor** (cracked flagstone or ladder; coins and venom
  before the boss); **falling hammers** (loose rock) in the forge hall; a grinding wheel
  before the exit.
- **Tested:** all per-level checks; optional route to the cellar.

### l16 Heart of the Mountain

- **Identity:** the World 4 finale: ferry relay, forge arena, long blinking crossing.
- **Added:** the **summit gate** opens only when both knights strike the twin hearts within
  two seconds ("Two hearts. One beat.").
- **Tested:** all per-level checks;
  `test_l16_summit_gate_needs_both_knights_striking_together` (one knight striking both hearts
  does not open it; two knights in the same frame do).

## World 5: Dark Fortress (combinations)

### l17 Iron Gate Keep

- **Identity:** three keys for two hands; the quiet road above the hall.
- **Added:** the catwalk **crumbles in front of its archer**, and the yellow jar moved behind
  him; an **archer covers the moving platforms under the saws** (jumping meets the saw, so
  crouch or cut the arrow).
- **Tested:** all per-level checks.

### l18 Clockwork Halls

- **Identity:** two machines worked at once.
- **Added:** **ticking steps** above the pen to a ledge (coins, a shield fruit); a **pendulum
  blade** between the last shieldbearer and the exit.
- **Tested:** all per-level checks; optional route up the ticking steps.

### l19 Broken Towers

- **Identity:** four towers over a spiked courtyard, in the wind.
- **Added:** the **span between the towers runs only while a knight holds its plate** (the
  rider latches it on the third tower, under an archer) — the level's first real co-op
  mechanism; a **cracked stone at the foot of the last tower** (coins, a strong shield fruit).
- **Recoverable:** a rider stranded on a stopped span can drop to the courtyard ladders.
- **Tested:** all per-level checks; optional route to the tower foot;
  `test_l19_span_runs_while_held_and_stays_running_once_latched`. Real-window render checked.

### l20 The Black Bastion

- **Identity:** the World 5 finale and the Hollow Captain.
- **Added:** **wind against the crumbling rampart**; the vault's fruit is now a feast; a power
  tile before the inner seal.
- **Tested:** all per-level checks, including the Captain's arena.

## World 6: Final Citadel (mastery)

### l21 Frost Causeway

- **Identity:** ice under quick doors.
- **Added:** **icicles** over the middle of the broken bridge; the yellow jar moved into an
  **alcove at the foot of the chasm ladder, held by an archer** in a corridor (crouch, or cut
  the arrows).
- **Tested:** all per-level checks; optional route to the alcove; timing of the chain.

### l22 Spire of Silence

- **Identity:** the tall climb; one above and one below strike together.
- **Added:** a **blade on the ledge above the blinking stair**; a **cache at the foot of the
  spire** (coins, a strong shield fruit) guarded by a brute and an ember slime.
- **Tested:** all per-level checks; optional route to the cache; timing of the stair.

### l23 Warden's Vault

- **Identity:** counted blows; the Citadel Warden below.
- **Added:** the floor above the vault is **ice, held by a shieldbearer, an orc and an
  archer**.
- **Tested:** all per-level checks.

### l24 Crown of Dawn

- **Identity:** the end: gauntlet, river, two roads, the Dawn Gate, the Crowned Hollow.
- **Added:** fire jets and an ember slime in the first gauntlet; a **feast and a venom fruit
  behind the Dawn Gate**, before the throne hall.
- **Tested:** all per-level checks, including the final arena; one knight alone at the exit
  completes the campaign.

## Things no automated check covers

| Item | Why | What to do |
|---|---|---|
| Whether the levels are fun, clear and fair | Needs people | Play; note where you get stuck or bored (`docs/FRIEND_PLAYTEST_CHECKLIST.md`) |
| Lantern and boost routes (l01, l03, l04) | The route validator plans without them | Try them; report any that cannot be made |
| Readability of dark levels, the wind and the reach crescent on a monitor | Screenshots were checked, motion was not | Look while playing |
| Boss fights against two real players | The probe fights arenas by script | Play l12, l20, l24 |
| Whether the new saws, archers and wind are too much in l14, l17, l20 | Balance by reasoning only | Report deaths per level |
| Keyboard ghosting with both players attacking and moving | Hardware | `docs/MANUAL_KEYBOARD_TEST.md` |
