#include "Defs.lua"

rumble_sound = LoadLoop("MOD/snd/rumble.ogg")
fire_sound = LoadLoop("MOD/snd/rocketfire.ogg")
spawn_sound = LoadSound("MOD/snd/clang.ogg")

PB_ = {}
PB_.ignition = false
PB_.injection_count = 100
PB_.burn_radius = 0.5
PB_.power = 0
PB_.ramp = 1 -- time to full power\
PB_.impulse_const = 100 
PB_.joint_offset = 4.7
PB_.inj_center = Vec(0, 2, 0)
PB_.stand_body = nil
PB_.gim_lim = 30
PB_.gim_apply = 0.5
PB_.real_flames = false
PB_.impulse = 0.5
PB_.pretty_flame_amount = 0.5
PB_.outline_time = 0
PB_.outlines = {}

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
    return inst
end

function delete_booster_bodies(booster)
    Delete(booster.bell)
    Delete(booster.mount)
end

function clear_boosters()
	reset_ff(TOOL.BOOSTER.pyro.ff)
	for i = 1, #boosters do
		delete_booster_bodies(boosters[i])
	end
	boosters = {}
    PB_.ignition = false
end

function reattach_boosters()
    for i = 1, #boosters do
        local booster = boosters[i]
        local t_mount = GetBodyTransform(booster.mount)
        local t_bell = GetBodyTransform(booster.bell)
        Delete(booster.mount)
        Delete(booster.bell)
        booster.mount = Spawn("MOD/prefab/pyro_booster_mount.xml", t_mount, false, true)[1]
        booster.bell = Spawn("MOD/prefab/pyro_booster_bell.xml", t_bell, false, true)[1]
        booster.t_mount = t_mount
        booster.t_bell = t_bell
        booster.q_home = t_mount.rot
        booster.v_home = QuatRotateVec(booster.q_home, Vec(0, 1, 0))
        PlaySound(spawn_sound, t_bell.pos, 10)
        table.insert(PB_.outlines, booster.mount)
        table.insert(PB_.outlines, booster.bell) 
        PB_.outline_time = 0
    end
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
        local booster = inst_booster(trans)
        table.insert(boosters, booster)
        PlaySound(spawn_sound,trans.pos, 10)
        table.insert(PB_.outlines, booster.mount)
        table.insert(PB_.outlines, booster.bell)
        PB_.outline_time = 0
	end
end

function booster_ignition_toggle()
    PB_.power = 0
    PB_.ignition = not PB_.ignition
end

function set_gimbal(booster)
    if PB_.gim_apply == 0 then 
        booster.gimbal = QuatEuler(0, 0, 0) 
        return
    end
    local q_heading = QuatSlerp(booster.t_bell.rot, booster.t_mount.rot, 0.5)
    local v_heading = QuatRotateVec(q_heading, Vec(0,1,0))
    local q_diff = quat_between_vecs(v_heading, booster.v_home)
    local dp_diff = VecDot(booster.v_home, v_heading)
    local error = 1 - ((VecDot(booster.v_home, v_heading) + 1) / 2)
    local q_gimbal = QuatSlerp(QuatEuler(0, 0, 0), q_diff, PB_.gim_apply)
    if DEBUG_MODE then 
        DebugLine(booster.t_mount.pos, VecAdd(booster.t_mount.pos, VecScale(v_heading, 5)), 1, 0, 0)
        DebugLine(booster.t_mount.pos, VecAdd(booster.t_mount.pos, VecScale(booster.v_home, 5)), 0, 1, 0)
    end
    local rot_x,rot_y,rot_z = GetQuatEuler(q_gimbal)
    booster.gimbal = QuatEuler(
        math.max(-PB_.gim_lim, math.min(PB_.gim_lim, rot_x)),
        math.max(-PB_.gim_lim, math.min(PB_.gim_lim, rot_y)),
        math.max(-PB_.gim_lim, math.min(PB_.gim_lim, rot_z))
    )
end

