#version 2
#include "script/include/common.lua"
#include "mplib/mp.lua"
#include "script/include/player.lua"

#include "script/toolanimation.lua"

#include "scripts/shared/custom.lua"

RESPAWN_TIME = 3.0

----- SERVER -----

-- Loot content is provided by the shared CDMP configuration.
spawnTransformTeam1 = {}
spawnTransformTeam2 = {}

flagToBase = Vec(0,1,0.5)
markerToBase = Vec(0,0.9,0)
markerToFlag = Vec(0,1.6,0)

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

	shared.time = 8 * 60;
	statsInit()
	teamsInit(2)
	teamsSetColors({{0.769, 0.286, 0.663}, {0.2, 0.596, 0.655}})
	teamsSetNames({"Team A", "Team B"})
	hudInit(true)
	hudAddUnstuckButton()

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
	toolsPreventToolDrop("flag1")
	toolsPreventToolDrop("flag2")

	spawnBases()

	-- register flag tools after adding mod tools to loot tables
	RegisterTool("flag1", "loc@CTF_TOOL_NAME_FLAG", "MOD/prefab/flag1_tool.xml")
	RegisterTool("flag2", "loc@CTF_TOOL_NAME_FLAG", "MOD/prefab/flag2_tool.xml")
	countdownInit(3)
	CDMP_ServerInit("ctf", toolSpawns)
end

function server.destroy()

	for i = 1, #shared.flags do
		if shared.flags[i].body ~= nil then
			Delete(shared.flags[i].body)
		end

		Delete(shared.bases[i])
	end

	shared.score[1] = 0
	shared.score[2] = 0
	for i = 1, #shared.playerScore do
		shared.playerScore[i] = 0
	end
	toolsCleanup()

	for p in Players() do
		SetToolEnabled("flag1", false, p)
		SetToolEnabled("flag2", false, p)
	end
end

shared.flags = {{body = 0, atBase = true, carriedByPlayer = nil, resetting = false}, {body = 0, atBase = true, carriedByPlayer = nil, resetting = false}}
shared.bases = {}

baseLocalPositions = {}

loc1 = nil
loc2 = nil

shared.score = {}
shared.score[1] = 0
shared.score[2] = 0

shared.playerScore = {}

server.toolBeforeFlag = {}
server.flagTools = {{players = {}}, {players = {}}}
server.flagState = {{reset = false, resetTimer = 0, timeSinceDrop = 0.0, lastCarriedBy = nil}, {reset = false, resetTimer = 0, timeSinceDrop = 0.0, lastCarriedBy = nil}}

function spawnBases()

	loc1 = utilLoadLevelPoi(1)[1]
	loc2 = utilLoadLevelPoi(2)[1]

	if loc1 == nil or loc2 == nil then
		-- no built-in spawn locations found. Generating base locations
		-- print("no built-in spawn locations found. Generating base locations")
		loc1 = utilGenerateSpawnPoints(1)[1]
		loc2 = utilGenerateSpawnPoints(1)[1]
	end

	-- to make moving the trigger with the base easier the prefab has an odd centerpoint that is not on ground, add 1 meter upwards to compensate
	loc1.pos[2] = loc1.pos[2] + 1
	loc2.pos[2] = loc2.pos[2] + 1

	local s1 = Spawn("MOD/prefab/base1.xml", loc1)
	base1 = s1[1]
	flag1 = Spawn("MOD/prefab/flag1.xml", loc1)[1]

	local s2 = Spawn("MOD/prefab/base2.xml", loc2)
	base2 = s2[1]
	flag2 = Spawn("MOD/prefab/flag2.xml", loc2)[1]

	shared.flags = {{body = flag1, atBase = true, carriedByPlayer = nil}, {body = flag2, atBase = true, carriedByPlayer = nil}}
	shared.bases = {base1, base2}

	for i=1, #shared.bases do
		local base = shared.bases[i]
		local t = GetBodyTransform(base)
		local pos = t.pos

		local localPos = TransformToLocalPoint(t, pos)

		baseLocalPositions[i] = localPos
	end
