#include "script/lib/HSVRGB.lua"
#include "script/Defs.lua"
#include "script/Utils.lua"
#include "script/GameOptions.lua"
#include "script/Migrations.lua"
#include "script/PyroField.lua"
#include "script/InitTools.lua"
#include "script/Bomb.lua"
#include "script/Thrower.lua"
#include "script/Rocket.lua"
#include "script/Booster.lua"
#include "script/Mapping.lua"

------------------------------------------------
-- INIT
-------------------------------------------------
function init()
	RegisterTool(REG.TOOL_KEY, TOOL_NAME, "MOD/vox/thrower.vox", 5)
	SetBool("game.tool."..REG.TOOL_KEY..".enabled", true)
	SetFloat("game.tool."..REG.TOOL_KEY..".ammo", 1000)
	
	-- setting to true will skip all PyroField and tool ticks. Used to
	-- debug some issues so the debug console doesn't scroll the error
	-- away. 
	suspend_ticks = false

	rumble_sound = LoadSound("MOD/snd/rumble.ogg")
	thrower_sound = LoadLoop("MOD/snd/thrower.ogg")

	-- rate per second you're allowed to plant bombs
	plant_rate = 1
	plant_timer = 0
	thruster_spawn_rate = 1
	thruster_timer = 0
	boom_timer = 0
	action_timer = 0
	action_rate = 3
	action_mode = false
	primary_shoot_timer = 0
	secondary_shoot_timer = 0
	-- prevent shooting while the player is grabbing things, etc
	shoot_lock = false

	-- option sets are the paramters for each subtool
	load_option_sets()

	-- init the field used for shock waves
	init_shock_field(boomness.tactical, 0.01)

	-- init the booster force field
	init_boost_field()

	-- true while the player has the options editor open
	editing_options = false
	option_page = 1

	DEBUG_MODE = false
end

-------------------------------------------------
-- Drawing
-------------------------------------------------

function draw(dt)
	if action_mode then 
		UiPush()
			UiTranslate(UiCenter(), 27)
			UiAlign("center")
			UiFont("bold.ttf", 25)
			UiTextOutline(0,0,0,1,1)
			UiColor(1,0,0)
			UiText("DANGER ! ACTION MOVIE MODE ON ! DANGER")
		UiPop()
	end

	if GetString("game.player.tool") ~= REG.TOOL_KEY or
		GetPlayerVehicle() ~= 0 then return end
	
	if editing_options then
		draw_option_modal()
	end

	-- on screen display to help the player remember what keys do what
	UiPush()
		UiTranslate(0, UiHeight() - UI.OPTION_TEXT_SIZE * 6)
		UiAlign("left")
		UiFont("bold.ttf", UI.OPTION_TEXT_SIZE)
		UiTextOutline(0,0,0,1,0.5)
		UiColor(1,1,1)
		UiText(KEY.PLANT_BOMB.key.." to plant bomb", true)
		UiText(KEY.DETONATE.key.." to detonate", true)
		UiText(KEY.OPTIONS.key.." for options", true)
		UiText(KEY.STOP_FIRE.key.." to stop all flame effects", true)
		UiText(KEY.RANDOM_BOOM.key.." to randomly explode something in your area", true)
		UiText(KEY.ACTION_MOVIE.key.. " = DANGER !! ACTION MOVIE MODE ON/OFF")
	UiPop()

	if DEBUG_MODE then 
		-- Debug display
		UiPush()
				UiTranslate(UiWidth() - 10, UiHeight() - UI.OPTION_TEXT_SIZE * 6)
				UiAlign("right")
				UiFont("bold.ttf", UI.OPTION_TEXT_SIZE)
				UiTextOutline(0,0,0,1,0.5)
				UiColor(1,1,1)
				UiText("bomb energy = "..tostring(TOOL.BOMB.pyro.ff.energy), true)
				UiText("rocket energy = "..tostring(TOOL.ROCKET.pyro.ff.energy), true)
				local num_rocket_points = "--"
				if TOOL.ROCKET.pyro.ff.field.points ~= nil then 
					num_rocket_points = #TOOL.ROCKET.pyro.ff.field.points
				end
				UiText("rocket points = "..tostring(num_rocket_points), true	)
				UiText("flamethrower energy = "..tostring(TOOL.THROWER.pyro.ff.energy), true)
				UiText("shockwave energy = "..tostring(SHOCK_FIELD.ff.energy), true)
				UiText("dt = "..tostring(dt))
		UiPop()
	end
end



