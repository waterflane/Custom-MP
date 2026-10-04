#version 2

--- Multiplayer Spawn System
--
-- This system manages player spawning and respawning in a multiplayer game session.
-- It supports timed respawns, custom spawn locations, team-based spawn grouping,
-- and configurable player loadouts.
--
-- Core responsibilities:
-- * Automatically respawn dead players after a delay
-- * Allow forced respawns (e.g. at round start or by host)
-- * Select spawn positions from grouped spawn transforms
-- * Apply a configurable loadout upon respawn
--
-- Execution context:
-- * This system is intended to run **server-side only**
-- * Shared state is synced using the `shared.respawnTimeLeft` table


#include "script/include/player.lua"

_spawnState = {}
shared.respawnTimeLeft = {}

--- Initializes the spawn system (server only).
--
-- Resets the internal state with defaults for dead tracking, spawn locations,
-- and respawn settings. Call this once.
function spawnInit()
    _spawnState = { deadTime={}, aliveTime={}, spawnTransformGroups={}, spawnTransformsUsage={}, defaultLoadout=nil, respawnTime = 3, respawnAtCurrentLocation=false, forceRespawn={}, time=0.0}
end

--- Sets the list of spawn transforms for one or more groups (server only).
--
-- Used to define where players can spawn based on group index (e.g. teams).
-- If no group index is provided, all spawn points are assigned to group 1.
--
-- @param spawnTransforms A list of transform tables
-- @param groupIndex (optional) Group ID (defaults to 1)
function spawnSetSpawnTransforms(spawnTransforms, groupIndex)
    _spawnState.time = 0.0

    local index = 1
    if groupIndex ~= nil then
        index = groupIndex
    end

    _spawnState.spawnTransformGroups[index] = spawnTransforms
    _spawnState.spawnTransformsUsage[index] = {}
    for i = 1, #spawnTransforms do
        _spawnState.spawnTransformsUsage[index][#_spawnState.spawnTransformsUsage[index]+1] = {lastUsedAt = 0.0, lastUsedBy = -1}
    end
end

--- Sets the respawn time in seconds (server only).
--
-- Controls how long a player must remain dead before being automatically respawned.
--
-- @param respawnTime Time in seconds before respawn
function spawnSetRespawnTime(respawnTime)
    _spawnState.respawnTime = respawnTime
end

--- Sets the default loadout for players on respawn (server only).
--
-- The loadout is a list of `{ toolName, ammoCount }` entries.
--
-- @param loadout A list of `{ tool, ammo }` tables
function spawnSetDefaultLoadout(loadout)
    _spawnState.defaultLoadout = loadout
end

--- Enables or disables respawning at the player's last known position (server only).
--
-- When enabled, players are respawned where they died instead of at a spawn point.
--
-- @param active `true` to enable, `false` to disable
function spawnSetRespawnAtCurrentLocation(active)
    _spawnState.respawnAtCurrentLocation = active
end

--- Returns the number of seconds until the player will respawn (server and client).
--
-- @param player Player id
-- @return Time in seconds until respawn (rounded up)
function spawnGetPlayerRespawnTimeLeft(player)
    if GetPlayerHealth(player) > 0 then return 0 end
    return shared.respawnTimeLeft[player]
end

--- Respawns a player at a given transform with a given loadout (server only).
--
-- If no transform is provided, the player is spawned at their default position.
-- The loadout is applied by disabling all tools, then enabling and setting
-- ammo for tools listed in the provided loadout. The first tool is set as active.
--
-- @param transform (optional) Spawn transform
-- @param loadout (optional) Loadout table `{ {toolName, ammo}, ... }`
-- @param player Player id
function spawnSpawnPlayer(transform, loadout, player)
    if transform then
        RespawnPlayerAtTransform(transform, player)
    else
        RespawnPlayer(player)
    end

    if loadout ~= nil then
        local tools = ListKeys("game.tool")
        for ti=1, #tools do
            local tool = tools[ti]
            SetToolEnabled(tool, false, player)
            SetToolAmmo(tool, 0, player)
        end

        for i=1,#loadout do
            SetToolEnabled(loadout[i][1], true, player)
            SetToolAmmo(loadout[i][1], loadout[i][2], player)
        end

        -- make the first tool in loadout the active tool
        if #loadout > 0 then
            SetPlayerTool(loadout[1][1], player)
        else
            SetPlayerTool("none", player)
        end
    end
end

--- Flags a player for forced respawn (server only).
--
-- The player will be respawned immediately during the next tick.
--
-- @param p Player id
function spawnRespawnPlayer(p)
    _spawnState.forceRespawn[p] = true
end

--- Flags all players for forced respawn (server only).
--
-- Useful for round start or global state resets.
function spawnRespawnAllPlayers()
    for p in Players() do
        spawnRespawnPlayer(p)
    end
end

--- Main update loop for the spawn system (server only).
--
-- Should be called every frame or tick. Handles:
-- * Incrementing dead time for each dead player
-- * Automatically respawning players once dead long enough
-- * Performing forced respawns
-- * Resetting internal timers and respawn flags
--
-- @param dt Time step
-- @param playerGroupList (optional) Table of player group assignments
function spawnTick(dt, playerGroupList)
    _spawnState.time = _spawnState.time + dt
    for p in Players() do

        if _spawnState.aliveTime[p] == nil then
            _spawnState.aliveTime[p] = 0.0
        end
        _spawnState.aliveTime[p] = _spawnState.aliveTime[p] + dt

        if _spawnState.aliveTime[p] < 5.0 then
            DisablePlayerDamage(p)
        end


        local doRespawn = false

        if _spawnState.forceRespawn[p] then
            doRespawn = true
        elseif _spawnState.deadTime[p] == nil then
            _spawnState.deadTime[p] = 0.0
        elseif GetPlayerHealth(p) <= 0.0 then
            _spawnState.deadTime[p] = _spawnState.deadTime[p] + dt
            _spawnState.aliveTime[p] = 0.0
            shared.respawnTimeLeft[p] = math.ceil(_spawnState.respawnTime - _spawnState.deadTime[p])

            if _spawnState.deadTime[p] > _spawnState.respawnTime then
                doRespawn = true
            end
        end

        if doRespawn then
            local t = spawnPickSpawnTransform(p, playerGroupList)
            spawnSpawnPlayer(t, _spawnState.defaultLoadout, p)
            _spawnState.deadTime[p] = 0.0
            _spawnState.aliveTime[p] = 0.0
        end

        _spawnState.forceRespawn[p] = false;
   end
end

--- Returns all current spawn transform groups (server only).
--
-- @return A table mapping group indices to spawn transform lists
function spawnGetSpawnTransformGroups()
    return _spawnState.spawnTransformGroups
end

-- Internal functions

--- Picks a spawn transform for a player (server only).
--
-- Chooses a spawn position based on the player's group index. If respawning
-- at current location is enabled, the player's current transform is returned.
--
-- @param local
-- @param playerId Player ID
-- @param playerGroupList (optional) Table mapping player IDs to group indices
-- @return A spawn transform or `nil` if none are available
function spawnPickSpawnTransform(playerId, playerGroupList)
    local groupIndex = 1

    if _spawnState.respawnAtCurrentLocation then
        return GetPlayerTransform(playerId)
    end

    if playerGroupList then
        groupIndex = playerGroupList[playerId]
    end

    if #_spawnState.spawnTransformGroups == 0 then
        return nil
    end

    local transformList = _spawnState.spawnTransformGroups[groupIndex]
    local transformUsageList = _spawnState.spawnTransformsUsage[groupIndex]

    if #transformList == 0 then
        return nil
    end

    if GetPlayerCount() <= 1 then
        local index = GetRandomInt(1, #transformList)
        transformUsageList[index].lastUsedBy = playerId
        transformUsageList[index].lastUsedAt = _spawnState.time
        return transformList[index]
    else

        local opposingPlayers = {}

        if playerGroupList == nil then
            for player in Players() do
                if player ~= playerId then
                    opposingPlayers[#opposingPlayers+1] = player
                end
            end
        else
            for player, index in pairs(playerGroupList) do
                if index ~= groupIndex then
                    opposingPlayers[#opposingPlayers+1] = player
                end
            end
        end

        local spawnTransformScore, spawnTransformScoreTotal = calculatePlayerSpawnTransformScore(playerId, transformList, transformUsageList, opposingPlayers)

        -- Weighted Random Roll
        local roll = GetRandomFloat(0.0, 1.0) * spawnTransformScoreTotal
        local running = 0

        for i = 1, #spawnTransformScore do
            running = running + spawnTransformScore[i]
            if roll <= running then
                transformUsageList[i].lastUsedBy = playerId
                transformUsageList[i].lastUsedAt = _spawnState.time
                return transformList[i]
            end
        end

        -- Fallback
        transformUsageList[1].lastUsedBy = playerId
        transformUsageList[1].lastUsedAt = _spawnState.time
        return transformList[1]
    end
end

function calculatePlayerSpawnTransformScore(player, transformList, usageList, opposingPlayers)
    local opposingPlayersTransform = {}

    for i = 1, #opposingPlayers do
        opposingPlayersTransform[#opposingPlayersTransform+1] = GetPlayerTransform(opposingPlayers[i])
    end

    local spawnTransformScore = {}
    local spawnTransformScoreTotal = 0.0
    for i = 1, #transformList do
        local t1 = transformList[i]

        local closestDistanceToOtherPlayers = 1000
        for j = 1, #opposingPlayersTransform do
            local t2 = opposingPlayersTransform[j]
            local d = VecLength(VecSub(t1.pos, t2.pos))

            if d < closestDistanceToOtherPlayers then
                closestDistanceToOtherPlayers = d
            end
        end

        local timeSinceLastUsed = _spawnState.time - usageList[i].lastUsedAt

        local score = 0.0
        score = score + (closestDistanceToOtherPlayers/100.0) * 0.7
        score = score + math.min(timeSinceLastUsed/60.0) * 0.3
        if usageList[i].lastUsedBy == player then
            score = 0.0
        end

        spawnTransformScore[#spawnTransformScore+1] = score
        spawnTransformScoreTotal = spawnTransformScoreTotal + score
    end

    return spawnTransformScore, spawnTransformScoreTotal
end
