-- live reward choice: scrollable popup (same approach as the seed popup of BountyHunter) in the loot screen

local init_original = LootScreenGui.init
local close_original = LootScreenGui.close

---@diagnostic disable-next-line: duplicate-set-field
function LootScreenGui:init(...)
	-- LootDropManager postpones the drop while this flag is set
	RewardPicker._loot_gui_init = true
	local ok, err = blt.pcall(init_original, self, ...)
	RewardPicker._loot_gui_init = nil
	if not ok then
		error(err, 0)
	end

	if managers.lootdrop._reward_picker_pending then
		self:_reward_picker_show_popup()
	end
end

---@diagnostic disable-next-line: duplicate-set-field
function LootScreenGui:close(...)
	self:_reward_picker_close_popup()
	return close_original(self, ...)
end

function LootScreenGui:_reward_picker_show_popup()
	self:_reward_picker_close_popup()

	local BOX_W = 360
	local TITLE_H = 56
	local ITEM_H = 48
	local PADDING = 8
	local FONT_SIZE = tweak_data.gui.font_sizes.large

	local data = {}
	for _, kind in ipairs(RewardPicker.ASK_KINDS) do
		if RewardPicker.available(kind) then
			table.insert(data, { text = managers.localization:to_upper_text("rewardpicker_ask_" .. kind), value = kind })
		end
	end

	local box_h = math.min(self._root_panel:h() - 200, TITLE_H + #data * (ITEM_H + 2) + PADDING)

	self._reward_picker_popup = self._root_panel:panel({
		name = "reward_picker_popup",
		w = self._root_panel:w(),
		h = self._root_panel:h(),
		layer = 5000,
	})
	self._reward_picker_popup:rect({
		color = Color.black:with_alpha(0.45),
		w = self._reward_picker_popup:w(),
		h = self._reward_picker_popup:h(),
	})

	local box = self._reward_picker_popup:panel({
		w = BOX_W,
		h = box_h,
	})
	box:set_center(self._reward_picker_popup:w() / 2, self._reward_picker_popup:h() / 2)
	box:rect({
		color = tweak_data.gui.colors.raid_black,
		layer = 1,
		w = box:w(),
		h = box:h(),
	})
	box:text({
		text = managers.localization:to_upper_text("rewardpicker_ask_text"),
		font = tweak_data.gui:get_font_path(tweak_data.gui.fonts.din_compressed, FONT_SIZE),
		font_size = FONT_SIZE,
		color = tweak_data.gui.colors.raid_white,
		align = "center",
		vertical = "center",
		layer = 10,
		h = TITLE_H,
		w = box:w(),
	})

	self._reward_picker_popup_scroll = box:scrollable_area({
		name = "reward_picker_popup_scroll",
		scroll_step = 35,
		x = PADDING,
		y = TITLE_H,
		w = box:w() - 2 * PADDING,
		h = box:h() - TITLE_H - PADDING,
	})

	self._reward_picker_popup_list = self._reward_picker_popup_scroll:get_panel():create_custom_control(RaidGUIControlSingleSelectList, {
		name = "reward_picker_popup_list",
		data_source_callback = function() return data end,
		item_class = RaidGUIControlListItemMenu,
		item_h = ITEM_H,
		on_item_clicked_callback = callback(self, self, "_reward_picker_on_item_clicked"),
		padding_top = 2,
		scrollable_area_ref = self._reward_picker_popup_scroll,
		selection_enabled = true,
		vertical_spacing = 2,
		w = self._reward_picker_popup_scroll:w(),
	})

	self._reward_picker_popup_scroll:setup_scroll_area()

	-- the root panel does not cover the whole screen, fill the rest as well
	self._reward_picker_popup_dim = self._fullscreen_ws_panel:rect({
		color = Color.black:with_alpha(0.45),
		w = self._fullscreen_ws_panel:w(),
		h = self._fullscreen_ws_panel:h(),
		layer = 5000,
	})

	self._reward_picker_popup_list:select_item_by_index(1, true, true)

	self:_reward_picker_touch()
	self._reward_picker_popup:get_engine_panel():animate(function()
		while true do
			-- seconds without mouse movement or arrow keys -> random (vanilla), 0 = never
			local timeout = RewardPicker._config.timeout
			if timeout > 0 and Application:time() - self._reward_picker_last_activity > timeout then
				self:_reward_picker_choose("off")
				return
			end
			coroutine.yield()
		end
	end)

	-- ESC = random (vanilla)
	self._reward_picker_prev_escape_callback = managers.raid_menu._component_on_escape_callback
	managers.raid_menu:register_on_escape_callback(function()
		self:_reward_picker_choose("off")
		return true
	end)
end

function LootScreenGui:_reward_picker_touch()
	self._reward_picker_last_activity = Application:time()
end

function LootScreenGui:_reward_picker_close_popup()
	if self._reward_picker_popup then
		if self._reward_picker_popup_dim then
			self._fullscreen_ws_panel:remove(self._reward_picker_popup_dim)
			self._reward_picker_popup_dim = nil
		end
		managers.raid_menu:register_on_escape_callback(self._reward_picker_prev_escape_callback)
		self._reward_picker_prev_escape_callback = nil

		-- RaidGUIPanel:remove() cannot handle nested RaidGUIPanels (nil _object), so unregister it by hand
		local popup = self._reward_picker_popup
		popup:clear()
		table.delete(self._root_panel._controls, popup)
		self._root_panel:get_engine_panel():remove(popup:get_engine_panel())
		self._reward_picker_popup = nil
		self._reward_picker_popup_scroll = nil
		self._reward_picker_popup_list = nil
	end
end

function LootScreenGui:_reward_picker_on_item_clicked(data)
	self:_reward_picker_choose(data.value)
end

function LootScreenGui:_reward_picker_choose(kind)
	-- the click comes from inside the popup, so remove it one frame later
	managers.queued_tasks:queue(nil, function()
		if not self._reward_picker_popup then
			return
		end
		self:_reward_picker_close_popup()
		managers.lootdrop:reward_picker_resolve(kind)
		-- on_loot_dropped_for_player only forwards the drop while the loot screen is the active screen
		self:set_local_loot_drop(managers.lootdrop:get_dropped_loot())
	end, self, nil, 0.05)
end

-- while the popup is open, it is the only thing that gets mouse input
local function popup_input(name, original)
	LootScreenGui[name] = function(self, o, ...)
		local popup = self._reward_picker_popup
		if popup then
			if name == "mouse_moved" then
				self:_reward_picker_touch()
			end

			local button = ...
			if name == "mouse_pressed" and button == Idstring("mouse wheel up") then
				return popup:mouse_scroll_up(o, ...)
			elseif name == "mouse_pressed" and button == Idstring("mouse wheel down") then
				return popup:mouse_scroll_down(o, ...)
			end

			local used, pointer = popup[name](popup, o, ...)
			return used or true, pointer
		end

		if original then
			return original(self, o, ...)
		end
	end
end

for _, name in ipairs({ "mouse_moved", "mouse_pressed", "mouse_clicked", "mouse_double_click", "mouse_released" }) do
	popup_input(name, LootScreenGui[name])
end

-- keyboard / controller: while the popup is open it is the only thing that reacts
function LootScreenGui:_reward_picker_popup_move(delta)
	self:_reward_picker_touch()

	local list = self._reward_picker_popup_list
	local count = #list._list_items
	local idx = ((list._selected_item_idx or (delta > 0 and 0 or 1)) - 1 + delta) % count + 1

	list:select_item_by_index(idx, true, true)
	list:_reposition_selected_item()
end

local function popup_key(name, handler)
	local original = LootScreenGui[name]
	LootScreenGui[name] = function(self, ...)
		if self._reward_picker_popup then
			if handler then
				handler(self, ...)
			end
			return true
		end

		if original then
			return original(self, ...)
		end
	end
end

local function popup_confirm(self)
	local idx = self._reward_picker_popup_list._selected_item_idx
	if idx then
		self._reward_picker_popup_list:click_item(idx)
	end
end

popup_key("move_up", function(self) self:_reward_picker_popup_move(-1) end)
popup_key("move_down", function(self) self:_reward_picker_popup_move(1) end)
popup_key("move_left")
popup_key("move_right")
popup_key("scroll_up", function(self) self:_reward_picker_popup_move(-1) end)
popup_key("scroll_down", function(self) self:_reward_picker_popup_move(1) end)
popup_key("scroll_left")
popup_key("scroll_right")
popup_key("confirm_pressed", popup_confirm)
-- Enter arrives as the "A" button (face_bottom) of the menu controller, not as confirm_pressed
popup_key("special_btn_pressed", function(self, button)
	if button == Idstring("menu_controller_face_bottom") then
		popup_confirm(self)
	end
end)
