#version 2

#include "script/include/common.lua"
#include "script/include/player.lua"

#include "mplib/countdown.lua"
#include "mplib/eventlog.lua"
#include "mplib/stats.lua"
#include "mplib/teams.lua"
#include "mplib/tools.lua"
#include "mplib/util.lua"
#include "mplib/spectate.lua"
#include "mplib/hud.lua"

#include "dm_spawn.lua"

#include "scripts/shared/custom.lua"


RESPAWN_TIME = 10.0 -- seconds

----- SERVER -----

-- Loot content is provided by the shared CDMP configuration.
defaultLoadout = {
	{"gun", 7},
	{"sledge", 0},
	{"spraycan", 0},
	{"extinguisher", 0}
}

function server.init()

    shared.time = 5 * 60; -- Match time

    statsInit()

	spawnInit()
	spawnSetRespawnTime(RESPAWN_TIME)
	-- what tools and ammo count player's will spawn with.
	spawnSetDefaultLoadout(defaultLoadout)

    -- check for built-in spawn locations in the level
	spawnTransform = {}
    spawnTransform = utilLoadLevelPlayerSpawns()
    if #spawnTransform == 0 then
        -- no buildt in spawn locations found. Generating 64 locations
        spawnTransform = utilGenerateSpawnPoints(64)
    end
	spawnSetSpawnTransforms(spawnTransform)
	spawnRespawnAllPlayers()

	 -- check for built-in tool spawn locations
	 local toolSpawns = {}
	 toolSpawns[1] = utilLoadLevelToolSpawns("low")
	 toolSpawns[2] = utilLoadLevelToolSpawns("medium")
	 toolSpawns[3] = utilLoadLevelToolSpawns("high")

	 if #toolSpawns[1] + #toolSpawns[2] + #toolSpawns[3] == 0 then
		 -- no buildt in spawn locations found. Generating 64 locations
		 toolSpawns = utilGenerateSpawnPointLists({1.0, 0.66, 0.5})
	 end

    toolsInit()
	toolsSetDropToolsOnDeath(true)
	toolsSetRespawnTime(20.0)

	hudInit(true)
	hudAddUnstuckButton()

	countdownInit(3)
	CDMP_ServerInit("dm", toolSpawns)
end

function server.destroy()
	toolsCleanup()
end

function server.tick(dt)

	for p in PlayersAdded() do
		spawnRespawnPlayer(p)
	end
    spawnTick(dt)

	if not hudGameIsSetup() then
		for p in Players() do
			DisablePlayer(p)
		end
		return
	end
	if countdownTick(dt) then return end

	if shared.time <= 0 then
		for p in Players() do
			DisablePlayerInput(p)
		end
		return
	end

	shared.time = shared.time - dt;

	CDMP_CombatTick(dt)
	statsTick()
	eventlogTick(dt)
	toolsTick(dt)

	for p in Players() do
		SetPlayerHurtSpeedScale(0.6, p)
	end
end


function client.tick(dt)

	hudTick(dt)
	SetLowHealthBlurThreshold(0.25)
	spectateTick({})
end

function client.draw(dt)

	hudDrawTitle(dt, "loc@DM_MOD_TITLE", countdownGetTime() > 0.4)

	if not countdownDone() then
		hudDrawGameModeHelpText("loc@DM_HELP_TITLE", "loc@DM_HELP_TEXT")
	end

	local matchEnded = shared.time <= 0
	if not matchEnded then
		hudDrawPlayerWorldMarkers(GetAllPlayers(), true, 40.0)
	end

	eventlogDraw(dt)

	if not hudGameIsSetup() then

		hudDrawPlayerList()

		CDMP_DrawSetup()

		return
	end

	hudDrawTimer(shared.time, 1.0 - clamp(countdownGetTime()/0.2, 0.0, 1.0))

	if countdownDraw(dt) then return end

	hudDrawDamageIndicators(dt)
	CDMP_DrawCombat()

	local rows = {}
	for p in Players() do
		rows[#rows+1] = { player=p, columns = {statsGetKills(p), statsGetDeaths(p)}}
	end
	table.sort(rows, function (a, b)
		if a.columns[1] ~= b.columns[1] then
			return a.columns[1] > b.columns[1] -- sort on kills
		else
			return a.columns[2] < b.columns[2] -- sort on deaths
		end
	end)

	local groups = {{name="loc@UI_TEXT_PLAYERS", color={0.52, 0.52, 0.52}, outline = matchEnded, rows = rows}}

	hudDrawScoreboard(not matchEnded and hudIsScoreboardRequested(), "", {{name="loc@UI_TEXT_KILLS",  align="center"} , {name="loc@UI_TEXT_DEATHS",  align="center"}}, groups)

	if matchEnded then
		local tie = #rows > 1 and rows[1].columns[1] == rows[2].columns[1] and rows[1].columns[2] == rows[2].columns[2]
		hudDrawResults(tie and GetTranslatedStringByKey("UI_TEXT_TIE") or GetTranslatedStringByKey("UI_TEXT_WINS,"..GetPlayerName(rows[1].player)), {0.0,0.0,0.0,0.75}, "loc@DM_RESULTS_TITLE", {{name="loc@UI_TEXT_KILLS",  align="center"} , {name="loc@UI_TEXT_DEATHS",  align="center"}}, groups)
	end
	if not matchEnded then
		spectateDraw()
		hudDrawRespawnTimer(spawnGetPlayerRespawnTimeLeft(GetLocalPlayer()))
	end
	local actions = inputActionsCreate()
	spectateAppendInputActions(actions)
	hudDrawInputActions(actions)

	hudDrawFade(dt) -- full screen fade in/out
end

function client.render(dt)
	spectateRender(dt)
end
