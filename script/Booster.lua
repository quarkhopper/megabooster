#include "Defs.lua"

rumble_sound = LoadLoop("MOD/snd/rumble.ogg")
fire_sound = LoadLoop("MOD/snd/rocketfire.ogg")

P_BOOSTER = {}
P_BOOSTER.booster = nil
P_BOOSTER.ignition = false
P_BOOSTER.injection_rate = 0.01
P_BOOSTER.injection_timer = 0
P_BOOSTER.injection_count = 10
P_BOOSTER.burn_radius = 2
P_BOOSTER.body = nil
P_BOOSTER.vel_offset_max = 1
P_BOOSTER.power = 0
P_BOOSTER.ramp = 1 -- time to full power

function respawn_booster()
	local camera = GetPlayerCameraTransform()
	local shoot_dir = TransformToParentVec(camera, Vec(0, 0, -1))
	local rotx, roty, rotz = GetQuatEuler(camera.rot)
	local hit, dist, normal, shape = QueryRaycast(camera.pos, shoot_dir, 100, 0.025, true)
	if hit then
		local hit_point = VecAdd(camera.pos, VecScale(shoot_dir, dist))
		local trans = Transform(hit_point, QuatEuler(0,0,0))
        if P_BOOSTER ~= nil then 
            Delete(P_BOOSTER.body)
        end
		P_BOOSTER.body = Spawn("MOD/prefab/pyro_booster.xml", trans, false, true)[1]
	end
end

function booster_ignition_toggle()
    P_BOOSTER.power = 0
    P_BOOSTER.ignition = not P_BOOSTER.ignition
end

function booster_tick(dt)
    if P_BOOSTER.ignition then
        P_BOOSTER.power = math.min(P_BOOSTER.power + (P_BOOSTER.ramp * dt), 1)
        TOOL.BOOSTER.pyro.impulse_scale = TOOL.BOOSTER.impulse.value * 10 * P_BOOSTER.power
        local booster_trans = GetBodyTransform(P_BOOSTER.body)
        local t_locus = Vec(0, 3, 0)
        local w_locus = TransformToParentPoint(booster_trans, t_locus)
        local vel = GetBodyVelocity(P_BOOSTER.body)
        local vel_offset = VecScale(vel, 0.1)
        if VecLength(vel_offset) > P_BOOSTER.vel_offset_max then 
            vel_offset = VecScale(VecNormalize(vel), P_BOOSTER.vel_offset_max)
        end
        w_locus = VecAdd(w_locus, vel_offset)
        if P_BOOSTER.injection_timer == 0 then 
            for i = 1, P_BOOSTER.injection_count do
                local dir = VecNormalize(random_vec(1))
                local w_pos = VecAdd(w_locus, VecScale(dir, P_BOOSTER.burn_radius))
                apply_force(TOOL.BOOSTER.pyro.ff, w_pos, TOOL.BOOSTER.pyro.ff.max_force / 2)
                if DEBUG_MODE then 
                    DebugCross(w_pos)
                end
            end
            P_BOOSTER.injection_timer = P_BOOSTER.injection_rate
        end
        P_BOOSTER.injection_timer = math.max(0, P_BOOSTER.injection_timer - dt)
        PlayLoop(fire_sound, booster_trans.pos, 10)
        PlayLoop(rumble_sound, booster_trans.pos, 10)
    end
end