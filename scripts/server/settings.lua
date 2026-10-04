-- Small configuration adapter around the official mode lifecycle.
function CDMP_ServerInit(mode, toolSpawns)
	server.cdmpMode = mode
	server.cdmpTools, server.cdmpToolById = CDMP.CollectToolCatalog()
	server.cdmpToolSpawns = toolSpawns
	server.cdmpStarted = false
	shared.cdmp = {
		version = CDMP.VERSION, mode = mode, tools = server.cdmpTools,
		settings = CDMP.DefaultSettings(mode, server.cdmpTools), hitEvents = {}, suppressedDamageEvents = {},
	}
	-- Official initial loot is replaced once, using the same spawn groups.
	toolsCleanup()
	spawnSetDefaultLoadout(CDMP.BuildLoadout(shared.cdmp.settings, server.cdmpTools))
end

function server.settingsApplyAndStart(playerId, raw)
	if type(playerId) ~= "number" or not IsPlayerValid(playerId) then return end
	if not IsPlayerHost(playerId) or server.cdmpStarted or hudGameIsSetup() then return end
	if type(raw) ~= "table" then return end
	local settings = CDMP.ValidateSettings(raw, server.cdmpMode, server.cdmpTools)
	shared.cdmp.settings = settings
	spawnSetDefaultLoadout(CDMP.BuildLoadout(settings, server.cdmpTools))
	local loot = CDMP.BuildLoot(settings, server.cdmpTools)
	if #loot > 0 then
		for _, transforms in ipairs(server.cdmpToolSpawns) do
			if #transforms > 0 then toolsAddLootTier(transforms, loot) end
		end
	end
	shared.time = settings.duration
	server.cdmpStarted = true
	if server.cdmpMode == "dm" then
		spawnRespawnAllPlayers()
	else
		teamsStart(false)
	end
	shared._hud.gameIsSetup = true
end

function CDMP.ShowNames()
	return not shared.cdmp or shared.cdmp.settings.hud.nameplates
end