end

function server.tick(dt)

	if teamsTick(dt) then
		eventlogPostMessage({"loc@EVENT_GLHF"})

		-- Place players at initial spawn lineup
		local playerTeamsList = teamsGetPlayerTeamsList()
		local spawnIndexTeam1 = 0
		local spawnIndexTeam2 = 0
		for p in Players() do

			shared.playerScore[p] = 0

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
		shared.playerScore[p] = 0
		eventlogPostMessage({p, "loc@EVENT_JOINED_THE_GAME"})
	end

	for p in PlayersRemoved() do
		for i = 1, #shared.flags do
			if shared.flags[i].carriedByPlayer == p then
				dropFlag(i)
			end
		end
		eventlogPostMessage({p, "loc@EVENT_LEFT_THE_GAME"})
	end

	spawnTick(dt, teamsGetPlayerTeamsList())
	spawnSetRespawnAtCurrentLocation(false)

	for i = 1, #server.flagTools do
		local toolId = "flag"..i
		local flag = shared.flags[i]
		for j = 1, #server.flagTools[i].players do
			local player = server.flagTools[i].players[j]
			if flag.carriedByPlayer ~= player and (GetPlayerTool(player) ~= toolId or not InputDown("usetool", player)) then
				removeFlagTool(i, player)
			end
		end
	end

	for i=1,#shared.flags do
		updateFlag(i, dt)
	end

	for i=1,#shared.bases do
		updateBase(i)
	end

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
	toolsTick(dt)
	eventlogTick(dt)

	for p in Players() do
		SetPlayerHurtSpeedScale(0.6, p)
	end

	for p in Players() do
		local currentTool = GetPlayerTool(p)
		if currentTool ~= "flag1" and currentTool ~= "flag2" then
			server.toolBeforeFlag[p] = currentTool
		end
	end
end

