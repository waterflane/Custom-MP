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

local function toggleOptions()
	return {option(CDMP.Text("OFF"), 0), option(CDMP.Text("ON"), 1)}
end

local function item(path, label, options, value)
	return {key = prefix .. string.lower(path), label = CDMP.Text(label), options = options, default = value}
end

local function sliderItem(path, label, maximum, value, formatter)
	return {key = prefix .. string.lower(path), label = CDMP.Text(label), slider = true,
		min = 0, max = maximum, step = 1, default = value, format = formatter}
end

local function matchItems(settings, seed)
	local mode = settings.timeMode or "preset"
	if not seed and HasKey(prefix .. "timemode") then mode = GetString(prefix .. "timemode") end
	local items = {item("timemode", "TIME_MODE", {
		option(CDMP.Text("PRESET_TIME"), "preset"), option(CDMP.Text("CUSTOM_TIME"), "custom")}, settings.timeMode or "preset")}
	if seed or mode == "preset" then
		items[#items + 1] = item("duration", "TIME", optionList(CDMP.DURATION_OPTIONS, CDMP.FormatTime), settings.duration)
	end
	if seed or mode == "custom" then
		items[#items + 1] = sliderItem("customminutes", "CUSTOM_TIME", CDMP.MAX_CUSTOM_DURATION / 60, (settings.customDuration or settings.duration) / 60,
			function(minutes)
				if minutes == 0 then return CDMP.Text("UNLIMITED") end
				return string.format("%02d:%02d", math.floor(minutes / 60), minutes % 60)
			end)
	end
	items[#items + 1] = item("headshot", "HEADSHOT", optionList(CDMP.HEADSHOT_OPTIONS, function(v) return "x" .. tostring(v) end), settings.headshot)
	return items
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
		sliderItem(path .. "ammo", "START_AMMO", 100, value.ammo),
		item(path .. "canLoot", "IN_LOOT", toggleOptions(), value.canLoot and 1 or 0),
		sliderItem(path .. "lootWeight", "LOOT_WEIGHT", 10, value.lootWeight),
		sliderItem(path .. "pickupAmount", "PICKUP_AMOUNT", 100, value.pickupAmount),
	}
end

local function seedItems(items)
	for _, field in ipairs(items) do
		if field.slider then
			ClearKey(field.key .. ".index")
			SetInt(field.key, CDMP.RoundSlider(field.default, field.min, field.max, field.step))
		else resetStepperValue(field.key, field.options, field.default) end
	end
end

function CDMP_SetDraft(settings)
	client.cdmpDraft = CDMP.Copy(settings)
	seedItems(matchItems(settings, true)); seedItems(hudItems(settings))
	for _, tool in ipairs(shared.cdmp.tools) do seedItems(toolItems(tool, settings)) end
end

function CDMP_ReadDraft()
	local settings = CDMP.Copy(client.cdmpDraft)
	settings.duration = readNumber(prefix .. "duration", settings.duration)
	settings.timeMode = GetString(prefix .. "timemode") == "custom" and "custom" or "preset"
	settings.customDuration = readNumber(prefix .. "customminutes", (settings.customDuration or settings.duration) / 60) * 60
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
		if field.slider then CDMP_DrawSlider(field, width)
		else
			local fits, label = uiTextConstrained(field.label, "regular.ttf", 23 * FONT_SCALE, width - 252)
			_drawSettingsItemStepper(field.key, label, fits and "" or field.label, field.options, width, false)
		end
		UiPop(); UiTranslate(0, rowHeight)
	end
	return pages
end

local function drawTools(width, availableHeight)
	local tools = shared.cdmp.tools
	local rowHeight = CDMP.TOOL_CARD_HEIGHT + CDMP.TOOL_CARD_GAP
	local rows = math.max(1, math.floor((availableHeight + CDMP.TOOL_CARD_GAP) / rowHeight))
	local pages = math.max(1, math.ceil(#tools / rows))
	client.cdmpPage = math.floor(CDMP.Clamp(client.cdmpPage or 1, 1, pages))
	local first = (client.cdmpPage - 1) * rows + 1
	local settings = CDMP_ReadDraft()
	for i = first, math.min(#tools, first + rows - 1) do
		UiPush(); UiAlign("left top")
		if CDMP.DrawToolCard(i, tools[i], settings.tools[tools[i].id], width) then
			client.cdmpSelectedTool = i; client.cdmpToolListPage = client.cdmpPage; client.cdmpPage = 1
		end
		UiPop(); UiTranslate(0, rowHeight)
	end
	return pages
end

local function drawPresets(width, availableHeight)
	local slot = client.cdmpSelectedPreset or 1
	local exists = CDMP.PresetExists(slot)
	client.cdmpPage = 1
	UiPush(); UiAlign("left top")
	local selectorHeight = math.min(80, availableHeight - 96)
	if CDMP.DrawPresetCard(slot, width, true, true, selectorHeight) then client.cdmpModal = "list" end
	UiTranslate(0, selectorHeight + 28); UiAlign("center middle")
	local buttonWidth = (width - 16) / 2
	UiPush(); UiTranslate(buttonWidth / 2, 0)
	if uiDrawPrimaryButton(CDMP.Text(exists and "OVERWRITE" or "SAVE"), buttonWidth) then
		CDMP.SavePreset(slot, CDMP_ReadDraft()); CDMP.Notify(CDMP.Text("PRESET_SAVED"))
	end
	UiPop(); UiPush(); UiTranslate(width - buttonWidth / 2, 0)
	if uiDrawSecondaryButton(CDMP.Text("LOAD"), buttonWidth, not exists) then
		local saved = CDMP.LoadPreset(slot)
		if saved then
			local draft, missing = CDMP.PreparePreset(saved, shared.cdmp.mode, shared.cdmp.tools)
			CDMP_SetDraft(draft)
			CDMP.Notify(#missing > 0 and (CDMP.Text("MISSING_TOOLS") .. " " .. table.concat(missing, ", ")) or CDMP.Text("PRESET_LOADED"))
		end
	end
	UiPop(); UiTranslate(0, 48)
	UiPush(); UiTranslate(buttonWidth / 2, 0)
	if uiDrawSecondaryButton(CDMP.Text("RENAME"), buttonWidth) then CDMP.OpenPresetRename(slot) end
	UiPop(); UiPush(); UiTranslate(width - buttonWidth / 2, 0)
	if uiDrawSecondaryButton(CDMP.Text("DELETE"), buttonWidth, not exists) then
		CDMP.DeletePreset(slot); CDMP.Notify(CDMP.Text("PRESET_DELETED"))
	end
	UiPop(); UiPop()
	return 1
end

local function drawSettingsPanel()
	local width, height = math.min(760, UiWidth() - 60), math.min(780, UiHeight() - 40)
	local contentWidth, rowHeight = width - 60, 48
	local compact = height < 480
	local titleTop, tabY, contentTop = compact and 16 or 24, compact and 68 or 96, compact and 112 or 148
	local footerY = height - (compact and 36 or 52)
	local pageY = footerY - 60
	local section = client.cdmpSection or 1
	local contentBottom = (section == 4 and footerY or pageY) - 36
	local availableHeight = contentBottom - contentTop
	local rows = math.max(1, math.floor(availableHeight / rowHeight))
	navigationBeginGroup("cdmpSettings", not client.cdmpModal, client.cdmpModal ~= nil)
	if client.cdmpModal then UiDisableInput() end
	UiMakeInteractive(); UiPush(); UiTranslate(30, 20); UiAlign("left top")
	uiDrawPanel(width, height, 16)
	UiTranslate(30, titleTop); UiColor(COLOR_WHITE); UiFont(FONT_BOLD, compact and FONT_SIZE_22 or FONT_SIZE_30); UiText(CDMP.Text("SETTINGS"))
	UiTranslate(0, tabY - titleTop)
	local tabWidth = (contentWidth - 30) / 4
	for i, name in ipairs(sections) do
		UiPush(); UiTranslate((i - 1) * (tabWidth + 10) + tabWidth / 2, 0); UiAlign("center middle")
		local _, label = uiTextConstrained(CDMP.Text(name), FONT_MEDIUM, FONT_SIZE_22, tabWidth - 8)
		if uiDrawSecondaryButton(label, tabWidth) then
			client.cdmpSection = i; client.cdmpPage = 1; client.cdmpSelectedTool = nil; client.cdmpToolListPage = nil
		end
		if i == section then UiTranslate(0, 24); UiColor(COLOR_YELLOW); UiRect(tabWidth - 10, 3) end
		UiPop()
	end
	UiPush(); UiTranslate(0, contentTop - tabY)
	local pages = 1
	if section == 1 then UiTranslate(0, 20); pages = drawItems(matchItems(client.cdmpDraft), contentWidth, rowHeight, rows)
	elseif section == 3 then UiTranslate(0, 20); pages = drawItems(hudItems(client.cdmpDraft), contentWidth, rowHeight, rows)
	elseif section == 4 then pages = drawPresets(contentWidth, availableHeight)
	elseif client.cdmpSelectedTool then UiTranslate(0, 20); pages = drawItems(toolItems(shared.cdmp.tools[client.cdmpSelectedTool], client.cdmpDraft), contentWidth, rowHeight, rows)
	else pages = drawTools(contentWidth, availableHeight) end
	UiPop()
	UiPush(); UiTranslate(contentWidth / 2, pageY - tabY); UiAlign("center middle")
	if section ~= 4 then
		UiPush(); UiTranslate(-130, 0)
		if uiDrawSecondaryButton("<", 70, client.cdmpPage <= 1) then client.cdmpPage = client.cdmpPage - 1 end
		UiPop(); UiFont(FONT_BOLD, FONT_SIZE_22); UiText(tostring(client.cdmpPage) .. " / " .. pages)
		UiPush(); UiTranslate(130, 0)
		if uiDrawSecondaryButton(">", 70, client.cdmpPage >= pages) then client.cdmpPage = client.cdmpPage + 1 end
		UiPop()
	end
	UiTranslate(0, footerY - pageY)
	local buttonWidth = (contentWidth - 20) / 2
	UiPush(); UiTranslate(-(buttonWidth + 20) / 2, 0)
	if client.cdmpSelectedTool then
		if uiDrawSecondaryButton(CDMP.Text("BACK"), buttonWidth) then client.cdmpSelectedTool = nil; client.cdmpPage = client.cdmpToolListPage or 1 end
	elseif uiDrawSecondaryButton(CDMP.Text("RESET"), buttonWidth) then
		CDMP_SetDraft(CDMP.DefaultSettings(shared.cdmp.mode, shared.cdmp.tools))
	end
	UiPop(); UiPush(); UiTranslate((buttonWidth + 20) / 2, 0)
	if uiDrawSecondaryButton(CDMP.Text("CLOSE"), buttonWidth) then client.cdmpSettingsVisible = false end
	UiPop(); UiPop()

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
	CDMP_DrawPresetModal()
end

function CDMP_DrawCombat()
	if not shared.cdmp or not hudGameIsSetup() or not countdownDone() or CDMP.MatchEnded() then return end
	drawHitMarkers(shared.cdmp); drawDamageNumbers(shared.cdmp)
end
