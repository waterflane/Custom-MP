#version 2

#include "mplib/countdown.lua"
#include "mplib/eventlog.lua"
#include "mplib/hud.lua"
#include "mplib/teams.lua"
#include "mplib/spectate.lua"
#include "mplib/tools.lua"
#include "mplib/util.lua"
#include "mplib/stats.lua"

#include "tdm_spawn.lua"

#include "scripts/shared/custom.lua"


RESPAWN_TIME = 10.0


----- SERVER -----

-- Loot content is provided by the shared CDMP configuration.
spawnTransformTeam1 = {}
spawnTransformTeam2 = {}

function server.init()
	-- check for built-in spawn locations in the level
	spawnTransformTeam1 = utilLoadLevelPlayerSpawns(1)
	spawnTransformTeam2 = utilLoadLevelPlayerSpawns(2)

	if #spawnTransformTeam1 == 0 or #spawnTransformTeam2 == 0 then
		-- no buildt in spawn locations found. Generating 64 locations
		spawnTransformTeam1 = utilGenerateSpawnPoints(32)
		spawnTransformTeam2 = utilGenerateSpawnPoints(32, spawnTransformTeam1)
	end

	-- check for built-in tool spawn locations
	local toolSpawns = {}
	toolSpawns[1] = utilLoadLevelToolSpawns("low")
	toolSpawns[2] = utilLoadLevelToolSpawns("medium")
	toolSpawns[3] = utilLoadLevelToolSpawns("high")

	if #toolSpawns[1] + #toolSpawns[2] + #toolSpawns[3] == 0 then
		-- no buildt in spawn locations found. Generating 64 locations
		toolSpawns = utilGenerateSpawnPointLists({1.0, 0.66, 0.5})
	end

	shared.time = 5 * 60; -- Match time

	hudInit(true)
	hudAddUnstuckButton()
	statsInit()
	teamsInit(2)

	spawnInit()
	spawnSetRespawnTime(RESPAWN_TIME)
	-- what tools and ammo count player's will spawn with.
	spawnSetDefaultLoadout({{"gun", 7}, {"sledge", 0}, {"spraycan", 0}, {"extinguisher", 0}})
	spawnSetSpawnTransforms(spawnTransformTeam1, 1)
	spawnSetSpawnTransforms(spawnTransformTeam2, 2)

	-- setup 3 three sets of tool locations & loot tables (rarities: low, medium, high)
	toolsInit()
	toolsSetRespawnTime(20.0)
	toolsSetDropToolsOnDeath(true)

	countdownInit(3)
	CDMP_ServerInit("tdm", toolSpawns)
end

function server.destroy()
	toolsCleanup()
end

function server.tick(dt)
	if teamsTick(dt) then
		eventlogPostMessage({"loc@EVENT_GLHF"})

		-- Place players at initial spawn lineup
		local playerTeamsList = teamsGetPlayerTeamsList()
		local spawnIndexTeam1 = 0
		local spawnIndexTeam2 = 0
		for p in Players() do
			if playerTeamsList[p] == 1 then
				spawnIndexTeam1 = spawnIndexTeam1 + 1
				SetPlayerTransform(spawnTransformTeam1[spawnIndexTeam1], p)
			else
				spawnIndexTeam2 = spawnIndexTeam2 + 1
				SetPlayerTransform(spawnTransformTeam2[spawnIndexTeam2], p)
			end
		end

		spawnSetRespawnAtCurrentLocation(true)
		spawnRespawnAllPlayers()
	end

	if not teamsIsSetup() then
		for p in Players() do
			DisablePlayer(p)
		end
		return
	end

	for p in PlayersAdded() do
		spawnRespawnPlayer(p)
	end
	spawnTick(dt, teamsGetPlayerTeamsList())
	spawnSetRespawnAtCurrentLocation(false)

	if countdownTick(dt) then return end
	if CDMP.MatchEnded() then
		for p in Players() do
			DisablePlayerInput(p)
		end
		return
	end

	CDMP.TickMatchTime(dt)

	CDMP_CombatTick(dt)
	statsTick(teamsGetPlayerTeamsList())
	eventlogTick(dt)
	toolsTick(dt)

	for p in Players() do
		SetPlayerHurtSpeedScale(0.6, p)
	end
end


----- CLIENT -----

function client.tick(dt)
	hudTick(dt)
	SetLowHealthBlurThreshold(0.25)
	spectateTick(teamsGetLocalTeam())
	teamsSetTags()
