CDMP = CDMP or {}

CDMP.VERSION = 4
CDMP.HITMARKER_TIME = 0.35
CDMP.KILLMARKER_TIME = 0.65
CDMP.DAMAGE_NUMBER_TIME = 0.85
CDMP.SUPPRESSED_DAMAGE_TIME = 0.35
CDMP.HEAD_RADIUS = 0.45
CDMP.HEAD_OFFSET = Vec(0, 0.18, 0)

CDMP.MAX_CUSTOM_DURATION = 6 * 60 * 60
CDMP.DURATION_OPTIONS = {180, 300, 480, 600, 900, 1200, 1800}
CDMP.HEADSHOT_OPTIONS = {1.0, 1.15, 1.25, 1.3, 1.5, 2.0, 2.5, 3.0}

CDMP.DEFAULT_UNLISTED_TOOL_AMMO = 10
CDMP.DEFAULT_UNLISTED_TOOL_PICKUP_AMOUNT = 10
CDMP.DEFAULT_UNLISTED_TOOL_CAN_LOOT = true
CDMP.DEFAULT_UNLISTED_TOOL_LOOT_WEIGHT = 0
CDMP.DEFAULT_UNLISTED_TOOL_START_ENABLED = false

CDMP.VANILLA_TOOLS = {
	{id = "sledge", label = "Sledge", ammo = 0, pickupAmount = 0, canLoot = false, lootWeight = 0, startEnabled = true},
	{id = "spraycan", label = "Spraycan", ammo = 0, pickupAmount = 0, canLoot = false, lootWeight = 0, startEnabled = true},
	{id = "extinguisher", label = "Extinguisher", ammo = 0, pickupAmount = 0, canLoot = false, lootWeight = 0, startEnabled = true},

	{id = "leafblower", label = "Leafblower", ammo = 0, pickupAmount = 0, canLoot = false, lootWeight = 0, startEnabled = false},
	{id = "blowtorch", label = "Blowtorch", ammo = 10, pickupAmount = 20, canLoot = true, lootWeight = 0, startEnabled = false},

	{id = "cable", label = "Cable", ammo = 6, pickupAmount = 4, canLoot = true, lootWeight = 0, startEnabled = false},
	{id = "plank", label = "Plank", ammo = 6, pickupAmount = 5, canLoot = true, lootWeight = 1, startEnabled = false},

	{id = "gun", label = "Gun", ammo = 14, pickupAmount = 12, canLoot = true, lootWeight = 4, startEnabled = true},
	{id = "shotgun", label = "Shotgun", ammo = 8, pickupAmount = 8, canLoot = true, lootWeight = 4, startEnabled = false},
	{id = "rifle", label = "Rifle", ammo = 12, pickupAmount = 8, canLoot = true, lootWeight = 2, startEnabled = false},
	{id = "rocket", label = "Rocket", ammo = 3, pickupAmount = 4, canLoot = true, lootWeight = 1, startEnabled = false},

	{id = "bomb", label = "Bomb", ammo = 3, pickupAmount = 4, canLoot = true, lootWeight = 3, startEnabled = false},
	{id = "pipebomb", label = "Pipebomb", ammo = 4, pickupAmount = 6, canLoot = true, lootWeight = 3, startEnabled = false},
	{id = "explosive", label = "Explosive", ammo = 3, pickupAmount = 6, canLoot = true, lootWeight = 2, startEnabled = false},

	{id = "booster", label = "Booster", ammo = 6, pickupAmount = 4, canLoot = true, lootWeight = 0, startEnabled = false},
	{id = "transport_booster", label = "Transport Booster", ammo = 6, pickupAmount = 4, canLoot = true, lootWeight = 0, startEnabled = false},
	{id = "steroid", label = "Steroid", ammo = 4, pickupAmount = 2, canLoot = true, lootWeight = 1, startEnabled = false},
}

function CDMP.Clamp(value, minValue, maxValue)
	value = tonumber(value) or minValue
	if value ~= value or value == math.huge or value == -math.huge then value = minValue end
	if value < minValue then return minValue end
	if value > maxValue then return maxValue end
	return value
end

