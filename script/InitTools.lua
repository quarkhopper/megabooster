#include "PyroField.lua"

-- Stores an instance of a tool (or mode) option set. 
TOOL = {}
-- The general option set for all tools
TOOL.GENERAL = {}
-- The option set for the bomb tool
TOOL.BOMB = {}
-- The option set for the rocket tool
TOOL.ROCKET = {}
-- The option set for the flamethrower tool
TOOL.THROWER = {}

function save_option_sets()
    -- Save the option sets from memory to the savegame.xml file
	save_option_set(TOOL.GENERAL)
	save_option_set(TOOL.BOMB)
	save_option_set(TOOL.ROCKET)
	save_option_set(TOOL.THROWER)
end

function load_option_sets()
	TOOL.GENERAL = load_option_set("general", true)
    PYRO.RAINBOW_MODE = TOOL.GENERAL.rainbow_mode.value == on_off.on
	TOOL.BOMB = load_option_set("bomb", true)
    init_pyro(TOOL.BOMB)
	TOOL.ROCKET = load_option_set("rocket", true)
    init_pyro(TOOL.ROCKET)
	TOOL.THROWER = load_option_set("thrower", true)
    init_pyro(TOOL.THROWER)
    all_option_sets = {TOOL.BOMB, TOOL.ROCKET, TOOL.THROWER, TOOL.GENERAL}
end

