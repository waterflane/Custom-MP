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
	client.cdmpNameUpper = false
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
local russianMap, upperRussian, lowerRussian = {}, {}, {}
for i = 2, 4 do
	local en, ru = symbols(englishRows[i]), symbols(russianRows[i])
	for j, char in ipairs(en) do russianMap[char] = ru[j] end
end
russianMap["`"] = "ё"
local lower, upper = symbols("абвгдеёжзийклмнопрстуфхцчшщъыьэюя"), symbols("АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ")
for i, char in ipairs(lower) do
	upperRussian[char] = upper[i]; lowerRussian[upper[i]] = char
end
local function uppercase(char)
	return upperRussian[char] or string.upper(char)
end

function CDMP.PresetNameKey(key)
	-- The engine reports key identifiers, which can be uppercase regardless of Shift.
	key = lowerRussian[key] or string.lower(key)
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
	UiTranslate(10, 9); UiFont("regular.ttf", FONT_SIZE_22)
	local _, name = uiTextConstrained((client.cdmpNameBuffer or "") .. "|", "regular.ttf", FONT_SIZE_22, width - 20)
	UiText(name); UiPop()
	UiTranslate(0, 72)
	UiPush(); UiTranslate(48, 0); UiAlign("center middle")
	if uiDrawSecondaryButton(client.cdmpNameLanguage == "ru" and "RU" or "EN", 96) then
		client.cdmpNameLanguage = client.cdmpNameLanguage == "ru" and "en" or "ru"
	end
	UiPop()
	UiPush(); UiTranslate(112, 0); UiAlign("left middle"); UiFont("regular.ttf", FONT_SIZE_18)
	local _, hint = uiTextConstrained(CDMP.Text("NAME_INPUT_HINT"), "regular.ttf", FONT_SIZE_18, width - 112)
	UiText(hint); UiPop()
	UiTranslate(0, 62)
	local buttonWidth = (width - 12) / 2
	UiPush(); UiTranslate(buttonWidth / 2, 0); UiAlign("center middle")
	if uiDrawPrimaryButton(CDMP.Text("CONFIRM"), buttonWidth) then CDMP.ConfirmPresetRename() end
	UiPop(); UiPush(); UiTranslate(width - buttonWidth / 2, 0); UiAlign("center middle")
	if uiDrawSecondaryButton(CDMP.Text("CANCEL"), buttonWidth) then CDMP.ClosePresetModal() end
	UiPop()
end

-- A text-independent chevron avoids missing-glyph boxes in Teardown fonts.
local function drawPresetChevron()
	UiPush(); UiAlign("left middle")
	UiPush(); UiRotate(-45); UiRect(10, 2); UiPop()
	UiTranslate(7, 7); UiRotate(45); UiRect(10, 2)
	UiPop()
end

function CDMP.DrawPresetCard(slot, width, selected, selector)
	local height = selector and 80 or 52
	UiPush(); UiAlign("left top")
	local navId = UiNavComponent(width, height)
	navigationAddItem(navId)
	local receivesInput = UiReceivesInput()
	local hovered = receivesInput and UiIsMouseInRect(width, height)
	local focused = receivesInput and UiIsComponentInFocus(navId)
	if hovered then navigationMakeLastItemFocused() end
	if selected then navigationMakeLastItemDefault() end
	local pressed = receivesInput and ((hovered and InputPressed("lmb")) or (focused and InputPressed("menu_accept")))
	UiColor(0.12, 0.14, 0.16, (hovered or focused) and 0.98 or 0.85)
	UiRoundedRect(width, height, 8)
	UiColor(selected and COLOR_YELLOW or COLOR_WHITE)
	if selected or hovered or focused then UiRoundedRectOutline(width, height, 8, 2) end
	UiPush(); UiTranslate(12, (height - 32) / 2)
	UiColor(1, 1, 1, 0.08); UiRoundedRect(32, 32, 6)
	UiTranslate(16, 16); UiAlign("center middle"); UiFont("regular.ttf", FONT_SIZE_18)
	UiColor(selected and COLOR_YELLOW or COLOR_WHITE); UiText(tostring(slot)); UiPop()
	UiTextDisableWildcards(true)
	local status = CDMP.Text(CDMP.PresetExists(slot) and "SAVED" or "EMPTY")
	local nameWidth = selector and width - 100 or width - 80 - UiGetTextSize(status)
	UiPush(); UiTranslate(58, selector and 26 or height / 2); UiAlign("left middle")
	UiColor(COLOR_WHITE); UiFont("regular.ttf", FONT_SIZE_22)
	local _, name = uiTextConstrained(CDMP.GetPresetName(slot), "regular.ttf", FONT_SIZE_22, nameWidth)
	UiText(name)
	if selector then
		UiTranslate(0, 27); UiColor(0.65, 0.7, 0.72, 1); UiFont("regular.ttf", FONT_SIZE_18); UiText(status)
	end
	UiPop(); UiPush(); UiTranslate(width - (selector and 32 or 16), height / 2)
	UiColor(selected and COLOR_YELLOW or COLOR_WHITE)
	if selector then drawPresetChevron()
	else UiAlign("right middle"); UiFont("regular.ttf", FONT_SIZE_18); UiText(status) end
	UiPop(); UiPop()
	if pressed then UiSound("ui/common/click.ogg") end
	return pressed
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
	local height = modal == "rename" and 262 or 448
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
			if CDMP.DrawPresetCard(slot, content, slot == (client.cdmpSelectedPreset or 1), false) then CDMP.SelectPreset(slot) end
			UiTranslate(0, 58)
		end
		UiPush(); UiTranslate(content / 2, 4); UiAlign("center middle")
		if uiDrawSecondaryButton(CDMP.Text("CANCEL"), content) then CDMP.ClosePresetModal() end
		UiPop()
	end
	UiPop(); navigationEndGroup()
