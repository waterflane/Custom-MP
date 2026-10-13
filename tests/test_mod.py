"""Lua 5.1 tests with a mocked Teardown API; no game session is started."""
import os
from pathlib import Path
import re
import sys
import tempfile
import unittest

try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    sys.path.insert(0, str(Path(tempfile.gettempdir()) / "cdmp-lua-tests"))
    from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(os.environ.get("TEARDOWN_PATH", r"D:\SteamLibrary\steamapps\common\Teardown"))

MOCK = r'''
server, client, shared = {}, {}, {_hud = {gameIsSetup = false}}
registry, tiers, loadout, calls = {}, {}, {}, {respawn = 0, teams = 0, damage = 0}
health, events, pendingEvents = {[1] = 1, [2] = 1}, {}, {}
function Vec(x,y,z) return {x or 0,y or 0,z or 0} end
function VecAdd(a,b) return Vec(a[1]+b[1],a[2]+b[2],a[3]+b[3]) end
function VecSub(a,b) return Vec(a[1]-b[1],a[2]-b[2],a[3]-b[3]) end
function VecLength(v) return math.sqrt(v[1]^2+v[2]^2+v[3]^2) end
function Quat() return {0,0,0,1} end
function Transform(pos,rot) return {pos=pos or Vec(),rot=rot or Quat()} end
function GetPlayerEyeTransform() return Transform() end
function TransformToParentPoint(t,p) return VecAdd(t.pos,p) end
function HasKey(key) return registry[key] ~= nil end
function checkKey(key) assert(key:match('^[a-z0-9_.%-]+$'), 'Invalid registry key: '..key) end
function SetString(key,value) checkKey(key); registry[key] = tostring(value) end
function SetInt(key,value) checkKey(key); registry[key] = value end
function SetFloat(key,value) checkKey(key); registry[key] = value end
function SetBool(key,value) checkKey(key); registry[key] = value end
function GetString(key) return registry[key] == nil and '' or tostring(registry[key]) end
function GetInt(key) return tonumber(registry[key]) or 0 end
GetFloat = GetInt
function GetBool(key) return registry[key] == true end
function ClearKey(prefix)
    for key in pairs(registry) do
        if key == prefix or key:sub(1,#prefix+1) == prefix..'.' then registry[key] = nil end
    end
end
function ListKeys(prefix)
    local keys, seen = {}, {}
    for key in pairs(registry) do
        if key:sub(1,#prefix+1) == prefix..'.' then
            local child = key:sub(#prefix+2):match('^[^.]+')
            if child and not seen[child] then keys[#keys+1] = child; seen[child] = true end
        end
    end
    table.sort(keys)
    return keys
end
for _, id in ipairs({'gun','sledge','spraycan','extinguisher','shotgun','rocket','a-b','a_b','flag1','flag2'}) do
    SetString('game.tool.'..id..'.name',id)
end
function IsPlayerHost(id) return id == 1 end
function GetLocalPlayer() return 1 end
function IsPlayerValid(id) return id == 1 or id == 2 end
function GetPlayerHealth(id) return health[id] end
function teamsGetTeamId(id) return id end
function hudGameIsSetup() return shared._hud.gameIsSetup end
function toolsCleanup() tiers = {} end
function toolsAddLootTier(transforms, loot) tiers[#tiers+1] = {transforms=transforms, loot=loot} end
function spawnSetDefaultLoadout(value) loadout = value end
function spawnRespawnAllPlayers() calls.respawn = calls.respawn + 1 end
function teamsStart() calls.teams = calls.teams + 1 end
function GetEventCount(name) return #(events[name] or {}) end
function GetEvent(name,index) return unpack(events[name][index],1,6) end
function ApplyPlayerDamage(victim,damage,cause,attacker)
    calls.damage = calls.damage + 1
    pendingEvents[#pendingEvents+1] = {victim,health[victim],math.max(0,health[victim]-damage),attacker}
    health[victim] = math.max(0,health[victim]-damage)
end
function countdownDone() return true end
function GetTranslatedStringByKey(key) return key end
function ServerCall(name,player,settings) calls.rpc = {name,player,settings} end
'''

