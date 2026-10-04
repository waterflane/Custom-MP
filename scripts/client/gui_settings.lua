-- Draft settings stay local until the host presses Start.
local prefix = "level.cdmp.draft."
local sections = {"MATCH", "TOOLS", "HUD", "PRESETS"}

function CDMP.Text(name)
	return GetTranslatedStringByKey("CDMP_" .. name)
end

local function optionList(values, formatter)
	local options = {}
	for _, value in ipairs(values) do options[#options + 1] = option(formatter(value), value) end
	return options
end

local function integers(maximum)
	local values = {}
	for i = 0, maximum do values[#values + 1] = i end
	return optionList(values, tostring)
end

local function toggleOptions()
	return {option(CDMP.Text("OFF"), 0), option(CDMP.Text("ON"), 1)}
end

local function item(path, label, options, value)
	return {key = prefix .. string.lower(path), label = CDMP.Text(label), options = options, default = value}
end

local function matchItems(settings)
	return {
		item("duration", "TIME", optionList(CDMP.DURATION_OPTIONS, CDMP.FormatTime), settings.duration),
		item("headshot", "HEADSHOT", optionList(CDMP.HEADSHOT_OPTIONS, function(v) return "x" .. tostring(v) end), settings.headshot),
	}
end

local function hudItems(settings)
	local items = {}
	for _, pair in ipairs({{"nameplates", "NAMES"}, {"hitMarker", "HIT_MARKER"}, {"killMarker", "KILL_MARKER"}, {"damageNumbers", "DAMAGE_NUMBERS"}}) do
		items[#items + 1] = item("hud." .. pair[1], pair[2], toggleOptions(), settings.hud[pair[1]] and 1 or 0)
	end
	return items
end

local function toolItems(tool, settings)
	local path = "tools." .. CDMP.ToolStorageId(tool.id) .. "."
	local value = settings.tools[tool.id]
	return {
		item(path .. "startEnabled", "START_TOOL", toggleOptions(), value.startEnabled and 1 or 0),
		item(path .. "ammo", "START_AMMO", integers(100), value.ammo),
		item(path .. "canLoot", "IN_LOOT", toggleOptions(), value.canLoot and 1 or 0),
		item(path .. "lootWeight", "LOOT_WEIGHT", integers(10), value.lootWeight),
		item(path .. "pickupAmount", "PICKUP_AMOUNT", integers(100), value.pickupAmount),
	}
end

local function seedItems(items)
	for _, field in ipairs(items) do resetStepperValue(field.key, field.options, field.default) end
end

function CDMP_SetDraft(settings)
	client.cdmpDraft = CDMP.Copy(settings)
	seedItems(matchItems(settings)); seedItems(hudItems(settings))
	for _, tool in ipairs(shared.cdmp.tools) do seedItems(toolItems(tool, settings)) end
end

function CDMP_ReadDraft()
	local settings = CDMP.Copy(client.cdmpDraft)
	settings.duration = readNumber(prefix .. "duration", settings.duration)
	settings.headshot = readNumber(prefix .. "headshot", settings.headshot)
	for name, value in pairs(settings.hud) do settings.hud[name] = readNumber(prefix .. "hud." .. string.lower(name), value and 1 or 0) == 1 end
	for _, tool in ipairs(shared.cdmp.tools) do
		local path = prefix .. "tools." .. CDMP.ToolStorageId(tool.id) .. "."
		local value = settings.tools[tool.id]
		for _, field in ipairs({"startEnabled", "canLoot"}) do value[field] = readNumber(path .. string.lower(field), value[field] and 1 or 0) == 1 end
		for _, field in ipairs({"ammo", "lootWeight", "pickupAmount"}) do value[field] = readNumber(path .. string.lower(field), value[field]) end
	end
	return CDMP.ValidateSettings(settings, shared.cdmp.mode, shared.cdmp.tools)
end

function hudOptionEnabled(name)
	return shared.cdmp and shared.cdmp.settings.hud[name] == true
end

local function drawItems(items, width, rowHeight, rows)
	local pages = math.max(1, math.ceil(#items / rows))
	client.cdmpPage = math.floor(CDMP.Clamp(client.cdmpPage or 1, 1, pages))
	local first = (client.cdmpPage - 1) * rows + 1
	for i = first, math.min(#items, first + rows - 1) do
		local field = items[i]
		UiPush(); UiAlign("left middle")
		local fits, label = uiTextConstrained(field.label, "regular.ttf", 23 * FONT_SCALE, width - 252)
		_drawSettingsItemStepper(field.key, label, fits and "" or field.label, field.options, width, false)
		UiPop(); UiTranslate(0, rowHeight)
	end
	return pages
end

local function drawTools(width, rowHeight, rows)
	local tools = shared.cdmp.tools
	local pages = math.max(1, math.ceil(#tools / rows))
	client.cdmpPage = math.floor(CDMP.Clamp(client.cdmpPage or 1, 1, pages))
	local first = (client.cdmpPage - 1) * rows + 1
	for i = first, math.min(#tools, first + rows - 1) do
		UiPush(); UiTranslate(width / 2, 0); UiAlign("center middle")
		local _, label = uiTextConstrained(tools[i].label, FONT_BOLD, FONT_SIZE_22, width - 40)
		if uiDrawSecondaryButton(label, width) then client.cdmpSelectedTool = i; client.cdmpPage = 1 end
		UiPop(); UiTranslate(0, rowHeight)
	end
	return pages
end

local function drawPresets(width, rowHeight, rows)
	local options = {}
	for i = 1, CDMP.PRESET_COUNT do options[#options + 1] = option(CDMP.Text("PRESET") .. " " .. i, i) end
	ensureStepperValue(prefix .. "slot", options, 1)
	local slot = math.floor(CDMP.Clamp(readNumber(prefix .. "slot", 1), 1, CDMP.PRESET_COUNT))
	local exists = CDMP.PresetExists(slot)
	local pages = math.max(1, math.ceil(5 / rows))
	client.cdmpPage = math.floor(CDMP.Clamp(client.cdmpPage or 1, 1, pages))
	local first = (client.cdmpPage - 1) * rows + 1
	for index = first, math.min(5, first + rows - 1) do
		UiPush()
		if index == 1 then
			UiAlign("left middle")
			_drawSettingsItemStepper(prefix .. "slot", CDMP.Text("PRESET"), "", options, width, false)
		else
			UiTranslate(width / 2, 0); UiAlign("center middle")
			if index == 2 then
				UiFont(FONT_BOLD, FONT_SIZE_22); UiText(CDMP.Text(exists and "SAVED" or "EMPTY"))
			elseif index == 3 and uiDrawSecondaryButton(CDMP.Text("SAVE"), width) then
				CDMP.SavePreset(slot, CDMP_ReadDraft()); client.cdmpNotice = CDMP.Text("PRESET_SAVED")
			elseif index == 4 and uiDrawSecondaryButton(CDMP.Text("LOAD"), width, not exists) then
				local saved = CDMP.LoadPreset(slot)
				if saved then
					local draft, missing = CDMP.PreparePreset(saved, shared.cdmp.mode, shared.cdmp.tools)
					CDMP_SetDraft(draft)
					client.cdmpNotice = #missing > 0 and (CDMP.Text("MISSING_TOOLS") .. " " .. table.concat(missing, ", ")) or CDMP.Text("PRESET_LOADED")
				end
			elseif index == 5 and uiDrawSecondaryButton(CDMP.Text("DELETE"), width, not exists) then
				CDMP.DeletePreset(slot); client.cdmpNotice = CDMP.Text("PRESET_DELETED")
			end
		end
		UiPop(); UiTranslate(0, rowHeight)
	end
	return pages
end

local function drawSettingsPanel()
	local width, height = math.min(760, UiWidth() - 60), math.min(780, UiHeight() - 40)
	local contentWidth, rowHeight = width - 60, 48
	local rows = math.max(1, math.floor((height - 290) / rowHeight))
	local section = client.cdmpSection or 1
	navigationBeginGroup("cdmpSettings", true)
	UiMakeInteractive(); UiPush(); UiTranslate(30, 20); UiAlign("left top")
	uiDrawPanel(width, height, 16)
	UiTranslate(30, 34); UiColor(COLOR_WHITE); UiFont(FONT_BOLD, FONT_SIZE_30); UiText(CDMP.Text("SETTINGS"))
	UiTranslate(0, 50)
	local tabWidth = (contentWidth - 30) / 4
	for i, name in ipairs(sections) do
		UiPush(); UiTranslate((i - 1) * (tabWidth + 10) + tabWidth / 2, 0); UiAlign("center middle")
		if uiDrawSecondaryButton(CDMP.Text(name), tabWidth) then
			client.cdmpSection = i; client.cdmpPage = 1; client.cdmpSelectedTool = nil; client.cdmpNotice = nil
		end
		if i == section then UiTranslate(0, 24); UiColor(COLOR_YELLOW); UiRect(tabWidth - 10, 3) end
		UiPop()
	end
	UiPush(); UiTranslate(0, 58)
	local pages = 1
	if section == 1 then pages = drawItems(matchItems(client.cdmpDraft), contentWidth, rowHeight, rows)
	elseif section == 3 then pages = drawItems(hudItems(client.cdmpDraft), contentWidth, rowHeight, rows)
	elseif section == 4 then pages = drawPresets(contentWidth, rowHeight, rows)
	elseif client.cdmpSelectedTool then pages = drawItems(toolItems(shared.cdmp.tools[client.cdmpSelectedTool], client.cdmpDraft), contentWidth, rowHeight, rows)
	else pages = drawTools(contentWidth, rowHeight, rows) end
	UiPop()
	UiPush(); UiTranslate(contentWidth / 2, height - 166); UiAlign("center middle")
	UiPush(); UiTranslate(-130, 0)
	if uiDrawSecondaryButton("<", 70, client.cdmpPage <= 1) then client.cdmpPage = client.cdmpPage - 1 end
	UiPop(); UiFont(FONT_BOLD, FONT_SIZE_22); UiText(tostring(client.cdmpPage) .. " / " .. pages)
	UiPush(); UiTranslate(130, 0)
	if uiDrawSecondaryButton(">", 70, client.cdmpPage >= pages) then client.cdmpPage = client.cdmpPage + 1 end
	UiPop(); UiTranslate(0, 48)
	local buttonWidth = (contentWidth - 20) / 2
	UiPush(); UiTranslate(-(buttonWidth + 20) / 2, 0)
	if client.cdmpSelectedTool then
		if uiDrawSecondaryButton(CDMP.Text("BACK"), buttonWidth) then client.cdmpSelectedTool = nil; client.cdmpPage = 1 end
	elseif uiDrawSecondaryButton(CDMP.Text("RESET"), buttonWidth) then
		CDMP_SetDraft(CDMP.DefaultSettings(shared.cdmp.mode, shared.cdmp.tools)); client.cdmpNotice = nil
	end
	UiPop(); UiPush(); UiTranslate((buttonWidth + 20) / 2, 0)
	if uiDrawSecondaryButton(CDMP.Text("CLOSE"), buttonWidth) then client.cdmpSettingsVisible = false end
	UiPop(); UiPop()
	if client.cdmpNotice then
		UiPush(); UiTranslate(0, height - 100); UiAlign("left top"); UiFont(FONT_MEDIUM, FONT_SIZE_18)
		local _, notice = uiTextConstrained(client.cdmpNotice, FONT_MEDIUM, FONT_SIZE_18, contentWidth, 2)
		UiText(notice); UiPop()
	end
	UiPop(); navigationEndGroup()
end

function CDMP_DrawSetup()
	SetBool("game.disablemap", true)
	if not shared.cdmp then return end
	if not IsPlayerHost(GetLocalPlayer()) then
		UiPush(); UiTranslate(UiCenter(), UiMiddle() + 300)
		uiDrawTextPanel("loc@UI_TEXT_WAITING_FOR_HOST", 1); UiPop()
		return
	end
	if not client.cdmpDraft then CDMP_SetDraft(shared.cdmp.settings); client.cdmpPage = 1 end
	navigationBeginGroup("cdmpHostMenu", false, client.cdmpSettingsVisible or client.cdmpStarting)
	if client.cdmpSettingsVisible or client.cdmpStarting then UiDisableInput() end
	UiMakeInteractive(); UiPush()
	UiTranslate(UiCenter(), math.min(UiMiddle() + 300, UiHeight() - 186)); UiAlign("center top")
	uiDrawPanel(330, 166, 16)
	UiTranslate(0, 14); UiColor(COLOR_WHITE); UiFont(FONT_BOLD, FONT_SIZE_30); UiText("loc@UI_TEXT_HOST_MENU")
	UiTranslate(0, 36)
	if uiDrawSecondaryButton("loc@UI_BUTTON_GAME_MODE_SETTINGS", 290, client.cdmpStarting) then client.cdmpSettingsVisible = not client.cdmpSettingsVisible end
	UiTranslate(0, 50)
	if uiDrawPrimaryButton("loc@UI_BUTTON_START", 290, client.cdmpStarting) then
		client.cdmpStarting = true
		ServerCall("server.settingsApplyAndStart", GetLocalPlayer(), CDMP_ReadDraft())
	end
	UiPop(); navigationEndGroup()
	if client.cdmpSettingsVisible then drawSettingsPanel() end
end

function CDMP_DrawCombat()
	if not shared.cdmp or not hudGameIsSetup() or not countdownDone() or shared.time <= 0 then return end
	drawHitMarkers(shared.cdmp); drawDamageNumbers(shared.cdmp)
end
