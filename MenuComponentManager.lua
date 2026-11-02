-- MenuComponentManager hands keyboard input to *all* active components, in pairs() order, and stops at the
-- first one that handles it. So while the reward popup is open, it has to be served before that loop.
local function popup_gui(self)
	local gui = self._raid_menu_loot_gui
	return gui and gui._reward_picker_popup and gui
end

for _, name in ipairs({
	"move_up", "move_down", "move_left", "move_right",
	"scroll_up", "scroll_down", "scroll_left", "scroll_right",
	"confirm_pressed", "special_btn_pressed",
}) do
	local original = MenuComponentManager[name]

	MenuComponentManager[name] = function(self, ...)
		local gui = popup_gui(self)
		if gui then
			return gui[name](gui, ...)
		end

		if original then
			return original(self, ...)
		end
	end
end
