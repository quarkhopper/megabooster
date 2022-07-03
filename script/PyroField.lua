#include "ForceField.lua"
#include "Utils.lua"
--[[
    This script is a wrapper for ForceField.lua. Where ForceField.lua covers the 
    "physics" of the forces moving around, this covers the fire and SFX and wraps
    that field. 
]]--


PYRO = {} -- Static PyroField options
PYRO.RAINBOW = Vec(0, 1, 0.8)
PYRO.RAINBOW_MODE = false
PYRO.MIN_PLAYER_PUSH = 1
PYRO.MAX_PLAYER_PUSH = 5
PYRO.MAX_PLAYER_VEL = 10
PYRO.MIN_IMPULSE = 50
PYRO.MAX_IMPULSE = 800
PYRO.GRAVITY = 0.5

function inst_pyro()
    local inst = {}
    inst.flames = {}
    inst.flames_per_spawn = 5
    inst.flame_light_intensity = 4 
    inst.cool_particle_size = 1
    inst.hot_particle_size = 0.5
    inst.smoke_life = 3
    inst.smoke_amount_n = 0.2
    inst.flame_amount_n = 1
    inst.render_flames = true
    inst.flame_puff_life = 0.5
    inst.flame_jitter = 0
    inst.flame_opacity = 1
    inst.fire_ignition_radius = 1
    inst.fire_density = 1
    inst.physical_damage_factor = 0.5
    inst.max_player_hurt = 0.5
    inst.color_cool = Vec(7.7, 1, 0.8)
    inst.color_hot = Vec(7.7, 1, 0.8)
    inst.jitter_hot = 0
    inst.jitter_cool = 0.5
    inst.fade_magnitude = 20
    inst.max_flames = 400
    inst.ff = inst_force_field_ff()
    return inst
end

function inst_flame(pos)
    -- A flame object is rendered as a point light in a diffusing smoke particle.
    local inst = {}
    inst.pos = pos
    -- Parent FORCE FIELD POINT that this flame was spawned for.
    inst.parent = nil
    return inst
end

function make_flame_effect(pyro, flame, dt)
    -- Render effects for one flame instance.
    local power =  bracket_value(range_value_to_fraction(flame.parent.mag, FF.LOW_MAG_LIMIT, pyro.ff.max_force), 1, 0)
    local color = Vec()
    local intensity = pyro.flame_light_intensity
    if PYRO.RAINBOW_MODE then
        -- Rainbow mode just cycles one color for the entire field and uses that color 
        -- for all fire effects universally
        PYRO.RAINBOW[1] = cycle_value(PYRO.RAINBOW[1], dt * 10, 0, 359)
        color = HSVToRGB(PYRO.RAINBOW)
        -- intensity is set to a hardcoded value that works well for displaying colors. Too high
        -- and the colors are washed out.
        intensity = 0.5
    else
        -- when not in rainbow mode...
        if flame.parent.mag > pyro.fade_magnitude then 
            color = HSVToRGB(blend_color(power ^ 2, pyro.color_cool, pyro.color_hot))
        else
            color = HSVToRGB(pyro.color_cool)
        end
    end

    local puff_color_value = 1
    local opacity = pyro.flame_opacity
    local particle_size = fraction_to_range_value(power ^ 0.5, pyro.cool_particle_size, pyro.hot_particle_size)
    if flame.parent.mag < pyro.fade_magnitude then 
        local burnout_n = range_value_to_fraction(flame.parent.mag, 0, pyro.fade_magnitude)
        puff_color_value = bracket_value(burnout_n, 1, 0.2)
        intensity = fraction_to_range_value(burnout_n, 0, intensity)
        opacity = fraction_to_range_value(burnout_n, 0, pyro.flame_opacity)
    end
    -- Put the light source in the middle of where the diffusing flame puff will be
    PointLight(flame.pos, color[1], color[2], color[3], intensity)
    -- fire puff smoke particle generation
    ParticleReset()
    ParticleType("smoke")
    ParticleAlpha(opacity, 0, "easeout", 0, 1)
    -- ParticleDrag(0.25)
    ParticleRadius(particle_size)
    local smoke_color = HSVToRGB(Vec(0, 0, puff_color_value))
    ParticleColor(smoke_color[1], smoke_color[2], smoke_color[3])
    ParticleGravity(PYRO.GRAVITY)
    local tile = 0
    if math.random(2) == 1 then tile = 5 end
    ParticleTile(tile)
    -- Apply a little random jitter if specified by the options, for the specified lifetime
    -- in options.
    SpawnParticle(VecAdd(flame.pos, random_vec(pyro.flame_jitter)), Vec(), pyro.flame_puff_life)

    -- if black smoke amount is set above 0, we're not in ember mode, and chance favors it...
    if math.random() < pyro.smoke_amount_n then
        -- Set up a smoke puff
        ParticleReset()
        ParticleType("smoke")
        -- ParticleDrag(0)
        ParticleAlpha(0.5, 0.9, "linear", 0.05, 0.5)
        ParticleRadius(particle_size + 0.15)
        if PYRO.RAINBOW_MODE then
            -- Rainbow mode: smoke puff is the universal color of the tick
            smoke_color = PYRO.RAINBOW
            smoke_color[3] = 1
            smoke_color = HSVToRGB(smoke_color)
        else
            -- Normal mode: smoke color is a hard-coded dingy value
            smoke_color = HSVToRGB(Vec(0, 0, 0.1))
        end
        ParticleColor(smoke_color[1], smoke_color[2], smoke_color[3])
        ParticleGravity(PYRO.GRAVITY)
        -- apply a little random jitter to the smoke puff based on the flame position,
        -- for the specified lifetime of the particle.
        SpawnParticle(VecAdd(flame.pos, random_vec(0.1)), Vec(), pyro.smoke_life)
    end
