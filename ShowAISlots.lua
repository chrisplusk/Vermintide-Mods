
--
-- TODO
--
-- show slot count at portraits instead of console
-- settings
--   hide inaccessible slots?
-- cleaner looks
--	 fixed color per player?
--


local oi = OptionsInjector
 
local mod_name = "ShowAISlots"
 
ShowAISlots = {
    MOD_SETTINGS = {
        ACTIVE = {
        ["save"] = "cb_save_show_ai_slots",
        ["widget_type"] = "stepper",
        ["text"] = "Show AI Slots",
        ["tooltip"] =  "Show AI Slots\n" ..
            "Toggle showing AI slot numbers on / off.",
        ["value_type"] = "boolean",
        ["options"] = {
            {text = "Off", value = false},
            {text = "On", value = true}
        },
        ["default"] = 1, -- Default first option is enabled. In this case Off
        },
    }
}
 
local me = ShowAISlots
 
local get = function(data)
    return Application.user_setting(data.save)
end
local set = Application.set_user_setting
local save = Application.save_user_settings

-- ####################################################################################################################
-- ##### Options ######################################################################################################
-- ####################################################################################################################
 
ShowAISlots.create_options = function()
    Mods.option_menu:add_group("show_ai_slots", "Show AI Slots")
 
    Mods.option_menu:add_item("show_ai_slots", me.MOD_SETTINGS.ACTIVE, true)
end
 
-- ####################################################################################################################
-- ##### Hook #########################################################################################################
-- ####################################################################################################################

local global_ai_target_units = AI_TARGET_UNITS
local unit_alive = AiUtils.unit_alive
--
-- local constants from ai_slot_system.lua
--
local SLOT_STATUS_UPDATE_INTERVAL = 0.5
local SLOT_QUEUE_RADIUS = 1.75
local SLOT_POSITION_CHECK_INDEX = {
	CHECK_LEFT = 0,
	CHECK_RIGHT = 2,
	CHECK_MIDDLE = 1
}
local SLOT_POSITION_CHECK_RADIANS = {
	[SLOT_POSITION_CHECK_INDEX.CHECK_LEFT] = math.degrees_to_radians(-90),
	[SLOT_POSITION_CHECK_INDEX.CHECK_RIGHT] = math.degrees_to_radians(90)
}
local SLOT_RADIUS = 0.5
local NAVMESH_DISTANCE_FROM_WALL = 0.5
local MOVER_RADIUS = 0.6
local RAYCANGO_OFFSET = NAVMESH_DISTANCE_FROM_WALL + MOVER_RADIUS

local SLOT_QUEUE_DISTANCE = 2.5
local SLOT_DISTANCE = SlotSettings.distance
local PENALTY_TERM = 100
local Z_MAX_DIFFERENCE = 1.5

Mods.hook.set(mod_name, "AISlotSystem.physics_async_update", function (orig_func, self, context, t)

	if get(me.MOD_SETTINGS.ACTIVE) then

		local target_units = self.target_units
		local unit_extension_data = self.unit_extension_data
		
		debug_print_slots_count(target_units, unit_extension_data)

		local nav_world = self.nav_world
		
		debug_draw_slots(unit_extension_data, nav_world, t)
	
	end
	
	return orig_func(self, context, t)
end)

--
--local functions from ai_slot_system.lua
--

function debug_print_slots_count(target_units, unit_extension_data)
	local target_slots = target_units
	local target_slots_n = #target_units
	local target_unit_extensions = unit_extension_data
	
	EchoConsole("OCCUPIED SLOTS")

	for unit_i = 1, target_slots_n, 1 do
		local target_unit = target_units[unit_i]
		local target_unit_extension = target_unit_extensions[target_unit]
		local player_manager = Managers.player
		local owner_player = player_manager.owner(player_manager, target_unit)
		local display_name = nil

		if owner_player then
			display_name = owner_player.profile_display_name(owner_player)
		else
			display_name = tostring(target_unit)
		end

		local disabled_slots_count = target_unit_extension.disabled_slots_count
		local occupied_slots = target_unit_extension.slots_count
		local total_slots_count = target_unit_extension.total_slots_count
		local enabled_slots_count = total_slots_count - disabled_slots_count
		local debug_text = string.format("%s: %d|%d(%d)", display_name, occupied_slots, enabled_slots_count, total_slots_count)

		EchoConsole(debug_text)
	end

	return 
end