function updateFlag(index, dt)
	local flag = shared.flags[index]
	local flagState = server.flagState[index]
	local flagTeam = index

	if flagState.reset then
		flag.resetting = true
		flagState.resetTimer = flagState.resetTimer - dt
		if flagState.resetTimer <= 0 then
			local base = shared.bases[index]
			local bt = GetBodyTransform(base)
			if flag.body == nil then
				flag.body = Spawn("MOD/prefab/flag"..index..".xml", bt)[1]
			end
			flag.atBase = true
			flag.resetting = false
			flagState.reset = false
		end
		return
	end

	-- Check for score
	if not flag.atBase then

		local flagPos = Vec()
		if flag.carriedByPlayer ~= nil then
			flagPos = GetPlayerTransform(flag.carriedByPlayer).pos
		elseif flag.body ~= nil then
			flagPos = TransformToParentPoint(GetBodyTransform(flag.body), Vec(0,1,0))
		end

		local otherTeamId = 1 + (index % 2)
		if isCloseToBase(flagPos, otherTeamId) then

			--Add one point to goalTeam
			shared.score[otherTeamId] = shared.score[otherTeamId] + 1


			local playerId = flag.carriedByPlayer
			if flag.carriedByPlayer == nil then
				playerId = flagState.lastCarriedBy
			end

			local flagItem = {
                text = "loc@CTF_MARKER_FLAG_TITLE",
                icon = "MOD/gfx/flag.png",
                iconTint = teamsGetColor(flagTeam),
                iconRight = true,
            }
            eventlogPostMessage({playerId, "loc@CTF_EVENT_PLAYER_SCORED", flagItem})

			--Add one point to the player
			shared.playerScore[playerId] = shared.playerScore[playerId] + 1

			for p in Players() do
				local teamId = teamsGetTeamId(p)
				ClientCall(p, "client.teamScored", otherTeamId)
			end

			if flag.carriedByPlayer ~= nil then
				removeFlagTool(index, playerId)
			end

			resetFlag(index)
			return
		end
	end

	if flag.atBase then
		local bt = GetBodyTransform(shared.bases[index])
		bt = TransformToParentTransform(bt, Transform(flagToBase))

		SetBodyTransform(flag.body, bt)
		SetBodyVelocity(flag.body, Vec(0,0,0))

		--The flag is at it's base and is picked up by a member from the other team
		for p in Players() do
			local playerTeam = teamsGetTeamId(p)

			if isCloseToFlag(p,index) and playerTeam ~= flagTeam then
				pickUpFlag(p, index)
				flag.atBase = false

				local flagItem = {
                    text = "loc@CTF_MARKER_FLAG_TITLE",
                    icon = "MOD/gfx/flag.png",
                    iconTint = teamsGetColor(flagTeam),
                    iconRight = true,
                }
				eventlogPostMessage({p, "loc@CTF_EVENT_PLAYER_STOLE_FLAG", flagItem})
			end
		end
	elseif flag.carriedByPlayer ~= nil then

		--- Check if the player that carries the flag dies, in that case drop the flag
		local count = GetEventCount("playerdied")
		for i=1,count do
			local victim, attacker, damage, hpBefore, cause, point, impulse = GetEvent("playerdied", i)
			if victim == flag.carriedByPlayer then
				local flagItem = {
					text = "loc@CTF_MARKER_FLAG_TITLE",
					icon = "MOD/gfx/flag.png",
					iconTint = teamsGetColor(flagTeam),
					iconRight = true,
				}
				eventlogPostMessage({victim, "loc@CTF_EVENT_PLAYER_DROPPED_FLAG", flagItem})

				for p in Players() do
					if teamsGetTeamId(p) == flagTeam then
						ClientCall(p, "client.flagDropped")
					end
				end

				removeFlagTool(index, flag.carriedByPlayer)
				dropFlag(index)
			end
		end


		-- Throw out flag
		local toolId = "flag"..index
		if GetPlayerTool(flag.carriedByPlayer) == toolId then
			if GetPlayerCanUseTool(flag.carriedByPlayer) and InputPressed("usetool", flag.carriedByPlayer) then
				local flagItem = {
					text = "loc@CTF_MARKER_FLAG_TITLE",
					icon = "MOD/gfx/flag.png",
					iconTint = teamsGetColor(flagTeam),
					iconRight = true,
				}
				eventlogPostMessage({flag.carriedByPlayer, "loc@CTF_EVENT_PLAYER_DROPPED_FLAG", flagItem})

				SetToolAmmo(toolId, 0, flag.carriedByPlayer)
				-- Tool will be disabled when usetool is released
				dropFlag(index)

			end
		end

	else

		flagState.timeSinceDrop = flagState.timeSinceDrop + dt
		if flagState.timeSinceDrop > 0.5 then
			for p in Players() do
				local playerTeam = teamsGetTeamId(p)
				if isCloseToFlag(p,index) then
					if playerTeam ~= flagTeam then
						pickUpFlag(p, index)

						local flagItem = {
							text = "loc@CTF_MARKER_FLAG_TITLE",
							icon = "MOD/gfx/flag.png",
							iconTint = teamsGetColor(flagTeam),
							iconRight = true,
                        }
                        eventlogPostMessage({p, "loc@CTF_EVENT_PLAYER_RETRIEVED_FLAG", flagItem})
					else
						local flagItem = {
							text = "loc@CTF_MARKER_FLAG_TITLE",
							icon = "MOD/gfx/flag.png",
							iconTint = teamsGetColor(flagTeam),
							iconRight = true,
                        }
						eventlogPostMessage({p, "loc@CTF_EVENT_PLAYER_RETURNED_FLAG", flagItem})

						resetFlag(index)

						for p in Players() do
							if teamsGetTeamId(p) == flagTeam then
								ClientCall(p, "client.flagReturned", GetBodyTransform(flag.body).pos, flagTeam)
							end
						end
					end
					break
				end
			end

			if flagState.timeSinceDrop > 10 then
				local flagItem = {
					text = "loc@CTF_MARKER_FLAG_TITLE",
					icon = "MOD/gfx/flag.png",
					iconTint = teamsGetColor(flagTeam),
					iconRight = true,
                }
				eventlogPostMessage({"loc@CTF_EVENT_PLAYER_RETURNED_FLAG", flagItem})

				resetFlag(index)
			end
		end
	end