-- draw the option editor
function draw_option_modal()
	local page_options = all_option_sets[option_page]
	UiMakeInteractive()
	UiPush()
		local margins = {}
		margins.x0, margins.y0, margins.x1, margins.y1 = UiSafeMargins()

		local box = {
			width = (margins.x1 - margins.x0) - 300,
			height = (margins.y1 - margins.y0) - 200
		}

		UiModalBegin()
			UiAlign("left top")
			UiFont("bold.ttf", UI.OPTION_TEXT_SIZE)
			UiTextOutline(0,0,0,1,0.5)
			UiColor(1,1,1)
			UiPush()
				-- borders and background
				UiTranslate(UiCenter(), UiMiddle())
				UiAlign("center middle")
				UiColor(1, 1, 1)
				UiRect(box.width + 5, box.height + 5)
				UiColor(0.2, 0.2, 0.2)
				UiRect(box.width, box.height)
			UiPop()
			UiPush()
				-- options
				UiTranslate(200, 220)
				UiAlign("left top")
				UiPush()
					for i = 1, #page_options.options do
						local option = page_options.options[i]
						draw_option(option)
						if math.fmod(i, 7) == 0 then 
							UiPop()
							UiTranslate(UI.OPTION_CONTROL_WIDTH, 0)
							UiPush()
						else
							UiTranslate(0, 100)
						end
					end
				UiPop()
			UiPop()
			UiPush()
				-- title
				UiAlign("center middle")
				UiTranslate(UiCenter(), 140)
				UiFont("bold.ttf", UI.OPTION_MODAL_HEADING_SIZE)
				UiText("Options: "..page_options.display_name)
			UiPop()
			UiPush()
				-- instructions
				UiAlign("center middle")
				UiTranslate(UiCenter(), UiHeight() - 140)
				UiFont("bold.ttf", UI.OPTION_MODAL_HEADING_SIZE)
				UiText("Press [Return/Enter] to save, [Backspace] to cancel, [Delete] to reset to defaults")
			UiPop()
			if option_page > 1 then 
				UiPush()
					-- page back
					UiTranslate(UiCenter(), UiHeight() - 150)
					UiAlign("left")
					UiTranslate((box.width / -2) + 10, -10)
					if UiImageButton("MOD/img/left.png") then
						option_page = option_page -1
					end
					UiTranslate(30, 20)
					UiText("Page back")
				UiPop()
			end
			if option_page < #all_option_sets then
				UiPush()
					-- page next
					UiTranslate(UiCenter(), UiHeight() - 150)
					UiAlign("right")
					UiTranslate((box.width / 2) - 10, -10)
					if UiImageButton("MOD/img/right.png") then
						option_page = option_page + 1
					end
					UiTranslate(-30, 20)
					UiText("Page next")
				UiPop()
			end
			-- SAVE OPTIONS
			if InputPressed("return") then 
				save_option_sets()
				load_option_sets()
				editing_options = false 
			end
			-- DISCARD CHANGES
			if InputPressed("backspace") then
				load_option_sets()
				editing_options = false
			end
			-- REVERT TO DEFAULTS
            if InputPressed("delete") then
                option_set_reset(page_options.name)
				load_option_sets()
            end
		UiModalEnd()
	UiPop()
end

function draw_option(option)
	UiPush()
		UiPush()
			-- label and value
			UiAlign("left middle")
			UiFont("bold.ttf", UI.OPTION_TEXT_SIZE)
			local line = option.friendly_name.." = "
			if option.type == option_type.color then
				UiText(line)
				local sampleColor = HSVToRGB(option.value) 
				UiColor(sampleColor[1], sampleColor[2], sampleColor[3])
				UiTranslate(UiGetTextSize(line), 0)
				UiRect(50,20)
			elseif option.type == option_type.enum then
				UiText(line..get_enum_key(option.value, option.accepted_values))
			elseif option.type == option_type.bool then
				UiText(line..tostring(option.value))
			else
				UiText(line..round_to_place(option.value, 3))
			end
		UiPop()
		UiPush()
			-- control
			UiAlign("left")
			UiTranslate(0,30)
			local value = make_option_control(option, UI.OPTION_CONTROL_WIDTH)
			mode_option_set_value(option, value)
		UiPop()
	UiPop()
end

