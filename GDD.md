# GAME DESIGN DOCUMENT
## Two-Player Cooperative Platformer
### Working title: Untitled

## 1. Game Overview

Develop a challenging 2D side-scrolling cooperative platformer designed for exactly two players sharing one Windows PC and one keyboard.

Both characters are knights. They must explore large interconnected environments, fight hostile creatures, collect upgrades, solve cooperative platforming challenges and reach the final destination.

The game emphasizes:
- Difficult precision platforming.
- Directional melee combat.
- Cooperative puzzles and synchronized actions.
- Permanent stat progression within a run.
- Punishing hazards and enemies.
- Full campaign restart when either player dies.
- Four independent local save slots.

The game must be playable entirely offline.

Target successful first-playthrough duration: 90–120 minutes.

## 2. Game Engine and Technical Requirements

- Engine: Godot 4.7.x.
- Language: GDScript.
- Platform: Windows desktop.
- Perspective: 2D side-view.
- Rendering: Pixel-art graphics with appropriate nearest-neighbor filtering.
- Aspect ratio: 16:9.
- Multiplayer: Local co-op, one keyboard.
- No online services, external APIs, analytics or cloud saves.
- No mandatory third-party plugins.
- No runtime asset downloads.

Use the downloaded Brackeys Platformer Bundle as the primary asset source. Create additional pixel-art assets or effects where required. Do not replace existing suitable assets unnecessarily.

## 3. Player Characters

There are two knights:

- Knight 1: Player One.
- Knight 2: Player Two.

Both have identical base attributes, animations, attack strength, health and movement abilities.

They differ visually through character colors or palette variations.

### Controls

Player One:
- W: Up / jump / climb.
- A: Move left.
- S: Down / crouch / drop through platforms.
- D: Move right.
- V: Attack.

Player Two:
- Up Arrow: Up / jump / climb.
- Left Arrow: Move left.
- Down Arrow: Down / crouch / drop through platforms.
- Right Arrow: Move right.
- Left Alt or Right Alt: Attack.

Vertical movement is context-sensitive:
- On ladders: Up and Down climb.
- On normal ground: Up jumps and Down crouches.
- On one-way platforms: Down drops through.
- In designated passages: directional input enables vertical navigation.

Do not introduce additional gameplay buttons.

### Movement

Implement:
- Walking and running.
- Jumping.
- Variable-height jumping if supported by the chosen movement design.
- Crouching.
- One-way platform dropping.
- Ladder climbing.
- Falling and landing.
- Responsive air control.
- Collision with the environment.
- Collision between the knights, with a controlled physical push effect.

Movement and collision must remain stable when both characters move simultaneously.

### Health

Each player starts with three health points.

Display health separately for each player.

Normal enemy contact removes one health point.

Spikes and hot ground remove one health point.

Lava causes instant death.

Falling below the level boundary returns the affected player to the last safe location and removes one health point.

After ordinary damage, provide a short configurable invulnerability period to prevent multiple consecutive damage events from a single contact.

If either player reaches zero health, both players lose the entire campaign run.

## 4. Camera System

Implement a dynamic camera system.

- Begin with one shared camera following the midpoint between both players.
- When players separate beyond an adjustable distance, switch to split-screen.
- Each camera follows its respective knight.
- Use vertical or horizontal split orientation based on the players' relative positions.
- Merge back into one shared camera when players reunite.
- Implement separate enter and exit distance thresholds to prevent rapid switching.
- Avoid sudden camera jumps and excessive zoom.
- Keep player status displays readable in both camera modes.

Both characters must remain visible and playable regardless of camera mode.

## 5. Combat System

Each knight carries a short-range knife.

The weapon has a sword-like slashing animation.

Attack behavior:
- One attack button per player.
- Direction comes from the last valid movement direction.
- Support left, right, up and down attack directions.
- Attack range is intentionally short.
- Include an attack cooldown.
- Include an attack hitbox active only during the appropriate animation frames.
- Prevent a single swing from repeatedly damaging the same enemy.
- Do not allow attacks through walls or solid obstacles.

