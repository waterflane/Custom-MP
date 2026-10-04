function CDMP.ReadToolName(id, fallback)
	local name = GetString("game.tool." .. id .. ".name")
	if name == nil or name == "" then return fallback or id end
	return name
end

function CDMP.CollectToolCatalog()
	local list = {}
	local byId = {}
	local ids = {}
	local available = {}
	local function add(tool)
		if not byId[tool.id] and available[tool.id] and not CDMP.IsFlagTool(tool.id) then
			byId[tool.id] = tool
			table.insert(list, tool)
			table.insert(ids, tool.id)
		end
	end

	local keys = ListKeys("game.tool")
	for i = 1, #keys do
		available[keys[i]] = true
	end

	for i = 1, #CDMP.VANILLA_TOOLS do
		local base = CDMP.VANILLA_TOOLS[i]
		add({
			id = base.id,
			label = CDMP.ReadToolName(base.id, base.label),
			ammo = base.ammo or 0,
			usesAmmo = base.id ~= "sledge",
			canLoot = base.canLoot == true,
			lootWeight = base.lootWeight or 0,
			pickupAmount = base.pickupAmount,
			startEnabled = base.startEnabled == true,
			vanilla = true,
			available = available[base.id] == true,
		})
	end

	for i = 1, #keys do
		local id = keys[i]
		if id ~= "" and not byId[id] then
			add({
				id = id,
				label = CDMP.ReadToolName(id, id),
				ammo = CDMP.DEFAULT_UNLISTED_TOOL_AMMO or 10,
				usesAmmo = true,
				canLoot = CDMP.DEFAULT_UNLISTED_TOOL_CAN_LOOT == true,
				lootWeight = CDMP.DEFAULT_UNLISTED_TOOL_LOOT_WEIGHT or 1,
				pickupAmount = CDMP.DEFAULT_UNLISTED_TOOL_PICKUP_AMOUNT,
				startEnabled = CDMP.DEFAULT_UNLISTED_TOOL_START_ENABLED == true,
				vanilla = false,
				available = true,
			})
		end
	end
	return list, byId, ids
end
