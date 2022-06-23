#include "Utils.lua"

function migrate_option_set(option_set_ser)
    local version = 0
    local parts = split_string(option_set_ser, DELIM.OPTION_SET)
    version = parts[3]
    if version == "2" then 
        -- add performance options to tools and remove from general
        version = "2.1"
        local set_parts = split_string(option_set_ser, DELIM.OPTION_SET)
        set_parts[3] = version
        local set_name = set_parts[1]
        if set_name ~= "general" then 
            local option = create_mode_option(
                option_type.enum,
                boomness.explody,
                "boomness",
                "Performance")
            option.accepted_values = boomness
            local ser = mode_option_to_string(option)
            set_parts[#set_parts + 1] = ser
        else
            local new_parts = {set_parts[1], set_parts[2], set_parts[3]}
            for i = 4, #set_parts do
                local option = mode_option_from_string(set_parts[i])
                if option.key ~= "boomness" then 
                    new_parts[#new_parts + 1] = mode_option_to_string(option)
                end
            end
            set_parts = new_parts
        end
        option_set_ser = join_strings(set_parts, DELIM.OPTION_SET)
    end

    if version == "2.1" then 
        -- add physical damage scaling
        version = "2.2"
        local set_parts = split_string(option_set_ser, DELIM.OPTION_SET)
        set_parts[3] = version
        local set_name = set_parts[1]
        if set_name ~= "general" then 
            local physical_damage_factor = create_mode_option(
                option_type.numeric, 
                0.5,
                "physical_damage_factor",
                "Physical damange modifier")
            physical_damage_factor.range.lower = 0
            physical_damage_factor.range.upper = 1
            physical_damage_factor.step = 0.001

            if set_name == "bomb" then physical_damage_factor.value = 0.3
            elseif set_name == "rocket" then physical_damage_factor.value = 0.5
            elseif set_name == "thrower" then physical_damage_factor.value = 0.05
            end

            local ser = mode_option_to_string(physical_damage_factor)
            set_parts[#set_parts + 1] = ser
        end
        option_set_ser = join_strings(set_parts, DELIM.OPTION_SET)
    end

    if version == "2.2" then 
        -- change "performance" boomness to "economy"
        version = "2.3"
        option_set_ser = option_set_ser:gsub("performance", "economy")
    end

    return option_set_ser
end

function  can_migrate(option_set_ser)
    local parts = split_string(option_set_ser, DELIM.OPTION_SET)
    local version = parts[3]
    if string.find(version, "1.", 1, true) then return false end
    return true
end
