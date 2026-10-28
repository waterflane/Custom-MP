-- Visibility policy for the local view, using the host's shared match settings.
function CDMP.ApplyMapVisibility()
	if shared.cdmp and shared.cdmp.settings.hud.map == false then
		-- Use the same engine flag as vanilla setup/results. Do not consume Tab,
		-- clear input, change bindings or re-enable a map disabled by another mod.
		SetBool("game.disablemap", true)
	end
end

function CDMP.ShowPlayerMarkers(playerId)
	local state = shared.cdmp
	if not state or state.mode == "dm" or state.settings.hud.teammateMarkers ~= false then return true end
	local myTeam = teamsGetTeamId(GetLocalPlayer())
	return myTeam <= 0 or teamsGetTeamId(playerId) ~= myTeam
end

function CDMP.AddTeammateMapMarker(playerId, tag)
	if not CDMP.ShowPlayerMarkers(playerId) then return end
	local myTeam = teamsGetTeamId(GetLocalPlayer())
	if myTeam <= 0 or teamsGetTeamId(playerId) ~= myTeam or IsPlayerLocal(playerId) or GetPlayerHealth(playerId) <= 0 then return end
	local characterId = GetPlayerCharacter(playerId)
	local imagePath = GetString("characters." .. characterId .. ".preview")
	local names = CDMP.ShowNames()
	AddMapMarker(playerId, tag, names and GetPlayerName(playerId) or "", "loc@UI_TEXT_TEAM", names,
		"loc@UI_TEXT_TEAM_MEMBER", GetPlayerTransform(playerId).pos, teamsGetColor(myTeam), imagePath, "hud/party-member_map-marker.png")
end