function debug_draw_slots(unit_extension_data, nav_world, t)
	--local drawer = Managers.state.debug:drawer({
	--	mode = "immediate",
	--	name = "AISlotSystem_immediate"
	--})
	
	--
	local player = Managers.player:local_player()
	local world = Managers.world:world("level_world")
	local viewport = ScriptWorld.viewport(world, player.viewport_name)
	local camera = ScriptViewport.camera(viewport)
	local font = "hell_shark"
	local font_size = 30
	local scale = UIResolutionScale()
	--
	
	local targets = global_ai_target_units
	local z = Vector3.up()*0.1

	for i_target, target_unit in pairs(targets) do
		if not unit_alive(target_unit) then
		else
			local target_unit_extension = unit_extension_data[target_unit]

			if target_unit_extension then
				if not target_unit_extension.valid_target then
				else
					local target_slots = target_unit_extension.slots
					local target_slots_n = #target_unit_extension.slots
					local target_position = target_unit_extension.position:unbox()
					local target_color = Colors.get(target_unit_extension.debug_color_name)

					--drawer.circle(drawer, target_position + z, 0.5, Vector3.up(), target_color)
					--drawer.circle(drawer, target_position + z, 0.45, Vector3.up(), target_color)

					if target_unit_extension.next_slot_status_update_at then
						local percent = (t - target_unit_extension.next_slot_status_update_at)/SLOT_STATUS_UPDATE_INTERVAL

						--drawer.circle(drawer, target_position + z, percent*0.45, Vector3.up(), target_color)
					end

					for i = 1, target_slots_n, 1 do
						local slot = target_slots[i]
						local anchor_slot = get_anchor_slot(target_unit, unit_extension_data)
						local is_anchor_slot = slot == anchor_slot
						local ai_unit = slot.ai_unit
						local ai_unit_extension = nil
						local alpha = (ai_unit and 255) or 150
						local color = (slot.disabled and Colors.get_color_with_alpha("gray", alpha)) or Colors.get_color_with_alpha(slot.debug_color_name, alpha)

						if slot.absolute_position then
							local slot_absolute_position = slot.absolute_position:unbox()

							if unit_alive(ai_unit) then
								local ai_unit_position = POSITION_LOOKUP[ai_unit]
								local ai_unit_extension = unit_extension_data[ai_unit]

								--drawer.circle(drawer, ai_unit_position + z, 0.35, Vector3.up(), color)
								--drawer.circle(drawer, ai_unit_position + z, 0.3, Vector3.up(), color)

								local head_node = Unit.node(ai_unit, "c_head")
								local viewport_name = "player_1"
								local color_table = (slot.disabled and Colors.get_table("gray")) or Colors.get_table(slot.debug_color_name)
								local color_vector = Vector3(color_table[2], color_table[3], color_table[4])
								local offset_vector = Vector3(0, 0, -1)
								local text_size = 0.4
								local text = slot.index
								local category = "slot_index"

								--
								local position = Unit.world_position(ai_unit, 0)
								local position2d, depth = Camera.world_to_screen(camera, position)
								local color_ = Color(alpha, color_table[2], color_table[3], color_table[4])
								
								if depth < 1 then
									Mods.gui.text(text, position2d[1], position2d[2], 1, font_size, color_, font)
								end
								
							--	Managers.state.debug_text:clear_unit_text(ai_unit, category)
							--	Managers.state.debug_text:output_unit_text(text, text_size, ai_unit, head_node, offset_vector, nil, category, color_vector, viewport_name)

								if slot.ghost_position.x ~= 0 and not slot.disable_at then
									local ghost_position = slot.ghost_position:unbox()

									--drawer.line(drawer, ghost_position + z, slot_absolute_position + z, color)
									--drawer.sphere(drawer, ghost_position + z, 0.3, color)
									--drawer.line(drawer, ghost_position + z, ai_unit_position + z, color)
								else
									--drawer.line(drawer, slot_absolute_position + z, ai_unit_position + z, color)
								end
							end

							local text_size = 0.4
							local color_table = (slot.disabled and Colors.get_table("gray")) or Colors.get_table(slot.debug_color_name)
							local color_vector = Vector3(color_table[2], color_table[3], color_table[4])
							local category = "slot_index_" .. slot.index .. "_" .. i_target

							--
							local position2d, depth = Camera.world_to_screen(camera, slot_absolute_position)
							local color_ = Color(alpha, color_table[2], color_table[3], color_table[4])
							
							if depth < 1 then
								Mods.gui.text(slot.index, position2d[1], position2d[2], 1, font_size, color_, font)
							end
							
							--Managers.state.debug_text:clear_world_text(category)
							--Managers.state.debug_text:output_world_text(slot.index, text_size, slot_absolute_position + z, nil, category, color_vector)
							--drawer.circle(drawer, slot_absolute_position + z, 0.5, Vector3.up(), color)
							--drawer.circle(drawer, slot_absolute_position + z, 0.45, Vector3.up(), color)

							local slot_queue_position = get_slot_queue_position(unit_extension_data, slot, nav_world)

							if slot_queue_position then
								--drawer.circle(drawer, slot_queue_position + z, SLOT_QUEUE_RADIUS, Vector3.up(), color)
								--drawer.circle(drawer, slot_queue_position + z, SLOT_QUEUE_RADIUS - 0.05, Vector3.up(), color)
								--drawer.line(drawer, slot_absolute_position + z, slot_queue_position + z, color)

								local queue = slot.queue
								local queue_n = #queue

								for i = 1, queue_n, 1 do
									local ai_unit_waiting = queue[i]
									local ai_unit_position = POSITION_LOOKUP[ai_unit_waiting]

									--drawer.circle(drawer, ai_unit_position + z, 0.35, Vector3.up(), color)
									--drawer.circle(drawer, ai_unit_position + z, 0.3, Vector3.up(), color)
									--drawer.line(drawer, slot_queue_position + z, ai_unit_position, color)
								end
							end

							if slot.released then
								local color = Colors.get("green")

								--drawer.sphere(drawer, slot_absolute_position + z, 0.2, color)
							end

							if is_anchor_slot then
								local color = Colors.get("red")

								--drawer.sphere(drawer, slot_absolute_position + z, 0.3, color)
							end

							local check_index = slot.position_check_index
							local check_position = slot_absolute_position

							if check_index == SLOT_POSITION_CHECK_INDEX.CHECK_MIDDLE then
							else
								local radians = SLOT_POSITION_CHECK_RADIANS[check_index]
								check_position = rotate_position_from_origin(check_position, target_position, radians, SLOT_RADIUS)
							end

							local ray_from_pos = target_position + Vector3.normalize(check_position - target_position)*RAYCANGO_OFFSET

							--drawer.line(drawer, ray_from_pos + z, check_position + z, color)
							--drawer.circle(drawer, check_position + z, 0.1, Vector3.up(), Color(255, 0, 255))
						end
					end
				end
			end
		end
	end

	return 
