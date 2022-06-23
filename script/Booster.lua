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

function spawn_booster()
	local camera = GetPlayerCameraTransform()
	local shoot_dir = TransformToParentVec(camera, Vec(0, 0, -1))
	local rotx, roty, rotz = GetQuatEuler(camera.rot)
	local hit, dist = QueryRaycast(camera.pos, shoot_dir, 100, 0.025, true)
	if hit then
		local hit_point = VecAdd(camera.pos, VecScale(shoot_dir, dist))
		local trans = Transform(hit_point, QuatEuler(0, roty - 90,0))
		P_BOOSTER.booster = inst_booster(trans)
	end
end

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
            local dir = VecNormalize(random_vec(1))
            local w_pos = VecAdd(w_locus, VecScale(dir, P_BOOSTER.burn_radius))
            local force_vec = VecScale(dir, TOOL.BOOSTER.pyro.ff.graph.max_force)
            apply_force(TOOL.BOOSTER.pyro.ff, w_pos, force_vec)
            -- DebugCross(w_pos)
            P_BOOSTER.injection_timer = P_BOOSTER.injection_rate
        end
        P_BOOSTER.injection_timer = math.max(0, P_BOOSTER.injection_timer - dt)
        P_BOOSTER.booster.trans = GetBodyTransform(P_BOOSTER.booster.body)
        P_BOOSTER.burn_timer = P_BOOSTER.burn_timer - dt
        -- if P_BOOSTER.burn_timer < 0 then P_BOOSTER.booster = nil end
    end
end