function init_pyro(tool)
    local pyro = inst_pyro()
    pyro.color_cool = tool.flame_color_cool.value
    pyro.color_hot = tool.flame_color_hot.value
    pyro.physical_damage_factor = tool.physical_damage_factor.value

    pyro.ff.bias = Vec(0, 1, 0)
    local intensity = tool.boomness.value

    if tool == TOOL.BOMB then 
        pyro.fade_magnitude = 0.5
        pyro.hot_particle_size = 0.3
        pyro.cool_particle_size = 0.5
        pyro.impulse_radius = 5
        pyro.impulse_scale = 0.8
        pyro.fire_ignition_radius = 5
        pyro.fire_density = 8
        pyro.flame_jitter = 0.5
        pyro.flame_light_intensity = 3
        pyro.smoke_life = 1
        pyro.smoke_amount_n = 0.2
        pyro.max_player_hurt = 0.55
        pyro.ff.point_max_life = 3
        pyro.ff.dir_jitter = 0.3
        pyro.ff.meta_resolution = 2

        if intensity == boomness.invisible then 
            tool.explosion_seeds = 100
            tool.explosion_fireball_radius = 1.5
            pyro.flames_per_spawn = 0
            pyro.max_flames = 0
            pyro.smoke_amount_n = 0
            pyro.ff.max_sim_points = 100
            pyro.ff.bias_gain = 0.5
            pyro.ff.resolution = 0.5
            pyro.ff.graph.curve = curve_type.linear
            pyro.ff.graph.max_force = 100000
            pyro.ff.graph.dead_force = 0.05
            pyro.ff.graph.hot_transfer = 300
            pyro.ff.graph.cool_transfer = 0.5
            pyro.ff.graph.hot_prop_split = 5
            pyro.ff.graph.cool_prop_split = 2
            pyro.ff.graph.hot_prop_angle = 20
            pyro.ff.graph.cool_prop_angle = 35
            pyro.ff.graph.extend_scale = 1.5

        elseif intensity == boomness.economy then 
            tool.explosion_seeds = 100
            tool.explosion_fireball_radius = 1.5
            pyro.flames_per_spawn = 2
            pyro.max_flames = 200
            pyro.hot_particle_size = 0.3
            pyro.cool_particle_size = 0.5
            pyro.smoke_amount_n = 0.05
            pyro.ff.max_sim_points = 250
            pyro.ff.bias_gain = 0.5
            pyro.ff.resolution = 0.5
            pyro.ff.graph.curve = curve_type.linear
            pyro.ff.graph.max_force = 100000
            pyro.ff.graph.dead_force = 0.15
            pyro.ff.graph.hot_transfer = 1000
            pyro.ff.graph.cool_transfer = 0.5
            pyro.ff.graph.hot_prop_split = 5
            pyro.ff.graph.cool_prop_split = 2
            pyro.ff.graph.hot_prop_angle = 20
            pyro.ff.graph.cool_prop_angle = 35
            pyro.ff.graph.extend_scale = 1.5

        elseif intensity == boomness.explody then 
            tool.explosion_seeds = 100
            tool.explosion_fireball_radius = 1.5
            pyro.flames_per_spawn = 4
            pyro.max_flames = 400
            pyro.hot_particle_size = 0.3
            pyro.cool_particle_size = 0.5
            pyro.smoke_amount_n = 0.05
            pyro.ff.max_sim_points = 300
            pyro.ff.bias_gain = 0.5
            pyro.ff.resolution = 0.5
            pyro.ff.graph.curve = curve_type.linear
            pyro.ff.graph.max_force = 100000
            pyro.ff.graph.dead_force = 0.15
            pyro.ff.graph.hot_transfer = 3000
            pyro.ff.graph.cool_transfer = 0.03
            pyro.ff.graph.hot_prop_split = 4
            pyro.ff.graph.cool_prop_split = 3
            pyro.ff.graph.hot_prop_angle = 50
            pyro.ff.graph.cool_prop_angle = 20
            pyro.ff.graph.extend_scale = 1.5

        elseif intensity == boomness.tactical then 
            tool.explosion_seeds = 100
            tool.explosion_fireball_radius = 0.5
            pyro.hot_particle_size = 0.3
            pyro.cool_particle_size = 0.4
            pyro.flames_per_spawn = 5
            pyro.max_flames = 600
            pyro.smoke_amount_n = 0.05
            pyro.ff.max_sim_points = 500
            pyro.ff.bias_gain = 0.2
            pyro.ff.resolution = 0.5
            pyro.ff.graph.curve = curve_type.square
            pyro.ff.graph.max_force = 100000
            pyro.ff.graph.dead_force = 0.15
            pyro.ff.graph.hot_transfer = 5000
            pyro.ff.graph.cool_transfer = 1.5
            pyro.ff.graph.hot_prop_split = 3
            pyro.ff.graph.cool_prop_split = 3
            pyro.ff.graph.hot_prop_angle = 45
            pyro.ff.graph.cool_prop_angle = 35
            pyro.ff.graph.extend_scale = 1.5

        elseif intensity == boomness.vaporizing then 
            tool.explosion_seeds = 100
            tool.explosion_fireball_radius = 0.5
            pyro.hot_particle_size = 0.3
            pyro.cool_particle_size = 0.5
            pyro.flames_per_spawn = 5
            pyro.max_flames = 800
            pyro.smoke_amount_n = 0.05
            pyro.ff.dir_jitter = 0.3
            pyro.ff.max_sim_points = 800
            pyro.ff.bias_gain = 0.5
            pyro.ff.resolution = 0.5
            pyro.ff.graph.curve = curve_type.square
            pyro.ff.graph.max_force = 100000
            pyro.ff.graph.dead_force = 0.1
            pyro.ff.graph.hot_transfer = 10000
            pyro.ff.graph.cool_transfer = 2
            pyro.ff.graph.hot_prop_split = 3
            pyro.ff.graph.cool_prop_split = 3
            pyro.ff.graph.hot_prop_angle = 45
            pyro.ff.graph.cool_prop_angle = 28
            pyro.ff.graph.extend_scale = 1.6

        elseif intensity == boomness.nuclear then 
            tool.explosion_seeds = 100
            tool.explosion_fireball_radius = 1
            pyro.hot_particle_size = 0.5
            pyro.cool_particle_size = 1
            pyro.flames_per_spawn = 6
            pyro.max_flames = 1000
            pyro.flame_jitter = 0.1
            pyro.flame_light_intensity = 5
            pyro.smoke_amount_n = 0.05
            pyro.flame_light_intensity = 5
            pyro.flame_puff_life = 0.5
            pyro.ff.max_sim_points = 1000
            pyro.ff.bias_gain = 0.5
            pyro.ff.resolution = 0.8
            pyro.ff.graph.curve = curve_type.linear
            pyro.ff.graph.max_force = 1000000
            pyro.ff.graph.dead_force = 0.15
            pyro.ff.graph.hot_transfer = 10000
            pyro.ff.graph.cool_transfer = 0.01
            pyro.ff.graph.hot_prop_split = 3
            pyro.ff.graph.cool_prop_split = 4
            pyro.ff.graph.hot_prop_angle = 60
            pyro.ff.graph.cool_prop_angle = 21.5
            pyro.ff.graph.extend_scale = 1.6
        end

    elseif tool == TOOL.ROCKET then 
        pyro.fade_magnitude = 1

        pyro.impulse_radius = 5
        pyro.fire_ignition_radius = 5
        pyro.fire_density = 8
        pyro.flame_light_intensity = 3
        pyro.smoke_life = 1
        pyro.smoke_amount_n = 0.1
        pyro.max_player_hurt = 0.55
        pyro.ff.point_max_life = 2
        pyro.ff.dir_jitter = 0.5
        pyro.ff.bias_gain = 0.3
        pyro.ff.meta_resolution = 2

        if intensity == boomness.invisible then 
            tool.explosion_seeds = 50
            tool.explosion_fireball_radius = 1
            pyro.hot_particle_size = 0.2
            pyro.cool_particle_size = 0.4
            pyro.flames_per_spawn = 0
            pyro.impulse_scale = 0.1
            pyro.max_flames = 0
            pyro.smoke_amount_n = 0
            pyro.ff.max_sim_points = 100
            pyro.ff.resolution = 0.3
            pyro.ff.graph.curve = curve_type.linear
            pyro.ff.graph.max_force = 10000
            pyro.ff.graph.dead_force = 0.05
            pyro.ff.graph.hot_transfer = 1000
            pyro.ff.graph.cool_transfer = 0.05
            pyro.ff.graph.hot_prop_split = 3
            pyro.ff.graph.cool_prop_split = 3
            pyro.ff.graph.hot_prop_angle = 30
            pyro.ff.graph.cool_prop_angle = 45
            pyro.ff.graph.extend_scale = 1.5

        elseif intensity == boomness.economy then 
            tool.explosion_seeds = 50
            tool.explosion_fireball_radius = 1
            pyro.hot_particle_size = 0.2
            pyro.cool_particle_size = 0.4
            pyro.flames_per_spawn = 2
            pyro.impulse_scale = 0.1
            pyro.max_flames = 100
            pyro.smoke_amount_n = 0.05
            pyro.ff.max_sim_points = 200
            pyro.ff.resolution = 0.3
            pyro.ff.graph.curve = curve_type.linear
            pyro.ff.graph.max_force = 10000 
            pyro.ff.graph.dead_force = 0.05
            pyro.ff.graph.hot_transfer = 1000
            pyro.ff.graph.cool_transfer = 0.05
            pyro.ff.graph.hot_prop_split = 3
            pyro.ff.graph.cool_prop_split = 3
            pyro.ff.graph.hot_prop_angle = 30
            pyro.ff.graph.cool_prop_angle = 45
            pyro.ff.graph.extend_scale = 1.5

        elseif intensity == boomness.explody then 
            tool.explosion_seeds = 50
            tool.explosion_fireball_radius = 1
            pyro.hot_particle_size = 0.2
            pyro.cool_particle_size = 0.4
            pyro.flames_per_spawn = 4
            pyro.impulse_scale = 0.1
            pyro.max_flames = 400
            pyro.smoke_amount_n = 0.05
            pyro.ff.max_sim_points = 300
            pyro.ff.resolution = 0.3
            pyro.ff.graph.curve = curve_type.linear
            pyro.ff.graph.max_force = 10000 
            pyro.ff.graph.dead_force = 0.15
            pyro.ff.graph.hot_transfer = 1000
            pyro.ff.graph.cool_transfer = 0.05
            pyro.ff.graph.hot_prop_split = 3
            pyro.ff.graph.cool_prop_split = 3
            pyro.ff.graph.hot_prop_angle = 30
            pyro.ff.graph.cool_prop_angle = 45
            pyro.ff.graph.extend_scale = 1.5

        elseif intensity == boomness.tactical then 
            tool.explosion_seeds = 100
            tool.explosion_fireball_radius = 1
            pyro.hot_particle_size = 0.3
            pyro.cool_particle_size = 0.4
            pyro.flames_per_spawn = 4
            pyro.impulse_scale = 0.2
            pyro.max_flames = 600
            pyro.smoke_amount_n = 0.05
            pyro.ff.max_sim_points = 500
            pyro.ff.bias_gain = 0.2
            pyro.ff.resolution = 0.3
            pyro.ff.graph.curve = curve_type.square
            pyro.ff.graph.max_force = 100000
            pyro.ff.graph.dead_force = 0.15
            pyro.ff.graph.hot_transfer = 5000
            pyro.ff.graph.cool_transfer = 1.2
            pyro.ff.graph.hot_prop_split = 3
            pyro.ff.graph.cool_prop_split = 3
            pyro.ff.graph.hot_prop_angle = 60
            pyro.ff.graph.cool_prop_angle = 26
            pyro.ff.graph.extend_scale = 1.5

        elseif intensity == boomness.vaporizing then 
            tool.explosion_seeds = 100
            tool.explosion_fireball_radius = 1
            pyro.hot_particle_size = 0.3
            pyro.cool_particle_size = 0.5
            pyro.flames_per_spawn = 4
            pyro.impulse_scale = 0.28
            pyro.max_flames = 800
            pyro.flame_puff_life = 1.8
            pyro.smoke_amount_n = 0.05
            pyro.ff.max_sim_points = 800
            pyro.ff.bias_gain = 0.5
            pyro.ff.resolution = 0.6
            pyro.ff.graph.curve = curve_type.square
            pyro.ff.graph.max_force = 100000
            pyro.ff.graph.dead_force = 0.15
            pyro.ff.graph.hot_transfer = 10000
            pyro.ff.graph.cool_transfer = 3
            pyro.ff.graph.hot_prop_split = 3
            pyro.ff.graph.cool_prop_split = 2
            pyro.ff.graph.hot_prop_angle = 36
            pyro.ff.graph.cool_prop_angle = 40
            pyro.ff.graph.extend_scale = 1.5

        elseif intensity == boomness.nuclear then 
            tool.explosion_seeds = 100
            tool.explosion_fireball_radius = 0.5
            pyro.hot_particle_size = 0.3
            pyro.cool_particle_size = 0.8
            pyro.flames_per_spawn = 6
            pyro.impulse_scale = 0.28
            pyro.max_flames = 1000
            pyro.flame_puff_life = 0.5
            pyro.flame_light_intensity = 5
            pyro.smoke_amount_n = 0.03
            pyro.ff.max_sim_points = 1000
            pyro.ff.bias_gain = 0.5
            pyro.ff.resolution = 0.5
            pyro.ff.graph.curve = curve_type.linear
            pyro.ff.graph.max_force = 100000 
            pyro.ff.graph.dead_force = 0.15 
            pyro.ff.graph.hot_transfer = 10000 
            pyro.ff.graph.cool_transfer = 0.01
            pyro.ff.graph.hot_prop_split = 3
            pyro.ff.graph.cool_prop_split = 4
            pyro.ff.graph.hot_prop_angle = 60
            pyro.ff.graph.cool_prop_angle = 20.5
            pyro.ff.graph.extend_scale = 1.8

        end

    elseif tool == TOOL.THROWER then 
        tool.gravity = 0.01
        pyro.fade_magnitude = 2
        pyro.hot_particle_size = 0.1
        pyro.cool_particle_size = 0.2
        pyro.impulse_radius = 0.5
        pyro.impulse_scale = 0.01
        pyro.flame_light_intensity = 1
        pyro.fire_ignition_radius = 1
        pyro.fire_density = 10
        pyro.smoke_life = 1
        pyro.smoke_amount_n = 0
        pyro.max_player_hurt = 0.1
        pyro.ff.dir_jitter = 0
        pyro.ff.bias = Vec(0, 1, 0)
        pyro.ff.bias_gain = 0
        pyro.ff.meta_resolution = 1
        pyro.ff.graph.curve = curve_type.linear
        pyro.ff.graph.extend_scale = 1.5

        if intensity == boomness.invisible then 
            pyro.flames_per_spawn = 1
            pyro.flame_light_intensity = 1
            pyro.fire_ignition_radius = 1
            pyro.fire_density = 10
            pyro.max_flames = 0
            pyro.ff.max_sim_points = 100
            pyro.ff.resolution = 0.2
            pyro.ff.graph.max_force = 500 
            pyro.ff.graph.dead_force = 10
            pyro.ff.graph.hot_transfer = 100
            pyro.ff.graph.cool_transfer = 10
            pyro.ff.graph.hot_prop_split = 2
            pyro.ff.graph.cool_prop_split = 3
            pyro.ff.graph.hot_prop_angle = 30
            pyro.ff.graph.cool_prop_angle = 60

        elseif intensity == boomness.economy then 
            pyro.flames_per_spawn = 1
            pyro.flame_light_intensity = 1
            pyro.fire_ignition_radius = 1
            pyro.fire_density = 10
            pyro.max_flames = 100
            pyro.ff.max_sim_points = 200
            pyro.ff.resolution = 0.2
            pyro.ff.graph.max_force = 500 
            pyro.ff.graph.dead_force = 10
            pyro.ff.graph.hot_transfer = 100
            pyro.ff.graph.cool_transfer = 10
            pyro.ff.graph.hot_prop_split = 2
            pyro.ff.graph.cool_prop_split = 3
            pyro.ff.graph.hot_prop_angle = 30
            pyro.ff.graph.cool_prop_angle = 60

        elseif intensity == boomness.explody then 
            pyro.flames_per_spawn = 1
            pyro.flame_light_intensity = 1
            pyro.fire_ignition_radius = 1
            pyro.fire_density = 10
            pyro.max_flames = 400
            pyro.flame_puff_life = 0.3
            pyro.ff.max_sim_points = 300
            pyro.ff.resolution = 0.1
            pyro.ff.graph.max_force = 500 
            pyro.ff.graph.dead_force = 0.1
            pyro.ff.graph.hot_transfer = 1000
            pyro.ff.graph.cool_transfer = 2
            pyro.ff.graph.hot_prop_split = 2
            pyro.ff.graph.cool_prop_split = 2
            pyro.ff.graph.hot_prop_angle = 30
            pyro.ff.graph.cool_prop_angle = 30

        elseif intensity == boomness.tactical then 
            pyro.flames_per_spawn = 1
            pyro.flame_light_intensity = 1
            pyro.fire_ignition_radius = 1.5
            pyro.fire_density = 15
            pyro.max_flames = 600
            pyro.flame_puff_life = 0.3
            pyro.ff.max_sim_points = 500
            pyro.ff.resolution = 0.1
            pyro.ff.graph.max_force = 1000 
            pyro.ff.graph.dead_force = 2
            pyro.ff.graph.hot_transfer = 1000
            pyro.ff.graph.cool_transfer = 2
            pyro.ff.graph.hot_prop_split = 2
            pyro.ff.graph.cool_prop_split = 3
            pyro.ff.graph.hot_prop_angle = 30
            pyro.ff.graph.cool_prop_angle = 30

        elseif intensity == boomness.vaporizing then 
            pyro.flames_per_spawn = 1
            pyro.flame_light_intensity = 2
            pyro.fire_ignition_radius = 2
            pyro.fire_density = 20
            pyro.max_flames = 800
            pyro.flame_puff_life = 0.3
            pyro.ff.max_sim_points = 800
            pyro.ff.resolution = 0.1
            pyro.ff.graph.max_force = 1000 
            pyro.ff.graph.dead_force = 0.15
            pyro.ff.graph.hot_transfer = 1000
            pyro.ff.graph.cool_transfer = 2
            pyro.ff.graph.hot_prop_split = 2
            pyro.ff.graph.cool_prop_split = 3
            pyro.ff.graph.hot_prop_angle = 30
            pyro.ff.graph.cool_prop_angle = 30

        elseif intensity == boomness.nuclear then 
            pyro.flames_per_spawn = 1
            pyro.flame_light_intensity = 2
            pyro.fire_ignition_radius = 2
            pyro.fire_density = 20
            pyro.max_flames = 800
            pyro.flame_puff_life = 0.3
            pyro.ff.max_sim_points = 800
            pyro.ff.resolution = 0.1
            pyro.ff.graph.max_force = 1000 
            pyro.ff.graph.dead_force = 2
            pyro.ff.graph.hot_transfer = 1000
            pyro.ff.graph.cool_transfer = 3
            pyro.ff.graph.hot_prop_split = 2
            pyro.ff.graph.cool_prop_split = 3
            pyro.ff.graph.hot_prop_angle = 5
            pyro.ff.graph.cool_prop_angle = 60
        end
    end

    tool.pyro = pyro