end

function get_anchor_slot(target_unit, unit_extension_data)
	local target_unit_extension = unit_extension_data[target_unit]
	local target_slots = target_unit_extension.slots
	local total_slots_count = target_unit_extension.total_slots_count
	local best_slot = target_slots[1]
	local best_anchor_weight = best_slot.anchor_weight

	for i = 1, total_slots_count, 1 do
		local slot = target_slots[i]
		local slot_disabled = slot.disabled

		if slot_disabled then
		else
			local slot_anchor_weight = slot.anchor_weight

			if best_anchor_weight < slot_anchor_weight or (slot_anchor_weight == best_anchor_weight and slot.index < best_slot.index) then
				best_slot = slot
				best_anchor_weight = slot_anchor_weight
			end
		end
	end

	return best_slot
end

function get_slot_queue_position(unit_extension_data, slot, nav_world, distance_modifier)
	local target_unit = slot.target_unit
	local ai_unit = slot.ai_unit

	if not unit_alive(target_unit) or not unit_alive(ai_unit) then
		return 
	end

	local target_unit_extension = unit_extension_data[target_unit]
	local target_unit_position = target_unit_extension.position:unbox()
	local ai_unit_position = POSITION_LOOKUP[ai_unit]
	local slot_queue_direction = slot.queue_direction:unbox()
	local slot_queue_distance_modifier = distance_modifier or 0
	local target_to_ai_distance = Vector3.distance(target_unit_position, ai_unit_position)
	local slot_queue_distance = target_to_ai_distance + SLOT_QUEUE_DISTANCE + slot_queue_distance_modifier
	local slot_queue_position = target_unit_position + slot_queue_direction*slot_queue_distance
	local slot_queue_position_on_navmesh = clamp_position_on_navmesh(slot_queue_position, nav_world)
	local max_tries = 5
	local i = 1

	while not slot_queue_position_on_navmesh and i <= max_tries do
		slot_queue_distance = math.max(target_to_ai_distance*(i/max_tries - 1), SLOT_DISTANCE) + SLOT_QUEUE_DISTANCE + slot_queue_distance_modifier
		slot_queue_position = target_unit_position + slot_queue_direction*slot_queue_distance
		slot_queue_position_on_navmesh = clamp_position_on_navmesh(slot_queue_position, nav_world)
		i = i + 1
	end

	local penalty_term = 0

	if not slot_queue_position_on_navmesh then
		penalty_term = PENALTY_TERM
		slot_queue_position = target_unit_position + slot_queue_direction*SLOT_QUEUE_DISTANCE

		return slot_queue_position, penalty_term
	else
		return slot_queue_position_on_navmesh, penalty_term
	end

	return 
end
function clamp_position_on_navmesh(position, nav_world, above, below)
	below = below or Z_MAX_DIFFERENCE
	above = above or Z_MAX_DIFFERENCE
	local position_on_navmesh = nil
	local is_on_navmesh, altitude = GwNavQueries.triangle_from_position(nav_world, position, above, below)

	if is_on_navmesh then
		position_on_navmesh = Vector3.copy(position)
		position_on_navmesh.z = altitude
	end

	return (is_on_navmesh and position_on_navmesh) or nil
end
function rotate_position_from_origin(origin, position, radians, distance)
	local direction_vector = Vector3.normalize(Vector3.flat(position - origin))
	local rotation = Quaternion(-Vector3.up(), radians)
	local vector = Quaternion.rotate(rotation, direction_vector)
	local position_rotated = origin + vector*distance

	return position_rotated
end



-- ####################################################################################################################
-- ##### Start ########################################################################################################
-- ####################################################################################################################
me.create_options()