end

function burn_fx(pyro)
    -- Start fires throught the native Teardown mechanism. Base these effects on the
    -- lower resolution metafield for better performance (typically)
    -- local points = flatten(pyro.ff.field)
    local num_fires = round((pyro.fire_density / pyro.fire_ignition_radius)^3)
    for i = 1, #pyro.flames do
        local point = pyro.flames[i].parent
        for j = 1, num_fires do
            local random_dir = random_vec(1)
            -- cast in some random dir and start a fire if you hit something. 
            local hit, dist = QueryRaycast(point.pos, random_dir, pyro.fire_ignition_radius)
            if hit then 
                local burn_at = VecAdd(point.pos, VecScale(random_dir, dist))
                SpawnFire(burn_at)
            end
        end
    end
end

function make_flame_effects(pyro, dt)
    -- for every flame instance, make the appropriate effect
    for i = 1, #pyro.flames do
        local flame = pyro.flames[i]
        make_flame_effect(pyro, flame, dt)
    end
end

function spawn_flames(pyro)
    -- Spawn flame instances to render based on the underlying base force field vectors.
    local new_flames = {}
    local points = flatten(pyro.ff.field)
    for i = 1, #points do
        local point = points[i]
        spawn_flame_group(pyro, point, new_flames)     
    end
    while #new_flames > pyro.max_flames do
        table.remove(new_flames, math.random(#new_flames))
    end
    pyro.flames = new_flames
end

function spawn_flame_group(pyro, point, flame_table, pos)
    pos = pos or point.pos
    for i = 1, pyro.flames_per_spawn do
        if math.random() < pyro.flame_amount_n then 
            local jitter = fraction_to_range_value(point.power, pyro.jitter_cool, pyro.jitter_hot)
            local offset_dir = VecNormalize(random_vec(jitter))
            local flame_pos = VecAdd(pos, VecScale(offset_dir, pyro.ff.resolution))
            local flame = inst_flame(pos)
            flame.parent = point
            table.insert(flame_table, flame)
        end
    end
end

function flame_tick(pyro, dt)
    force_field_ff_tick(pyro.ff, dt)
    
    if pyro.render_flames then 
        spawn_flames(pyro)
        if not DEBUG_MODE then 
            make_flame_effects(pyro, dt)
        end
    end

    burn_fx(pyro)
end