Base attack power is 1.

Red permanent jars increase attack power by 1.

Attack power contributes to enemy stagger thresholds.

### Enemy stagger and defeat

Green slime:
- Stagger threshold: 2 attack-power points.
- Once staggered, it can be killed with one additional successful melee hit.

Purple slime:
- Stagger threshold: 4 attack-power points.
- Once staggered, it can be killed with one additional successful melee hit.

Stagger duration: 10 seconds minimum.

After recovering:
- Enemy resumes its normal behavior.
- Stagger progress resets.

A staggered enemy must visibly communicate its vulnerable state.

Killing a slime drops between 4 and 6 coins.

## 6. Enemy AI

Implement patrol and chase behavior.

Slimes normally patrol assigned areas.

When a slime detects a player:
- It changes to chase behavior.
- It moves toward the detected player at twice its normal movement speed.
- It damages the player upon contact.
- It returns to its patrol behavior after the target is no longer detectable for a configurable period.

Use appropriate collision boundaries and line-of-sight or detection-area logic.

Create distinct green and purple slime behavior through configurable properties rather than duplicating entire AI systems.

### Boss enemies

Bosses are optional encounters.

They should have:
- Distinct attack patterns.
- More health or more complex stagger mechanics.
- Larger arenas.
- Unique rewards.

Do not require optional boss encounters for normal campaign completion.

## 7. Collectibles and Permanent Progression

### Jars

Jars are individual collectibles with predefined effects.

Green jar:
- Permanently increases maximum health by one.
- Also fills the newly added health point.

Red jar:
- Permanently increases attack power by one.
- Place in difficult platforming sections.
- Make its location challenging to reach.

Yellow jar:
- Provides a 50% chance to negate each incoming damage event.
- Duration: 60 seconds.

Blue jar:
- Permanently increases movement speed by 5%.

Permanent upgrades last throughout the current run and survive saving and resuming.

They reset after a team wipe.

Each unique jar can be collected only once per run.

### Fruits

Green fruit:
- Restores health.
- Tier 1: 1 health point.
- Tier 2: 2 health points.
- Tier 3: 3 health points.
- Never exceed maximum health.

Yellow fruit:
- Blocks incoming hits.
- Tier 1: 1 hit, maximum duration 5 seconds.
- Tier 2: 2 hits, maximum duration 10 seconds.
- Tier 3: 3 hits, maximum duration 20 seconds.
- The effect ends when the hit allowance is exhausted or the timer expires, whichever happens first.

Red fruit:
- Permanently increases attack range.
- Tier 1: 10%.
- Tier 2: 20%.
- Tier 3: 30%.

Purple fruit:
- Gives melee attacks a poison effect.
- Tier 1: 1 second.
- Tier 2: 2 seconds.
- Tier 3: 3 seconds.
- Poison deals one damage-over-time tick per second.
- Poison contributes toward an enemy's stagger threshold but does not independently execute a staggered enemy.

Fruit effects apply to the player who collects the fruit.

Fruit tiers should be introduced progressively through campaign progression.

### Coins

Coins are dropped by defeated enemies.

Each enemy drops 4–6 coins.

Each coin pickup has an independent 10% chance to heal both players by one health point.

Healing cannot exceed maximum health.

Coins are shared campaign resources.

No spending or upgrade shop is required in the initial version. Keep the coin system expandable for future updates.

## 8. Random Power-up Tiles

Separate these tiles from the colored permanent-stat jars.

When a player steps on a power-up tile:
- Activate the effect immediately.
- Choose a random effect from a configurable pool.
- Affect only the player who activated it.
- Duration: 5 seconds.
- Prevent one player from repeatedly triggering the same tile without leaving and re-entering or satisfying a defined cooldown.

