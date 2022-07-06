#include "Defs.lua"

rumble_sound = LoadLoop("MOD/snd/rumble.ogg")
fire_sound = LoadLoop("MOD/snd/rocketfire.ogg")
spawn_sound = LoadSound("MOD/snd/clang.ogg")
boosters = {}
debugline = {Vec(), Vec()}
nav_mode = enum {
    "fly", -- orient to point at target, constant impulse
    "hover", -- orient to point above target, constant rate of ascent/descent
    "att" -- orient to home attitude
}
waypoints = {}


PB_ = {}
PB_.injection_count = 100
PB_.burn_radius = 0.5
PB_.impulse_const = 100 
PB_.att_impulse = 0
PB_.joint_offset = 4.7 -- from bottom of bell
PB_.inj_center = Vec(0, 2, 0)
PB_.stand_body = nil
PB_.gim_lim = 30
PB_.real_flames = false
PB_.pretty_flame_amount = 0.5
PB_.outline_time = 0
PB_.outlines = {}
PB_.gimb_kp = 3
PB_.gimb_ki = 0.001
PB_.gimb_kd = 0.4
PB_.imp_kp = 3
PB_.imp_ki = 0.001
PB_.imp_kd = 0.4
PB_.max_vel_adj = 1


function PID(pid, set_point, actual)
	local error = set_point - actual
	local integral = pid.last_i + error
	local derivative = error - pid.last_e
		
	pid.last_e = error
	pid.last_i = integral
    return (pid.kp * error) + (pid.ki * integral) + (pid.kd * derivative)
end

function inst_pid(kp, ki, kd)
    local inst = {}
    inst.last_e = 0
    inst.last_i = 0
    inst.kp = kp
    inst.ki = ki
    inst.kd = kd
    return inst
end

function inst_waypoint(pos, nav_mode, degree, rad, shutdown)
    local inst = {}
    inst.pos = pos
    inst.shutdown = shutdown
    inst.nav_mode = nav_mode
    inst.degree = degree
    inst.rad = rad or 10
    return inst
end

function inst_booster(trans)
    local inst = {}
    inst.mount = Spawn("MOD/prefab/pyro_booster_mount.xml", trans, false, true)[1]
    inst.bell = Spawn("MOD/prefab/pyro_booster_bell.xml", trans, false, true)[1]
    inst.q_home = trans.rot
    inst.v_home = QuatRotateVec(inst.q_home, Vec(0, 1, 0))
    inst.p_home = trans.pos
    inst.t_mount = QuatEuler(0, 0, 0)
    inst.t_bell = QuatEuler(0, 0, 0)
    inst.gimb_kp = PB_.gimb_kp
    inst.gimb_ki = PB_.gimb_ki
    inst.gimb_kd = PB_.gimb_kd
    inst.imp_kp = PB_.imp_kp
    inst.imp_ki = PB_.imp_ki
    inst.imp_kd = PB_.imp_kd
    inst.x_pid = inst_pid(inst.gimb_kp, inst.gimb_ki, inst.gimb_kd) -- x gimbal
    inst.y_pid = inst_pid(inst.gimb_kp, inst.gimb_ki, inst.gimb_kd) -- y gimbal
    inst.z_pid = inst_pid(inst.gimb_kp, inst.gimb_ki, inst.gimb_kd) -- z gimbal
    inst.i_pid = inst_pid(inst.imp_kp, inst.imp_ki, inst.imp_kd) -- impulse
    inst.gimbal = QuatEuler(0, 0, 0)
    inst.impulse = PB_.att_impulse
    inst.nav_mode = nav_mode.att
    inst.waypoints = {}
    inst.waypoint_i = 0
    inst.waypoint = nil        
    inst.ignition = false

    return inst
end

function next_waypoint(booster)
    booster.waypoint_i = booster.waypoint_i + 1
    if booster.waypoint_i > #booster.waypoints then booster.waypoint_i = 1 end
    booster.waypoint = booster.waypoints[booster.waypoint_i]
    booster.nav_mode = booster.waypoint.nav_mode
end

function set_booster_waypoints(booster, waypoints)
    booster.waypoints = waypoints
    booster.waypoint_i = 0
    next_waypoint(booster)
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
        end
        local booster = inst_booster(trans)
-- TEST 
        -- local waypoints = {
        --     inst_waypoint(Vec(0, 50, 0), nav_mode.hover, 1, 10, false),
        --     inst_waypoint(Vec(0, 20, 0), nav_mode.hover, 1, 10, false),
        --     inst_waypoint(Vec(0, 0, 0), nav_mode.hover, 1, 1, true)
        -- } 
        -- set_booster_waypoints(booster, waypoints)
-- END TEST
        table.insert(boosters, booster)
        PlaySound(spawn_sound,trans.pos, 10)
        table.insert(PB_.outlines, booster.mount)
        table.insert(PB_.outlines, booster.bell)
        PB_.outline_time = 0
	end
end

function booster_ignition_toggle()
    for i = 1, #boosters do
        local booster = boosters[i]
        booster.ignition = not booster.ignition
    end
end