UI_MOCK = r'''
FONT_BOLD, FONT_MEDIUM, FONT_SIZE_30, FONT_SIZE_22, FONT_SIZE_18, FONT_SCALE = 'bold.ttf','regular.ttf',36.9,27,22,1.23
COLOR_WHITE, COLOR_YELLOW = {1,1,1,1}, {1,1,0.5,1}
uiStack, uiDisabled, uiClicks, uiGroups, uiSteppers = {}, false, {}, {}, {}
function UiPush() uiStack[#uiStack+1] = uiDisabled end
function UiPop() assert(#uiStack>0); uiDisabled=table.remove(uiStack) end
function UiDisableInput() uiDisabled=true end
function UiWidth() return 1280 end
function UiHeight() return 720 end
function UiCenter() return UiWidth()/2 end
function UiMiddle() return UiHeight()/2 end
function UiTranslate() end
function UiAlign() end
function UiColor() end
function UiFont() end
function UiText() end
function UiRect() end
function UiMakeInteractive() end
function UiRoundedRectOutline() end
function UiRoundedRect() end
function UiNavComponent() return 'slider' end
function navigationAddItem() end
function navigationMakeLastItemFocused() end
function UiReceivesInput() return not uiDisabled end
function UiIsComponentInFocus() return false end
function UiIsMouseInRect() return false end
function UiNavSkipUpdate() end
function UiIgnoreNavigation() end
function UiSlider(path,axis,current) return current,false end
function UiTextDisableWildcards() end
function InputPressed() return false end
function InputDown() return false end
function InputClear() end
function InputLastPressedKey() return "" end
function uiDrawPanel() end
function uiDrawTextPanel() end
function uiTextConstrained(text) return true,text end
function navigationBeginGroup(name) UiPush(); uiGroups[#uiGroups+1] = name end
function navigationEndGroup() UiPop() end
function uiDrawSecondaryButton(label,width,disabled)
    if not disabled and not uiDisabled and uiClicks[label] then uiClicks[label]=nil; return true end
    return false
end
uiDrawPrimaryButton=uiDrawSecondaryButton
function _drawSettingsItemStepper(key,label,info,options,width)
    assert(HasKey(key..'.index'))
    uiSteppers[#uiSteppers+1] = key
    SetString(key,options[GetInt(key..'.index')].value)
end
'''


def stripped(path):
    return re.sub(r"^#(?:include|version).*?$", "", path.read_text(encoding="utf-8"), flags=re.M)


def expand(path, seen=None):
    """Resolve Teardown includes relative to the script, mod root, then game data."""
    seen = set() if seen is None else seen
    path = path.resolve()
    if path in seen:
        return ""
    seen.add(path)
    lines = []
    for line in path.read_text(encoding="utf-8").splitlines():
        include = re.match(r'^#include "([^"]+)"', line)
        if include:
            candidates = [path.parent / include[1], ROOT / include[1], GAME / "data" / include[1]]
            target = next((p for p in candidates if p.is_file()), None)
            if target is None:
                raise AssertionError(f"Missing include {include[1]} from {path}")
            lines.append(expand(target, seen))
        elif not line.startswith("#version"):
            lines.append(line)
    return "\n".join(lines)


class ModTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(MOCK)
        for filename in (
            "shared/config.lua", "shared/world.lua", "shared/presets.lua",
            "server/settings.lua", "server/combat.lua", "client/gui.lua",
            "client/gui_widgets.lua", "client/gui_settings.lua", "client/gui_combat.lua",
        ):
            self.lua.execute(stripped(ROOT / "scripts" / filename))
        self.lua.execute('CDMP_ServerInit("dm", {{Transform()}, {Transform()}, {Transform()}})')

    def check(self, code):
        self.lua.execute(code)

    def test_vanilla_defaults_and_catalog(self):
        self.check('''
            local s = shared.cdmp.settings
            assert(s.duration == 300 and s.headshot == 1)
            assert(s.hud.nameplates and not s.hud.hitMarker and not s.hud.killMarker and not s.hud.damageNumbers)
            assert(s.tools.gun.startEnabled and s.tools.gun.ammo == 7)
            assert(not server.cdmpToolById.flag1 and not server.cdmpToolById.flag2)
            assert(not server.cdmpToolById.rifle) -- unavailable vanilla tool
            assert(server.cdmpToolById['a-b'] and server.cdmpToolById.a_b)
            assert(loadout[1][1] == 'gun' and #loadout == 4)
            assert(CDMP.DefaultSettings('ctf',server.cdmpTools).duration == 480)
        ''')

    def test_validation(self):
        self.check('''
            local s = CDMP.ValidateSettings({duration=99,headshot=99,hud={nameplates='no',hitMarker=true},
                tools={gun={ammo=999,lootWeight=-1,pickupAmount=0,startEnabled=false,canLoot=true},
                shotgun={ammo=0/0,pickupAmount=math.huge},flag1={startEnabled=true},unknown={canLoot=true}}},'dm',server.cdmpTools)
            assert(s.duration == 300 and s.headshot == 1)
            assert(s.hud.nameplates and s.hud.hitMarker)
            assert(s.tools.gun.ammo == 100 and s.tools.gun.lootWeight == 0 and s.tools.gun.pickupAmount == 0)
            assert(s.tools.shotgun.ammo == 0 and s.tools.shotgun.pickupAmount == 0)
            assert(not s.tools.gun.startEnabled and not s.tools.flag1 and not s.tools.unknown)
            assert(#CDMP.BuildLoadout(CDMP.ValidateSettings(nil,'dm',server.cdmpTools),server.cdmpTools) == 4)
            assert(CDMP.ValidateSettings({headshot=1.149999976},'dm',server.cdmpTools).headshot == 1.15)
            assert(CDMP.ValidateSettings({duration={},headshot=math.huge},'dm',server.cdmpTools).headshot == 1)
        ''')

    def test_five_presets_roundtrip_overwrite_delete(self):
        self.check('''
            for slot=1,5 do
                assert(not CDMP.PresetExists(slot) and CDMP.LoadPreset(slot) == nil)
                local s = CDMP.Copy(shared.cdmp.settings)
                s.duration = 480; s.headshot = 2; s.hud.damageNumbers = true
                s.tools.gun.ammo = slot
                s.tools['a-b'].ammo = 41; s.tools.a_b.ammo = 42
                assert(CDMP.SavePreset(slot,s))
                local loaded = CDMP.LoadPreset(slot)
                assert(loaded.tools.gun.ammo == slot and loaded.duration == 480 and loaded.headshot == 2)
                assert(loaded.hud.damageNumbers and loaded.tools['a-b'].ammo == 41 and loaded.tools.a_b.ammo == 42)
                local prepared = CDMP.PreparePreset(loaded,'tdm',server.cdmpTools)
                assert(prepared.duration == 480 and prepared.tools.gun.ammo == slot)
            end
            CDMP.SavePreset(1,shared.cdmp.settings)
            assert(CDMP.LoadPreset(1).tools.gun.ammo == 7)
            local draft = CDMP.Copy(shared.cdmp.settings)
            CDMP.DeletePreset(1)
            assert(not CDMP.PresetExists(1) and CDMP.PresetExists(2) and draft.tools.gun.ammo == 7)
            assert(not CDMP.SavePreset(0,draft) and not CDMP.SavePreset(6,draft) and not CDMP.DeletePreset(1.5))
        ''')

    def test_persistence_across_runtime_restart(self):
        self.check("CDMP.RenamePreset(3, 'Saved name'); CDMP.SavePreset(3, shared.cdmp.settings)")
        data = dict(self.lua.globals().registry.items())
        other = LuaRuntime()
        other.execute(MOCK)
        other.globals().registry = other.table_from(data)
        for filename in ("config.lua", "presets.lua"):
            other.execute(stripped(ROOT / "scripts/shared" / filename))
        other.execute("assert(CDMP.LoadPreset(3).tools.gun.ammo == 7 and CDMP.GetPresetName(3) == 'Saved name')")

    def test_missing_tools_do_not_change_saved_slot(self):
        self.check('''
            local saved = CDMP.Copy(shared.cdmp.settings)
            saved.tools.workshop_missing = {startEnabled=true,ammo=83,canLoot=true,lootWeight=5,pickupAmount=70}
            CDMP.SavePreset(1,saved)
            local prepared, missing = CDMP.PreparePreset(CDMP.LoadPreset(1),'ctf',server.cdmpTools)
            assert(#missing == 1 and missing[1] == 'workshop_missing')
            assert(not prepared.tools.workshop_missing and CDMP.LoadPreset(1).tools.workshop_missing.ammo == 83)
            SetInt('savegame.mod.cdmp.presets.1.version',99)
            assert(not CDMP.PresetExists(1) and CDMP.LoadPreset(1) == nil)
        ''')

    def test_atomic_host_start_and_lock(self):
        self.check('''
            server.settingsApplyAndStart(2,shared.cdmp.settings)
            server.settingsApplyAndStart('invalid',shared.cdmp.settings)
            server.settingsApplyAndStart(1,nil)
            server.hudPlayPressed = function() end
            server.hudPlayPressed()
            assert(not hudGameIsSetup() and #tiers == 0 and not server.cdmpStarted)
            local raw = CDMP.Copy(shared.cdmp.settings)
            raw.duration=600; raw.tools.gun.ammo=42
            server.settingsApplyAndStart(1,raw)
            assert(hudGameIsSetup() and shared.time == 600 and calls.respawn == 1 and calls.teams == 0)
            assert(loadout[1][2] == 42 and #tiers == 3)
            raw.tools.gun.ammo=99
            assert(shared.cdmp.settings.tools.gun.ammo == 42)
            server.settingsApplyAndStart(1,raw)
            assert(#tiers == 3 and calls.respawn == 1 and loadout[1][2] == 42)
        ''')

    def test_empty_loadout_loot_and_zero_pickup(self):
        self.check('''
            local s = CDMP.Copy(shared.cdmp.settings)
            for _, item in pairs(s.tools) do item.startEnabled=false; item.lootWeight=0 end
            server.settingsApplyAndStart(1,s)
            assert(#loadout == 0 and #tiers == 0)
            s.tools.gun.canLoot=true; s.tools.gun.lootWeight=1; s.tools.gun.pickupAmount=0
            assert(CDMP.BuildLoot(s,server.cdmpTools)[1].amount == 0)
        ''')

    def test_team_modes_start_vanilla_teams(self):
        self.check('''
            for _, mode in ipairs({'tdm','ctf'}) do
                shared._hud.gameIsSetup=false
                CDMP_ServerInit(mode,{{Transform()}})
                server.settingsApplyAndStart(1,shared.cdmp.settings)
                assert(shared.time == (mode == 'ctf' and 480 or 300))
            end
            assert(calls.teams == 2 and calls.respawn == 0)
        ''')

    def test_draft_and_start_rpc(self):
        self.check('''
            CDMP_SetDraft(shared.cdmp.settings)
            local path = 'level.cdmp.draft.tools.' .. CDMP.ToolStorageId('a-b') .. '.ammo'
            SetString(path,37)
            local draft = CDMP_ReadDraft()
            assert(draft.tools['a-b'].ammo == 37 and draft.tools.a_b.ammo == 10)
            assert(shared.cdmp.settings.tools['a-b'].ammo == 10)
            CDMP.SavePreset(1,draft)
            CDMP_SetDraft(CDMP.PreparePreset(CDMP.LoadPreset(1),'dm',server.cdmpTools))
            assert(CDMP_ReadDraft().tools['a-b'].ammo == 37 and not hudGameIsSetup())
        ''')

    def test_setup_ui_presets_and_single_start_rpc(self):
        self.check(UI_MOCK)
        self.check('''
            client.cdmpSettingsVisible=true; client.cdmpSection=4
            uiClicks.CDMP_SAVE=true
            CDMP_DrawSetup()
            assert(CDMP.PresetExists(1) and #uiStack == 0)
            SetString('level.cdmp.draft.duration',600)
            uiClicks.CDMP_LOAD=true
            CDMP_DrawSetup()
            assert(CDMP_ReadDraft().duration == 300 and not calls.rpc)
            uiClicks.CDMP_DELETE=true
            CDMP_DrawSetup()
            assert(not CDMP.PresetExists(1) and CDMP_ReadDraft().duration == 300)
            uiClicks['loc@UI_BUTTON_START']=true
            CDMP_DrawSetup()
            assert(not calls.rpc) -- modal blocks the background start button
            client.cdmpSettingsVisible=false
            CDMP_DrawSetup()
            assert(calls.rpc[1] == 'server.settingsApplyAndStart' and calls.rpc[2] == 1)
            assert(calls.rpc[3].duration == 300 and client.cdmpStarting and #uiStack == 0)
        ''')

    def test_short_window_tool_and_preset_pagination(self):
        self.check(UI_MOCK)
        self.check('''
            UiHeight=function() return 480 end
            client.cdmpSettingsVisible=true; client.cdmpSection=2
            CDMP_DrawSetup()
            assert(#uiStack == 0)
            client.cdmpSelectedTool=1
            for page=1,2 do client.cdmpPage=page; CDMP_DrawSetup() end
            client.cdmpSelectedTool=nil; client.cdmpSection=4
            for page=1,2 do client.cdmpPage=page; CDMP_DrawSetup() end
            assert(#uiStack == 0 and client.cdmpPage == 2)
        ''')

    def test_preset_names_survive_save_clear_and_reload(self):
        self.check("""
            assert(CDMP.RenamePreset(1,'  Снайперы  '))
            assert(CDMP.GetPresetName(1) == 'Снайперы' and not CDMP.PresetExists(1))
            CDMP.SavePreset(1,shared.cdmp.settings)
            CDMP.DeletePreset(1)
            assert(CDMP.GetPresetName(1) == 'Снайперы' and not CDMP.PresetExists(1))
            CDMP.SavePreset(1,shared.cdmp.settings)
            assert(CDMP.GetPresetName(1) == 'Снайперы')
            CDMP.RenamePreset(2,'Снайперы')
            assert(CDMP.GetPresetName(2) == CDMP.GetPresetName(1))
            CDMP.RenamePreset(3,string.rep('я',40))
            assert(CDMP.GetPresetName(3) == string.rep('я',32))
            CDMP.RenamePreset(3,'  ')
            assert(CDMP.GetPresetName(3) == 'CDMP_PRESET 3')
            assert(not CDMP.RenamePreset(6,'bad'))
        """)

    def test_preset_dropdown_rename_confirm_and_cancel(self):
        self.check(UI_MOCK)
        self.check("""
            client.cdmpSettingsVisible=true; client.cdmpSection=4
            CDMP_DrawSetup()
            client.cdmpModal='list'
            uiClicks['2. CDMP_PRESET 2 — CDMP_EMPTY']=true
            CDMP_DrawSetup()
            assert(client.cdmpSelectedPreset == 2 and not client.cdmpModal and not calls.rpc)
            CDMP.OpenPresetRename(2)
            client.cdmpNameLanguage='ru'
            CDMP.PresetNameKey('q'); CDMP.PresetNameKey('w')
            assert(client.cdmpNameBuffer == 'йц')
            CDMP.BackspacePresetName()
            assert(client.cdmpNameBuffer == 'й')
            CDMP.ClosePresetModal()
            assert(CDMP.GetPresetName(2) == 'CDMP_PRESET 2')
            CDMP.OpenPresetRename(2); client.cdmpNameBuffer='Мой пресет'; client.cdmpNameSelectAll=false
            uiClicks.CDMP_CONFIRM=true
            CDMP_DrawSetup()
            assert(CDMP.GetPresetName(2) == 'Мой пресет' and not client.cdmpModal and #uiStack == 0)
        """)

    def test_tool_slider_rounding_focus_and_disabled_input(self):
        self.check(UI_MOCK)
        self.check("""
            local field={key='level.cdmp.testslider',label='Ammo',min=0,max=100,step=1,default=0}
            assert(CDMP.RoundSlider(49.6,0,100,1) == 50)
            assert(CDMP.RoundSlider(-5,0,100,1) == 0 and CDMP.RoundSlider(900,0,100,1) == 100)
            assert(CDMP.RoundSlider(0/0,0,100,1) == 0)
            function UiSlider(path,axis,current,min,max) return max*0.376,false end
            assert(CDMP_DrawSlider(field,700) == 38 and GetInt(field.key) == 38)
            function UiSlider(path,axis,current) return current,false end
            function UiIsComponentInFocus() return true end
            function InputPressed(key) return key == 'menu_right' end
            assert(CDMP_DrawSlider(field,700) == 39)
            uiDisabled=true
            assert(CDMP_DrawSlider(field,700) == 39)
            uiDisabled=false
            field.max=10; SetInt(field.key,10)
            assert(CDMP_DrawSlider(field,700) == 10 and #uiStack == 0)
        """)

    def test_tool_sliders_do_not_restore_stale_stepper_index(self):
        self.check(UI_MOCK)
        self.check("""
            local path='level.cdmp.draft.tools.'..CDMP.ToolStorageId('gun')..'.ammo'
            SetInt(path..'.index',100)
            CDMP_SetDraft(shared.cdmp.settings)
            assert(not HasKey(path..'.index') and GetInt(path) == 7)
            SetInt(path,63)
            CDMP.SavePreset(1,CDMP_ReadDraft())
            CDMP_SetDraft(CDMP.PreparePreset(CDMP.LoadPreset(1),'dm',server.cdmpTools))
            assert(GetInt(path) == 63 and CDMP_ReadDraft().tools.gun.ammo == 63)
            client.cdmpSettingsVisible=true; client.cdmpSection=2; client.cdmpSelectedTool=4
            CDMP_DrawSetup()
            assert(GetInt(path) == 63)
            CDMP_SetDraft(CDMP.DefaultSettings('dm',server.cdmpTools))
            assert(GetInt(path) == 7)
        """)

    def test_combat_defaults_and_optional_feedback(self):
        self.check('''
            health[2]=0.8
            events.playerhurt={{2,1,0.8,1,Vec(0,0.18,0)}}
            CDMP_CombatTick(0.01)
            assert(calls.damage == 0 and #shared.cdmp.hitEvents == 0)
            shared.cdmp.settings.hud.hitMarker=true
            CDMP_CombatTick(0.01)
            assert(calls.damage == 0 and #shared.cdmp.hitEvents == 1)
            assert(math.abs(shared.cdmp.hitEvents[1].damage - 0.2) < 0.001)
            events.playerhurt={}; events.playerdied={{2,1}}
            shared.cdmp.settings.hud.killMarker=true
            CDMP_CombatTick(0.01)
            assert(shared.cdmp.hitEvents[2].kind == 'kill')
        ''')

    def test_headshot_no_recursive_bonus_or_double_marker(self):
        self.check('''
            shared.cdmp.settings.headshot=2
            shared.cdmp.settings.hud.hitMarker=true
            health[2]=0.8
            events.playerhurt={{2,1,0.8,1,Vec(0,0.18,0)}}
            CDMP_CombatTick(0.01)
            assert(calls.damage == 1 and math.abs(health[2]-0.6) < 0.001)
            assert(#shared.cdmp.hitEvents == 1 and shared.cdmp.hitEvents[1].headshot)
            events.playerhurt=pendingEvents
            CDMP_CombatTick(0.01)
            assert(calls.damage == 1 and #shared.cdmp.hitEvents == 1)
        ''')

    def test_combat_ignores_friendlies_suicides_and_lethal_base_hit(self):
        self.check('''
            shared.cdmp.settings.headshot=2
            server.cdmpMode='tdm'
            teamsGetTeamId=function() return 1 end
            events.playerhurt={{2,1,0.8,1,Vec(0,0.18,0)},{1,1,0.8,1,Vec(0,0.18,0)}}
            CDMP_CombatTick(0.01)
            assert(calls.damage == 0)
            server.cdmpMode='dm'
            events.playerhurt={{2,0.2,0,1,Vec(0,0.18,0)}}
            CDMP_CombatTick(0.01)
            assert(calls.damage == 0)
        ''')


