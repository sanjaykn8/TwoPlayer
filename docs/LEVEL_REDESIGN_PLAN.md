# Level Redesign Plan (overhaul)

2026-11-08. The audit (`docs/GAMEPLAY_AUDIT.md`) found long flat corridors with one enemy type.
Every level now has a recognisable identity, a signature mechanic, enemy variety and at least
one optional reward. "Rebuilt" levels are new layouts. "Remixed" levels keep a strong set piece
from before (a puzzle, a boss lair) but have new enemies, mechanisms, arenas and secrets.
Specs are in `tools/campaign/world_*.gd`; per-level numbers are in `docs/CAMPAIGN_PLAN.md`
(generated).

## How the worlds build up

| World | Introduces | Combines with |
|---|---|---|
| 1 Ancient Forest | Orc grunts (read the wind-up), spring mushrooms, cracked blocks and the charged slash, pogo lanterns, the stack boost (secrets), the first arena | Slimes, plates, lifts |
| 2 Underground Caves | Darkness with carried lights and torches, cave bats, falling rocks, updrafts, orc brutes and shockwaves, the Brood Mother (optional) | World 1 mechanics |
| 3 Abandoned Ruins | Orc shieldbearers (flank them), hollow archers (crouch, jump or cut the arrow), saw blades, the Orc Warchief (mandatory) | Sync, sequence and split puzzles |
| 4 Lava Kingdom | Ember slimes (fuses, chain blasts, break walls), fire jets, hot-air vents, the Magma Heart (optional) | Lava, crumbling and blinking stones, brutes |
| 5 Dark Fortress | Mixed packs (shields and archers together), saws over spike trenches, wind over the towers, the Hollow Captain (mandatory) | Multi-key locks, separated objectives |
| 6 Final Citadel | Ice under the timed doors, every enemy mixed, the Citadel Warden (optional), the Crowned Hollow (mandatory final boss) | Everything |

## The 24 levels

| # | Level | Status | Identity | Signature beats | Optional rewards |
|---|---|---|---|---|---|
| 1 | The Mossy Path | Rebuilt | Tutorial on two tiers | Spring to the canopy, a cracked wall that teaches the charged slash, plate gate, the first grunt | Canopy (red fruit, coins); a room above the cracked wall (charged up-strike plus stack boost) |
| 2 | Rootway Hollows | Rebuilt | Descent into the roots | Ladder down, lift over a pit, the two-knight lock in the hollow, grunts | Spring to a root ledge (coins); cracked root wall (purple fruit, coins) |
| 3 | Old Watchtrees | Rebuilt | Vertical tree climb | Co-op lift (one holds, one latches), branches and a spring, a grunt on the high branch, a glide between trunks | Pogo-lantern chain to the green jar |
| 4 | Heart of the Grove | Rebuilt | World 1 finale | Arena ambush in the clearing, rafts, the split (one holds above, one runs below), two-plate gate | Coin cave under a cracked floor (strike the earth from above) |
| 5 | Crystal Descent | Rebuilt | Dark descent | Bats, rocks over a spike gap, a drop shaft, the lowest chamber | Cracked crystal room (purple fruit); updraft chimney to the yellow jar |
| 6 | Echoing Shafts | Rebuilt | Ascent on the wind | Two updrafts, the blinking bridge, rocks and an orc on the high shelf, timed stones | Spring pocket (power tile, coins) |
| 7 | Brood Caverns | Remixed | Dark brood cave | Bats under hanging rock, ferry, timed steps, a brute arena at the exit | Brood Mother (red jar) |
| 8 | The Sunless Lift | Remixed | Dark lift shaft | The two-lift co-op machine, rocks, a brute arena at the top | Timed hops (red fruit); crack treasure room |
| 9 | Sunken Gatehouse | Rebuilt | Gatehouse assault | Shieldbearer, saws in the tunnel, an archer on the battlement while targets are struck together, a guard-hall arena | Hidden tower room (red fruit) |
| 10 | Hall of Echoes | Remixed | Ordered strikes | Sequence targets guarded by a shield, a saw in the plate pit, the balcony bridge, archers, the timed door | Balcony ledge; yellow jar |
| 11 | Twin Sanctums | Remixed | Split routes | Roof (saw, shield, archer) and crypt (orcs, archer) open each other's doors | Roof ledge (green fruit) |
| 12 | The Gilded Seal | Remixed | Three locks and a boss | Sync targets, timed plates, ordered switches, then the Orc Warchief arena (mandatory) | Red jar above the gallery |
| 13 | Ashen Steps | Remixed | Fire and lava intro | Fire jets, an ember slime, a cracked wall (ember blast or charged slash), a brute | Green jar over the crumbling stones |
| 14 | Cinder Bridges | Remixed | Bridges over a lava sea | Embers and a brute on one-way bridges, fire jets, the blinking chain | Purple fruit ledge |
| 15 | Forge of Embers | Remixed | The forge | Fire-jet corridor, a brute, the island ferry | Magma Heart (green jar) |
| 16 | Heart of the Mountain | Remixed | World 4 finale | Forge arena (brute and two embers among burning floors), hot-air vent, the blinking chain, the summit lift | Vent ledge (coins); red fruit above the pillar |
| 17 | Iron Gate Keep | Remixed | The keep | Three-key gate, shields and archers on the walk, fire jets, saws over the spike trench | Catwalk; trench vault (red jar) |
| 18 | Clockwork Halls | Remixed | Two machines | A saw across the lower hall, archers, a shield on the catwalk, fire, the pen | Green fruit |
| 19 | Broken Towers | Remixed | Towers in the wind | Crumbling bridges, wind over the span, shields and archers on the towers | Blue jar climb |
| 20 | The Black Bastion | Remixed | World 5 finale | Ramparts with archers and shields, the inner seal, then the Hollow Captain (mandatory) | Coin vault; purple fruit |
| 21 | Frost Causeway | Remixed | Ice and speed | Ice under the timed door, blinking stones, mixed packs | Yellow jar; red fruit |
| 22 | Spire of Silence | Remixed | The tall climb | Archers and shields on the climb, the blinking staircase, the summit sync | Green jar side climb |
| 23 | Warden's Vault | Remixed | The vault gauntlet | Fire jets, a brute and an archer, a saw, mixed packs | Citadel Warden (blue jar) |
| 24 | Crown of Dawn | Remixed | The finale | The last gauntlet, the three-lock Dawn Gate, the Crowned Hollow in the throne hall (mandatory, three phases) | Ledges on the roof route |

## Rules every layout follows (checked automatically)

- **Movement:** the main route stays inside the movement limits (`tools/level_analyzer.gd`).
  The real knight physically walks it with base stats and no bosses (`test_campaign_routes`).
- **Recovery:** every reachable place leads back to the exit (`test_no_level_can_trap_a_knight`).
  Updrafts cannot be fallen through, so updraft rooms have a separate way down.
- **Secrets:** secrets may need the stack boost (two knights). Bosses are only required where
  they are a level's set piece (l12, l20, l24); the three slime bosses stay optional.
- **Arenas:** gates FOLLOW an encounter zone and close only with both knights inside. They
  never close on an occupant, and every arena enemy can be reached.
- **Blinking chains:** they vanish behind the knights (`test_platform_timing`).
- **Spawns:** no enemy starts near a spawn (`test_every_level_spawns_both_knights_safely`).