end

function updateBase(index)

	local base = shared.bases[index]
	local t = GetBodyTransform(base)

	local wet, d = IsPointInWater(t.pos)

	if wet and d > .5 then
		local baseSpawns = FindLocations("base", true)
		if #baseSpawns >= 2 then
			SetBodyTransform(base, GetBodyTransform(baseSpawns[index]))
		else
			SetBodyTransform(base, utilGenerateSpawnPoints(1)[1])
		end
	end
end

function isCloseToBase(pos, index)
	local base = shared.bases[index]
	local t = GetBodyTransform(base)

	local d = VecLength(VecSub(pos, t.pos))
	return d < 1.5
end

function isCloseToFlag(playerId, index)
	local health = GetPlayerHealth(playerId)
	if health <= 0 then return end

	local up = Vec(0,1,0)
	local pt = GetPlayerTransform(playerId)
	local ft = GetBodyTransform(shared.flags[index].body)

	local v = VecSub(TransformToParentPoint(pt, Vec(0,0.5,0)), TransformToParentPoint(ft, Vec(0,1,0)))
	return VecLength(v) < 2
end

function pickUpFlag(playerId, index)
	local flag = shared.flags[index]

	--Already following another player
	if flag.carriedByPlayer ~= nil then return end

	local flagTeam = index
	for p in Players() do
		if teamsGetTeamId(p) == flagTeam then
			ClientCall(p, "client.flagStolen")
		end
	end

	--play sound on the player picking up the flag
	ClientCall(playerId, "client.flagPickedUp")

	flag.carriedByPlayer = playerId
	Delete(flag.body)
	flag.body = nil

	addFlagTool(index, playerId)
end

function dropFlag(index)

	local flag = shared.flags[index]
	if flag.carriedByPlayer == nil then return end

	local playerTransform = GetPlayerTransform(flag.carriedByPlayer)
    local offset = QuatRotateVec(playerTransform.rot, Vec(0, 1, -0.5)) -- in front
    local flagPosition = VecAdd(playerTransform.pos, offset)

	local _, startPos, endPos, direction = GetPlayerAimInfo(flagPosition, 10, flag.carriedByPlayer)
    local t = Transform(startPos, playerTransform.rot)

	flag.body = Spawn("MOD/prefab/flag"..index..".xml", t)[1]

	local speed = GetPlayerWalkingSpeed(flag.carriedByPlayer)

	SetBodyVelocity(flag.body, VecScale(direction, speed + 3))
	local axis = VecNormalize(Vec(0, GetRandomFloat(-1.0, 1.0), GetRandomFloat(0.2, 1.0)))
	SetBodyAngularVelocity(flag.body, VecScale(axis, GetRandomFloat(3, 5)))

	server.flagState[index].timeSinceDrop = 0.0
	server.flagState[index].lastCarriedBy = flag.carriedByPlayer
	flag.carriedByPlayer = nil
end

function resetFlag(index)
	server.flagState[index].reset = true
	server.flagState[index].resetTimer = 1.5
	server.flagState[index].lastCarriedBy = nil
	shared.flags[index].carriedByPlayer = nil
	Delete(shared.flags[index].body)
	shared.flags[index].body = nil
end