class InputHintTests(unittest.TestCase):
    def test_public_key_bindings_and_fallbacks(self):
        lua = LuaRuntime()
        lua.execute(MOCK)
        lua.execute(UI_MOCK)
        lua.execute(stripped(ROOT / "mplib/inputactions.lua"))
        lua.execute(r'''
            internalCalls, measured = 0, {}
            function GetKeyByAction() internalCalls=internalCalls+1; error('engine-only API') end
            UI_DEVICE_GAMEPAD=1
            function LastInputDevice() return 0 end
            function UiGetTextSize(text) measured[#measured+1]=text; return #text*10,20,0,0 end
            SetString('options.input.keymap.interact','K')
            inputActionsMeasureInline('interact')
            assert(measured[#measured] == 'K' and internalCalls == 0)
            inputActionsMeasureInline('unboundaction')
            assert(measured[#measured] == 'Unboundaction')
            SetString('options.input.keymap.interact','space')
            inputActionsMeasureInline('interact')
            assert(measured[#measured]:find('space.png',1,true))
            inputActionsMeasureInline('lmb')
            assert(measured[#measured]:find('lmb.png',1,true))
            function LastInputDevice() return UI_DEVICE_GAMEPAD end
            inputActionsMeasureInline('interact')
            assert(measured[#measured]:find('player:interact',1,true) and internalCalls == 0)
        ''')


