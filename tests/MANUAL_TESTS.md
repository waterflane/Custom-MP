# In-game acceptance checks

Status: **not run in a live Teardown session**. Automated Lua tests use a mocked API.

Use a host and a second player. Compare each custom mode with the installed official Multiplayer Classics equivalent. Keep the headshot multiplier at 1.0 and extra combat overlays off for the comparison. The custom loot pool is an intentional difference.

## All three modes

- Select the mode on a map with multiplayer spawn tags and on a map using generated positions. Confirm there are no script/resource errors.
- Confirm the host can edit settings before Start; clients see the waiting/team interface and cannot start or change the match settings.
- Check Russian and English labels, all tabs, tool pages and preset actions at 1920×1080 and 1280×720. Check a smaller window for paginated tool/preset controls, clipping and overlaps.
- Navigate by mouse, keyboard and a gamepad. Opening settings must keep the host menu and team selection from receiving input behind the panel; closing restores navigation.
- Start with vanilla equipment, a custom Workshop tool, and an empty starting loadout. Confirm the configuration applies on the initial spawn, after death and to a player joining mid-match.
- Confirm countdown, spawn protection, spawn selection, respawn delay, kill/death scoring, spectator camera, scoreboard, match timer, draw/win result and leaving the results match the official mode.
- Test crate interaction, ammo 0 and 100, a single positive loot weight, all weights zero, and all tools excluded from loot. Confirm drops and crate respawns match official behavior.
- Enable each combat overlay separately. Test body hits, headshots, lethal hits, explosions, suicide and friendly hits. A headshot bonus must not recurse, duplicate kill scoring or bypass spawn protection.
- Turn player names off and confirm CTF flag/base/carrier icons remain available.

## Presets

- Save distinct settings in all five empty slots; load each and verify every setting. Overwrite a slot and verify the replacement.
- Load a preset without starting the game. Delete it and verify the draft stays unchanged; other slots remain intact.
- Save in DM, create TDM/CTF on another map, and load the same slot. Verify stored duration and settings transfer.
- Restart Teardown completely, create another session and verify all saved slots remain available.
- Save a Workshop tool, disable its mod, and load the preset. Verify a missing-tool notification and successful match start. Re-enable the tool and reload the original slot; its saved values must remain. Explicitly overwrite while the tool is absent and verify the absent entry is removed.

## Team Deathmatch and Capture the Flag

- Confirm team selection, team assignment, countdown, friendly-hit scoring, teammate markers and mid-match joining follow the official mode.
- In CTF, check stealing, carrying, dropping, picking up, returning and capturing both flags, carrier death/disconnection, and base/flag map markers and sounds.
- Exit CTF into another mode and confirm both flag tools and spawned objective entities are cleaned up.

Record the game build, map, active Workshop tools, input device and any script-log errors when reporting a failure.
