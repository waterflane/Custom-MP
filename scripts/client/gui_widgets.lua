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
	client.cdmpModal = "rename"
end

function CDMP.SelectPreset(slot)
	if slot < 1 or slot > CDMP.PRESET_COUNT then return end
	client.cdmpSelectedPreset = slot
	CDMP.ClosePresetModal()
end

function CDMP.ConfirmPresetRename()
	CDMP.RenamePreset(client.cdmpSelectedPreset or 1, client.cdmpNameBuffer)
	CDMP.Notify(CDMP.Text("PRESET_RENAMED"))
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

local function symbols(text)
	local result = {}
	for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do result[#result + 1] = char end
	return result
end
local upperRussian, lowerRussian = {}, {}
local lower, upper = symbols("абвгдеёжзийклмнопрстуфхцчшщъыьэюя"), symbols("АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ")
for i, char in ipairs(lower) do
	upperRussian[char] = upper[i]; lowerRussian[upper[i]] = char
end
local function uppercase(char)
	return upperRussian[char] or string.upper(char)
end

function CDMP.PresetNameKey(key)
	-- The engine reports key identifiers, which can be uppercase regardless of Shift.
	key = lowerRussian[key] or (upperRussian[key] and key) or string.lower(key)
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
	UiTranslate(0, 86)
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

function CDMP.DrawPresetCard(slot, width, selected, selector, rowHeight)
	local height = selector and 80 or (rowHeight or 52)
	local badgeSize = height < 44 and 24 or 32
	local nameLeft = badgeSize + 26
	local nameFont = height < 44 and FONT_SIZE_18 or FONT_SIZE_22
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
	UiPush(); UiTranslate(12, (height - badgeSize) / 2)
	UiColor(1, 1, 1, 0.08); UiRoundedRect(badgeSize, badgeSize, 6)
	UiTranslate(badgeSize / 2, badgeSize / 2); UiAlign("center middle"); UiFont("regular.ttf", FONT_SIZE_18)
	UiColor(selected and COLOR_YELLOW or COLOR_WHITE); UiText(tostring(slot)); UiPop()
	UiTextDisableWildcards(true)
	local status = CDMP.Text(CDMP.PresetExists(slot) and "SAVED" or "EMPTY")
	UiFont("regular.ttf", FONT_SIZE_18)
	local statusWidth = math.min(UiGetTextSize(status), width * 0.35)
	local _, statusLabel = uiTextConstrained(status, "regular.ttf", FONT_SIZE_18, statusWidth)
	local nameWidth = selector and width - 100 or width - nameLeft - 28 - statusWidth
	UiPush(); UiTranslate(nameLeft, selector and 26 or height / 2); UiAlign("left middle")
	UiColor(COLOR_WHITE); UiFont("regular.ttf", nameFont)
	local _, name = uiTextConstrained(CDMP.GetPresetName(slot), "regular.ttf", nameFont, nameWidth)
	UiText(name)
	if selector then
		UiTranslate(0, 27); UiColor(0.65, 0.7, 0.72, 1); UiFont("regular.ttf", FONT_SIZE_18); UiText(status)
	end
	UiPop(); UiPush(); UiTranslate(width - (selector and 32 or 16), height / 2)
	UiColor(selected and COLOR_YELLOW or COLOR_WHITE)
	if selector then drawPresetChevron()
	else UiAlign("right middle"); UiFont("regular.ttf", FONT_SIZE_18); UiText(statusLabel) end
	UiPop(); UiPop()
	if pressed then UiSound("ui/common/click.ogg") end
	return pressed
end

function CDMP.PresetListLayout(viewHeight)
	local height = math.min(448, viewHeight - 32)
	local top = height < 400 and 58 or 80
	local gap, footer = 6, 72 -- 40px button, 16px gap, 16px bottom padding
	local rows = math.max(1, math.min(CDMP.PRESET_COUNT, math.floor((height - top - footer + gap) / 40)))
	local rowHeight = math.min(52, math.floor((height - top - footer - gap * (rows - 1)) / rows))
	return {height = height, top = top, rows = rows, rowHeight = rowHeight, gap = gap}
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
	local layout = CDMP.PresetListLayout(UiHeight())
	local height = modal == "rename" and 214 or layout.height
	navigationBeginGroup(modal == "rename" and "cdmpRename" or "cdmpPresetList", true)
	UiMakeInteractive(); UiPush()
	UiAlign("left top"); UiColor(0, 0, 0, 0.65); UiRect(UiWidth(), UiHeight())
	UiTranslate((UiWidth() - width) / 2, math.max(10, (UiHeight() - height) / 2))
	UiColor(COLOR_WHITE); uiDrawPanel(width, height, 16)
	UiTranslate(24, 22); UiFont(FONT_BOLD, FONT_SIZE_30)
	UiText(CDMP.Text(modal == "rename" and "RENAME" or "PRESETS"))
	UiTranslate(0, (modal == "rename" and 80 or layout.top) - 22)
	-- Names are literal text, not localization keys or inline image markup.
	UiTextDisableWildcards(true)
	if modal == "rename" then drawRename(width - 48)
	else
		local content = width - 48
		local pages = math.ceil(CDMP.PRESET_COUNT / layout.rows)
		client.cdmpPresetPage = math.floor(CDMP.Clamp(client.cdmpPresetPage or math.ceil((client.cdmpSelectedPreset or 1) / layout.rows), 1, pages))
		local first = (client.cdmpPresetPage - 1) * layout.rows + 1
		for slot = first, math.min(CDMP.PRESET_COUNT, first + layout.rows - 1) do
			UiPush(); UiTranslate(0, (slot - first) * (layout.rowHeight + layout.gap))
			if CDMP.DrawPresetCard(slot, content, slot == (client.cdmpSelectedPreset or 1), false, layout.rowHeight) then CDMP.SelectPreset(slot) end
			UiPop()
		end
		-- The footer is anchored to the panel, independently of card count/height.
		UiPush(); UiTranslate(content / 2, height - layout.top - 36); UiAlign("center middle")
		local cancelWidth = pages > 1 and content - 144 or content
		if uiDrawSecondaryButton(CDMP.Text("CANCEL"), cancelWidth) then CDMP.ClosePresetModal() end
		if pages > 1 then
			UiPush(); UiTranslate(-content / 2 + 26, 0)
			if uiDrawSecondaryButton("<", 52, client.cdmpPresetPage == 1) then client.cdmpPresetPage = client.cdmpPresetPage - 1 end
			UiPop(); UiPush(); UiTranslate(content / 2 - 26, 0)
			if uiDrawSecondaryButton(">", 52, client.cdmpPresetPage == pages) then client.cdmpPresetPage = client.cdmpPresetPage + 1 end
			UiPop()
		end
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