class SourceTests(unittest.TestCase):
    def test_multiplayer_metadata_version(self):
        # info.txt version is the engine format, not the CDMP release number.
        info = (ROOT / "info.txt").read_text(encoding="utf-8")
        self.assertRegex(info, r"(?m)^version\s*=\s*2\s*$")

    def test_full_modes_initialize_with_official_spawn_systems(self):
        for filename, mode in (("cdmp.lua", "dm"), ("teamdeathmatch.lua", "tdm"), ("capturetheflag.lua", "ctf")):
            with self.subTest(mode=mode):
                lua = LuaRuntime()
                lua.execute(MOCK)
                lua.execute(expand(ROOT / filename))
                lua.execute('''
                    function GetAllPlayers() return {1,2} end
                    function LoadSound() return 1 end
                    function FindLocation() return 0 end
                    function setupToolsUpgradedFully() end
                    function _initiateToolPickupData() end
                    function utilLoadLevelPlayerSpawns() return {Transform(),Transform()} end
                    function utilLoadLevelToolSpawns() return {Transform()} end
                    function spawnBases()
                        shared.bases={101,102}
                        shared.flags={{body=103},{body=104}}
                    end
                    function RegisterTool(id) SetString('game.tool.'..id..'.name',id) end
                    server.init()
                    assert(not server.cdmpStarted and not hudGameIsSetup())
                    assert(#_toolState.lootTiers == 0 and _toolState.respawnTime == 20)
                    server.hudPlayPressed()
                    assert(not hudGameIsSetup())
                    server.settingsApplyAndStart(1,shared.cdmp.settings)
                    assert(server.cdmpStarted and hudGameIsSetup() and #_toolState.lootTiers == 3)
                    assert(_spawnState.defaultLoadout[1][1] == 'gun' and _spawnState.defaultLoadout[1][2] == 7)
                ''')
                self.assertEqual(lua.eval("_spawnState.respawnTime"), 3 if mode == "ctf" else 10)
                if mode == "ctf":
                    lua.execute("assert(_toolState.notDroppableTools.flag1 and _toolState.notDroppableTools.flag2)")

    def test_lua51_syntax(self):
        lua = LuaRuntime()
        compile_lua = lua.eval('function(s,name) local f,e=loadstring(s,name); assert(f,e) end')
        for path in ROOT.rglob("*.lua"):
            with self.subTest(path=path.relative_to(ROOT)):
                compile_lua(stripped(path), "@" + path.as_posix())

    def test_all_mode_include_graphs_compile(self):
        self.assertTrue(GAME.is_dir(), "Set TEARDOWN_PATH to the installed game directory")
        lua = LuaRuntime()
        compile_lua = lua.eval('function(s,name) local f,e=loadstring(s,name); assert(f,e) end')
        for filename in ("cdmp.lua", "teamdeathmatch.lua", "capturetheflag.lua"):
            with self.subTest(mode=filename):
                compile_lua(expand(ROOT / filename), "@" + filename)

    def test_static_mod_assets_and_localization(self):
        for path in list(ROOT.rglob("*.lua")) + list(ROOT.rglob("*.xml")):
            text = path.read_text(encoding="utf-8")
            for asset in re.findall(r'["\']MOD/([^"\']+\.(?:xml|vox|png|ogg))["\']', text):
                with self.subTest(asset=asset):
                    self.assertTrue((ROOT / asset).is_file(), f"Missing MOD/{asset} in {path}")
        keys = set(re.findall(r'CDMP.Text\("([A-Z_]+)"\)', (ROOT / "scripts/client/gui_settings.lua").read_text(encoding="utf-8")))
        for language in ("english", "russian"):
            text = (ROOT / f"data/texts/strings_{language}.str").read_text(encoding="utf-8")
            for key in keys:
                self.assertRegex(text, rf'(?m)^CDMP_{key}\s+".+"$')


if __name__ == "__main__":
    unittest.main(verbosity=2)