end

function client.draw(dt)
	hudDrawTitle(dt, "loc@TDM_MOD_TITLE", countdownGetTime() > 0.4)

	if not countdownDone() then
		hudDrawGameModeHelpText("loc@TDM_HELP_TITLE", "loc@TDM_HELP_TEXT")
	end

	if not teamsIsSetup() then

		teamsDraw(dt)
		if not hudGameIsSetup() then
			CDMP_DrawSetup()
		end
		return
	end

	eventlogDraw(dt, teamsGetPlayerColorsList())

	local myTeamId = teamsGetTeamId(GetLocalPlayer())
	local otherTeamId = 1 + (myTeamId % 2)

	local matchEnded = CDMP.MatchEnded()

	if not matchEnded then
		hudDrawPlayerWorldMarkers(teamsGetTeamPlayers(myTeamId), false, 9999.0, teamsGetColor(myTeamId))
		hudDrawPlayerWorldMarkers(teamsGetTeamPlayers(otherTeamId), true, 40.0, teamsGetColor(otherTeamId))
	end

	for p in Players() do
		if teamsGetTeamId(p) == myTeamId and not IsPlayerLocal(p) and GetPlayerHealth(p) > 0 then
			local characterId = GetPlayerCharacter(p)
			local imagePath = GetString("characters."..characterId..".preview")
			AddMapMarker(p, "player", GetPlayerName(p), "loc@UI_TEXT_TEAM", true, "loc@UI_TEXT_TEAM_MEMBER", GetPlayerTransform(p).pos, teamsGetColor(myTeamId), imagePath, "hud/party-member_map-marker.png")
		end
	end

	CDMP.DrawMatchTimer(1.0 - clamp(countdownGetTime()/0.2, 0.0, 1.0))
	local teamTotals = {0, 0}
	for p in Players() do
		local otherTeamId = 1 + (teamsGetTeamId(p) % 2)
		teamTotals[otherTeamId] = teamTotals[otherTeamId] + statsGetDeaths(p)
	end

	hudDrawScore2Teams(
		teamsGetColor(myTeamId),    teamTotals[myTeamId],
		teamsGetColor(otherTeamId), teamTotals[otherTeamId],
		1.0 - clamp(countdownGetTime()/0.2, 0.0, 1.0))

	if countdownDraw(dt) then return end

	hudDrawDamageIndicators(dt)
	CDMP_DrawCombat()

	-- setup and draw scoreboard
	local groups =
	{
		{name=teamsGetName(1), color=teamsGetColor(1), outline=matchEnded, rows={}},
		{name=teamsGetName(2), color=teamsGetColor(2), outline=matchEnded, rows={}}
	}
	for p in Players() do
		local teamId = teamsGetTeamId(p)
		local rows = groups[teamId].rows
		rows[#rows+1] = { player=p, columns = {statsGetKills(p), statsGetDeaths(p)}}
	end
	table.sort(groups[1].rows, function (a, b) return a.columns[1] > b.columns[1] end)
	table.sort(groups[2].rows, function (a, b) return a.columns[1] > b.columns[1] end)

	hudDrawScoreboard(hudIsScoreboardRequested() and not matchEnded, "", {{name="loc@UI_TEXT_KILLS",  align="center"}, {name="loc@UI_TEXT_DEATHS",  align="center"}}, {groups[myTeamId], groups[otherTeamId]})

	if matchEnded then
		if teamTotals[1] < teamTotals[2] then
			local tmp = groups[1]
			groups[1] = groups[2]
			groups[2] = tmp
		end
		if teamTotals[1] == teamTotals[2] then
			groups[1].dim = false
			groups[2].dim = false
			hudDrawResults("loc@UI_TEXT_TIE", {0.0,0.0,0.0,0.75}, "loc@TDM_RESULTS_TITLE", {{name="loc@UI_TEXT_KILLS",  align="center"} , {name="loc@UI_TEXT_DEATHS",  align="center"}}, groups)
		else
			groups[1].dim = false
			groups[1].name = "loc@UI_TEXT_WINS," .. groups[1].name
			groups[2].dim = true

			local rgb = groups[1].color

			hudDrawResults(groups[1].name, {rgb[1], rgb[2], rgb[3], 0.75}, "loc@TDM_RESULTS_TITLE", {{name="loc@UI_TEXT_KILLS",  align="center"} , {name="loc@UI_TEXT_DEATHS",  align="center"}}, groups)
		end
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
