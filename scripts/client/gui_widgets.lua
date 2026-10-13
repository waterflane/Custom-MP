-- Public mod UI/input functions only: no engine-only text-input functions.
function CDMP.ClosePresetModal()
	client.cdmpModal = nil
	client.cdmpNameBuffer = nil
	client.cdmpNameSelectAll = nil
end

function CDMP.OpenPresetRename(slot)
	client.cdmpSelectedPreset = slot
	client.cdmpNameBuffer = CDMP.GetPresetName(slot)
	client.cdmpNameSelectAll = true
	client.cdmpNameLanguage = client.cdmpNameLanguage or "en"
	client.cdmpModal = "rename"
end

function CDMP.SelectPreset(slot)
	if slot < 1 or slot > CDMP.PRESET_COUNT then return end
	client.cdmpSelectedPreset = slot
	CDMP.ClosePresetModal()
end

function CDMP.ConfirmPresetRename()
	CDMP.RenamePreset(client.cdmpSelectedPreset or 1, client.cdmpNameBuffer)
	client.cdmpNotice = CDMP.Text("PRESET_RENAMED")
	CDMP.ClosePresetModal()
end

function CDMP.AppendPresetName(char)
	if client.cdmpNameSelectAll then client.cdmpNameBuffer = ""; client.cdmpNameSelectAll = false end
	-- Do not trim trailing spaces while editing.
	local name = (client.cdmpNameBuffer or "") .. char
	local chars = {}
	for symbol in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		if #chars == 32 then break end
		chars[#chars + 1] = symbol
	end
	client.cdmpNameBuffer = table.concat(chars)
end

function CDMP.BackspacePresetName()
	if client.cdmpNameSelectAll then
		client.cdmpNameBuffer = ""; client.cdmpNameSelectAll = false
	else
		client.cdmpNameBuffer = (client.cdmpNameBuffer or ""):gsub("[%z\1-\127\194-\244][\128-\191]*$", "")
	end
end

local englishRows = {"1234567890", "qwertyuiop[]", "asdfghjkl;'", "zxcvbnm,./"}
local russianRows = {"1234567890", "йцукенгшщзхъ", "фывапролджэ", "ячсмитьбю."}
local function symbols(text)
	local result = {}
	for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do result[#result + 1] = char end
	return result
end
local russianMap, upperRussian = {}, {}
for i = 2, 4 do
	local en, ru = symbols(englishRows[i]), symbols(russianRows[i])
	for j, char in ipairs(en) do russianMap[char] = ru[j] end
end
russianMap["`"] = "ё"
local lower, upper = symbols("абвгдеёжзийклмнопрстуфхцчшщъыьэюя"), symbols("АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ")
for i, char in ipairs(lower) do upperRussian[char] = upper[i] end
local function uppercase(char)
	return upperRussian[char] or string.upper(char)
end

function CDMP.PresetNameKey(key)
	if key == "backspace" then CDMP.BackspacePresetName(); return end
	if key == "delete" then client.cdmpNameBuffer = ""; client.cdmpNameSelectAll = false; return end
	if key == "capslock" then client.cdmpNameUpper = not client.cdmpNameUpper; return end
	if key == "space" then CDMP.AppendPresetName(" "); return end
	if InputDown("ctrl") then
		if key == "a" then client.cdmpNameSelectAll = true end
		return
	end
	local char = key
	if #key ~= 1 and not upperRussian[key] then return end
	if client.cdmpNameLanguage == "ru" then char = russianMap[key] or key end
	if (client.cdmpNameUpper == true) ~= InputDown("shift") then char = uppercase(char) end
	CDMP.AppendPresetName(char)
end

local function drawRename(width)
	UiPush(); UiAlign("left top")
	UiColor(client.cdmpNameSelectAll and COLOR_YELLOW or COLOR_WHITE)
	UiRoundedRectOutline(width, 46, 6, 2)
	UiTranslate(10, 9); UiFont(FONT_MEDIUM, FONT_SIZE_22)
	local _, name = uiTextConstrained((client.cdmpNameBuffer or "") .. "|", FONT_MEDIUM, FONT_SIZE_22, width - 20)
	UiText(name); UiPop()
	UiTranslate(0, 68)
	local rows = client.cdmpNameLanguage == "ru" and russianRows or englishRows
	local cell = (width - 11 * 4) / 12
	for _, row in ipairs(rows) do
		for i, char in ipairs(symbols(row)) do
			if client.cdmpNameUpper then char = uppercase(char) end
			UiPush(); UiTranslate((i - 1) * (cell + 4) + cell / 2, 0); UiAlign("center middle")
			if uiDrawSecondaryButton(char, cell) then CDMP.AppendPresetName(char) end
			UiPop()
		end
		UiTranslate(0, 44)
	end
	local controls = {
		{label = client.cdmpNameLanguage == "ru" and "RU" or "EN", click = function() client.cdmpNameLanguage = client.cdmpNameLanguage == "ru" and "en" or "ru" end},
		{label = "Aa", click = function() client.cdmpNameUpper = not client.cdmpNameUpper end},
		{label = CDMP.Text("SPACE"), click = function() CDMP.AppendPresetName(" ") end},
		{label = CDMP.Text("BACKSPACE"), click = CDMP.BackspacePresetName},
		{label = CDMP.Text("CLEAR_NAME"), click = function() client.cdmpNameBuffer = ""; client.cdmpNameSelectAll = false end},
	}
	local controlWidth = (width - 4 * 6) / 5
	for i, control in ipairs(controls) do
		UiPush(); UiTranslate((i - 1) * (controlWidth + 6) + controlWidth / 2, 0); UiAlign("center middle")
		if uiDrawSecondaryButton(control.label, controlWidth) then control.click() end
		UiPop()
	end
	UiTranslate(0, 56)
	local buttonWidth = (width - 12) / 2
	UiPush(); UiTranslate(buttonWidth / 2, 0); UiAlign("center middle")
	if uiDrawPrimaryButton(CDMP.Text("CONFIRM"), buttonWidth) then CDMP.ConfirmPresetRename() end
	UiPop(); UiPush(); UiTranslate(width - buttonWidth / 2, 0); UiAlign("center middle")
	if uiDrawSecondaryButton(CDMP.Text("CANCEL"), buttonWidth) then CDMP.ClosePresetModal() end
	UiPop()
end

function CDMP_DrawPresetModal()
	local modal = client.cdmpModal
	if not modal then return end
	if InputPressed("menu_cancel") or InputLastPressedKey() == "esc" then
		InputClear("menu_cancel"); InputClear("esc"); CDMP.ClosePresetModal(); return
	end
	if modal == "rename" then
		local key = InputLastPressedKey()
		if key == "return" or key == "enter" then
			InputClear("menu_accept"); CDMP.ConfirmPresetRename(); return
		end
		CDMP.PresetNameKey(key)
	end
	local width = math.min(700, UiWidth() - 40)
	local height = modal == "rename" and 424 or 384
	navigationBeginGroup(modal == "rename" and "cdmpRename" or "cdmpPresetList", true)
	UiMakeInteractive(); UiPush()
	UiAlign("left top"); UiColor(0, 0, 0, 0.65); UiRect(UiWidth(), UiHeight())
	UiTranslate((UiWidth() - width) / 2, math.max(10, (UiHeight() - height) / 2))
	UiColor(COLOR_WHITE); uiDrawPanel(width, height, 16)
	UiTranslate(24, 22); UiFont(FONT_BOLD, FONT_SIZE_30)
	UiText(CDMP.Text(modal == "rename" and "RENAME" or "PRESETS"))
	UiTranslate(0, 58)
	-- Names are literal text, not localization keys or inline image markup.
	UiTextDisableWildcards(true)
	if modal == "rename" then drawRename(width - 48)
	else
		local content = width - 48
		for slot = 1, CDMP.PRESET_COUNT do
			local _, name = uiTextConstrained(CDMP.GetPresetName(slot), FONT_MEDIUM, FONT_SIZE_22, content - 210)
			local label = slot .. ". " .. name .. " — " .. CDMP.Text(CDMP.PresetExists(slot) and "SAVED" or "EMPTY")
			UiPush(); UiTranslate(content / 2, 0); UiAlign("center middle")
			if uiDrawSecondaryButton(label, content) then CDMP.SelectPreset(slot) end
			if slot == (client.cdmpSelectedPreset or 1) then UiTranslate(0, 21); UiColor(COLOR_YELLOW); UiRect(content - 12, 2) end
			UiPop(); UiTranslate(0, 48)
		end
		UiPush(); UiTranslate(content / 2, 4); UiAlign("center middle")
		if uiDrawSecondaryButton(CDMP.Text("CANCEL"), content) then CDMP.ClosePresetModal() end
		UiPop()
	end
	UiPop(); navigationEndGroup()
end
