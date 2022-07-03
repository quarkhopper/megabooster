#include "PyroField.lua"
#include "Booster.lua"

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
    PB_.gim_lim = TOOL.BOOSTER.gimbal_max_angle.value
    PB_.gim_apply = fraction_to_range_value(TOOL.BOOSTER.gimbal_stiffness.value, 5, 0)
    PB_.real_flames = TOOL.BOOSTER.real_flames.value == on_off.on
    PB_.impulse_scale = TOOL.BOOSTER.impulse.value
    init_pyro(TOOL.BOOSTER)

    all_option_sets = {TOOL.BOOSTER, TOOL.GENERAL}
end

function init_pyro(tool)
    local pyro = inst_pyro()
    pyro.color_cool = tool.flame_color_cool.value
    pyro.color_hot = tool.flame_color_hot.value
    pyro.flame_puff_life = fraction_to_range_value(tool.flame_life.value, 0.1, 10)
    pyro.flame_amount_n = tool.flame_amount.value
    pyro.fade_magnitude = 100
    pyro.hot_particle_size = 0.4
    pyro.cool_particle_size = 0.8
    pyro.smoke_life = 1
    pyro.smoke_amount_n = 0.1
    pyro.flame_opacity = 0.8
    pyro.max_player_hurt = 0.1
    pyro.flames_per_spawn = 1
    pyro.flame_light_intensity = 4
    pyro.fire_ignition_radius = 1.5
    pyro.fire_density = 10
    pyro.max_flames = 500
    pyro.ff.resolution = 0.3
    pyro.ff.max_sim_points = 300
    pyro.ff.max_force = 100
    pyro.ff.extend_scale = 1.5
    pyro.ff.dead_force = 10
    pyro.ff.themro_loss = 0.1
    tool.pyro = pyro
end
