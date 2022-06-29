#include "Defs.lua"

rumble_sound = LoadLoop("MOD/snd/rumble.ogg")
fire_sound = LoadLoop("MOD/snd/rocketfire.ogg")

PB_ = {}
PB_.booster = nil
PB_.ignition = false
PB_.injection_rate = 0.01
PB_.injection_timer = 0
PB_.injection_count = 10
PB_.burn_radius = 1
PB_.body = nil
PB_.power = 0
PB_.ramp = 1 -- time to full power\
PB_.impulse_const = 1

function respawn_booster()
	local camera = GetPlayerCameraTransform()
	local shoot_dir = TransformToParentVec(camera, Vec(0, 0, -1))
	local rotx, roty, rotz = GetQuatEuler(camera.rot)
	local hit, dist, normal, shape = QueryRaycast(camera.pos, shoot_dir, 100, 0.025, true)
	if hit then
		local hit_point = VecAdd(camera.pos, VecScale(shoot_dir, dist))
		local trans = Transform(hit_point, QuatEuler(0,0,0))
        if PB_ ~= nil then 
            Delete(PB_.body)
        end
		PB_.body = Spawn("MOD/prefab/pyro_booster.xml", trans, false, true)[1]
	end
end

function booster_ignition_toggle()
    PB_.power = 0
    PB_.ignition = not PB_.ignition
end

function booster_tick(dt)
    if PB_.ignition then
        PB_.power = math.min(PB_.power + (PB_.ramp * dt), 1)
        TOOL.BOOSTER.pyro.impulse_scale = TOOL.BOOSTER.impulse.value * PB_.impulse_const * PB_.power
        local booster_trans = GetBodyTransform(PB_.body)
        if PB_.injection_timer == 0 then 
            local l_inj_center = Vec(0, 5, 0)
            local w_inj_center = TransformToParentPoint(booster_trans, l_inj_center)
            local booster_vel = GetBodyVelocity(PB_.body)
            for i = 1, PB_.injection_count do
                local l_inj_dir = random_vec(1, Vec(0, -1, 0), 60)
                local w_inj_dir = TransformToParentVec(booster_trans, l_inj_dir)
                local w_inj_pos = VecAdd(w_inj_center, VecScale(w_inj_dir, PB_.burn_radius))
                local magnitude = TOOL.BOOSTER.pyro.ff.max_force / 2
                apply_force(TOOL.BOOSTER.pyro.ff, w_inj_pos, magnitude)
                ApplyBodyImpulse(PB_.body, w_inj_center, VecScale(VecScale(w_inj_dir, -1), magnitude * TOOL.BOOSTER.pyro.impulse_scale))
                if DEBUG_MODE then 
                    DebugLine(w_inj_center, w_inj_pos)
                end
            end
            PB_.injection_timer = PB_.injection_rate
        end
        PB_.injection_timer = math.max(0, PB_.injection_timer - dt)
        PlayLoop(fire_sound, booster_trans.pos, 10)
        PlayLoop(rumble_sound, booster_trans.pos, 10)
    end
end