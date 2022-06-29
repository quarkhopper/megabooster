#include "PyroField.lua"

-- Stores an instance of a tool (or mode) option set. 
TOOL = {}
TOOL.GENERAL = {}
TOOL.BOOSTER = {}


function save_option_sets()
    -- Save the option sets from memory to the savegame.xml file
	save_option_set(TOOL.GENERAL)
	save_option_set(TOOL.BOOSTER)
end

function load_option_sets()
	TOOL.GENERAL = load_option_set("general", true)
    PYRO.RAINBOW_MODE = TOOL.GENERAL.rainbow_mode.value == on_off.on
	TOOL.BOOSTER = load_option_set("booster", true)
    init_pyro(TOOL.BOOSTER)
    all_option_sets = {TOOL.BOOSTER, TOOL.GENERAL}
end

function init_pyro(tool)
    local pyro = inst_pyro()
    pyro.color_cool = tool.flame_color_cool.value
    pyro.color_hot = tool.flame_color_hot.value
    pyro.physical_damage_factor = tool.physical_damage_factor.value

    if tool == TOOL.BOOSTER then 
        pyro.fade_magnitude = 50
        pyro.hot_particle_size = 0.5
        pyro.cool_particle_size = 1
        pyro.impulse_radius = 3
        pyro.smoke_life = 1
        pyro.smoke_amount_n = 0.2
        pyro.flame_amount_n = 0.5
        pyro.flame_opacity = 1
        pyro.max_player_hurt = 0.0
        pyro.flames_per_spawn = 4
        pyro.flame_light_intensity = 2
        pyro.fire_ignition_radius = 1.5
        pyro.fire_density = 5
        pyro.max_flames = 300
        pyro.flame_puff_life = 1
        pyro.ff.resolution = 0.2
        pyro.ff.max_sim_points = 500
        pyro.ff.max_force = 100
        pyro.ff.extend_scale = 1.5
        pyro.ff.dead_force = 10
        pyro.ff.themro_loss = 0.3
    end
    tool.pyro = pyro
end
