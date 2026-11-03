# Manual Hazard Test (Phase 6)

Status: **pending**. To be performed by the project owner and a second player.

## Starting the hazard test room

```
"C:/Users/Reaper/Downloads/Godot/Godot_v4.7.2-stable_win64.exe" --path "C:/Users/Reaper/Desktop/code/game" res://scenes/dev/hazard_test_room.tscn
```

Or open `scenes/dev/hazard_test_room.tscn` in the editor and press **F6**.

Layout, from left to right:
- **SPIKES** on the floor.
- **HOT GROUND:** glowing red earth you can stand on.
- **LAVA:** a shallow pit.
- **PIT:** a small bottomless gap.
- **H-MOVE:** a platform moving sideways over a wide pit.
- **V-MOVE:** a solid platform lifting you to the **LEDGE**.
- **TIMED:** two ice platforms (solid → blinking red → gone → fading back).
- **BLINK:** two grass platforms that appear and disappear on a schedule.
- **CRUMBLE:** two orange platforms that collapse after you land.
- **LANDING:** open floor.

The overlay (top left) shows, per knight: health, state, `INV` while invulnerable, the last safe
position, the number of hazards touched and falls. It also shows every platform's state and the
latest hazard events. With F9 on, a small cross marks each knight's last safe position.

| Key | Action (this room only) |
|---|---|
| F1 / F2 | Hurt P1 / P2 (contact damage) |
| F3 | Heal both by 1; revive a dead knight at its spawn |
| F4 | Give P1 a 3-hit yellow fruit shield and the yellow jar |
| F5 | **New run** and reload |
| F6 | Reload the room, keeping the run |
| F7 | Overlay on/off |
| F8 | Pause / resume (platform timers must stop) |
| F9 | Safe-position markers on/off |

## Tests

| # | Procedure | Pass when |
|---|---|---|
| 1 | Walk P1 through the spikes | Exactly 1 HP lost. Standing in them does not drain more. Walk out and back in after the flashing stops: 1 more |
| 2 | F4, then walk into the spikes and onto the hot ground | "BLOCKED"/"LUCKY!" appears and no HP is lost while the shield lasts |
| 3 | Stand on the hot ground | You stand on it (no sinking); 1 HP lost on stepping on, no more while standing |
| 4 | F4, then walk P1 into the lava | P1 dies immediately (shields do nothing). P2 is unaffected and keeps playing. F3 revives P1 |
| 5 | Stand still on safe floor, then jump into a pit | 1 HP lost, P1 reappears where it last stood safely, blinking, and is not hurt by anything for about 1 s. P2 does not move |
| 6 | Fall with 1 HP left | The knight dies once; it does not keep falling or respawning |
| 7 | Both fall at once into different pits | Each comes back at its own last safe spot |
| 8 | Stand on the hot ground or a platform, then fall | You never respawn on hot ground or on a platform |
| 9 | Ride H-MOVE with both knights | Both are carried smoothly; walking on it works; nobody slides off |
| 10 | Ride V-MOVE up to the LEDGE and step off; ride it back down | No jitter, no falling through, the ledge is reachable |
| 11 | Jump up through H-MOVE from below (when it is over ground); press Down on it | Jumping through works; Down drops through |
| 12 | Stand on a TIMED platform | It blinks red before vanishing; you fall. While you stand in its space (if reachable), it does not reappear inside you |
| 13 | Cross the BLINK platforms | They alternate predictably; the warning blink is readable |
| 14 | Land on a CRUMBLE platform; also walk/jump under and beside one | Landing makes it shake then fall away; it returns after about 3 s. Passing under or jumping up through does not trigger it |
| 15 | F8 while platforms are cycling | All platform timers stop; they continue after unpausing |
| 16 | Do 5, 9 and 14 while the screen is split | Respawns and platforms work in both views; the camera follows the respawned knight |
| 17 | General feel | Hazards are readable at a glance; nothing hurts twice from one touch |