function update_control(booster, dt)
    if not booster.ignition then return end -- don't bother doing anything
    local q_actual = booster.t_mount.rot
    local v_actual = QuatRotateVec(q_actual, Vec(0, 1, 0))
    local x_a, y_a, z_a = GetQuatEuler(q_actual)
    local q_guide = Quat()

    -- set guide attitude
    if booster.nav_mode == nav_mode.att then 
        -- keep the target attitude the home attitude, no target vector
        q_guide = booster.q_home
    elseif booster.nav_mode == nav_mode.fly or booster.nav_mode == nav_mode.hover then 
        booster.nav_mode = booster.waypoint.nav_mode
        local p_target = Vec()
        if booster.nav_mode == nav_mode.fly then 
            p_target = booster.waypoint.pos -- fly right at the waypoint
        elseif booster.nav_mode == nav_mode.hover then
            p_target = VecAdd(booster.waypoint.pos, Vec(0, booster.t_mount.pos[2] + 10, 0)) -- "hanging" from a 10 unit string above the target
        end
        local v_target = VecNormalize(VecSub(p_target, booster.t_mount.pos))
        q_guide = quat_between_vecs(v_actual, v_target)
        if VecLength(VecSub(booster.waypoint.pos, booster.t_mount.pos)) <= booster.waypoint.rad then 
            booster.ignition = not booster.waypoint.shutdown
            next_waypoint(booster)
        end 
    end
    if not booster.ignition then return end -- in case we've just shut down

    -- gimble converge on guide attitude
    local x_s, y_s, z_s = GetQuatEuler(q_guide)
    local r_pid = Vec(
        bracket_value(PID(booster.x_pid, x_s, x_a), PB_.gim_lim, -PB_.gim_lim),
        bracket_value(PID(booster.y_pid, y_s, y_a), PB_.gim_lim, -PB_.gim_lim),
        bracket_value(PID(booster.z_pid, z_s, z_a), PB_.gim_lim, -PB_.gim_lim)
    )
    booster.gimbal = QuatEuler(r_pid[1], r_pid[2], r_pid[3])

    -- impulse converge on 0 delta v
    if booster.nav_mode == nav_mode.hover then 
        -- constant asc/desc 
        local sign = 1
        if booster.t_mount.pos[2] > booster.waypoint.pos[2] then sign = -1 end
        local vel = GetBodyVelocity(booster.mount)
        local vel_set = (booster.waypoint.degree * sign)
        local vel_pid = PID(booster.i_pid, vel_set, vel[2])
        local scale = vel_pid / (vel_pid - vel[2])
        booster.impulse = bracket_value(scale, 0.08, 0)
        -- DebugPrint("wp: "..tostring(booster.waypoint_i)..", s: "..tostring(vel_set)..", a: "..tostring(vel[2])..", vel_pid: "..tostring(vel_pid)..", impulse: "..tostring(booster.impulse))
    elseif booster.nav_mode == nav_mode.fly then
        -- constant impulse 
        booster.impulse = booster.waypoint.degree
    end -- if nav_mode is att then don't change the set impulse

    if DEBUG_MODE then 
        DebugLine(booster.t_mount.pos, VecAdd(booster.t_mount.pos, QuatRotateVec(q_actual, Vec(0, 10, 0))))
        DebugLine(booster.t_mount.pos, VecAdd(booster.t_mount.pos, QuatRotateVec(q_guide, Vec(0, 10, 0))), 0, 1, 0)
        DebugLine(booster.t_mount.pos, VecAdd(booster.t_mount.pos, QuatRotateVec(booster.gimbal, Vec(0, 10, 0))), 1, 1, 0)
        for w = 1, #booster.waypoints do
            local waypoint = booster.waypoints[w]
            draw_waypoint(waypoint)
        end
        DebugPrint(tostring(booster.impulse))
    end
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
        if booster.ignition then
            update_control(booster, dt)
            ConstrainOrientation(booster.bell, booster.mount, QuatRotateQuat(booster.gimbal, booster.t_bell.rot), booster.t_mount.rot)    
            local booster_trans = GetBodyTransform(booster.bell)
            local l_inj_center = PB_.inj_center
            local w_inj_center = TransformToParentPoint(booster_trans, l_inj_center)
            local total_thrust = 0
            local magnitude = TOOL.BOOSTER.pyro.ff.max_force * booster.impulse
            local force_mag = magnitude * booster.impulse * PB_.impulse_const
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
            -- when not ignition, just straighten out the gimble
            ConstrainOrientation(booster.bell, booster.mount, booster.t_bell.rot, booster.t_mount.rot)    
        end
    end
end

function draw_waypoint(waypoint)
    DebugCross(waypoint.pos)
    local t = Transform(waypoint.pos, QuatEuler(0,0,0))
    draw_square(t, waypoint.rad, 1, 0, 0)
    t = Transform(waypoint.pos, QuatEuler(90,0,0))
    draw_square(t, waypoint.rad, 0, 1, 0)
    t = Transform(waypoint.pos, QuatEuler(0,0,90))
    draw_square(t, waypoint.rad, 0, 0, 1)
end

function draw_square(trans, size, r, g, b)
    local half = size / 2
    local ca = TransformToParentPoint(trans, Vec(-half, 0, -half))
    local cb = TransformToParentPoint(trans, Vec(half, 0, -half))
    local cc = TransformToParentPoint(trans, Vec(half, 0, half))
    local cd = TransformToParentPoint(trans, Vec(-half, 0, half))
    DebugLine(ca, cb, r, g, b)
    DebugLine(cb, cc, r, g, b)
    DebugLine(cc, cd, r, g, b)
    DebugLine(cd, ca, r, g, b)
end