function make_option_control(option, width)
	local k = get_keys_and_values(option.accepted_values)
	local enum_value_count = #k
	UiPush()
		-- convert the value to a slider fraction [0,1]
		local value = option.value
		if option.type == option_type.enum then
			value = range_value_to_fraction(value, 1, enum_value_count)
		elseif option.type == option_type.numeric then 
			value = range_value_to_fraction(value, option.range.lower, option.range.upper)
		elseif option.type == option_type.bool then
			local convert = {[false]=0, [true]=1}
			value = convert[value]
		end

		-- generate controls
		local color_hue, color_saturation, color_value
		local bump_amount = 0
		if option.type == option_type.color then
			color_hue = draw_slider(value[1]/359, UI.OPTION_COLOR_SLIDER_WIDTH, "H", 15)
			UiTranslate(0, 20)
			color_saturation = draw_slider(value[2], UI.OPTION_COLOR_SLIDER_WIDTH, "S", 15)
			UiTranslate(0, 20)
			color_value = draw_slider(value[3], UI.OPTION_COLOR_SLIDER_WIDTH, "V", 15)
		else
			UiTranslate(15,0)
			value = draw_slider(value, UI.OPTION_STANDARD_SLIDER_WIDTH)
			UiTranslate(-15,-15)
			if UiImageButton("MOD/img/up.png") then
				bump_amount = option.step				
			end
			UiTranslate(0, 15)
			if UiImageButton("MOD/img/down.png") then
				bump_amount = 0 - option.step
			end
		end

		-- convert back to an appropriate value
		if option.type == option_type.numeric then 
			local range = option.range.upper - option.range.lower
			value = (value * range) + option.range.lower
			value = round_to_interval(value, option.step)
			value = bracket_value(value + bump_amount, option.range.upper, option.range.lower)
		elseif option.type == option_type.enum then 
			local range = enum_value_count - 1
			value = round((value * range) + 1)
			value = bracket_value(value + bump_amount, enum_value_count, 1)
		elseif option.type == option_type.color then
			value = Vec(color_hue*359, color_saturation, color_value)
		elseif option.type == option_type.bool then
			if 1-value > 0.5 then value = false else value = true end
		end

	UiPop()
	return value
end

function draw_slider(value, width, label, label_width)
	local returnValue = nil
	UiPush()
		UiAlign("left middle")
		local control_width = width
		if label ~= nil then
			if label_width == nil then 
				local label_width, _ = UiGetTextSize(label)
			end
			local control_width = width - 5 - label_width
			UiText(label)
			UiTranslate(label_width + 5, 0)
		else
			control_width = width
		end
		UiTranslate(8,0)
		UiRect(control_width, 2)
		UiTranslate(-8,0)
		local return_value = UiSlider("ui/common/dot.png", "x", value * control_width, 0, control_width) / control_width
	UiPop()
	return return_value
end

-------------------------------------------------
-- TICK and UPDATE
-------------------------------------------------

function update(dt)
	if not suspend_ticks then 
		flame_tick(TOOL.BOMB.pyro, dt)
		flame_tick(TOOL.THROWER.pyro, dt)
		flame_tick(TOOL.ROCKET.pyro, dt)
		flame_tick(SHOCK_FIELD, dt)
		flame_tick(BOOST_FIELD, dt)
		rocket_tick(dt)
		thrower_tick(dt)
		booster_tick(dt)
	end
end

function tick(dt)
	handle_input(dt)

	if GetPlayerHealth() == 0 then
		action_mode = false 
	end

	if action_mode and
	#TOOL.BOMB.pyro.flames == 0 then
		action_timer = action_rate
		local tries = 1000
		local player_trans = GetPlayerTransform()
		while tries > 0 do
			local dir = VecNormalize(Vec(random_vec_component(1), 0, random_vec_component(1)))
			local pos = VecAdd(player_trans.pos, VecScale(dir, TOOL.BOMB.min_random_radius.value))
			local pos = VecAdd(pos, Vec(0, 1, 0))
			local hit = QueryClosestPoint(pos, 0.5)
			if not hit then
				blast_at(pos)
				break
			end
		end
	end
end

-------------------------------------------------
-- Input handler
-------------------------------------------------

