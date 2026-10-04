local CDMP_SETTING_PREFIX = "level.cdmp.draft."

function key(name)
	return CDMP_SETTING_PREFIX .. name
end

function option(label, value)
	return {label = label, value = tostring(value)}
end

function optionIndex(options, value)
	local wanted = tostring(value)
	for i = 1, #options do
		if tostring(options[i].value) == wanted then return i end
	end
	return 1
end

function ensureStepperValue(settingKey, options, defaultValue)
	if HasKey(settingKey) then return end
	local idx = optionIndex(options, defaultValue)
	SetInt(settingKey .. ".index", idx)
	SetString(settingKey, options[idx].value)
end

function resetStepperValue(settingKey, options, defaultValue)
	local idx = optionIndex(options, defaultValue)
	SetInt(settingKey .. ".index", idx)
	SetString(settingKey, options[idx].value)
end

function readNumber(settingKey, fallback)
	local value = tonumber(GetString(settingKey))
	if value == nil then return fallback end
	return value
end