Initial provisional power pool:
- Movement speed increase: 25%.
- Attack cooldown reduction: 25%.
- One-hit protective shield.

These effects must be configurable and independently testable.

## 9. Hazards

Lava:
- Immediate death.
- Triggers full campaign restart for both players.

Spikes:
- Remove one health point.

Hot ground:
- Remove one health point.

Falling:
- Respawn the affected player at the last safe position.
- Remove one health point.
- If health reaches zero, reset the entire run.

Implement reliable damage detection and prevent repeated damage from one continuous collision.

## 10. Cooperative Gameplay

Cooperative mechanics must be distributed throughout the campaign.

Include:
- Simultaneous pressure plates.
- One player holding a switch while the other crosses.
- Enemy distraction and coordination.
- Separate targets that must be activated close together.
- Timed gates.
- Separate routes requiring mutual assistance.
- Moving platforms requiring synchronized timing.
- Optional situations in which one player takes a controlled risk to help the other.

Introduce these mechanics gradually.

Provide brief, cryptic environmental text clues. Avoid lengthy tutorial messages or excessive instructions.

Either player can activate a level exit. Once activated, both surviving players transition to the next level, regardless of their relative positions.

## 11. World Structure

Create six themed worlds with four main levels per world.

This gives 24 substantial main levels.

Suggested themes:

1. Ancient Forest.
2. Underground Caves.
3. Abandoned Ruins.
4. Lava Kingdom.
5. Dark Fortress.
6. Final Citadel.

These names are provisional.

Each world should introduce new combinations of enemies, hazards, platforming mechanics and cooperative puzzles.

Include optional boss branches and optional reward areas.

Do not generate the entire world as one unnecessarily enormous scene. Use manageable level scenes and shared reusable components.

Successful first-playthrough target: 90–120 minutes, excluding retries.

## 12. Death and Campaign Reset

The game uses a shared campaign life rule.

If either knight dies:
- Display a game-over transition.
- Reset both players.
- Return the campaign to the first level.
- Reset coins.
- Reset collected fruits and jars.
- Reset temporary effects.
- Reset permanent stat upgrades earned during that run.
- Reset level progression.
- Reset enemy and puzzle progress.
- Start a fresh campaign in the same save slot.

Quitting the game must never count as death.

A player cannot preserve an old campaign by quitting after death.

## 13. Saving System

Implement four independent local save slots.

Save:
- Current world and level.
- Both player positions.
- Current and maximum health.
- Permanent stats.
- Coins.
- Collected fruit and jars.
- Active power-ups and remaining durations.
- Defeated enemies.
- Puzzle and switch states.
- Opened doors and gates.
- Other relevant level progression.

Save at:
- Important zone transitions.
- Level completion.
- Important cooperative milestones.
- Safe save locations.
- Normal game exit.

On exit, preserve the current playable state as accurately as possible.

Temporary effect timers must pause while the game is closed.

Save data must be local and versioned. Handle missing, malformed or outdated files safely.

Use atomic writes or another safe replacement strategy to prevent partially written saves.

The save system must not create a respawn checkpoint after death. A team wipe always starts a fresh run.

## 14. UI

Required interface:

Main menu:
- New Game.
- Continue.
- Save Slots.
- Settings.
- Exit.

Gameplay:
- Player One health.
- Player Two health.
- Shared coin counter.
- Active power-up indicators.
- Power-up countdowns.
- Current world and level.

Pause:
- Resume.
- Restart campaign.
- Save and quit.
- Return to main menu.

Other screens:
- Game-over screen.
- Victory screen.
- Controls guide.
- Save-slot selection.
- Initial tutorial.

## 15. Art and Audio Direction

Use the downloaded Brackeys Platformer Bundle as the primary art and audio source.

Inspect all files before creating replacement assets.

Use:
- Knight sprites.
- Slime sprites.
- Tilesets.
- Platforms.
- Coins.
- Fruits.
- Available music and sound effects.

