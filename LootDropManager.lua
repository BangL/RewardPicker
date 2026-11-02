-- force the mission end reward type (see RewardPicker.lua)

local MAX_DEPTH = 20 -- vanilla re-rolls via give_loot_to_player when a drop fails (e.g. owned customization)

local function rarity_ok(reward)
	local wanted = RewardPicker.rarities[RewardPicker._config.rarity]
	return wanted == "any" or reward.rarity == "loot_rarity_" .. wanted
end

local function collect(tbl)
	local list = {}
	for _, reward in pairs(tbl or {}) do
		if type(reward) == "table" and rarity_ok(reward) then
			table.insert(list, reward)
		end
	end
	return list
end

local function candidates(kind)
	local lootdrop = tweak_data.lootdrop
	if kind == "weapon_skin" then
		-- same filter as WeaponInventoryManager:get_weapon_skin_reward_by_rarity
		local rarities = {}
		for skin_id, skin in pairs(tweak_data.weapon.weapon_skins) do
			if skin.droppable and not (skin.dlc or skin.challenge) and not managers.weapon_inventory:is_weapon_skin_owned(skin_id) then
				rarities[skin.rarity] = true
			end
		end
		local list = {}
		for _, reward in ipairs(collect(lootdrop.rewards_weapon_skin)) do
			if rarities[reward.rarity] then
				table.insert(list, reward)
			end
		end
		return list
	elseif kind == "customization" then
		local list = {}
		for _, reward in ipairs(collect(lootdrop.rewards_customization)) do
			for _, key in ipairs(tweak_data.character_customization:get_reward_loot_by_rarity(reward.rarity)) do
				if not managers.character_customization:is_character_customization_owned(key) then
					table.insert(list, reward)
					break
				end
			end
		end
		return list
	elseif kind == "melee" then
		if managers.weapon_inventory:is_drop_inventory_complete_melee() then
			return {}
		end
		return { lootdrop.rewards_melee }
	elseif kind == "xp" then
		return collect(lootdrop.rewards_xp_packs)
	elseif kind == "gold_bars" then
		return collect(lootdrop.rewards_gold_bars)
	elseif kind == "card_pack" then
		if managers.raid_menu and managers.raid_menu:is_offline_mode() then
			return {}
		end
		return collect(lootdrop.rewards_card_packs)
	end
	return {}
end

-- complete categories are not offered in the live choice
local function available(kind)
	return kind == "off" or #candidates(kind) > 0
end

RewardPicker.ASK_KINDS = { "off", "weapon_skin", "customization", "melee", "xp", "gold_bars", "card_pack" }
RewardPicker.available = available

local give_loot_to_player_original = LootDropManager.give_loot_to_player
---@diagnostic disable-next-line: duplicate-set-field
function LootDropManager:give_loot_to_player(...)
	local depth = self._reward_picker_depth or 0

	-- live choice: only while the loot screen is being created (it shows the selector, see LootScreenGui.lua)
	if depth == 0 and not self._reward_picker_choice and RewardPicker._loot_gui_init and RewardPicker.types[RewardPicker._config.reward] == "ask" then
		self._reward_picker_pending = { ... }
		return
	end

	self._reward_picker_depth = depth + 1
	local ok, res = blt.pcall(give_loot_to_player_original, self, ...)
	self._reward_picker_depth = depth
	if not ok then
		error(res, 0)
	end
	return res
end


-- called by the selector; runs the postponed drop with the chosen kind
function LootDropManager:reward_picker_resolve(kind)
	local args = self._reward_picker_pending
	self._reward_picker_pending = nil
	if not args then
		return
	end

	self._reward_picker_choice = kind
	local ok, err = blt.pcall(self.give_loot_to_player, self, unpack(args))
	self._reward_picker_choice = nil
	if not ok then
		log("[RewardPicker] drop failed: " .. tostring(err))
	end
end

local produce_loot_drop_original = LootDropManager.produce_loot_drop
---@diagnostic disable-next-line: duplicate-set-field
function LootDropManager:produce_loot_drop(...)
	local kind = self._reward_picker_choice or RewardPicker.types[RewardPicker._config.reward]
	if kind and kind ~= "off" and kind ~= "ask" and (self._reward_picker_depth or 0) <= MAX_DEPTH and managers.weapon_inventory then
		local list = candidates(kind)
		if #list > 0 then
			local drop = list[math.random(#list)]
			log("[RewardPicker] forcing " .. kind .. " drop")
			return clone(drop)
		end
	end

	return produce_loot_drop_original(self, ...)
end