end

BOOST_FIELD = {}
function init_boost_field()
    local pyro = inst_pyro()
    pyro.fade_magnitude = 2
    pyro.hot_particle_size = 0.4
    pyro.cool_particle_size = 0.4
    pyro.impulse_radius = 0.8
    pyro.impulse_scale = 10
    pyro.smoke_life = 1
    pyro.smoke_amount_n = 0.02
    pyro.max_player_hurt = 0.1
    pyro.flames_per_spawn = 3
    pyro.flame_light_intensity = 2
    pyro.fire_ignition_radius = 1.5
    pyro.fire_density = 5
    pyro.max_flames = 600
    pyro.flame_puff_life = 1
    pyro.ff.dir_jitter = 0.0
    pyro.ff.bias = Vec(0, -1, 0)
    pyro.ff.bias_gain = 0
    pyro.ff.resolution = 0.1
    pyro.ff.use_metafield = false
    pyro.ff.max_sim_points = 500
    pyro.ff.point_max_life = 1
    pyro.ff.graph.max_force = 100
    pyro.ff.graph.curve = curve_type.linear
    pyro.ff.graph.extend_scale = 1.5
    pyro.ff.graph.dead_force = 0.2
    pyro.ff.graph.hot_transfer = 100
    pyro.ff.graph.cool_transfer = 10
    pyro.ff.graph.hot_prop_split = 3
    pyro.ff.graph.cool_prop_split = 4
    pyro.ff.graph.hot_prop_angle = 30
    pyro.ff.graph.cool_prop_angle = 60
    BOOST_FIELD = pyro
