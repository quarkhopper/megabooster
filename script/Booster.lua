#include "Defs.lua"

rumble_sound = LoadLoop("MOD/snd/rumble.ogg")
fire_sound = LoadLoop("MOD/snd/rocketfire.ogg")

PB_ = {}
PB_.ignition = false
PB_.injection_count = 10
PB_.burn_radius = 0.5
PB_.power = 0
PB_.ramp = 1 -- time to full power\
PB_.impulse_const = 1
PB_.joint_offset = 4.7

boosters = {}

debugline = {Vec(), Vec()}

function inst_booster(trans)
    local inst = {}
    inst.mount = Spawn("MOD/prefab/pyro_booster_mount.xml", trans, false, true)[1]
    inst.bell = Spawn("MOD/prefab/pyro_booster_bell.xml", trans, false, true)[1]
    inst.q_home = trans.rot
    inst.v_home = QuatRotateVec(inst.q_home, Vec(0, 1, 0))
    inst.t_mount = QuatEuler(0, 0, 0)
    inst.t_bell = QuatEuler(0, 0, 0)
    inst.gimbal = QuatEuler(0, 0, 0)
    inst.gimlim = 10
    return inst
end

function delete_booster(booster)
    Delete(booster.bell)
    Delete(booster.mount)
end

function clear_boosters()
	reset_ff(TOOL.BOOSTER.pyro.ff)
	for i = 1, #boosters do
		delete_booster(boosters[i])
	end
	boosters = {}
    PB_.ignition = false
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
        table.insert(boosters, inst_booster(trans))
	end
end

function booster_ignition_toggle()
    PB_.power = 0
    PB_.ignition = not PB_.ignition
end

function set_gimbal(booster)
    local q_heading = QuatSlerp(booster.t_bell.rot, booster.t_mount.rot, 0.5)
    local v_heading = QuatRotateVec(q_heading, Vec(0,1,0))
    local q_gimbal = quat_between_vecs(v_heading, booster.v_home)
    if DEBUG_MODE then 
        DebugLine(booster.t_mount.pos, VecAdd(booster.t_mount.pos, VecScale(v_heading, 5)), 1, 0, 0)
        DebugLine(booster.t_mount.pos, VecAdd(booster.t_mount.pos, VecScale(booster.v_home, 5)), 0, 1, 0)
    end
    local rot_x,rot_y,rot_z = GetQuatEuler(q_gimbal)
    booster.gimbal = QuatEuler(
        math.max(-booster.gimlim, math.min(booster.gimlim, rot_x)),
        math.max(-booster.gimlim, math.min(booster.gimlim, rot_y)),
        math.max(-booster.gimlim, math.min(booster.gimlim, rot_z))
    )
end

function booster_tick(dt)
    for b = 1, #boosters do
        local booster = boosters[b]
        booster.t_bell = GetBodyTransform(booster.bell)
        booster.t_mount = GetBodyTransform(booster.mount)
        set_gimbal(booster)
        ConstrainOrientation(booster.bell, booster.mount, QuatRotateQuat(booster.gimbal, booster.t_bell.rot), booster.t_mount.rot)
        -- ConstrainOrientation(booster.bell, booster.mount, booster.t_bell.rot, booster.t_mount.rot)
        if PB_.ignition then
            PB_.power = math.min(PB_.power + (PB_.ramp * dt), 1)
            TOOL.BOOSTER.pyro.impulse_scale = TOOL.BOOSTER.impulse.value * PB_.impulse_const * PB_.power
            local booster_trans = GetBodyTransform(booster.bell)
            local l_inj_center = Vec(0, 1, 0)
            local w_inj_center = TransformToParentPoint(booster_trans, l_inj_center)
            local booster_vel = GetBodyVelocity(booster.bell)
            for i = 1, PB_.injection_count do
                local l_inj_dir = random_vec(1, Vec(0, -1, 0), 60)
                local w_inj_dir = TransformToParentVec(booster_trans, l_inj_dir)
                local w_inj_pos = VecAdd(w_inj_center, VecScale(w_inj_dir, PB_.burn_radius))
                local magnitude = TOOL.BOOSTER.pyro.ff.max_force / 2
                apply_force(TOOL.BOOSTER.pyro.ff, w_inj_pos, magnitude)
                local force_vec = VecScale(TransformToParentVec(booster_trans, Vec(0, 1, 0)), magnitude * 1)
                local force_point = TransformToParentPoint(booster_trans, Vec(0,2,0))
                ApplyBodyImpulse(booster.bell, force_point, force_vec)
                if DEBUG_MODE then 
                    DebugLine(w_inj_center, w_inj_pos)
                end
            end
            if not DEBUG_MODE then 
                local flame_pos = TransformToParentPoint(booster_trans, Vec(0,2,0))
                local light_color = HSVToRGB(TOOL.BOOSTER.pyro.color_hot)
                PointLight(flame_pos, light_color[1], light_color[2], light_color[3], 10)
                ParticleReset()
                ParticleType("smoke")
                ParticleAlpha(1, 0, "easeout", 0, 1)
                ParticleRadius(0.5)
                local smoke_color = HSVToRGB(Vec(0, 0, 0.3))
                ParticleColor(smoke_color[1], smoke_color[2], smoke_color[3])
                SpawnParticle(flame_pos, Vec(), 0.2)
            end
            PlayLoop(fire_sound, booster_trans.pos, 10)
            PlayLoop(rumble_sound, booster_trans.pos, 10)
        end
    end
end