Create additional pixel-art effects and missing visuals where appropriate.

Audio should remain restrained and gameplay-focused.

Include feedback for:
- Attacking.
- Receiving damage.
- Collecting coins.
- Collecting fruit and jars.
- Enemy staggering.
- Enemy death.
- Hazard activation.
- Level completion.

## 16. Performance and Reliability

The game must:
- Run locally without internet access.
- Support both players simultaneously.
- Maintain responsive controls.
- Avoid unintended player lockups.
- Avoid duplicate damage events.
- Avoid corrupted saves.
- Avoid missing resource references.
- Avoid accidental loss of player visibility.
- Avoid softlocks in cooperative puzzles.
- Handle restarting and scene transitions reliably.

Use configurable values rather than hardcoding balance parameters throughout scripts.

## 17. Success Criteria

The game is complete only when:

1. Both players can play simultaneously on one keyboard.
2. All four directional movement inputs work correctly in their intended contexts.
3. Both attacks work independently.
4. Enemy AI, stagger and death mechanics work as specified.
5. All jars, fruit, coins and power tiles have their correct effects.
6. Hazards behave consistently.
7. Split-screen and shared-camera transitions work correctly.
8. Cooperative puzzles are completable.
9. Death resets the full campaign.
10. All four save slots work.
11. Quitting and resuming preserve campaign progress.
12. All 24 main levels are playable.
13. The game can be exported and launched offline.
14. Automated and manual gameplay tests pass.

A feature must never be described as completed without implementation and validation.
## 18. Approved Design Decisions

Approved by the project owner on 2026-11-03 (Phase 0 recommendations D-1 to D-14).
Where a decision refines an earlier section, this section is authoritative.

**D-1 Attack direction.**
- Up or Down held *when the attack begins* selects an upward or downward attack.
- Otherwise the knight attacks in the direction it last faced.
- Only horizontal movement input updates the last-facing direction. Pressing Up or Down to jump, climb, crouch or drop never changes it.
- If Up and Down are both held, the attack uses the last-facing direction.

**D-2 Down attack on the ground.** On the ground, holding Down means crouching, and an attack started there is a low forward slash. A true downward slash happens only in the air or on a ladder.

**D-3 Standing on the other knight.** Allowed, as a cooperative boost.
- The lower knight can always walk out from underneath.
- When the lower knight jumps, the upper knight is lifted with it.
- A low ceiling pushes the upper knight off.

**D-4 Falling damage** (respawn at the last safe position, −1 health) cannot be blocked by shields, yellow fruit, the yellow jar or power-tile protection.

**D-5 Staggered slimes** do not cause contact damage.

**D-6 No fast-fall.** Down in mid-air has no effect except grabbing a ladder.

**D-7 Rendering.** Logical resolution 640 × 360 (16:9). Nearest-neighbour filtering. Integer scaling with letterboxing; pixels are never stretched. Default window 1280 × 720.

**D-8 Camera.** The camera does not zoom. Separation is handled by split-screen.

**D-9 Resume position.** Continuing a save places each knight at its last safe grounded position in the saved level.

**D-10 Renderer.** Godot Compatibility renderer (OpenGL).

**D-11 Version control.** Git, starting with the baseline commit made before Phase 1.

