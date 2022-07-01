#include "Defs.lua"

rumble_sound = LoadLoop("MOD/snd/rumble.ogg")
fire_sound = LoadLoop("MOD/snd/rocketfire.ogg")

PB_ = {}
PB_.ignition = false
PB_.injection_count = 10
PB_.burn_radius = 1
PB_.power = 0
PB_.ramp = 1 -- time to full power\
PB_.impulse_const = 1
PB_.joint_offset = 4

boosters = {} -- body handles

debugline = {Vec(), Vec()}

function clear_boosters()
	reset_ff(TOOL.BOOSTER.pyro.ff)
	for i = 1, #boosters do
		Delete(boosters[i])
	end
	boosters = {}
end

function spawn_booster()
	local camera = GetPlayerCameraTransform()
	local shoot_dir = TransformToParentVec(camera, Vec(0, 0, -1))
	local rotx, roty, rotz = GetQuatEuler(camera.rot)
	local hit, dist, normal, shape = QueryRaycast(camera.pos, shoot_dir, 100, 0.025, true)
	if hit then
		local hit_point = VecAdd(camera.pos, VecScale(shoot_dir, dist))
        local hit_body = GetShapeBody(shape)
        local trans = nil
        if hit_body ~= 1 and hit_body ~= nil then 
            local spawn_point = VecAdd(hit_point, VecScale(normal, PB_.joint_offset))
            local spawn_quat = quat_between_vecs(Vec(0,1,0), VecScale(normal, -1))
            trans = Transform(spawn_point, spawn_quat)
        else
		    trans = Transform(hit_point, QuatEuler(0,0,0))
            PB_.host_body = nil
        end
		local booster_body = Spawn("MOD/prefab/pyro_booster.xml", trans, false, true)[1]
        table.insert(boosters, booster_body)
	end
end

function booster_ignition_toggle()
    PB_.power = 0
    PB_.ignition = not PB_.ignition
end

function booster_tick(dt)
    if PB_.ignition then
        for b = 1, #boosters do
            local booster_body = boosters[b]
            PB_.power = math.min(PB_.power + (PB_.ramp * dt), 1)
            TOOL.BOOSTER.pyro.impulse_scale = TOOL.BOOSTER.impulse.value * PB_.impulse_const * PB_.power
            local booster_trans = GetBodyTransform(booster_body)
            local l_inj_center = Vec(0, 1, -0.1)
            local w_inj_center = TransformToParentPoint(booster_trans, l_inj_center)

            local booster_vel = GetBodyVelocity(booster_body)
            for i = 1, PB_.injection_count do
                local l_inj_dir = random_vec(1, Vec(0, -1, 0), 60)
                local w_inj_dir = TransformToParentVec(booster_trans, l_inj_dir)
                local w_inj_pos = VecAdd(w_inj_center, VecScale(w_inj_dir, PB_.burn_radius))
                local magnitude = TOOL.BOOSTER.pyro.ff.max_force / 2
                apply_force(TOOL.BOOSTER.pyro.ff, w_inj_pos, magnitude)
                if DEBUG_MODE then 
                    DebugLine(w_inj_center, w_inj_pos)
                end
            end
            PlayLoop(fire_sound, booster_trans.pos, 10)
            PlayLoop(rumble_sound, booster_trans.pos, 10)
        end
    end
end