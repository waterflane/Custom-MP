# Custom MP

A Teardown multiplayer mod with **Deathmatch**, **Team Deathmatch** and **Capture the Flag**, configurable loadouts, weighted loot and five shared presets.

Built on the official Multiplayer Classics scripts, with host-selected match settings and optional combat feedback.

[Download](#download) · [Features](#features) · [Game Modes](#game-modes) · [Installation](#installation) · [Configuration](#configuration) · [Presets](#presets) · [How It Works](#how-it-works)

---

> [!IMPORTANT]
> The host configures the match before pressing **Start**. The selected rules apply to every participant and remain fixed during the match.

## Download

| Platform | Link |
| --- | --- |
| Steam Workshop | [Open the Workshop item](https://steamcommunity.com/sharedfiles/filedetails/?id=3819124313) |
| GitHub | [Browse the source](https://github.com/waterflane/Custom-MP) · [Download main as ZIP](https://github.com/waterflane/Custom-MP/archive/refs/heads/main.zip) |

> [!NOTE]
> This README describes the current source version. Updates to the Workshop build are published separately.

## Features

| Feature | Behavior |
| --- | --- |
| Three classic modes | Official Deathmatch, Team Deathmatch and Capture the Flag gameplay with shared configuration |
| Starting equipment | Enable each tool and choose its starting ammo |
| Weighted loot | Choose eligible tools, relative spawn weights and pickup ammo |
| Match duration | Preset durations, custom time up to six hours, or an unlimited match |
| Headshot damage | Choose a preset multiplier from 1.0× to 3.0× |
| Combat feedback | Optional hit markers, kill markers and floating damage numbers |
| Player names | Toggle names while keeping CTF flags and objective markers visible |
| Five shared presets | Save, load, rename and clear slots across all three modes and maps |
| Workshop tools | Configure active mod tools registered in `game.tool` |
| Setup menu | Tool/preset cards, integer sliders, pages and mouse/keyboard/gamepad navigation |
| Localization | English and Russian settings; other languages use English for added text |

## Game Modes

| Mode | Default match time | Respawn delay |
| --- | --- | --- |
| Deathmatch | 5 minutes | 10 seconds |
| Team Deathmatch | 5 minutes | 10 seconds |
| Capture the Flag | 8 minutes | 3 seconds |

The official teams, spawn protection, scoring, victory checks, spectating, countdown and results remain the foundation of each mode. CTF includes the official flag/base prefabs, models, icons and sounds, including flag pickup, carrying, drops, returns and captures.

## Installation

### Steam Workshop

1. Subscribe to the [Workshop item](https://steamcommunity.com/sharedfiles/filedetails/?id=3819124313).
2. Enable **Custom MP** in Teardown's Mod Manager.
3. Start a multiplayer session and open the game modes menu.
4. Select **Custom MP: Deathmatch**, **Custom MP: Team Deathmatch** or **Custom MP: Capture the Flag**.
5. The host opens **Game mode settings**, chooses the configuration and presses **Start**.

### Local source

1. Download or clone the repository.
2. Place the mod in `Documents/Teardown/mods/Custom MP/`, with `info.txt` directly inside that folder.
3. Enable **Custom MP** under the Mod Manager's local mods.
4. Launch a compatible map and select one of the Custom MP modes.

Custom MP is a global game-mode mod. It does not contain a playable root `main.xml`; open a separate map when using the editor.

## Configuration

All player-facing configuration is available in the host's setup menu; editing Lua files is not required.

| Setting | Options |
| --- | --- |
| Time mode | Preset durations or custom time; switching keeps both choices |
| Preset duration | 3, 5, 8, 10, 15, 20 or 30 minutes |
| Custom duration | 0–6 hours, in one-minute steps; **0 means Unlimited** |
| Starting tool | Enabled or disabled for each tool |
| Starting ammo | Integer slider, 0–100 |
| Allowed in loot | Enabled or disabled for each tool |
| Loot weight | Integer slider, 0–10; **0 excludes the tool** |
| Pickup ammo | Integer slider, 0–100 |
| Headshot multiplier | 1.0, 1.15, 1.25, 1.3, 1.5, 2.0, 2.5 or 3.0 |
| HUD | Player names, hit markers, kill markers and damage numbers |

### Defaults

The default loadout is the vanilla gun with **7 rounds**, sledge, spraycan and extinguisher, with the gun selected. Headshot damage defaults to **1.0×**. Extra hit/kill markers and damage numbers start **off**; player names follow the vanilla rules.

Custom tools start disabled and with zero loot weight until configured. Reset restores the current mode's defaults. A new game starts with defaults; use a saved preset to reuse your changes.

### Match timer

Finite matches keep the official countdown and results behavior. Unlimited matches show **elapsed time with ∞**, skip end-of-timer warnings and do not end because of the timer.

Older presets without time-mode fields use preset durations. A saved custom duration above six hours is capped when applied; loading does not rewrite the saved slot.

### Tool cards and sliders

The tool list shows each tool's name and its current loadout/loot status. Open a card to edit its settings. **Back to tools** returns to the same list page.

Drag numeric sliders with the mouse, or use left/right inputs while the slider has keyboard/gamepad focus. All three tool sliders use integer steps and show the current value. Long lists reserve space for page controls and the lower buttons.

## Presets

Five initially empty slots belong to the local host. They are shared across **DM, TDM and CTF** and all maps.

| Action | Result |
| --- | --- |
| Select a slot | Changes the selected slot without loading it |
| Save / overwrite | Writes the entire current configuration to the selected slot; keeps its name |
| Load | Fills the setup menu without starting the match |
| Rename | Sets a name of up to 32 characters, including for empty slots; an empty name restores the default |
| Clear settings | Clears the saved configuration; keeps the name and current setup |

Names are edited with the physical keyboard, with Shift/Caps Lock, Backspace and Ctrl+A. Preset actions show separate notifications at the bottom left; they fade out within five seconds even after closing the settings window.

A preset includes duration choices, tools, ammo, loot parameters, headshots and HUD options. Maps, teams, scores and live match state are not saved in a preset.

Missing Workshop tools are skipped with a notice. Their stored data remains in the slot and can be used when those tools are available again. Explicitly overwriting the slot saves the currently available tool configuration.

### Storage

Presets use `savegame.mod.cdmp.presets`, with a versioned format. On Windows, the game stores mod data in:

```text
%LOCALAPPDATA%\Teardown\savegame.xml
```

The local folder `Custom MP` normally uses the mod entry `local-custom-mp`. Renaming that folder or switching to the Workshop build changes the mod identity and can open a different save entry. Copying the Lua files alone does not copy presets.

> [!NOTE]
> Editor preview runs have been observed to lose presets between test launches. Check persistence through normal game launches; real engine persistence has not yet been verified in a controlled live session.

<details>
<summary>Transfer presets to another computer or mod identity</summary>

1. Close Teardown on both computers and back up their `savegame.xml` files.
2. In the source file, find the mod's entry inside `<savegame><mod>`, then its `<cdmp><presets>` section.
3. Copy the complete `<presets>...</presets>` block, including all five slots, names and format versions.
4. At the destination, install the mod, save one preset and close the game to create its save entry.
5. In a text editor, replace only that entry's `<presets>` block. For a different folder name or Workshop build, use the destination mod's entry rather than copying the source mod identifier.
6. Start the game and load the desired slot. Enable the same Workshop tool mods if their tools are needed.

There is no separate preset export file. Copying the entire `savegame.xml` also transfers game progress and other mods' data.

</details>

## How It Works

Each mode uses the official Multiplayer Classics lifecycle with a shared Custom MP configuration adapter.

The host sends one structured settings request when pressing **Start**. The server checks the host, setup state, available tools and numeric ranges, then applies the configuration and begins the official start sequence. Settings become fixed for the match.

### Loot

A single weighted pool is used at the official low, medium and high loot spawn groups. Official spawn-point generation, pickup, death drops and **20-second crate respawns** remain in place.

A zero weight excludes a tool. An empty pool produces no crates. An empty starting loadout and zero pickup ammo are supported. Internal CTF flag tools are excluded from configuration and loot.

### HUD and combat

The headshot multiplier and optional feedback are shared match settings. Hiding player names keeps CTF objectives and flag markers visible. Input hints read current keyboard bindings and retain gamepad glyphs.

## Example Setup

To create a gun-only match:

1. Choose **Deathmatch**, then a preset duration or custom time.
2. Enable only the gun in the starting loadout and set its ammo.
3. Allow only the gun in loot, give it a nonzero weight and choose its pickup ammo.
4. Keep headshot damage at 1.0×, or choose another multiplier; enable the HUD effects you want.
5. Save the configuration in a preset, rename it, then press **Start**.

These are settings to create yourself; the five preset slots are initially empty.

## Local Editor Testing

1. Enable the local mod and open a separate version-2 map in the editor.
2. Press **F5** to play, then select a Custom MP mode through **Esc → Game Modes**. **F4** returns to the editor.
3. For two/four-player local testing, select a local version-2 map in the Mod Manager and press **Play**. Its play-options dialog offers the active game modes and a **Number of Players** choice.

`info.txt` uses `version = 2`, the engine's mod format. This is separate from the internal `CDMP.VERSION`. Online sessions use the published Workshop build; local files are used for development tests.

## Project Structure

```text
Custom MP/
├── gamemodes.txt              # Mode registration and previews
├── cdmp.lua                   # Deathmatch
├── teamdeathmatch.lua         # Team Deathmatch
├── capturetheflag.lua         # Capture the Flag
├── dm_spawn.lua / tdm_spawn.lua
├── mplib/                     # Multiplayer helpers
├── scripts/
│   ├── shared/                # Configuration, tool catalog and presets
│   ├── server/                # Settings validation and combat integration
│   └── client/                # Setup menu, cards, sliders, notices and HUD
├── data/texts/                # Localized strings
├── prefab/ / vox/ / gfx/ / snd/
└── tests/test_mod.py           # Automated Lua 5.1 checks
```

Mode identifiers remain `customdeathmatchmp`, `customteamdeathmatchmp` and `customcapturetheflagmp`. The shared entry include is `scripts/shared/custom.lua`; preset storage lives in `scripts/shared/presets.lua`. Deathmatch and TDM retain their official spawn scripts; CTF uses `mplib/spawn.lua`.

## Development and Validation

The mod runs directly from its source folder; no build step is required.

Install Python and `lupa` with its Lua 5.1 runtime, and point the checks at your Teardown installation:

```powershell
python -m pip install --target "$env:TEMP\cdmp-lua-tests" lupa
$env:TEARDOWN_PATH = 'D:\SteamLibrary\steamapps\common\Teardown'
python tests\test_mod.py
```

Automated checks cover Lua syntax, includes, assets, mode initialization, host-only settings application, value validation, empty loot/loadouts, preset operations, missing tools, optional combat effects, sliders, menu geometry and pagination. Persistence is checked across mocked runtime restarts.

> [!NOTE]
> The mocked API does not prove live rendering, networking, controller navigation or engine save persistence. Those checks have not been completed in a controlled Teardown session.

Local Workshop state, including `id.txt` and `steam_description.txt`, is excluded from Git. `id.txt` links a local folder to a Workshop item.

## Bug Reports

Report issues through [GitHub Issues](https://github.com/waterflane/Custom-MP/issues). Include the selected mode, map, tool mods, relevant settings, reproduction steps and a screenshot or relevant Lua error when available. For editor issues, mention whether the launch was single-player or a two/four-player test.

## Credits and Support

- **WaterFlane** — Custom MP.
- **Tuxedo Labs** — official Multiplayer Classics scripts and assets.
- **Exorsky (babon)** — headshot multiplier idea.

Support development on [Patreon](https://patreon.com/waterflane_dev).

## License

Project code is distributed under [GNU GPL v3.0](LICENSE). Included Multiplayer Classics scripts and assets originate from the installed official Teardown mod. Gameplay integration is limited to configuration, loot and optional feedback, plus the CTF cleanup typo fix from `falg2` to `flag2`.
