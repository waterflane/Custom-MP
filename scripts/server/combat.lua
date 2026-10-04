local function playerHit(victim, attacker)
	if not attacker or attacker == 0 or attacker == victim then return false end
	if not IsPlayerValid(victim) or not IsPlayerValid(attacker) then return false end
	if server.cdmpMode ~= "dm" and teamsGetTeamId(victim) == teamsGetTeamId(attacker) then return false end
	return true
end

local function matchesDamage(event, victim, attacker, damage, before, after)
	return event.victim == victim and event.attacker == attacker and damage > 0
		and math.abs(event.damage - damage) <= 0.01
		and math.abs(event.before - before) <= 0.01 and math.abs(event.after - after) <= 0.01
end

function CDMP.SuppressHudDamage(victim, attacker, before, after)
	for _, event in ipairs(shared.cdmp and shared.cdmp.suppressedDamageEvents or {}) do
		if matchesDamage(event, victim, attacker, before - after, before, after) then return true end
	end
	return false
end

local function pushHit(player, kind, damage, headshot, point)
	server.cdmpHitSeq = (server.cdmpHitSeq or 0) + 1
	local events = shared.cdmp.hitEvents
	events[#events + 1] = {
		seq = server.cdmpHitSeq, player = player, kind = kind, damage = damage, headshot = headshot, point = point,
		time = kind == "kill" and CDMP.KILLMARKER_TIME or CDMP.HITMARKER_TIME,
		numberTime = damage and CDMP.DAMAGE_NUMBER_TIME or 0,
	}
	while #events > 24 do table.remove(events, 1) end
end

function CDMP_CombatTick(dt)
	local st = shared.cdmp
	for i = #st.hitEvents, 1, -1 do
		local event = st.hitEvents[i]
		event.time = event.time - dt
		event.numberTime = event.numberTime - dt
		if event.time <= 0 and event.numberTime <= 0 then table.remove(st.hitEvents, i) end
	end
	for i = #st.suppressedDamageEvents, 1, -1 do
		local event = st.suppressedDamageEvents[i]
		event.time = event.time - dt
		if event.time <= 0 then table.remove(st.suppressedDamageEvents, i) end
	end
	local settings = st.settings
	if settings.headshot == 1 and not settings.hud.hitMarker and not settings.hud.killMarker and not settings.hud.damageNumbers then return end
	for i = 1, GetEventCount("playerhurt") do
		local victim, before, after, attacker, point = GetEvent("playerhurt", i)
		local damage = before - after
		local suppressed = false
		for _, event in ipairs(st.suppressedDamageEvents) do
			if not event.consumed and matchesDamage(event, victim, attacker, damage, before, after) then
				event.consumed = true
				suppressed = true
				break
			end
		end
		if damage > 0 and playerHit(victim, attacker) and not suppressed then
			local headshot = point and settings.headshot > 1 and VecLength(VecSub(point, CDMP.GetHeadshotCenter(victim))) <= CDMP.HEAD_RADIUS
			local bonus = headshot and damage * (settings.headshot - 1) or 0
			-- A lethal base hit needs no additional damage or second death event.
			local currentHealth = GetPlayerHealth(victim)
			if bonus > 0 and after > 0 and currentHealth > 0 then
				bonus = math.min(bonus, currentHealth)
				st.suppressedDamageEvents[#st.suppressedDamageEvents + 1] = {
					victim = victim, attacker = attacker, damage = bonus, before = currentHealth, after = currentHealth - bonus,
					time = CDMP.SUPPRESSED_DAMAGE_TIME,
				}
				ApplyPlayerDamage(victim, bonus, "headshot", attacker)
			else
				bonus = 0
			end
			if settings.hud.hitMarker or settings.hud.damageNumbers then
				pushHit(attacker, "hit", math.min(before, damage + bonus), headshot == true, point)
			end
		end
	end
	if settings.hud.killMarker then
		for i = 1, GetEventCount("playerdied") do
			local victim, attacker = GetEvent("playerdied", i)
			if playerHit(victim, attacker) then pushHit(attacker, "kill") end
		end
	end
end
