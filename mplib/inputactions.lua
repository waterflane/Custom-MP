--- Multiplayer input-action HUD utilities.
--
-- Renders input icon and label UI for mouse/keyboard and gamepad input,
-- including anchored action panels, inline glyph sequences, and layout
-- measurement helpers.

#include "ui/ui_helpers.lua"

local INPUT_ACTIONS_STYLE = {
	iconSize = 42,
	rowGap = 6,
	panelPadding = 10,
	panelMargin = 20,
	textGap = 10,
	keyFontSize = 21,
	textFontSize = 27,
}

local INPUT_SPECIAL_ICONS = {
	lmb = "lmb.png",
	rmb = "rmb.png",
	mmb = "mmb.png",
	wheel = "wheel.png",
	mousewheel = "wheel.png",
	mouse_wheel = "wheel.png",
	mouse_wheel_up = "wheel.png",
	mouse_wheel_down = "wheel.png",
	scroll_up = "wheel.png",
	scroll_down = "wheel.png",
	space = "space.png",
	enter = "enter.png",
	["return"] = "enter.png",
	alt = "alt.png",
	del = "del.png",
	delete = "del.png",
	ctrl = "ctrl.png",
	shift = "shift.png",
	wasd = "wasd.png",
}

local INPUT_KEY_EXCEPTION_ICONS = {
	uparrow = "guparrow.png",
	downarrow = "downarrow.png",
	leftarrow = "leftarrow.png",
	rightarrow = "rightarrow.png",
	backspace = "backspace.png",
	["return"] = "enter.png",
	space = "space.png",
	ctrl = "ctrl.png",
	tab = "tab.png",
}

local function inputActionsTrim(str)
	return tostring(str):match("^%s*(.-)%s*$")
end

local function inputActionsStartsWith(str, prefix)
	return string.sub(str, 1, string.len(prefix)) == prefix
end

local function inputActionsMeasureText(text, font, fontSize)
	UiPush()
	UiAlign("left top")
	UiFont(font, fontSize)
	local w, h, x, y = UiGetTextSize(text)
	UiPop()
	return w, h, x, y
end

local function inputActionsMakeInlineIcon(icon, iconSize)
	local iconString = icon
	if not inputActionsStartsWith(iconString, "[[") then
		iconString = string.format("[[%s;iconsize=%i,%i]]", iconString, iconSize, iconSize)
	end

	local w = inputActionsMeasureText(iconString, "regular.ttf", iconSize)
	return {
		kind = "inline",
		text = iconString,
		w = w,
		h = iconSize,
		fontSize = iconSize,
	}
end

local function inputActionsFormatKeyLabel(key)
	if key == nil or key == "" then
		return "?"
	end

	key = tostring(key)
	if string.len(key) <= 2 then
		return string.upper(key)
	end

	return key:gsub("^%l", string.upper)
end

local function inputActionsMakeKeyIcon(key, iconSize)
	local label = inputActionsFormatKeyLabel(key)
	local textWidth = inputActionsMeasureText(label, "regular.ttf", INPUT_ACTIONS_STYLE.keyFontSize * iconSize / 42)
	local padding = iconSize * 0.45
	return {
		kind = "key",
		key = label,
		w = math.max(iconSize, textWidth + padding),
		h = iconSize,
	}
end

local function inputActionsGetKeyByAction(action)
	if action == nil or action == "" then return "" end
	-- GetKeyByAction is engine-only. The public registry contains current bindings.
	return string.lower(GetString("options.input.keymap." .. action) or "")
end

local function inputActionsResolveKeyboardToken(token, iconSize)
	if inputActionsStartsWith(token, "key:") then
		return inputActionsMakeKeyIcon(string.sub(token, 5), iconSize)
	end

	local action = token
	if string.find(action, ":") then
		action = action:match("^[^:]+:(.+)$") or action
	end

	local specialPath = INPUT_SPECIAL_ICONS[action]
	if specialPath then
		return inputActionsMakeInlineIcon("ui/common/key_icons/white/" .. specialPath, iconSize)
	end

	local key = inputActionsGetKeyByAction(action)
	if key == nil or key == "" then
		key = action
	end

	local resolvedSpecialPath = INPUT_SPECIAL_ICONS[key]
	if resolvedSpecialPath then
		return inputActionsMakeInlineIcon("ui/common/key_icons/white/" .. resolvedSpecialPath, iconSize)
	end

	local exceptionPath = INPUT_KEY_EXCEPTION_ICONS[key]
	if exceptionPath then
		return inputActionsMakeInlineIcon("ui/common/key_icons/white/" .. exceptionPath, iconSize)
	end

	return inputActionsMakeKeyIcon(key, iconSize)
end