function CDMP.Copy(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for k, v in pairs(value) do copy[k] = CDMP.Copy(v) end
	return copy
end

function CDMP.IsFlagTool(id)
	return id == "flag1" or id == "flag2"
end

function CDMP.DefaultSettings(mode, tools)
	local settings = {
		duration = mode == "ctf" and 480 or 300,
		timeMode = "preset", customDuration = mode == "ctf" and 480 or 300,
		headshot = 1.0,
		hud = {nameplates = true, hitMarker = false, killMarker = false, damageNumbers = false},
		tools = {},
	}
	for _, tool in ipairs(tools) do
		local starts = tool.id == "gun" or tool.id == "sledge" or tool.id == "spraycan" or tool.id == "extinguisher"
		settings.tools[tool.id] = {
			startEnabled = starts, ammo = tool.id == "gun" and 7 or (starts and 0 or tool.ammo),
			canLoot = tool.canLoot, lootWeight = tool.lootWeight, pickupAmount = tool.pickupAmount,
		}
	end
	return settings
end

local function allowedNumber(value, options, fallback)
	if type(value) ~= "number" then return fallback end
	for _, option in ipairs(options) do
		-- Registry/network floats can round values such as 1.15.
		if math.abs(value - option) <= 0.00001 then return option end
	end
	return fallback
end

function CDMP.ValidateSettings(raw, mode, tools)
	local settings = CDMP.DefaultSettings(mode, tools)
	if type(raw) ~= "table" then return settings end
	settings.duration = allowedNumber(raw.duration, CDMP.DURATION_OPTIONS, settings.duration)
	settings.timeMode = raw.timeMode == "custom" and "custom" or "preset"
	settings.customDuration = settings.duration
	local seconds = raw.customDuration
	if type(seconds) == "number" and seconds == seconds and seconds ~= math.huge and seconds ~= -math.huge then
		settings.customDuration = math.floor(CDMP.Clamp(seconds, 0, CDMP.MAX_CUSTOM_DURATION) / 60 + 0.5) * 60
	end
	settings.headshot = allowedNumber(raw.headshot, CDMP.HEADSHOT_OPTIONS, settings.headshot)
	if type(raw.hud) == "table" then
		for name, default in pairs(settings.hud) do
			if type(raw.hud[name]) == "boolean" then settings.hud[name] = raw.hud[name] end
		end
	end
	if type(raw.tools) == "table" then
		for id, item in pairs(settings.tools) do
			local incoming = raw.tools[id]
			if type(incoming) == "table" then
				for _, field in ipairs({"startEnabled", "canLoot"}) do
					if type(incoming[field]) == "boolean" then item[field] = incoming[field] end
				end
				for _, field in ipairs({"ammo", "lootWeight", "pickupAmount"}) do
					if type(incoming[field]) == "number" then
						item[field] = math.floor(CDMP.Clamp(incoming[field], 0, field == "lootWeight" and 10 or 100))
					end
				end
			end
		end
	end
	return settings
end

function CDMP.BuildLoadout(settings, tools)
	local loadout = {}
	-- Keep the vanilla gun-first selection order unless the gun is disabled.
	local function add(tool)
		local item = settings.tools[tool.id]
		if item and item.startEnabled then loadout[#loadout + 1] = {tool.id, item.ammo} end
	end
	for _, tool in ipairs(tools) do if tool.id == "gun" then add(tool) end end
	for _, tool in ipairs(tools) do if tool.id ~= "gun" then add(tool) end end
	return loadout
end

function CDMP.BuildLoot(settings, tools)
	local loot = {}
	for _, tool in ipairs(tools) do
		local item = settings.tools[tool.id]
		if item and item.canLoot and item.lootWeight > 0 then
			loot[#loot + 1] = {name = tool.id, weight = item.lootWeight, amount = item.pickupAmount}
		end
	end
	return loot
end

function CDMP.FormatTime(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local minutes = math.floor(seconds / 60)
	local secs = seconds - minutes * 60
	if secs < 10 then return tostring(minutes) .. ":0" .. tostring(secs) end
	return tostring(minutes) .. ":" .. tostring(secs)
end

function CDMP.GetHeadshotCenter(playerId)
	local eye = GetPlayerEyeTransform(playerId)
	return TransformToParentPoint(eye, CDMP.HEAD_OFFSET)
end

function CDMP.GetMatchDuration(settings)
	return settings.timeMode == "custom" and settings.customDuration or settings.duration
end

function CDMP.IsUnlimitedTime()
	local settings = shared.cdmp and shared.cdmp.settings
	return settings ~= nil and settings.timeMode == "custom" and settings.customDuration == 0
end

function CDMP.MatchEnded()
	return not CDMP.IsUnlimitedTime() and (shared.time or 0) <= 0
end

function CDMP.TickMatchTime(dt)
	if CDMP.IsUnlimitedTime() then shared.time = shared.time + dt
	else shared.time = math.max(0, shared.time - dt) end
end

function CDMP.FormatClock(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end
