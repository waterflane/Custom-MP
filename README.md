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

- **Match:** choose preset durations (3, 5, 8, 10, 15, 20 or 30 minutes) or a custom time slider from 0 to 6 hours, in one-minute steps. The lowest value is labelled Unlimited. Headshot multiplier keeps its existing selector.
- **Tools:** numbered cards show tool names and current loadout/loot status. Card rows and pagination reserve space for the footer; opening a tool shows its controls, and Back returns to the same list page. Enable each starting tool, set starting ammo (0–100), allow it in loot, set its relative loot weight (0–10) and pickup ammo (0–100). These three numeric values use integer sliders with visible values and mouse/keyboard/gamepad control.
- **HUD:** player names, hit markers, kill markers and damage numbers. These are host-selected settings for all players; objective markers remain visible when player names are disabled.
- **Presets:** five shared slots in a card list showing names and saved/empty status. The list reserves space for Cancel, uses smaller rows in short windows and pages when needed. The selected card opens the list; Save/overwrite is the primary action, beside Load, with Rename and Clear settings below.

Settings are applied together when the host presses **Start** and cannot be changed during the match. Team modes retain the official team selection/countdown. Settings reset to the mode's defaults when a new game is created; use a preset to reuse a configuration.

Vanilla starting equipment is a gun with 7 rounds, sledge, spraycan and extinguisher, with the gun selected. Headshot multiplier defaults to 1.0; extra combat overlays default to off. Existing saved settings from earlier versions do not enable them automatically.

The loot pool uses configurable tool weights and the same pool at all official low/medium/high spawn points. Official spawn-point generation, interaction pickup, weapon drops and 20-second crate respawn remain in use. A zero weight excludes a tool; an entirely empty pool produces no crates. Starting with no tools is supported. Pickup ammo of zero is preserved.

Active vanilla and Workshop tools come from `game.tool`. Custom tools start disabled and with zero loot weight until configured. Internal CTF flag tools never appear in the settings or loot pool.

Unlimited matches show elapsed time with ∞ and do not end by timer. Finite matches retain the official countdown/results behavior. Presets store both time choices and the selected mode; older presets without time-mode fields load as preset durations. Custom durations above six hours are capped when applied, without changing the saved slot.

## Presets / Пресеты

The five slots are initially empty and belong to the local host. They are shared across these three modes and all maps, and persist across game restarts through `savegame.mod.cdmp.presets`. The storage implementation is in `scripts/shared/presets.lua`; the game writes its own mod save data, rather than modifying a Lua source file.

Save writes all current settings into the selected slot; saving again replaces that slot. Load fills the setup screen without starting a match. Clear settings empties the slot without changing the current draft or its name. Rename works for empty and saved slots, accepts up to 32 characters and uses physical keyboard input with Shift/Caps Lock, Backspace and Ctrl+A. There is no on-screen keyboard or layout selector. Presets do not contain a map, teams, scores or match state. Preset actions show stacked notifications at the bottom left, independently of the settings window; each fades out within five seconds.

Missing Workshop tools are skipped with a message. Loading never changes the saved slot, so those tools remain in the preset if they become available again. Explicitly overwriting the slot saves only the currently available tool configuration.

**Русский:** перед началом матча хост открывает «Настройки режима» → «Пресеты». Доступны пять общих пустых слотов. «Сохранить / перезаписать» записывает текущие настройки, «Загрузить» заполняет меню, «Очистить настройки» очищает конфиг выбранного слота, сохраняя его имя. Слоты выбираются из выпадающего списка; их можно переименовать. Для применения загруженных настроек нужно запустить матч. Пресеты сохраняются после перезапуска игры и доступны в DM, TDM и CTF на любой карте.

Preset storage on Windows is part of `%LOCALAPPDATA%\Teardown\savegame.xml`, under the mod's own entry in `savegame.mod`. For this local folder the entry is normally `local-custom-mp`; copying only the mod's Lua files does not copy presets. Renaming the folder or switching to the Workshop version changes the mod identity and may open a different save entry.

**Перенос только пресетов:**

1. Закройте Teardown на обоих компьютерах и сделайте резервные копии их `savegame.xml`.
2. На исходном компьютере найдите запись мода (`local-custom-mp` для папки `Custom MP`) внутри `<savegame><mod>`, затем её `<cdmp><presets>`. Скопируйте целиком блок `<presets>...</presets>`: в нём все пять слотов, имена и версии формата.
3. На другом компьютере установите мод, один раз сохраните любой пресет и закройте игру, чтобы создать запись назначения. В текстовом редакторе замените только её блок `<presets>` скопированным. Для другого имени папки или Workshop используйте запись назначения, а не исходный идентификатор мода. Остальные данные сохранения не меняйте.
4. Запустите игру и загрузите нужный слот. Для Workshop-инструментов нужны те же активные моды; отсутствующие инструменты пропускаются.

Отдельного файла экспорта пресетов пока нет. Для переноса всего игрового сохранения можно копировать весь `savegame.xml`, но тогда переносятся также прогресс и настройки других модов.

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
