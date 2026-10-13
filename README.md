# Custom MP

Vanilla DM, TDM and CTF with configurable loadouts, loot, HUD and five shared presets.

| Mode | Identifier | Default match time | Respawn delay |
| --- | --- | --- | --- |
| Deathmatch | `customdeathmatchmp` | 5 minutes | 10 seconds |
| Team Deathmatch | `customteamdeathmatchmp` | 5 minutes | 10 seconds |
| Capture the Flag | `customcapturetheflagmp` | 8 minutes | 3 seconds |

The mode scripts, spawn algorithms, teams, spectator cameras, scoring, objectives, countdown and results are based on the official `mods/mpclassics` files. CTF includes its flag/base prefabs, models, icons and sounds. Treasure Thieves and Sandbox are not included.

## Host settings

Before starting the match, open **Game mode settings**. The panel uses Teardown's Multiplayer Classics UI and navigation helpers, with English and Russian text. Other languages use English for the added settings.

- **Match:** choose preset durations (3, 5, 8, 10, 15, 20 or 30 minutes) or a custom time slider up to 24 hours, in one-minute steps. The lowest value is labelled Unlimited. Headshot multiplier keeps its existing selector.
- **Tools:** enable each starting tool, set starting ammo (0–100), allow it in loot, set its relative loot weight (0–10) and pickup ammo (0–100). These three numeric values use integer sliders with visible values and mouse/keyboard/gamepad control.
- **HUD:** player names, hit markers, kill markers and damage numbers. These are host-selected settings for all players; objective markers remain visible when player names are disabled.
- **Presets:** five shared slots in a dropdown, with Save/overwrite, Load, Rename and Clear settings actions.

Settings are applied together when the host presses **Start** and cannot be changed during the match. Team modes retain the official team selection/countdown. Settings reset to the mode's defaults when a new game is created; use a preset to reuse a configuration.

Vanilla starting equipment is a gun with 7 rounds, sledge, spraycan and extinguisher, with the gun selected. Headshot multiplier defaults to 1.0; extra combat overlays default to off. Existing saved settings from earlier versions do not enable them automatically.

The loot pool uses configurable tool weights and the same pool at all official low/medium/high spawn points. Official spawn-point generation, interaction pickup, weapon drops and 20-second crate respawn remain in use. A zero weight excludes a tool; an entirely empty pool produces no crates. Starting with no tools is supported. Pickup ammo of zero is preserved.

Active vanilla and Workshop tools come from `game.tool`. Custom tools start disabled and with zero loot weight until configured. Internal CTF flag tools never appear in the settings or loot pool.

Unlimited matches show elapsed time with ∞ and do not end by timer. Finite matches retain the official countdown/results behavior. Presets store both time choices and the selected mode; older presets load as preset durations.

## Presets / Пресеты

The five slots are initially empty and belong to the local host. They are shared across these three modes and all maps, and persist across game restarts through `savegame.mod.cdmp.presets`. The storage implementation is in `scripts/shared/presets.lua`; the game writes its own mod save data, rather than modifying a Lua source file.

Save writes all current settings into the selected slot; saving again replaces that slot. Load fills the setup screen without starting a match. Clear settings empties the slot without changing the current draft or its name. Rename works for empty and saved slots, accepts up to 32 characters and supports English/Russian keyboard input and an on-screen keyboard. Presets do not contain a map, teams, scores or match state.

Missing Workshop tools are skipped with a message. Loading never changes the saved slot, so those tools remain in the preset if they become available again. Explicitly overwriting the slot saves only the currently available tool configuration.

**Русский:** перед началом матча хост открывает «Настройки режима» → «Пресеты». Доступны пять общих пустых слотов. «Сохранить / перезаписать» записывает текущие настройки, «Загрузить» заполняет меню, «Очистить настройки» очищает конфиг выбранного слота, сохраняя его имя. Слоты выбираются из выпадающего списка; их можно переименовать. Для применения загруженных настроек нужно запустить матч. Пресеты сохраняются после перезапуска игры и доступны в DM, TDM и CTF на любой карте.

## Installation

Place this mod's folder under `Documents/Teardown/mods/` and enable **Custom MP**. The existing game-mode identifiers are retained. Do not commit `id.txt`; it links the local folder to a Steam Workshop item.

## Testing from the editor / Тестирование из редактора

This is a global game-mode mod, not a map: there is no root `main.xml` to open. The editor's Open/Save level dialogs list level files/folders, not the registered game modes. Open a separate test map in the editor instead.

1. Enable **Custom MP** in the Mod Manager's local mods list, then reopen the editor/game if necessary to refresh metadata.
2. Open a map made for version 2 (`version = 2` in that map's `info.txt`). Press **F5** to play it.
3. Open **Esc → Game Modes / Игровые режимы** and select **Custom MP: Deathmatch**, **Custom MP: Team Deathmatch** or **Custom MP: Capture the Flag**. Then set up the match as host and press Start. **F4** returns to the editor.
4. For a local two/four-player test, select a local version-2 map in the Mod Manager and press **Play / Играть**. The play-options dialog includes the active mod's game modes and a **Number of Players / Количество игроков** choice for 1, 2 or 4 local players.

`info.txt` must use `version = 2`: this is the engine's mod format, not the mod's release number (`CDMP.VERSION`). Real online sessions require published Workshop mods; use local testing during development.

**Русский:** включите локальный мод Custom MP, откройте в редакторе другую карту версии 2, запустите её через F5 и выберите режим через Esc → «Игровые режимы». Custom MP не содержит карты, поэтому искать его как уровень в File → Open не нужно. Для проверки с несколькими локальными игроками запускайте карту кнопкой «Играть» в менеджере модов и выбирайте количество игроков.

Input hints use current keyboard bindings from the public settings registry and retain gamepad glyphs.

## Development and validation

Entry points are `cdmp.lua`, `teamdeathmatch.lua` and `capturetheflag.lua`. Each includes `scripts/shared/custom.lua`, which connects shared configuration, presets, server settings and optional combat feedback. The official `dm_spawn.lua` and `tdm_spawn.lua` remain separate; CTF uses `mplib/spawn.lua`.

Run the automated checks with Python, `lupa` (including its Lua 5.1 runtime), and the installed game files:

```powershell
python -m pip install --target "$env:TEMP\cdmp-lua-tests" lupa
$env:TEARDOWN_PATH = 'D:\SteamLibrary\steamapps\common\Teardown'
python tests\test_mod.py
```

The suite covers Lua 5.1 syntax, include graphs, resources, mode initialization, host-only/one-time settings application, validation, empty pools/loadouts, five preset slots, overwrite/delete, persistence across mocked runtime restarts, cross-mode loading, missing tools, optional combat effects and setup UI interactions/pagination. It uses a mocked engine API; it does not prove game rendering or networking behavior.

Two-player networking, real engine persistence, visual layout and controller navigation have **not been verified in a live Teardown session**.

## License

This project is licensed under GNU GPL v3.0; see LICENSE. The included Multiplayer Classics scripts and assets originate from the installed official Teardown mod. Changes to official gameplay code are limited to the configuration/feedback integration and correcting the CTF cleanup typo `falg2` to `flag2`.
