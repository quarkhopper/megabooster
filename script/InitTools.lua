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

    pyro.ff.bias = Vec(0, 1, 0)
    if tool == TOOL.BOOSTER then 
        pyro.fade_magnitude = 2
        pyro.hot_particle_size = 0.2
        pyro.cool_particle_size = 0.4
        pyro.impulse_radius = 1
        pyro.impulse_scale = 20 * tool.impulse.value
        pyro.smoke_life = 1
        pyro.smoke_amount_n = 0.02
        pyro.max_player_hurt = 0.1
        pyro.flames_per_spawn = 3
        pyro.flame_light_intensity = 2
        pyro.fire_ignition_radius = 1.5
        pyro.fire_density = 5
        pyro.max_flames = 300
        pyro.flame_puff_life = 1
        pyro.ff.dir_jitter = 0.0
        pyro.ff.bias = Vec(0, -1, 0)
        pyro.ff.bias_gain = 0
        pyro.ff.resolution = 0.1
        pyro.ff.use_metafield = false
        pyro.ff.max_sim_points = 500
        pyro.ff.point_max_life = 1
        pyro.ff.graph.max_force = 1000
        pyro.ff.graph.curve = curve_type.linear
        pyro.ff.graph.extend_scale = 1.5
        pyro.ff.graph.dead_force = 0.2
        pyro.ff.graph.hot_transfer = 100
        pyro.ff.graph.cool_transfer = 10
        pyro.ff.graph.hot_prop_split = 3
        pyro.ff.graph.cool_prop_split = 4
        pyro.ff.graph.hot_prop_angle = 30
        pyro.ff.graph.cool_prop_angle = 60
    end
    tool.pyro = pyro
end