function booster_tick(dt)
    if PB_.outline_time < 1 then 
        PB_.outline_time = math.min(PB_.outline_time + dt, 1)
        for i = 1, #PB_.outlines do
            DrawBodyOutline(PB_.outlines[i], 1, 1, 1, 1)
        end
    else
        PB_.outlines = {}
    end
    for b = 1, #boosters do
        local booster = boosters[b]
        booster.t_bell = GetBodyTransform(booster.bell)
        booster.t_mount = GetBodyTransform(booster.mount)
        set_gimbal(booster)
        ConstrainOrientation(booster.bell, booster.mount, QuatRotateQuat(booster.gimbal, booster.t_bell.rot), booster.t_mount.rot)
        if PB_.ignition then
            PB_.power = math.min(PB_.power + (PB_.ramp * dt), 1)
            TOOL.BOOSTER.pyro.impulse_scale = PB_.impulse * PB_.impulse_const * PB_.power
            local booster_trans = GetBodyTransform(booster.bell)
            local l_inj_center = PB_.inj_center
            local w_inj_center = TransformToParentPoint(booster_trans, l_inj_center)
            local total_thrust = 0
            local magnitude = TOOL.BOOSTER.pyro.ff.max_force / 2
            local force_mag = magnitude * TOOL.BOOSTER.pyro.impulse_scale
            local pretty_color = blend_color(math.random(), 
                HSVToRGB(TOOL.BOOSTER.pyro.color_hot), 
                HSVToRGB(TOOL.BOOSTER.pyro.color_cool))
            for i = 1, PB_.injection_count do
                local l_inj_dir = random_vec(1, Vec(0, -1, 0), 90)
                local w_inj_dir = TransformToParentVec(booster_trans, l_inj_dir)
                if PB_.real_flames then 
                    local w_inj_pos = VecAdd(w_inj_center, VecScale(w_inj_dir, PB_.burn_radius))
                    apply_force(TOOL.BOOSTER.pyro.ff, w_inj_pos, magnitude)
                end
                -- aeaeaesthetic flames
                if not DEBUG_MODE and not PB_.real_flames then
                        if math.random() < PB_.pretty_flame_amount then
                            local light_color = blend_color(math.random(), 
                                HSVToRGB(TOOL.BOOSTER.pyro.color_hot), 
                                HSVToRGB(TOOL.BOOSTER.pyro.color_cool))
                            PointLight(VecAdd(random_vec(1), w_inj_center), pretty_color[1], pretty_color[2], pretty_color[3], 1)
                            ParticleReset()
                            ParticleType("smoke")
                            ParticleTile(5)
                            ParticleAlpha(1, 0, "easeout", 0, 1)
                            ParticleRadius(0.5)
                            local smoke_color = HSVToRGB(Vec(0, 0, 0.8))
                            ParticleColor(smoke_color[1], smoke_color[2], smoke_color[3])
                            SpawnParticle(w_inj_center, VecScale(l_inj_dir, 10), 0.2)
                    end
                end

                -- push on the booster bell the opposite way
                total_thrust = total_thrust + force_mag
                local force_dir = VecScale(w_inj_dir, -1)
                local force_vec = VecScale(force_dir, force_mag)
                ApplyBodyImpulse(booster.bell, w_inj_center, force_vec)
            end

            -- add a little glow inside the bell
            if not DEBUG_MODE and PB_.real_flames then 
                PointLight(w_inj_center, pretty_color[1], pretty_color[2], pretty_color[3], 10)
            end

            PlayLoop(fire_sound, booster_trans.pos, 10)
            PlayLoop(rumble_sound, booster_trans.pos, 10)
        else
            PB_.power = 0
        end
    end
end

-- PID_ = {}
-- PID_.last_error = 0
-- PID_.last_integral = 0
-- PID_.kp = 0.3
-- PID_.ki = 0.3
-- PID_.kd = 0.3
-- PID_.error = 0

-- function PID(set_point, actual)
-- 	PID_.error = set_point - actual
-- 	PID_.integral = PID_.last_integral + PID_.error
-- 	PID_.derivative = PID_.error - PID_.last_error	
		
-- 	PID_.last_error = PID_.error
-- 	PID_.last_integral = PID_.integral
	
--     return PID_.kp * PID_.error + PID_.ki * PID_.integral + PID_.kd * PID_.derivative
-- end