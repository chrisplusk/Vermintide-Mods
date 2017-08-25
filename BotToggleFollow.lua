local mod_name = "BotToggleFollow"

local oi = OptionsInjector

BotToggleFollow = {
	SETTINGS = {
		FOLLOW = {
			["save"] = "cb_follow_host",
			["widget_type"] = "stepper",
			["text"] = "Follow the host",
			["tooltip"] =  "Follow Host\n" ..
				"Bots will prioritize following the host.",
			["value_type"] = "boolean",
			["options"] = {
				{text = "Off", value = false},
				{text = "On", value = true},
			},
			["default"] = 1, -- Default first option is enabled. In this case Off
			["hide_options"] = {
				{
					1,
					mode = "hide",
					options = {
						"cb_bot_improvements_follow_stay_hotkey",
					}
				},
				{
					2,
					mode = "show",
					options = {
						"cb_bot_improvements_follow_stay_hotkey",
					}
				},
			},
		},
			
		FOLLOW_STAY_HOTKEY = {
			["save"] = "cb_bot_improvements_follow_stay_hotkey",
			["widget_type"] = "modless_keybind",
			["text"] = "Toggle Follow or Stay",
			["default"] = {
				"numpad .",
			},
		},
		FOLLOW_STAY_TOGGLE = false
	},
}

local me = BotToggleFollow

local get = function(data)
	return Application.user_setting(data.save)
end
local set = Application.set_user_setting
local save = Application.save_user_settings

-- ############################################################################################################
-- ##### Options ##############################################################################################
-- ############################################################################################################
--[[
	Create options
--]]
BotToggleFollow.create_options = function()
--	Mods.option_menu:add_group("bot_improvements", "Bot Improvements")

	Mods.option_menu:add_item("bot_improvements", me.SETTINGS.FOLLOW, true)

	Mods.option_menu:add_item("bot_improvements", me.SETTINGS.FOLLOW_STAY_HOTKEY, true)
end

Mods.hook.set(mod_name, "AISystem.update_brains", function (func, self, ...)
	local result = func(self, ...)

	if (Keyboard.button(Keyboard.button_index(get(me.SETTINGS.FOLLOW_STAY_HOTKEY) or "numpad .")) > 0.5) then
		me.SETTINGS.FOLLOW_STAY_TOGGLE = not me.SETTINGS.FOLLOW_STAY_TOGGLE
	end
	
	return result
end)


me.stay_points = {}

Mods.hook.set(mod_name, "BotImprovements.generate_points",
function (func, ai_bot_group_system, player)
	local points = func(ai_bot_group_system, player)
	
	if me.SETTINGS.FOLLOW_STAY_TOGGLE then
		points = {}
		for i,v in next,me.stay_points,nil do 
			points[i] = Vector3(v[1], v[2], v[3])
		end
	else
		for i,v in next,points,nil do 
			me.stay_points[i] = Vector3Box(v[1], v[2], v[3])
		end
	end
	
	return points
end)

Mods.hook.set(mod_name, "AIBotGroupSystem._assign_destination_points",
function (func, self, bot_ai_data, points, follow_unit, follow_unit_table)
	if not me.SETTINGS.FOLLOW_STAY_TOGGLE then
		func(self, bot_ai_data, points, follow_unit, follow_unit_table)
	end
	
end)

Mods.hook.set(mod_name, "BTBotTeleportToAllyAction.run",
function (func, self, unit, blackboard, t, dt)
	if not me.SETTINGS.FOLLOW_STAY_TOGGLE then
		return func(self, unit, blackboard, t, dt)
	end
	
	return "done"
end)

-- ####################################################################################################################
-- ##### Start ########################################################################################################
-- ####################################################################################################################
me.create_options()