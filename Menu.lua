RewardPickerMenu = RewardPickerMenu or class(BLTMenu)

function RewardPickerMenu:Init(root)
	self:Title({ text = "rewardpicker_title" })
	self:Label({ text = nil, localize = false, h = 8 })

	self:AutoBindNamedControlsBegin()
	self:_MakeChoice("reward", RewardPicker.types)
	self:_MakeChoice("rarity", RewardPicker.rarities)
	self:Slider({
		name = "rewardpicker_timeout",
		text = "rewardpicker_timeout",
		desc = "rewardpicker_timeout_desc",
		value = RewardPicker._config.timeout,
		callback = callback(self, self, "OnOptionChanged", "timeout"),
		min = 0,
		max = 60,
		value_format = "%.0f",
		auto_select_on_hover = true,
	})
	self:AutoBindNamedControlsEnd()
end

function RewardPickerMenu:_MakeChoice(option, items)
	local id = "rewardpicker_" .. option
	local params = {
		name = id,
		text = id,
		desc = id .. "_desc",
		value = RewardPicker._config[option],
		callback = callback(self, self, "OnOptionChanged", option),
		items = {},
		auto_select_on_hover = true,
	}
	for i, item in ipairs(items) do
		table.insert(params.items, { text_id = id .. "_" .. item, value = i })
	end
	self:MultiChoice(params)
end

function RewardPickerMenu:OnOptionChanged(option, value)
	RewardPicker._config[option] = (type(value) == "table") and value.value or value
	self._changed = true
end

function RewardPickerMenu:Close()
	if self._changed then
		RewardPicker:save()
	end
end

Hooks:Add("MenuComponentManagerInitialize", "RewardPicker_MenuComponentManagerInitialize", function(self)
	RaidMenuHelper:CreateMenu({
		name = "rewardpicker_options",
		name_id = "rewardpicker_title",
		inject_list = "blt_options",
		icon = "waypoint_special_loot",
		class = RewardPickerMenu,
	})
end)