local function inputActionsResolveToken(token, isGamepad, iconSize)
	token = inputActionsTrim(token)
	if token == "" then
		return nil
	end

	if inputActionsStartsWith(token, "[[") then
		return inputActionsMakeInlineIcon(token, iconSize)
	end

	local isExplicitKeyboard = inputActionsStartsWith(token, "key:") or INPUT_SPECIAL_ICONS[token] ~= nil
	local isExplicitGamepad = inputActionsStartsWith(token, "menu:") or inputActionsStartsWith(token, "player:") or inputActionsStartsWith(token, "gamepad_")

	if isExplicitKeyboard then
		return inputActionsResolveKeyboardToken(token, iconSize)
	end

	if isExplicitGamepad then
		return inputActionsMakeInlineIcon(token, iconSize)
	end

	if isGamepad then
		local action = token:match("^[^:]+:(.+)$") or token
		return inputActionsMakeInlineIcon("player:" .. action, iconSize)
	end

	return inputActionsResolveKeyboardToken(token, iconSize)
end

local function inputActionsTokenize(input)
	local parts = {}
	local token = ""

	for i = 1, string.len(input) do
		local ch = string.sub(input, i, i)
		if ch == "+" or ch == "/" or ch == "," then
			token = inputActionsTrim(token)
			if token ~= "" then
				parts[#parts + 1] = { kind = "token", value = token }
			end
			parts[#parts + 1] = { kind = "separator", value = ch }
			token = ""
		else
			token = token .. ch
		end
	end

	token = inputActionsTrim(token)
	if token ~= "" then
		parts[#parts + 1] = { kind = "token", value = token }
	end

	return parts
end

local function inputActionsSeparatorText(separator)
	if separator == "," then
		return ", "
	end
	return separator
end

local function inputActionsBuildSequence(input, iconSize)
	local isGamepad = LastInputDevice() == UI_DEVICE_GAMEPAD
	local sequence = { parts = {}, w = 0, h = iconSize }
	local tokens = nil

	if inputActionsStartsWith(inputActionsTrim(input), "[[") then
		tokens = { { kind = "token", value = input } }
	else
		tokens = inputActionsTokenize(input)
	end

	for i = 1, #tokens do
		local part = tokens[i]
		if part.kind == "token" then
			local icon = inputActionsResolveToken(part.value, isGamepad, iconSize)
			if icon ~= nil then
				sequence.parts[#sequence.parts + 1] = icon
				sequence.w = sequence.w + icon.w
			end
		else
			local text = inputActionsSeparatorText(part.value)
			local w = inputActionsMeasureText(text, "regular.ttf", iconSize * 0.75)
			sequence.parts[#sequence.parts + 1] = { kind = "separator", text = text, w = w, h = iconSize }
			sequence.w = sequence.w + w
		end
	end

	return sequence
end

local function inputActionsDrawPart(part)
	if part.kind == "inline" then
		UiPush()
			UiAlign("left middle")
			UiTranslate(0, part.h / 2)
			UiColor(1, 1, 1, 1)
			UiFont("regular.ttf", part.fontSize)
			UiText(part.text)
		UiPop()
	elseif part.kind == "key" then
		local radius = 6 * part.h / 42
		local outline = 1.5 * part.h / 42

		UiPush()
			UiAlign("left top")
			UiColor(1, 1, 1, 1)
			UiRoundedRect(part.w, part.h, radius)
			UiColor(0, 0, 0, 1)
			UiRoundedRectOutline(part.w, part.h, radius, outline)
			UiAlign("center middle")
			UiTranslate(part.w / 2, part.h / 2)
			UiFont("regular.ttf", INPUT_ACTIONS_STYLE.keyFontSize * part.h / 42)
			UiText(part.key)
		UiPop()
	elseif part.kind == "separator" then
		UiPush()
			UiAlign("left top")
			UiColor(1, 1, 1, 0.8)
			UiAlign("center middle")
			UiTranslate(part.w / 2, part.h / 2)
			UiFont("regular.ttf", part.h * 0.75)
			UiText(part.text)
		UiPop()
	end
end

local function inputActionsFirstDefined(item, keys)
	for i = 1, #keys do
		local value = item[keys[i]]
		if value ~= nil then
			return value
		end
	end

	return nil
end

local function inputActionsHasText(text)
	return text ~= nil and inputActionsTrim(text) ~= ""
end

local function inputActionsBuildEntries(actions)
	local entries = {}
	if actions == nil then
		return entries
	end

	if #actions > 0 then
		for i = 1, #actions do
			local item = actions[i]
			if type(item) == "table" then
				local input = inputActionsFirstDefined(item, { "input", "key", "action", 1 })
				local text = inputActionsFirstDefined(item, { "text", "label", "description", 2 })
				if input ~= nil and text ~= nil then
					entries[#entries + 1] = { input = tostring(input), text = text }
				end
			end
		end
	else
		for input, text in pairs(actions) do
			entries[#entries + 1] = { input = tostring(input), text = text }
		end

		table.sort(entries, function(a, b)
			return a.input < b.input
		end)
	end

	return entries
end

local function inputActionsComputeLayout(actions)
	local entries = inputActionsBuildEntries(actions)
	local style = INPUT_ACTIONS_STYLE
	local iconColumnWidth = 0
	local textColumnWidth = 0
	local hasTextColumn = false

	if #entries == 0 then
		return {
			entries = entries,
			style = style,
			iconColumnWidth = 0,
			textColumnWidth = 0,
			hasTextColumn = false,
			width = 0,
			height = 0,
		}
	end

	for i = 1, #entries do
		local sequence = inputActionsBuildSequence(entries[i].input, style.iconSize)
		local textWidth = 0
		if inputActionsHasText(entries[i].text) then
			textWidth = inputActionsMeasureText(entries[i].text, "regular.ttf", style.textFontSize)
			hasTextColumn = true
		end
		entries[i].sequence = sequence
		iconColumnWidth = math.max(iconColumnWidth, sequence.w)
		textColumnWidth = math.max(textColumnWidth, textWidth)
	end

	local textSectionWidth = textColumnWidth
	if hasTextColumn then
		textSectionWidth = style.textGap + textColumnWidth
	end

	return {
		entries = entries,
		style = style,
		iconColumnWidth = iconColumnWidth,
		textColumnWidth = textColumnWidth,
		hasTextColumn = hasTextColumn,
		width = style.panelPadding * 2 + iconColumnWidth + textSectionWidth,
		height = style.panelPadding * 2 + #entries * style.iconSize + (#entries - 1) * style.rowGap,
	}
end

local function inputActionsDrawSequence(sequence)
	local partX = 0
	for i = 1, #sequence.parts do
		local part = sequence.parts[i]
		UiPush()
			UiTranslate(partX, -part.h / 2)
			inputActionsDrawPart(part)
		UiPop()
		partX = partX + part.w
	end
end

local function inputActionsResolveAnchor(anchor)
	if anchor == "top right" then
		return 1, 0
	elseif anchor == "bottom left" then
		return 0, 1
	elseif anchor == "bottom right" then
		return 1, 1
	elseif anchor == "center" then
		return 0.5, 0.5
	end

	return 0, 0
end

local function inputActionsGetPosition(layout, options)
	local style = layout.style
	if options == nil then
		return UiWidth() - layout.width - style.panelMargin, UiHeight() - layout.height - style.panelMargin
	end

	local x = options.x
	local y = options.y

	if x == nil then
		x = UiWidth() - layout.width - style.panelMargin
	end

	if y == nil then
		y = UiHeight() - layout.height - style.panelMargin
	end

	local anchorX, anchorY = inputActionsResolveAnchor(options.anchor)
	return x - layout.width * anchorX, y - layout.height * anchorY
end

--- Create a new frame-local input-actions list.
--
-- Intended for immediate-mode usage where callers rebuild the list every frame,
-- let lower-level systems append their entries, and finally draw once.
--
-- @return[type=table] Empty ordered action list.
function inputActionsCreate()
	return {}
end

--- Append one action row to an ordered input-actions list.
--
-- @param[type=table] actions Target ordered action list.
-- @param[type=string] input Input identifier or expression.
-- @param[type=string] text Action label.
--
-- @return[type=table] The same `actions` table for chaining.
function inputActionsAdd(actions, input, text)
	if actions == nil then
		actions = {}
	end

	if input ~= nil and text ~= nil then
		actions[#actions + 1] = {
			input = tostring(input),
			text = text
		}
	end

	return actions
end

--- Append several action rows into an ordered input-actions list.
--
-- Accepts either an ordered row array or a key/value table and normalizes it
-- into appended rows.
--
-- @param[type=table] actions Target ordered action list.
-- @param[type=table] items Source action rows.
--
-- @return[type=table] The same `actions` table for chaining.
function inputActionsAppend(actions, items)
	if actions == nil then
		actions = {}
	end

	local entries = inputActionsBuildEntries(items)
	for i = 1, #entries do
		actions[#actions + 1] = entries[i]
	end

	return actions
end

--- Draw an input-action table (client).
--
-- Typical immediate-mode usage:
--
-- `local actions = inputActionsCreate()`
-- `inputActionsAdd(actions, "shift", "Scoreboard")`
-- `spectateAppendInputActions(actions)`
-- `inputActionsDraw(actions)`
--
-- Logical actions are resolved through `options.input.keymap` on keyboard/mouse and
-- use `player:<action>` icons on gamepad. Physical inputs can be forced with
-- keys such as `key:e`, `lmb`, `rmb`, `mmb`, `wheel`, `menu:*`, or `player:*`.
--
-- @param[type=table] actions Action descriptor table.
-- @param[opt,type=table] options Optional placement table:
--   * `x` (number)      Anchor x position.
--   * `y` (number)      Anchor y position.
--   * `anchor` (string) Anchor mode: `"top left"` (default), `"top right"`,
--                       `"bottom left"`, `"bottom right"`, or `"center"`.
--
-- @return[type=number] width Drawn panel width in pixels.
-- @return[type=number] height Drawn panel height in pixels.
function inputActionsDraw(actions, options)
	local layout = inputActionsComputeLayout(actions)
	if #layout.entries == 0 then
		return 0, 0
	end

	local x, y = inputActionsGetPosition(layout, options)

	UiPush()
		UiAlign("left top")
		UiTranslate(x, y)
		uiDrawPanel(layout.width, layout.height, 6)
		UiTranslate(layout.style.panelPadding, layout.style.panelPadding)

		for i = 1, #layout.entries do
			local entry = layout.entries[i]

			UiPush()
				UiAlign("left middle")
				UiTranslate(0, layout.style.iconSize / 2)
				UiTranslate(layout.iconColumnWidth - entry.sequence.w, 0)
				inputActionsDrawSequence(entry.sequence)
			UiPop()

			if layout.hasTextColumn and inputActionsHasText(entry.text) then
				UiPush()
					UiAlign("left middle")
					UiTranslate(layout.iconColumnWidth + layout.style.textGap, layout.style.iconSize / 2)
					UiFont("regular.ttf", layout.style.textFontSize)
					UiColor(1,1,1)
					UiText(entry.text)
				UiPop()
			end

			UiTranslate(0, layout.style.iconSize + layout.style.rowGap)
		end
	UiPop()

	return layout.width, layout.height
end

--- Draw a single inline input sequence without a surrounding panel (client).
--
-- Useful when a caller needs to position one resolved input glyph or combo
-- inside a custom HUD layout.
--
-- @param[type=string] input Input identifier or expression.
-- @param[opt,type=table] options Optional draw settings:
--   * `x` (number)         Anchor x position.
--   * `y` (number)         Anchor y position.
--   * `anchor` (string)    Anchor mode: `"top left"` (default), `"top right"`,
--                          `"bottom left"`, `"bottom right"`, or `"center"`.
--   * `iconSize` (number)  Icon height in pixels.
--   * `alpha` (number)     Alpha multiplier.
--
-- @return[type=number] width Drawn width in pixels.
-- @return[type=number] height Drawn height in pixels.
function inputActionsDrawInline(input, options)
	local iconSize = INPUT_ACTIONS_STYLE.iconSize
	local alpha = 1.0
	if options ~= nil and options.iconSize ~= nil then
		iconSize = options.iconSize
	end
	if options ~= nil and options.alpha ~= nil then
		alpha = options.alpha
	end

	local sequence = inputActionsBuildSequence(input or "", iconSize)
	if #sequence.parts == 0 then
		return 0, 0
	end

	local x = 0
	local y = 0
	local anchor = "top left"
	if options ~= nil then
		x = options.x or x
		y = options.y or y
		anchor = options.anchor or anchor
	end

	local anchorX, anchorY = inputActionsResolveAnchor(anchor)

	UiPush()
		UiAlign("left top")
		UiTranslate(x - sequence.w * anchorX, y - sequence.h * anchorY)
		UiColorFilter(1, 1, 1, alpha)
		UiAlign("left middle")
		UiTranslate(0, sequence.h / 2)
		inputActionsDrawSequence(sequence)
	UiPop()

	return sequence.w, sequence.h
end

--- Measure a single inline input sequence without drawing it (client).
--
-- @param[type=string] input Input identifier or expression.
-- @param[opt,type=number] iconSize Icon height in pixels.
--
-- @return[type=number] width Sequence width in pixels.
-- @return[type=number] height Sequence height in pixels.
function inputActionsMeasureInline(input, iconSize)
	local size = iconSize or INPUT_ACTIONS_STYLE.iconSize
	local sequence = inputActionsBuildSequence(input or "", size)
	return sequence.w, sequence.h
end

--- Measure the size of an input-action table without drawing it (client).
--
-- @param[type=table] actions Action descriptor table.
--
-- @return[type=number] width Panel width in pixels.
-- @return[type=number] height Panel height in pixels.
function inputActionsMeasure(actions)
	local layout = inputActionsComputeLayout(actions)
	return layout.width, layout.height
end