**D-12 Save location.** The permanent identifier is `TwoKnightCoop` (`application/config/custom_user_dir_name`). It is independent of the displayed title. Saves live in `user://saves/`, which is `%APPDATA%\TwoKnightCoop\saves\` on Windows.

**D-13 Pressure plates.** Only knights press pressure plates. Slimes do not.

**D-14 Controls.** Controls are fixed as listed in section 3. There is no key remapping in v1; it will be revisited only if physical keyboard testing shows unavoidable ghosting.

**Ordinary damage.** Contact damage is applied once per contact event. The invulnerability window stops it repeating during one continuous collision. Spikes and hot ground remove 1 health. Lava kills instantly.

**Vertical input priority** (refines section 3):
1. On a ladder or in a passage, Up and Down climb.
2. Overlapping a ladder, Up grabs it. Down grabs it only if the ladder continues below the knight's feet.
3. Standing on a one-way platform, Down drops through it. There is no crouching on one-way platforms.
4. Standing on solid ground, Up jumps and Down crouches.
5. In the air, Up has no effect beyond the short jump buffer, and Down grabs a ladder only.

**Camera behaviour (Phase 2 instruction, 2026-11-03)** (refines section 4):
- **Shared view.** One full-screen view follows the midpoint between the knights, with a small
  dead zone and smoothing.
- **Splitting.** The view splits when the knights are farther apart than 85 % of the shared
  view's safe region, or as soon as either knight would leave the view. The split shows no jump.
- **Split direction.**
  - Mostly horizontal separation: side-by-side views with a vertical divider.
  - Mostly vertical separation: stacked views with a horizontal divider.
  - The direction changes only when the other axis clearly dominates (×1.35 for 0.35 s).
- **Fixed views.** Player One always has the left or top view. Player Two always has the right or bottom view.
- **Merging.** The views merge back after the knights stay within 55 % of the safe region for
  0.25 s. The halves line up and become one view with no jump.
- **Limits.** Each level defines camera bounds; cameras never show anything outside them.
  There is no zoom (D-8).
- All values live in `resources/config/camera_config.tres`.

**Combat and health behaviour (Phase 3, 2026-11-03)** (refines sections 3 and 5):
- **Range and timing.** The knife reaches about 13 px beyond the body (one swing covers less than a
  tile). The hit frames run from 0.05 s to 0.15 s, and a new attack can start every 0.30 s.
  A press up to 0.10 s early is remembered.
- **Up attacks.** On solid ground Up also jumps, so an up attack from the ground is a jump
  attack. On a ladder the knight stays put.
- **Hit rules.**
  - One swing can damage several enemies, but each enemy at most once.
  - Attacks never pass through solid terrain; one-way platforms do not block them.
  - Knights cannot hurt each other.
- **Damage and stagger.** Damage equals the attack power: 1, or more with red jars later.
  Each hit adds that many points toward a slime's stagger threshold (Phase 4).
- **Invulnerability.** After ordinary damage a knight is invulnerable for 1 s and blinks.
  Falling and lava ignore invulnerability and every protection. Lava kills instantly.
- **Death.** A knight at 0 health is dead: it cannot move, attack, be healed or take damage.
  It only comes back through an explicit revive (development reset now, campaign reset in Phase 8).

**Slime behaviour (Phase 4, 2026-11-03)** (refines sections 5 and 6):
- **Shared design.** Green and purple slimes behave identically except for the stagger
  threshold (2 and 4 attack-power points) and their sprites.
- **Patrol and chase.** They patrol at 30 px/s within a per-slime area, never walking off
  edges or into walls. On seeing a knight they show **!** for 0.2 s, then chase at exactly
  60 px/s (twice the patrol speed).
- **Seeing knights.** Sight is blocked by solid terrain, not by one-way platforms. A slime
  chases the nearest visible knight and does not switch for small distance differences. It
  ignores dead knights and gives up 1 s after losing sight.
- **Unreachable knights.** Slimes cannot jump. A knight on another level makes the slime wait
  below or above it, then give up after 3 s.
- **Contact.** Touching a slime costs 1 health, subject to the knight's 1 s invulnerability.
- **Stagger.** Each distinct melee hit adds the attacker's attack power. At the threshold the
  slime is staggered for 10 s: it is harmless and still, and it pulses with circling stars.
  The next hit from a different attack kills it. After 10 s it recovers and its progress
  starts again from zero.
- **Defeat.** A defeated slime drops 4–6 coins that land on the ground. Collecting them, the
  shared coin total and the 10 % healing chance arrive in Phase 5.
