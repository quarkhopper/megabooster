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
        oSet.gimbal_stiffness = nil
        oSet.options["gimbal_stiffness"] = nil 


        -- ensure these exist
        if oSet.impulse == nil then 
            oSet.impulse = create_option(
                option_type.numeric, 
                0.1,
                "impulse",
                "Impulse")
            oSet.impulse.range.lower = 0
            oSet.impulse.range.upper = 1
            oSet.impulse.step = 0.001
        end
        if oSet.flame_color_hot == nil then 
            oSet.flame_color_hot = create_option(
                option_type.color,
                Vec(7.6, 0.6, 0.9),
                "flame_color_hot",
                "Hot flame color")
           end
        if oSet.flame_color_cool == nil then 
            oSet.flame_color_cool = create_option(
                option_type.color,
                CONSTS.FLAME_COLOR_DEFAULT,
                "flame_color_cool",
                "Cool flame color")
        end
        if oSet.real_flames == nil then 
            oSet.real_flames = create_option(
                option_type.enum,
                on_off.off,
                "real_flames",
                "Realistic flames")
            oSet.real_flames.accepted_values = on_off
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
        end
        if oSet.kp == nil then 
            oSet.kp = create_option(
                oSet.numeric, 
                0.8,
                "kp",
                "Gimbal PID Kp")
            oSet.kp.range.lower = 0
            oSet.kp.range.upper = 5
            oSet.kp.step = 0.001
        end
        if oSet.ki == nil then 
            oSet.ki = create_option(
                oSet.numeric, 
                0.4,
                "ki",
                "Gimbal PID Ki")
            oSet.ki.range.lower = 0
            oSet.ki.range.upper = 5
            oSet.ki.step = 0.001
        end
        if oSet.kd == nil then 
            oSet.kd = create_option(
                oSet.numeric, 
                0.1,
                "kd",
                "Gimbal PID Kd")
            oSet.kd.range.lower = 0
            oSet.kd.range.upper = 5
            oSet.kd.step = 0.001
        end

        -- order
        local order = {
            "impulse", 
            "kp", 
            "ki", 
            "kd", 
            "gimbal_max_angle", 
            "real_flames", 
            "flame_amount", 
            "flame_life", 
            "flame_color_hot", 
            "flame_color_cool"}

        oSet.options = {}
        for i = 1, #order do
            table.insert(oSet.options, oSet[order[i]])
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
