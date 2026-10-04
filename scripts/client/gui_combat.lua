function drawHitMarkers(st)
	local localPlayer = GetLocalPlayer()
	local events = st.hitEvents or {}
	local showHitMarker = hudOptionEnabled("hitMarker")
	local showKillMarker = hudOptionEnabled("killMarker")
	local marker = nil
	for i = 1, #events do
		local event = events[i]
		local isKillEvent = event.kind == "kill"
		local visible = (isKillEvent and showKillMarker) or (not isKillEvent and showHitMarker)
		if visible and event.player == localPlayer and (event.time or 0) > 0 then
			if marker == nil or isKillEvent or (event.time or 0) > (marker.time or 0) then
				marker = event
			end
		end
	end
	if marker == nil then return end

	local isKill = marker.kind == "kill"
	local duration = isKill and CDMP.KILLMARKER_TIME or CDMP.HITMARKER_TIME
	local alpha = CDMP.Clamp((marker.time or 0) / duration, 0.0, 1.0)
	local gap = isKill and 24 or 18
	local len = isKill and 14 or 10
	local thick = isKill and 4 or 3

	UiPush()
	UiTranslate(UiCenter(), UiMiddle())
	UiAlign("left top")
	if isKill then UiColor(1.0, 0.86, 0.12, alpha) else UiColor(1.0, 1.0, 1.0, alpha) end

	UiPush()
	UiTranslate(-gap - len, -gap - len)
	UiRect(len, thick)
	UiRect(thick, len)
	UiPop()

	UiPush()
	UiTranslate(gap, -gap - len)
	UiRect(len, thick)
	UiTranslate(len - thick, 0)
	UiRect(thick, len)
	UiPop()

	UiPush()
	UiTranslate(-gap - len, gap)
	UiTranslate(0, len - thick)
	UiRect(len, thick)
	UiTranslate(0, -len + thick)
	UiRect(thick, len)
	UiPop()

	UiPush()
	UiTranslate(gap, gap)
	UiTranslate(0, len - thick)
	UiRect(len, thick)
	UiTranslate(len - thick, -len + thick)
	UiRect(thick, len)
	UiPop()

	UiPop()
end

function drawDamageNumbers(st)
	if not hudOptionEnabled("damageNumbers") then return end

	local localPlayer = GetLocalPlayer()
	local events = st.hitEvents or {}
	local duration = CDMP.DAMAGE_NUMBER_TIME or 0.85
	for i = 1, #events do
		local event = events[i]
		local damage = tonumber(event.damage or 0) or 0
		local time = event.numberTime or 0
		if event.player == localPlayer and damage > 0 and time > 0 then
			local progress = 1.0 - CDMP.Clamp(time / duration, 0.0, 1.0)
			local fadeIn = CDMP.Clamp(progress / 0.12, 0.0, 1.0)
			local fadeOut = CDMP.Clamp(time / 0.22, 0.0, 1.0)
			local alpha = math.min(fadeIn, fadeOut)
			local seq = event.seq or i
			local spread = ((seq * 37) % 100) / 100.0 - 0.5
			local x = UiCenter() + spread * 72
			local y = UiMiddle() - 58 - progress * 48
			if event.point ~= nil then
				local point = Vec(event.point[1] or 0, event.point[2] or 0, event.point[3] or 0)
				local wx, wy, dist = UiWorldToPixel(VecAdd(point, Vec(spread * 0.18, 0.35 + progress * 0.75, 0)))
				if dist > 0 then
					x = wx
					y = wy
				end
			end
			local value = math.max(1, math.ceil(damage * 100))

			UiPush()
			UiTranslate(x, y)
			UiAlign("center middle")
			UiFont(FONT_BOLD, FONT_SIZE_30)
			UiTextShadow(0, 0, 0, 0.45 * alpha, 1.5, 0.8)
			if event.headshot then
				UiColor(1.0, 0.86, 0.12, alpha)
			else
				UiColor(1.0, 1.0, 1.0, alpha)
			end
			UiScale(1.0 + 0.12 * (1.0 - progress))
			UiText("-" .. tostring(value))
			UiPop()
		end
	end
end
