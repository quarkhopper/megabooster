#include "ForceField.lua"

function create_option_set()
	local inst = {}
	inst.name = "Unnamed"
	inst.display_name = "Unnamed option set"
	inst.version = CURRENT_VERSION
	inst.options = {}

	return inst
end

function option_set_to_string(inst)
	local ser_parts = {inst.name, inst.display_name, inst.version}
	for i = 1, #inst.options do
		ser_parts[#ser_parts + 1] = mode_option_to_string(inst.options[i])
	end
	return join_strings(ser_parts, DELIM.OPTION_SET)
end

function save_option_set(inst)
	if inst.name == "" or inst.name == nil then return end
	SetString(REG.PREFIX_TOOL_OPTIONS.."."..inst.name, option_set_to_string(inst))
end

function load_option_set(name, create_if_not_found)
	local ser = GetString(REG.PREFIX_TOOL_OPTIONS.."."..name)
	if ser == "" or not can_migrate(ser) then
		if create_if_not_found then
			local test = create_option_set_by_name(name)
			return test
		else 
			return nil
		end
	end
	ser = migrate_option_set(ser)
	local options = option_set_from_string(ser)
	options.name = name
	return options
end

function option_set_from_string(ser)
	local options = create_option_set()
	options.options = {}
	local option_sers = split_string(ser, DELIM.OPTION_SET)
	options.name = option_sers[1]
	options.display_name = option_sers[2]
	options.version = option_sers[3]
	local parse_start_index = 4
	for i = parse_start_index, #option_sers do
		local option_ser = option_sers[i]
		local option = mode_option_from_string(option_ser)
		options[option.key] = option
		table.insert(options.options, option)
	end
	return options
end

function reset_all_options()
	-- This is an emergency reset that the main menu option screen uses.
	-- it does not rely on the TOOL globals being loaded.
	local option_set_keys = {"general", "booster"}
	for i = 1, #option_set_keys do
		option_set_reset(option_set_keys[i])
	end
end

function option_set_reset(name)
	ClearKey(REG.PREFIX_TOOL_OPTIONS.."."..name)
end

function create_mode_option(o_type, value, key, friendly_name)
	local inst = {}
	inst.type = o_type or option_type.numeric
	inst.value = value
	inst.range = {}
	inst.range.upper = 1
	inst.range.lower = 0
	inst.step = 1
	inst.accepted_values = {}
	inst.key = key or "unnamed_option"
	inst.friendly_name = friendly_name or "Unnamed option"

	return inst
end

function mode_option_to_string(inst)
	local parts = {}
	parts[1] = tostring(inst.type)
	if inst.type == option_type.color then
		parts[2] = vec_to_string(inst.value)
	else
		parts[2] = inst.value
	end
	parts[3] = tostring(inst.range.lower)
	parts[4] = tostring(inst.range.upper)
	parts[5] = tostring(inst.step)
	parts[6] = enum_to_string(inst.accepted_values)
	parts[7] = inst.key
	parts[8] = inst.friendly_name

	return join_strings(parts, DELIM.OPTION)
end

function mode_option_set_value(inst, value)
	if inst.type == option_type.numeric then
		inst.value = bracket_value(value, inst.range.upper, inst.range.lower) or 0
	else
		inst.value = value
	end
end

function mode_option_from_string(ser)
	local option = create_mode_option()
	local parts = split_string(ser, DELIM.OPTION)
	option.type = tonumber(parts[1])
	if option.type == option_type.bool then
		option.value = string_to_boolean[parts[2]]
	elseif option.type == option_type.color then
		option.value = string_to_vec(parts[2])
	else
		option.value = tonumber(parts[2])
	end
	
	if parts[3] ~= nil then
		option.range.lower = tonumber(parts[3])
	end
	if parts[4] ~= nil then
		option.range.upper = tonumber(parts[4])
	end
	if parts[5] ~= nil then
		option.step = tonumber(parts[5])
	end
	if parts[6] ~= nil then 
		option.accepted_values = string_to_enum(parts[6])
	end
	option.key = parts[7]
	option.friendly_name = parts[8]
	return option
end

function create_option_set_by_name(name)
	if name == "general" then
		return create_general_option_set()		
	elseif name == "booster" then 
		return create_booster_option_set()
	end
end

option_type = enum {
	"numeric",
	"enum",
	"bool",
	"color"
}

on_off = enum {
	"off",
	"on"
}

function create_general_option_set()
    local oSet = create_option_set()
    oSet.name = "general"
	oSet.display_name = "General"
    oSet.version = CURRENT_VERSION

	oSet.rainbow_mode = create_mode_option(
		option_type.enum,
		on_off.off,
		"rainbow_mode",
		"Rainbow mode")
	oSet.rainbow_mode.accepted_values = on_off
	oSet.options[#oSet.options + 1] = oSet.rainbow_mode

	return oSet
end

function create_mode_option_set(name, display_name)
    local oSet = create_option_set()
    oSet.name = name
	oSet.display_name = display_name
    oSet.version = CURRENT_VERSION
	oSet.options = {}

    oSet.flame_color_hot = create_mode_option(
		option_type.color,
		Vec(7.6, 0.6, 0.9),
		"flame_color_hot",
		"Hot flame color")
	oSet.options[#oSet.options + 1] = oSet.flame_color_hot

    oSet.flame_color_cool = create_mode_option(
		option_type.color,
		CONSTS.FLAME_COLOR_DEFAULT,
		"flame_color_cool",
		"Cool flame color")
	oSet.options[#oSet.options + 1] = oSet.flame_color_cool

	oSet.physical_damage_factor = create_mode_option(
		option_type.numeric, 
		0.1,
		"physical_damage_factor",
		"Physical damange modifier")
	oSet.physical_damage_factor.range.lower = 0
	oSet.physical_damage_factor.range.upper = 1
	oSet.physical_damage_factor.step = 0.001
	oSet.options[#oSet.options + 1] = oSet.physical_damage_factor

    return oSet
end	

function create_booster_option_set()
	local oSet = create_mode_option_set("booster", "Booster settings")

	oSet.impulse = create_mode_option(
		option_type.numeric, 
		0.1,
		"impulse",
		"Relative impulse")
	oSet.impulse.range.lower = 0
	oSet.impulse.range.upper = 1
	oSet.impulse.step = 0.001
	oSet.options[#oSet.options + 1] = oSet.impulse

	oSet.flame_density = create_mode_option(
		option_type.numeric, 
		0.2,
		"flame_density",
		"Flame density")
	oSet.flame_density.range.lower = 0
	oSet.flame_density.range.upper = 1
	oSet.flame_density.step = 0.001
	oSet.options[#oSet.options + 1] = oSet.flame_density

	oSet.flame_life = create_mode_option(
		option_type.numeric, 
		0.5,
		"flame_life",
		"Flame life")
	oSet.flame_life.range.lower = 0
	oSet.flame_life.range.upper = 1
	oSet.flame_life.step = 0.001
	oSet.options[#oSet.options + 1] = oSet.flame_life
	return oSet
end