end

-- Stores a special pyro field for shock wave effects
SHOCK_FIELD = {}
function init_shock_field(intensity, damage_factor)
    -- special parameters that make a shock wave field work
    local pyro = inst_pyro()
    pyro.fade_magnitude = 0
    pyro.cool_particle_size = 1
    pyro.hot_particle_size = 1
    pyro.smoke_life = 0
    pyro.smoke_amount_n = 0
    pyro.flame_puff_life = 0.3
    pyro.flame_jitter = 2
    pyro.flame_tile = 0
    pyro.flame_opacity = 1
    pyro.impulse_scale = 1
    pyro.fire_ignition_radius = 0
    pyro.fire_density = 0
    pyro.physical_damage_factor = damage_factor
    pyro.max_player_hurt = 0.01
    pyro.rainbow_mode = false
    pyro.flame_light_intensity = 0
    pyro.ff.point_max_life = 2
    pyro.ff.resolution = 2.5
    pyro.ff.meta_resolution = 4
    pyro.ff.bias = Vec()
    pyro.ff.bias_gain = 0
    pyro.ff.dir_jitter = 10
    pyro.ff.graph.curve = curve_type.sqrt
    pyro.ff.graph.extend_scale = 2

    if intensity == boomness.invisible then 
        pyro.flames_per_spawn = 0
        pyro.impulse_radius = 10
        pyro.max_flames = 0
        pyro.ff.max_sim_points = 100
        pyro.ff.graph.max_force = 10000
        pyro.ff.graph.dead_force = 10
        pyro.ff.graph.hot_transfer = 1000
        pyro.ff.graph.cool_transfer = 10
        pyro.ff.graph.hot_prop_split = 4
        pyro.ff.graph.cool_prop_split = 4
        pyro.ff.graph.hot_prop_angle = 45
        pyro.ff.graph.cool_prop_angle = 45

    elseif intensity == boomness.economy then 
        pyro.flames_per_spawn = 2
        pyro.impulse_radius = 10
        pyro.max_flames = 100
        pyro.ff.max_sim_points = 200
        pyro.ff.graph.max_force = 10000
        pyro.ff.graph.dead_force = 10
        pyro.ff.graph.hot_transfer = 1000
        pyro.ff.graph.cool_transfer = 10
        pyro.ff.graph.hot_prop_split = 3
        pyro.ff.graph.cool_prop_split = 3
        pyro.ff.graph.hot_prop_angle = 45
        pyro.ff.graph.cool_prop_angle = 45

    elseif intensity == boomness.explody then 
        pyro.flames_per_spawn = 5
        pyro.impulse_radius = 10
        pyro.max_flames = 400
        pyro.ff.max_sim_points = 300
        pyro.ff.graph.max_force = 10000
        pyro.ff.graph.dead_force = 10
        pyro.ff.graph.hot_transfer = 1000
        pyro.ff.graph.cool_transfer = 10
        pyro.ff.graph.hot_prop_split = 3
        pyro.ff.graph.cool_prop_split = 3
        pyro.ff.graph.hot_prop_angle = 45
        pyro.ff.graph.cool_prop_angle = 45

    elseif intensity == boomness.tactical then 
        pyro.flames_per_spawn = 5
        pyro.impulse_radius = 10
        pyro.max_flames = 600
        pyro.ff.max_sim_points = 500
        pyro.ff.graph.max_force = 10000
        pyro.ff.graph.dead_force = 50
        pyro.ff.graph.hot_transfer = 2000
        pyro.ff.graph.cool_transfer = 100
        pyro.ff.graph.hot_prop_split = 4
        pyro.ff.graph.cool_prop_split = 4
        pyro.ff.graph.hot_prop_angle = 45
        pyro.ff.graph.cool_prop_angle = 45

    elseif intensity == boomness.vaporizing then 
        pyro.flames_per_spawn = 6
        pyro.impulse_radius = 10
        pyro.max_flames = 800
        pyro.ff.max_sim_points = 800
        pyro.ff.graph.max_force = 50000
        pyro.ff.graph.dead_force = 10
        pyro.ff.graph.hot_transfer = 2000
        pyro.ff.graph.cool_transfer = 100
        pyro.ff.graph.hot_prop_split = 4
        pyro.ff.graph.cool_prop_split = 4
        pyro.ff.graph.hot_prop_angle = 45
        pyro.ff.graph.cool_prop_angle = 45

    elseif intensity == boomness.nuclear then 
        pyro.flames_per_spawn = 8
        pyro.impulse_radius = 20
        pyro.max_flames = 1000
        pyro.ff.max_sim_points = 1000
        pyro.ff.graph.max_force = 1000000
        pyro.ff.graph.dead_force = 6
        pyro.ff.graph.hot_transfer = 2000
        pyro.ff.graph.cool_transfer = 100
        pyro.ff.graph.hot_prop_split = 4
        pyro.ff.graph.cool_prop_split = 4
        pyro.ff.graph.hot_prop_angle = 45
        pyro.ff.graph.cool_prop_angle = 45

    end

    SHOCK_FIELD = pyro
end