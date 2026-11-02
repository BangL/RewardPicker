RewardPicker = RewardPicker or {}

-- option values (index = save value)
RewardPicker.types = { "off", "ask", "weapon_skin", "customization", "melee", "xp", "gold_bars", "card_pack" }
RewardPicker.rarities = { "any", "common", "uncommon", "rare" }

RewardPicker._path = SavePath .. "RewardPicker.json"
RewardPicker._config = { reward = 1, rarity = 1, timeout = 5 }

function RewardPicker:save()
	local file = io.open(self._path, "w+")
	if file then
		file:write(json.encode(self._config))
		file:close()
	end
end

function RewardPicker:load()
-- stale index (removed option)
if not RewardPicker.types[RewardPicker._config.reward] then
	RewardPicker._config.reward = 1
end
	local file = io.open(self._path, "r")
	if file then
		local ok, config = blt.pcall(json.decode, file:read("*all"))
		file:close()
		if ok and type(config) == "table" then
			for k in pairs(self._config) do
				if type(config[k]) == "number" then
					self._config[k] = config[k]
				end
			end
		end
	end
end

RewardPicker:load()
-- stale index (removed option)
if not RewardPicker.types[RewardPicker._config.reward] then
	RewardPicker._config.reward = 1
end
