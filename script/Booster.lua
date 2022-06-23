#include "Defs.lua"

P_BOOSTER = {}
P_BOOSTER.booster = nil
P_BOOSTER.burn_time = 3
P_BOOSTER.burn_timer = 0
P_BOOSTER.injection_rate = 0.01
P_BOOSTER.injection_timer = 0
P_BOOSTER.burn_radius = 0.5
vert_dir = 1
-- boom_sound = LoadSound("MOD/snd/toiletBoom.ogg")

function inst_booster(trans)
    local inst = {}
    inst.trans = trans
    inst.body = Spawn("MOD/prefab/pyro_booster.xml", inst.trans)[1]
    return inst
end

function booster_ignition()
    P_BOOSTER.burn_timer = P_BOOSTER.burn_time
end

function booster_tick(dt)
    if P_BOOSTER.burn_timer > 0 then 
        local t_locus = Vec(0,3,0)
        local w_locus = TransformToParentPoint(P_BOOSTER.booster.trans, t_locus)
        if P_BOOSTER.injection_timer == 0 then 
            local t_dir = nil
            t_dir = Vec(0,vert_dir,0)
            vert_dir = -1 * vert_dir
            -- local w_dir = VecNormalize(TransformToParentPoint(P_BOOSTER.booster.trans, t_dir)) 
            local dir = VecNormalize(random_vec(1))
            local w_pos = VecAdd(w_locus, VecScale(dir, P_BOOSTER.burn_radius))
            local force_vec = VecScale(dir, BOOST_FIELD.ff.graph.max_force)
            apply_force(BOOST_FIELD.ff, w_pos, force_vec)
            -- apply_force(BOOST_FIELD.ff, w_locus, VecScale(w_dir, BOOST_FIELD.ff.graph.max_force))
            -- DebugCross(w_pos)
            P_BOOSTER.injection_timer = P_BOOSTER.injection_rate
        end
        P_BOOSTER.injection_timer = math.max(0, P_BOOSTER.injection_timer - dt)
        P_BOOSTER.booster.trans = GetBodyTransform(P_BOOSTER.booster.body)
        P_BOOSTER.burn_timer = P_BOOSTER.burn_timer - dt
        -- if P_BOOSTER.burn_timer < 0 then P_BOOSTER.booster = nil end
    end
end