function addFlagTool(index, player)
	local toolId = "flag"..index
	SetToolEnabled(toolId, true, player)
	SetToolAmmo(toolId, 1, player)
	SetPlayerTool(toolId, player)

	server.flagTools[index].players[#server.flagTools[index].players+1] = player
end

function removeFlagTool(index, player)

	local toolId = "flag"..index
	if GetPlayerTool(player) == toolId then
		SetPlayerTool(server.toolBeforeFlag[player], player)
	end
	SetToolEnabled(toolId, false, player)

	for i, v in ipairs(server.flagTools[index].players) do
		if v == player then
		  table.remove(server.flagTools[index].players, i)
		  break
		end
	end
end


----- CLIENT -----

client.toolAnimators = {}

function client.init()
	scoreSound = LoadSound("snd/score-sound.ogg")
	flagStolenSound = LoadSound("snd/flag-stolen-sound.ogg")

	flagPickupSound = LoadSound("snd/other-team-takes-flag.ogg")

	dropFlagSound = LoadSound("snd/drop-flag-sound.ogg")
	flagReturnedSound = LoadSound("snd/own-flag-back.ogg")
end

function client.teamScored(teamId)
	if teamId == teamsGetTeamId(GetLocalPlayer()) then
		PlaySound(scoreSound)
	end

	local teamName = teamsGetName(teamId)
	hudShowBanner("loc@CTF_EVENT_TEAM_SCORED,"..teamName, teamsGetColor(teamId))
end

function client.flagPickedUp()
	PlaySound(flagPickupSound)
end

function client.flagStolen()
	PlaySound(flagStolenSound)
end

function client.flagReturned(pos, teamId)
	client.coloredSmokePuff(pos, teamId)
	PlaySound(flagReturnedSound)
end

function client.flagDropped()
	PlaySound(dropFlagSound)
end

function client.coloredSmokePuff(pos, teamId)
	ParticleReset()
	ParticleType("smoke")
	local color = teamsGetColor(teamId)
	ParticleColor(color[1], color[2], color[3])
	--Spawn particle at world origo with upwards velocity and a lifetime of ten seconds
	pos[2] = pos[2] + 1.2
	for i=1, 20 do
		SpawnParticle(pos, Vec(0, 1, 0), 2.0)
	end
end

function client.tickTool(player, dt)

	if client.toolAnimators[player] == nil then
		local ta = ToolAnimator()
		client.toolAnimators[player] = ta
	end
	tickToolAnimator(client.toolAnimators[player], dt, nil, player)
end

function client.tick(dt)
	CDMP.ApplyMapVisibility()
	hudTick(dt)
	for p in Players() do
		local toolId = GetPlayerTool(p)
		if toolId == "flag1" or toolId == "flag2" then
			client.tickTool(p, dt)
		end
	end
	spectateTick(teamsGetLocalTeam())
	teamsSetTags()
end

local function drawMode(dt)
	hudDrawTitle(dt, "loc@CTF_MOD_TITLE", countdownGetTime() > 0.4)
	hudDrawBanner(dt)

	if not countdownDone() then
		hudDrawGameModeHelpText("loc@CTF_HELP_TITLE", "loc@CTF_HELP_TEXT")
	end

	if not teamsIsSetup() then
		teamsDraw(dt)

		if not hudGameIsSetup() then
			CDMP_DrawSetup()
		end

		return
	end

	local myTeamId = teamsGetTeamId(GetLocalPlayer())
	local otherTeamId = 1 + (myTeamId % 2)

	local markers = {}

	markers[1 + #markers] = {
		pos=TransformToParentTransform(GetBodyTransform(shared.bases[myTeamId]), Transform(markerToBase)).pos,
		color=teamsGetColor(myTeamId),
		lineOfSightRequired = false,
		maxRange = 999999,
		icon=shared.flags[myTeamId].atBase and "MOD/gfx/flagbase.png" or "MOD/gfx/base.png",
	}

	for p in Players() do
		CDMP.AddTeammateMapMarker(p, "member")
	end

	for i = 1, #shared.flags do
		local flag = shared.flags[i]
		local color = teamsGetColor(i)

		-- BASE MARKER
		markers[1 + #markers] = {
			pos=TransformToParentTransform(GetBodyTransform(shared.bases[i]), Transform(markerToBase)).pos,
			color=color,
			lineOfSightRequired = false,
			maxRange = 999999,
			icon= flag.atBase and "MOD/gfx/flagbase.png" or "MOD/gfx/base.png",
		}

		local transform = GetBodyTransform(flag.body)
		transform = TransformToParentTransform(transform, Transform(markerToFlag))
		local pos = transform.pos

		-- FLAG NOT CARRIED
		if not flag.atBase and not flag.resetting and flag.carriedByPlayer == nil then
			markers[1 + #markers] = {
				pos=pos,
				color=color,
				lineOfSightRequired = i ~= myTeamId,
				maxRange = 40,
				icon="MOD/gfx/flag.png",
			}
		end

		if flag.atBase then
			AddMapMarker(i, "flag", GetTranslatedStringByKey("loc@CTF_MARKER_TEAMS_FLAG," .. teamsGetName(i)), "loc@UI_TEXT_OBJECTIVES", false, "", pos, color, "", "MOD/gfx/flagbase.png")
		else
			if (flag.carriedByPlayer ~= nil and teamsGetTeamId(flag.carriedByPlayer) == myTeamId) then
				AddMapMarker(i, "flag", GetTranslatedStringByKey("loc@CTF_MARKER_TEAMS_FLAG," .. teamsGetName(i)), "loc@UI_TEXT_OBJECTIVES", false, "", GetPlayerTransform(flag.carriedByPlayer).pos, color, "", "MOD/gfx/flag.png")
			end
			AddMapMarker(i, "base", GetTranslatedStringByKey("loc@CTF_MARKER_TEAMS_BASE," .. teamsGetName(i)), "loc@UI_TEXT_OBJECTIVES", false, "", GetBodyTransform(shared.bases[i]).pos, color, "", "MOD/gfx/base.png")
		end
	end

	for p in Players() do
		if not IsPlayerLocal(p) and GetPlayerHealth(p) > 0 then
			local color = teamsGetColor(teamsGetTeamId(p))
			local isTeamMate = teamsGetTeamId(p) == myTeamId
			local showPlayer = CDMP.ShowPlayerMarkers(p)
			local iconColor = nil
			local icon = nil
			local drawIconInView = true

			if shared.flags[otherTeamId].carriedByPlayer == p then
				icon = "MOD/gfx/flag.png"
				iconColor = teamsGetColor(otherTeamId)
			elseif shared.flags[myTeamId].carriedByPlayer == p then
				icon = "MOD/gfx/flag.png"
				iconColor = teamsGetColor(myTeamId)
			elseif isTeamMate then
				icon = "ui/hud/team-direction.png"
				drawIconInView = false
			end

			-- Hidden allies expose only a carried flag objective, never their
			-- name, directional teammate icon or player health bar.
			if showPlayer or icon == "MOD/gfx/flag.png" then
				markers[1 + #markers] = {
					pos=VecAdd(GetPlayerTransform(p).pos, Vec(0, 1.0, 0)),
					offset = Vec(0, 1.2, 0),
					color=color,
					lineOfSightRequired = not isTeamMate,
					maxRange = isTeamMate and 9999.0 or 40.0,
					label=showPlayer and CDMP.ShowNames() and GetPlayerName(p) or nil,
					player=showPlayer and p or nil,
					icon=icon,
					iconColor=iconColor,
					drawIconInView = drawIconInView
				}
			end
		end
	end

	local matchEnded = CDMP.MatchEnded()

	if not matchEnded then
		hudDrawWorldMarkers(markers)
	end

	eventlogDraw(dt, teamsGetPlayerColorsList())

	CDMP.DrawMatchTimer(1.0 - clamp(countdownGetTime()/0.2, 0.0, 1.0))

	hudDrawScore2Teams(
		teamsGetColor(myTeamId),    shared.score[myTeamId],
		teamsGetColor(otherTeamId), shared.score[otherTeamId],
		1.0 - clamp(countdownGetTime()/0.2, 0.0, 1.0))
	if countdownDraw(dt) then return end

	hudDrawDamageIndicators(dt)
	CDMP_DrawCombat()

	local matchEnded = CDMP.MatchEnded()

	if not matchEnded and (shared.flags[1].carriedByPlayer == GetLocalPlayer() or shared.flags[2].carriedByPlayer == GetLocalPlayer()) then
		UiPush()
		UiTranslate(UiCenter(), 102)
		local message = "loc@CTF_FLAG_CARRIED"
		uiDrawTextAndImagePanel(message, {path = "MOD/gfx/flag-2.png", color = teamsGetColor(otherTeamId)})
		UiPop()
	end

	local groups =
	{
		{name=teamsGetName(1), color=teamsGetColor(1), outline=matchEnded, rows={}},
		{name=teamsGetName(2), color=teamsGetColor(2), outline=matchEnded, rows={}}
	}

	for p in Players() do
		local teamId = teamsGetTeamId(p)
		local rows = groups[teamId].rows
		rows[#rows+1] = {player = p, columns = {shared.playerScore[p], statsGetKills(p), statsGetDeaths(p)}}
	end

	table.sort(groups[1].rows, function (a, b) return a.columns[1] > b.columns[1] end)
	table.sort(groups[2].rows, function (a, b) return a.columns[1] > b.columns[1] end)

	hudDrawScoreboard(hudIsScoreboardRequested() and not matchEnded, "", {{name="loc@UI_TEXT_SCORE",  align="center"}, {name="loc@UI_TEXT_KILLS",  align="center"}, {name="loc@UI_TEXT_DEATHS",  align="center"}}, {groups[myTeamId], groups[otherTeamId]})

	-- setup and draw scoreboard
	if matchEnded then
		if shared.score[1] < shared.score[2] then
			local tmp = groups[1]
			groups[1] = groups[2]
			groups[2] = tmp
		end

		if shared.score[1] == shared.score[2] then
			groups[1].dim = false
			groups[2].dim = false
			hudDrawResults("loc@UI_TEXT_TIE", {0.0,0.0,0.0,0.75}, "loc@CTF_RESULTS_TITLE", {{name="loc@UI_TEXT_SCORE",  align="center"}, {name="loc@UI_TEXT_KILLS",  align="center"} , {name="loc@UI_TEXT_DEATHS",  align="center"}}, groups)
		else
			groups[1].dim = false
			groups[1].name = "loc@UI_TEXT_WINS," .. groups[1].name
			groups[2].dim = true

			local rgb = groups[1].color

			hudDrawResults(groups[1].name, {rgb[1], rgb[2], rgb[3], 0.75}, "loc@CTF_RESULTS_TITLE", {{name="loc@UI_TEXT_SCORE",  align="center"}, {name="loc@UI_TEXT_KILLS",  align="center"} , {name="loc@UI_TEXT_DEATHS",  align="center"}}, groups)
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

function client.draw(dt)
	CDMP.ApplyMapVisibility()
	drawMode(dt)
	CDMP_DrawNotices()
end

function client.render(dt)
	SetLowHealthBlurThreshold(0.25)

	for p in Players() do
		local toolId = GetPlayerTool(p)
		if toolId == "flag1" or toolId == "flag2" then

			local visible = GetToolAmmo(toolId, p) > 0
			local body = GetToolBody(p)
			local shapes = GetBodyShapes(body)

			if visible then
				for i = 1, #shapes do
					RemoveTag(shapes[i], "invisible")
				end
			else
				for i = 1, #shapes do
					SetTag(shapes[i], "invisible")
				end
			end

		end
	end

	-- Do render override to keep flag stable
	for i = 1, #shared.flags do
		local flag = shared.flags[i]
		if flag.atBase then
			local bt = GetBodyTransform(shared.bases[i])
			bt = TransformToParentTransform(bt, Transform(flagToBase))
			SetBodyTransform(flag.body, bt)
		end
	end

	spectateRender(dt)
end
