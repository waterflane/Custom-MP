-- Client-side persistence shared by every game mode in this mod.
CDMP.PRESET_VERSION = 1
CDMP.PRESET_COUNT = 5
CDMP.PRESET_PREFIX = "savegame.mod.cdmp.presets."

function CDMP.ToolStorageId(id)
	return (string.gsub(id, ".", function(char) return string.format("%02x", string.byte(char)) end))
end

local function slotKey(slot)
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > CDMP.PRESET_COUNT then return nil end
	return CDMP.PRESET_PREFIX .. tostring(slot)
end

function CDMP.NormalizePresetName(name)
	name = tostring(name or ""):gsub("[%z\1-\31\127]", ""):match("^%s*(.-)%s*$")
	local chars = {}
	for char in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		if #chars == 32 then break end
		chars[#chars + 1] = char
	end
	return table.concat(chars)
end

function CDMP.GetPresetName(slot)
	local prefix = slotKey(slot)
	if not prefix then return "" end
	local name = GetString(prefix .. ".name")
	if name ~= "" then return name end
	return GetTranslatedStringByKey("CDMP_PRESET") .. " " .. tostring(slot)
end

function CDMP.RenamePreset(slot, name)
	local prefix = slotKey(slot)
	if not prefix then return false end
	name = CDMP.NormalizePresetName(name)
	if name == "" then ClearKey(prefix .. ".name") else SetString(prefix .. ".name", name) end
	return true
end

function CDMP.PresetExists(slot)
	local prefix = slotKey(slot)
	return prefix ~= nil and GetInt(prefix .. ".version") == CDMP.PRESET_VERSION
end

function CDMP.SavePreset(slot, settings)
	local prefix = slotKey(slot)
	if not prefix or type(settings) ~= "table" then return false end
	local name = GetString(prefix .. ".name")
	ClearKey(prefix)
	if name ~= "" then SetString(prefix .. ".name", name) end
	SetFloat(prefix .. ".duration", settings.duration)
	SetString(prefix .. ".timemode", settings.timeMode or "preset")
	SetFloat(prefix .. ".customduration", settings.customDuration or settings.duration)
	SetFloat(prefix .. ".headshot", settings.headshot)
	for name, value in pairs(settings.hud) do SetBool(prefix .. ".hud." .. string.lower(name), value) end
	for id, item in pairs(settings.tools) do
		local path = prefix .. ".tools." .. CDMP.ToolStorageId(id)
		SetString(path .. ".id", id)
		SetBool(path .. ".startenabled", item.startEnabled)
		SetBool(path .. ".canloot", item.canLoot)
		SetInt(path .. ".ammo", item.ammo)
		SetInt(path .. ".lootweight", item.lootWeight)
		SetInt(path .. ".pickupamount", item.pickupAmount)
	end
	-- Mark complete only after all fields have been written.
	SetInt(prefix .. ".version", CDMP.PRESET_VERSION)
	return true
end

function CDMP.LoadPreset(slot)
	local prefix = slotKey(slot)
	if not prefix or not CDMP.PresetExists(slot) then return nil end
	local settings = {duration = GetFloat(prefix .. ".duration"), headshot = GetFloat(prefix .. ".headshot"), hud = {}, tools = {}}
	settings.timeMode = GetString(prefix .. ".timemode") == "custom" and "custom" or "preset"
	settings.customDuration = HasKey(prefix .. ".customduration") and GetFloat(prefix .. ".customduration") or settings.duration
	for _, field in ipairs(CDMP.HUD_OPTIONS) do
		local name = field.key
		if HasKey(prefix .. ".hud." .. string.lower(name)) then settings.hud[name] = GetBool(prefix .. ".hud." .. string.lower(name)) end
	end
	for _, storageId in ipairs(ListKeys(prefix .. ".tools")) do
		local path = prefix .. ".tools." .. storageId
		local id = GetString(path .. ".id")
		if id ~= "" and not CDMP.IsFlagTool(id) then
			settings.tools[id] = {
				startEnabled = GetBool(path .. ".startenabled"), canLoot = GetBool(path .. ".canloot"),
				ammo = GetInt(path .. ".ammo"), lootWeight = GetInt(path .. ".lootweight"), pickupAmount = GetInt(path .. ".pickupamount"),
			}
		end
	end
	return settings
end

function CDMP.DeletePreset(slot)
	local prefix = slotKey(slot)
	if not prefix then return false end
	local name = GetString(prefix .. ".name")
	ClearKey(prefix)
	if name ~= "" then SetString(prefix .. ".name", name) end
	return true
end

function CDMP.PreparePreset(settings, mode, tools)
	local available, missing = {}, {}
	for _, tool in ipairs(tools) do available[tool.id] = true end
	for id in pairs(settings.tools or {}) do
		if not available[id] and not CDMP.IsFlagTool(id) then missing[#missing + 1] = id end
	end
	table.sort(missing)
	-- Validation creates a fresh configuration; it never edits the saved slot.
	return CDMP.ValidateSettings(settings, mode, tools), missing
end
