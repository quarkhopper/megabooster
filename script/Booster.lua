#include "Defs.lua"

rumble_sound = LoadLoop("MOD/snd/rumble.ogg")
fire_sound = LoadLoop("MOD/snd/rocketfire.ogg")

PB_ = {}
PB_.ignition = false
PB_.injection_count = 100
PB_.burn_radius = 0.5
PB_.power = 0
PB_.ramp = 1 -- time to full power\
PB_.impulse_const = 10
PB_.joint_offset = 4.7
PB_.inj_center = Vec(0, 2, 0)
PB_.stand_body = nil

boosters = {}
stands = {}

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
    local hit_point, normal, shape = get_shoot_hit(100)
	if hit_point then
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

function spawn_stand()
    local hit_point = get_shoot_hit(100)
    if hit_point then
        local trans = Transform(hit_point, QuatEuler(0,0,0))
        table.insert(stands, Spawn("MOD/prefab/pyro_stand.xml", trans)[1])
    end
end

function clear_stands()
    for i = 1, #stands do
        Delete(stands[i])
    end
    stands = {}
end

function booster_ignition_toggle()
    PB_.power = 0
    PB_.ignition = not PB_.ignition
end

function set_gimbal(booster)
    local q_heading = QuatSlerp(booster.t_bell.rot, booster.t_mount.rot, 0.5)
    local v_heading = QuatRotateVec(q_heading, Vec(0,1,0))
    local q_diff = quat_between_vecs(v_heading, booster.v_home)
    local dp_diff = VecDot(booster.v_home, v_heading)
    local error = 1 - ((VecDot(booster.v_home, v_heading) + 1) / 2)
    local q_gimbal = QuatSlerp(QuatEuler(0,0,0), q_diff, TOOL.BOOSTER.gimbal_strength.value)
    if DEBUG_MODE then 
        DebugLine(booster.t_mount.pos, VecAdd(booster.t_mount.pos, VecScale(v_heading, 5)), 1, 0, 0)
        DebugLine(booster.t_mount.pos, VecAdd(booster.t_mount.pos, VecScale(booster.v_home, 5)), 0, 1, 0)
    end
    local rot_x,rot_y,rot_z = GetQuatEuler(q_gimbal)
    local lim = TOOL.BOOSTER.gimbal_max_angle.value
    booster.gimbal = QuatEuler(
        math.max(-lim, math.min(lim, rot_x)),
        math.max(-lim, math.min(lim, rot_y)),
        math.max(-lim, math.min(lim, rot_z))
    )
end

function booster_tick(dt)
    for b = 1, #boosters do
        local booster = boosters[b]
        booster.t_bell = GetBodyTransform(booster.bell)
        booster.t_mount = GetBodyTransform(booster.mount)
        set_gimbal(booster)
        ConstrainOrientation(booster.bell, booster.mount, QuatRotateQuat(booster.gimbal, booster.t_bell.rot), booster.t_mount.rot)
        if PB_.ignition then
            PB_.power = math.min(PB_.power + (PB_.ramp * dt), 1)
            TOOL.BOOSTER.pyro.impulse_scale = TOOL.BOOSTER.impulse.value * PB_.impulse_const * PB_.power
            local booster_trans = GetBodyTransform(booster.bell)
            local l_inj_center = PB_.inj_center
            local w_inj_center = TransformToParentPoint(booster_trans, l_inj_center)
            local booster_vel = GetBodyVelocity(booster.bell)
            local total_thrust = 0
            for i = 1, PB_.injection_count do
                local l_inj_dir = random_vec(1, Vec(0, -1, 0), 90)
                local w_inj_dir = TransformToParentVec(booster_trans, l_inj_dir)
                local w_inj_pos = VecAdd(w_inj_center, VecScale(w_inj_dir, PB_.burn_radius))
                local magnitude = TOOL.BOOSTER.pyro.ff.max_force / 2
                apply_force(TOOL.BOOSTER.pyro.ff, w_inj_pos, magnitude)
                -- push on the booster bell the opposite way
                local force_mag = magnitude * TOOL.BOOSTER.pyro.impulse_scale
                total_thrust = total_thrust + force_mag
                local force_dir = VecScale(w_inj_dir, -1)
                local force_vec = VecScale(force_dir, force_mag)
                ApplyBodyImpulse(booster.bell, w_inj_center, force_vec)
                -- if DEBUG_MODE then 
                --     DebugLine(w_inj_center, w_inj_pos)
                --     DebugLine(w_inj_center, VecAdd(w_inj_pos, VecScale(force_dir, 1)), 1, 0, 0)
                -- end
            end
            -- DebugPrint(tostring(total_thrust))
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

PID_ = {}
PID_.last_error = 0
PID_.last_integral = 0
PID_.kp = 0.3
PID_.ki = 0.3
PID_.kd = 0.3
PID_.error = 0

function PID(set_point, actual)
	PID_.error = set_point - actual
	PID_.integral = PID_.last_integral + PID_.error
	PID_.derivative = PID_.error - PID_.last_error	
		
	PID_.last_error = PID_.error
	PID_.last_integral = PID_.integral
	
    return PID_.kp * PID_.error + PID_.ki * PID_.integral + PID_.kd * PID_.derivative
end