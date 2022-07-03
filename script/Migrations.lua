#include "Utils.lua"

function migrate_option_set(oSet)
    if oSet.name == "general" then
        if oSet.rainbow_mode == nil then 
            oSet.rainbow_mode = create_option(
                option_type.enum,
                on_off.off,
                "rainbow_mode",
                "Rainbow mode")
            oSet.rainbow_mode.accepted_values = on_off
            oSet.options["rainbow_mode"] = oSet.rainbow_mode
        end
    elseif oSet.name == "booster" then
        -- remove these
        oSet.physical_damage_factor = nil
        oSet.options["physical_damage_factor"] = nil
        oSet.flame_density = nil
        oSet.options["flame_density"] = nil
        oSet.gimbal_strength = nil
        oSet.options["gimbal_strength"] = nil

        -- ensure these exist
        if oSet.impulse == nil then 
            oSet.impulse = create_option(
                option_type.numeric, 
                0.3,
                "impulse",
                "Impulse")
            oSet.impulse.range.lower = 0
            oSet.impulse.range.upper = 1
            oSet.impulse.step = 0.001
            oSet.options["impulse"] = oSet.impulse
        end
        if oSet.flame_color_hot == nil then 
            oSet.flame_color_hot = create_option(
                option_type.color,
                Vec(7.6, 0.6, 0.9),
                "flame_color_hot",
                "Hot flame color")
            oSet.options["flame_color_hot"] = oSet.flame_color_hot
        end
        if oSet.flame_color_cool == nil then 
            oSet.flame_color_cool = create_option(
                option_type.color,
                CONSTS.FLAME_COLOR_DEFAULT,
                "flame_color_cool",
                "Cool flame color")
            oSet.options["flame_color_cool"] = oSet.flame_color_cool
        end
        if oSet.real_flames == nil then 
            oSet.real_flames = create_option(
                option_type.enum,
                on_off.off,
                "real_flames",
                "Realistic flames")
            oSet.real_flames.accepted_values = on_off
            oSet.options["real_flames"] = oSet.real_flames
        end
        if oSet.flame_amount == nil then
            oSet.flame_amount = create_option(
                option_type.numeric, 
                0.3,
                "flame_amount",
                "Simulated flame amount")
            oSet.flame_amount.range.lower = 0
            oSet.flame_amount.range.upper = 1
            oSet.flame_amount.step = 0.001
            oSet.options["flame_amount"] = oSet.flame_amount
        end
        if oSet.flame_life == nil then 
            oSet.flame_life = create_option(
                option_type.numeric, 
                0.5,
                "flame_life",
                "Flame life")
            oSet.flame_life.range.lower = 0
            oSet.flame_life.range.upper = 1
            oSet.flame_life.step = 0.001
            oSet.options["flame_life"] = oSet.flame_life
        end
        if oSet.gimbal_max_angle == nil then 
            oSet.gimbal_max_angle = create_option(
                oSet.numeric, 
                20,
                "gimbal_max_angle",
                "Gimbal max angle")
            oSet.gimbal_max_angle.range.lower = 0
            oSet.gimbal_max_angle.range.upper = 60
            oSet.gimbal_max_angle.step = 0.1
            oSet.options["gimbal_max_angle"] = oSet.gimbal_max_angle
        end
        if oSet.gimbal_stiffness == nil then 
            oSet.gimbal_stiffness = create_option(
                oSet.numeric, 
                0.8,
                "gimbal_stiffness",
                "Gimbal stiffness")
            oSet.gimbal_stiffness.range.lower = 0
            oSet.gimbal_stiffness.range.upper = 1
            oSet.gimbal_stiffness.step = 0.001
            oSet.options["gimbal_stiffness"] = oSet.gimbal_stiffness
        end
    end
    return oSet
end

function  can_migrate(option_set_ser)
    local parts = split_string(option_set_ser, DELIM.OPTION_SET)
    local version = parts[3]
    -- No need for now
    -- if string.find(version, "1.", 1, true) then return false end
    return true
end