function handle_input(dt)
	if editing_options then return end
	plant_timer = math.max(plant_timer - dt, 0)
	thruster_timer = math.max(thruster_timer - dt, 0)
	boom_timer = math.max(boom_timer - dt, 0)
	action_timer = math.max(action_timer - dt, 0)
	primary_shoot_timer = math.max(primary_shoot_timer - dt, 0)
	secondary_shoot_timer = math.max(secondary_shoot_timer - dt, 0)

	if GetString("game.player.tool") == REG.TOOL_KEY  then 
		--action mode toggle
		if InputPressed(KEY.ACTION_MOVIE.key) then
			action_mode = not action_mode
		end
		if GetPlayerVehicle() == 0 then 

			-- options menus
			if InputPressed(KEY.OPTIONS.key) then 
				editing_options = true
			else
				-- plant bomb
				if plant_timer == 0 and
				InputPressed(KEY.PLANT_BOMB.key) then
					local camera = GetPlayerCameraTransform()
					local drop_pos = TransformToParentPoint(camera, Vec(0.2, -0.2, -1.25))
					local bomb = Spawn("MOD/prefab/pyro_bomb.xml", Transform(drop_pos))[2]
					table.insert(bombs, bomb)
					plant_timer = plant_rate
				end
				
				-- end all flame effects
				if InputPressed(KEY.STOP_FIRE.key) then
					stop_all_flames()
				end
			
				-- detonate bomb
				if InputPressed(KEY.DETONATE.key) then
					detonate_all()
				end

				-- Random boom
				if boom_timer == 0 and
				InputPressed(KEY.RANDOM_BOOM.key) then
					local player_trans = GetPlayerTransform()
					set_spawn_area_parameters(player_trans.pos, TOOL.BOMB.max_random_radius.value)
					local boom_pos = find_spawn_location(player_trans.pos, TOOL.BOMB.min_random_radius.value)
					boom_pos = VecAdd(boom_pos, Vec(spawn_block_h_size/2,0,spawn_block_h_size/2))
					blast_at(boom_pos)
					boom_timer = 1
				end

				-- spawn/launch booster
				if InputPressed(KEY.BOOSTER.key) then
					if P_BOOSTER.booster == nil then 
						spawn_booster()
					else
						booster_ignition()
					end
				end

				--primary fire
				if not shoot_lock and
				primary_shoot_timer == 0 and
				InputDown("LMB") and 
				not InputDown("RMB") then
					fire_rocket()
					primary_shoot_timer = TOOL.ROCKET.rate_of_fire.value
				end
				
				-- secondary fire
				if not shoot_lock and
				GetPlayerGrabShape() == 0 and
				InputDown("RMB") and 
				not InputDown("LMB") then
					thrower_muzzle_flames()
					local trans = GetPlayerTransform()
					PlayLoop(thrower_sound, trans.pos, 50)
					if secondary_shoot_timer == 0 then
						shoot_thrower()
						secondary_shoot_timer = TOOL.THROWER.rate_of_fire.value
					end
				end
			
				-- debug mode
				if InputPressed(KEY.DEBUG.key) then
					DEBUG_MODE = not DEBUG_MODE
				end

				-- shoot lock for when the player is grabbing and 
				-- throwing things
				if GetPlayerGrabShape() ~= 0 then
					shoot_lock = true
				elseif shoot_lock == true and
				GetPlayerGrabShape() == 0 and
				not InputDown("RMB") and
				not InputDown("LMB") then
					shoot_lock = false
				end
			end
		end
	end
end

-------------------------------------------------
-- Support functions
-------------------------------------------------

function spawn_booster()
	local camera = GetPlayerCameraTransform()
	local shoot_dir = TransformToParentVec(camera, Vec(0, 0, -1))
	local rotx, roty, rotz = GetQuatEuler(camera.rot)
	local hit, dist = QueryRaycast(camera.pos, shoot_dir, 100, 0.025, true)
	if hit then
		local hit_point = VecAdd(camera.pos, VecScale(shoot_dir, dist))
		local trans = Transform(hit_point, QuatEuler(0, roty - 90,0))
		P_BOOSTER.booster = inst_booster(trans)
	end
end

function stop_all_flames()
	reset_ff(TOOL.BOMB.pyro.ff)
	reset_ff(TOOL.THROWER.pyro.ff)
	reset_ff(TOOL.ROCKET.pyro.ff)
	reset_ff(SHOCK_FIELD.ff)
	reset_ff(BOOST_FIELD.ff)
	P_BOOSTER.burn_timer = 0
end

function shock_at(pos, intensity, damage_factor)
	init_shock_field(intensity, damage_factor)
    local force_mag = SHOCK_FIELD.ff.graph.max_force
    local fireball_rad = 2
    local explosion_seeds = 1000
    for i = 1, explosion_seeds do
        local spawn_dir = VecNormalize(random_vec(1))
        local spark_offset = VecScale(spawn_dir, random_float_in_range(0, fireball_rad))
        local spark_pos = VecAdd(pos, spark_offset)
        local force_dir = VecNormalize(VecSub(spark_pos, pos))
        local hit, dist = QueryRaycast(pos, force_dir, spark_offset, 0.025)
        if hit then
            local spark_pos = VecAdd(pos, VecScale(force_dir, dist - 0.1)) 
        end
        local spark_vec = VecScale(force_dir, force_mag)
        apply_force(SHOCK_FIELD.ff, spark_pos, spark_vec)
    end
end