end

function CDMP.RoundSlider(value, minimum, maximum, step)
	step = step or 1
	value = CDMP.Clamp(value, minimum, maximum)
	return CDMP.Clamp(minimum + math.floor((value - minimum) / step + 0.5) * step, minimum, maximum)
end

function CDMP_DrawSlider(field, width)
	local minimum, maximum, step = field.min or 0, field.max, field.step or 1
	local value = CDMP.RoundSlider(readNumber(field.key, field.default), minimum, maximum, step)
	local controlWidth = math.min(300, width * 0.5)
	local valueWidth = field.format and math.min(150, controlWidth * 0.55) or 64
	local trackWidth = controlWidth - valueWidth - 8
	UiPush(); UiAlign("left middle"); UiFont("regular.ttf", 23 * FONT_SCALE); UiColor(COLOR_WHITE)
	local _, label = uiTextConstrained(field.label, "regular.ttf", 23 * FONT_SCALE, width - controlWidth - 16)
	UiText(label)
	UiTranslate(width - controlWidth, -16); UiAlign("left top")
	local navId = UiNavComponent(controlWidth, 32)
	navigationAddItem(navId)
	local receivesInput = UiReceivesInput()
	local focused = receivesInput and UiIsComponentInFocus(navId)
	if receivesInput and UiIsMouseInRect(controlWidth, 32) then navigationMakeLastItemFocused() end
	if focused then
		if InputPressed("menu_left") or InputPressed("leftarrow") then
			value = CDMP.RoundSlider(value - step, minimum, maximum, step); UiNavSkipUpdate()
		elseif InputPressed("menu_right") or InputPressed("rightarrow") then
			value = CDMP.RoundSlider(value + step, minimum, maximum, step); UiNavSkipUpdate()
		end
	end
	local range = math.max(1, maximum - minimum)
	local position = (value - minimum) / range * trackWidth
	UiPush(); UiTranslate(0, 13); UiColor(0.5, 0.5, 0.5, 0.5); UiRoundedRect(trackWidth, 6, 3)
	UiColor(COLOR_YELLOW); UiRoundedRect(math.max(1, position), 6, 3); UiPop()
	UiPush(); UiTranslate(0, 16); UiAlign("center middle"); UiColor(focused and COLOR_YELLOW or COLOR_WHITE)
	UiIgnoreNavigation()
	local moved = UiSlider("ui/common/dot.png", "x", position, 0, trackWidth)
	if receivesInput then value = CDMP.RoundSlider(minimum + moved / trackWidth * range, minimum, maximum, step) end
	UiPop()
	SetInt(field.key, value)
	UiPush(); UiTranslate(controlWidth, 16); UiAlign("right middle"); UiColor(COLOR_WHITE)
	UiFont(FONT_MEDIUM, FONT_SIZE_22)
	local valueLabel = field.format and field.format(value) or tostring(value)
	local textWidth = UiGetTextSize(valueLabel)
	if textWidth > valueWidth then UiFont(FONT_MEDIUM, FONT_SIZE_22 * valueWidth / textWidth) end
	UiText(valueLabel); UiPop()
	UiPop()
	return value
end

function CDMP.DrawMatchTimer(alpha)
	if not CDMP.IsUnlimitedTime() and shared.time < 3600 then
		hudDrawTimer(shared.time, alpha)
		return
	end
	-- Elapsed time must not trigger the vanilla end-of-countdown warnings.
	local text = CDMP.FormatClock(CDMP.IsUnlimitedTime() and shared.time or math.ceil(shared.time))
	if CDMP.IsUnlimitedTime() then text = "∞ " .. text end
	UiPush(); UiAlign("center top"); UiTranslate(UiCenter(), 40)
	UiFont(FONT_BOLD, FONT_SIZE_36)
	local textWidth = UiGetTextSize(text)
	local a = alpha or 1
	UiColor(0, 0, 0, 0.75 * a); UiRoundedRect(math.max(138, textWidth + 28), 52, 8)
	UiColor(1, 1, 1, a); UiAlign("center middle"); UiTranslate(0, 26); UiText(text)
	UiPop()
end
