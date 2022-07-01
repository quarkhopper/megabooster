#include "script/lib/HSVRGB.lua"
#include "script/Defs.lua"
#include "script/Utils.lua"
#include "script/GameOptions.lua"
#include "script/Migrations.lua"
#include "script/PyroField.lua"
#include "script/InitTools.lua"
#include "script/Booster.lua"

------------------------------------------------
-- INIT
-------------------------------------------------
function init()
	RegisterTool(REG.TOOL_KEY, TOOL_NAME, nil, 5)
	SetBool("game.tool."..REG.TOOL_KEY..".enabled", true)
	SetFloat("game.tool."..REG.TOOL_KEY..".ammo", 1000)
	
	-- setting to true will skip all PyroField and tool ticks. Used to
	-- debug some issues so the debug console doesn't scroll the error
	-- away. 
	suspend_ticks = false

	primary_shoot_timer = 0
	secondary_shoot_timer = 0
	primary_shoot_delay = 0.5
	-- secondary_shoot_delay = 0.5
	-- prevent shooting while the player is grabbing things, etc
	shoot_lock = false

	-- option sets are the paramters for each subtool
	load_option_sets()

	-- true while the player has the options editor open
	editing_options = false
	option_page = 1

	DEBUG_MODE = false
end

-------------------------------------------------
-- Drawing
-------------------------------------------------

function draw(dt)
	if GetString("game.player.tool") ~= REG.TOOL_KEY or
		GetPlayerVehicle() ~= 0 then return end
	
	if editing_options then
		draw_option_modal()
	end

	-- on screen display to help the player remember what keys do what
	UiPush()
		UiTranslate(0, UiHeight() - UI.OPTION_TEXT_SIZE * 5)
		UiAlign("left")
		UiFont("bold.ttf", UI.OPTION_TEXT_SIZE)
		UiTextOutline(0,0,0,1,0.5)
		UiColor(1,1,1)
		UiText("Left click to place booster", true)
		UiText(KEY.CLEAR.key.." to clear all boosters", true)
		UiText(KEY.IGNITION.key.." for ignition toggle", true)
		UiText(KEY.OPTIONS.key.." for booster options", true)
		UiText(KEY.DEBUG.key.." for physics debug")
	UiPop()

	if DEBUG_MODE then 
		-- Debug display
		UiPush()
			UiTranslate(UiWidth() - 10, UiHeight() - UI.OPTION_TEXT_SIZE * 2 )
			UiAlign("right")
			UiFont("bold.ttf", UI.OPTION_TEXT_SIZE)
			UiTextOutline(0,0,0,1,0.5)
			UiColor(1,1,1)
			UiText("field energy = "..tostring(TOOL.BOOSTER.pyro.ff.energy), true)
			local num_field_points = TOOL.BOOSTER.pyro.ff.num_points
			UiText("field points = "..tostring(num_field_points), true)
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
		if TOOL.BOOSTER.pyro == nil then suspend_ticks = true end
		flame_tick(TOOL.BOOSTER.pyro, dt)
		booster_tick(dt)
	end
end

function tick(dt)
	handle_input(dt)
end

-------------------------------------------------
-- Input handler
-------------------------------------------------

function handle_input(dt)
	if editing_options then return end
	primary_shoot_timer = math.max(primary_shoot_timer - dt, 0)
	-- secondary_shoot_timer = math.max(secondary_shoot_timer - dt, 0)

	if GetString("game.player.tool") == REG.TOOL_KEY  then 
		if GetPlayerVehicle() == 0 then 

			-- options menus
			if InputPressed(KEY.OPTIONS.key) then 
				editing_options = true
			else
				-- clear all boosters
				if InputPressed(KEY.CLEAR.key) then
					clear_boosters()
				end

				--primary fire
				if not shoot_lock and
				primary_shoot_timer == 0 and
				InputDown("LMB") and 
				not InputDown("RMB") then
					spawn_booster()
					primary_shoot_timer = primary_shoot_delay
				end
				
				-- ignition
				if InputPressed(KEY.IGNITION.key) then
					if #boosters > 0 then
						booster_ignition_toggle()
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

