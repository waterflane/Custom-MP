-- Client-local notifications use wall time and are drawn outside the settings panel.
CDMP.NOTICE_LIFETIME = 5

function CDMP.PruneNotices(now)
	local notices = client.cdmpNotices or {}
	for i = #notices, 1, -1 do
		if now - notices[i].created >= CDMP.NOTICE_LIFETIME then table.remove(notices, i) end
	end
	client.cdmpNotices = notices
	return notices
end

function CDMP.Notify(text)
	local now = GetTime()
	local notices = CDMP.PruneNotices(now)
	notices[#notices + 1] = {text = tostring(text), created = now}
end

function CDMP.NoticeAlpha(age)
	local value = math.max(0, math.min(1, age / 0.15, (CDMP.NOTICE_LIFETIME - age) / 0.8))
	return value * value * (3 - 2 * value)
end

function CDMP_DrawNotices()
	local now = GetTime()
	local notices = CDMP.PruneNotices(now)
	if #notices == 0 then return end
	local width = math.min(520, UiWidth() - 48)
	UiPush(); UiIgnoreNavigation(); UiTextDisableWildcards(true)
	UiAlign("left top"); UiTranslate(24, UiHeight() - 24)
	-- Newest at the bottom; wrapped cards reserve their actual height.
	for i = #notices, 1, -1 do
		local notice = notices[i]
		local alpha = CDMP.NoticeAlpha(now - notice.created)
		UiPush(); UiFont("regular.ttf", FONT_SIZE_18); UiWordWrap(width - 36)
		local _, text = uiTextConstrained(notice.text, "regular.ttf", FONT_SIZE_18, width - 36, 3)
		local _, textHeight = UiGetTextSize(text)
		local height = math.max(52, textHeight + 28)
		UiPop()
		UiTranslate(0, -height)
		UiPush(); UiTranslate(-12 * (1 - alpha), 0)
		UiColor(0.08, 0.1, 0.12, 0.94 * alpha); UiRoundedRect(width, height, 8)
		UiColor(1, 1, 0.5, alpha); UiRoundedRect(3, height, 1)
		UiTranslate(18, 14); UiFont("regular.ttf", FONT_SIZE_18); UiWordWrap(width - 36)
		UiColor(1, 1, 1, alpha); UiText(text)
		UiPop(); UiTranslate(0, -10)
	end
	UiPop()
end
