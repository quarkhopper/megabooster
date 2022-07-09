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
PB_ = {}
PB_.selected_booster = nil
PB_.edit_wp = nil
PB_.edit_wp_dist = 10
PB_.edit_wp_rad = 1
PB_.editing_wp = false
PB_.injection_count = 100
PB_.burn_radius = 0.5
PB_.impulse_const = 100 
PB_.impulse_hover_min = 0.05
PB_.max_impulse = 0
PB_.joint_offset = 4.7 -- from bottom of bell
PB_.inj_center = Vec(0, 2, 0)
PB_.stand_body = nil
PB_.gim_lim = 10
PB_.lat_gim_lim = 6
PB_.real_flames = false
PB_.pretty_flame_amount = 0.5
PB_.outline_time = 0
PB_.outlines = {}
PB_.gimb_kp = 3
PB_.gimb_ki = 0.001
PB_.gimb_kd = 0.1
PB_.imp_kp = 0.5
PB_.imp_ki = 0.001
PB_.imp_kd = 0.1
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

function inst_waypoint(pos, rad)
    local inst = {}
    inst.pos = pos
    inst.rad = rad or 10
    local hit, dist = QueryRaycast(inst.pos, Vec(0, -1, 0), 2000)
    if not hit then 
        dist = 2000
    end
    inst.ground = VecAdd(inst.pos, VecScale(Vec(0, -1, 0), dist))
    inst.on_groud = VecLength(VecSub(inst.pos, inst.ground)) < 0.1
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
    inst.att_x_pid = inst_pid(inst.gimb_kp, inst.gimb_ki, inst.gimb_kd) -- x gimbal
    inst.att_y_pid = inst_pid(inst.gimb_kp, inst.gimb_ki, inst.gimb_kd) -- y gimbal
    inst.att_z_pid = inst_pid(inst.gimb_kp, inst.gimb_ki, inst.gimb_kd) -- z gimbal
    inst.lat_x_pid = inst_pid(inst.gimb_kp, inst.gimb_ki, inst.gimb_kd) -- lateral motion x
    inst.lat_z_pid = inst_pid(inst.gimb_kp, inst.gimb_ki, inst.gimb_kd) -- lateral motion z
    inst.i_pid = inst_pid(inst.imp_kp, inst.imp_ki, inst.imp_kd) -- impulse
    inst.gimbal = QuatEuler(0, 0, 0)
    inst.impulse = PB_.max_impulse
    inst.nav_mode = nav_mode.hover
    inst.waypoint = nil        
    inst.ignition = false

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
end

function magnetize_boosters()
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

function spawn_or_select_booster()
    local hit_point, normal, shape = get_shoot_hit(100)
	if hit_point then
        local hit_body = GetShapeBody(shape)
        local trans = nil
        local booster_selected = nil
        for i = 1, #booster do
            local booster = boosters[i]
            if hit_body == booster.mount or hit_body == booster.bell then 
                booster_selected = booster
                break
            end
        end
        if booster_selected ~= nil then
            PB_.selected_booster = booster_selected
            PlaySound(spawn_sound, booster_selected.t_bell.pos, 10)
            table.insert(PB_.outlines, booster_selected.mount)
            table.insert(PB_.outlines, booster_selected.bell) 
            PB_.outline_time = 0
        else
            if hit_body ~= 1 and hit_body ~= nil then 
                local spawn_point = VecAdd(hit_point, VecScale(normal, PB_.joint_offset))
                local spawn_quat = quat_between_vecs(Vec(0,1,0), VecScale(normal, -1))
                trans = Transform(spawn_point, spawn_quat)
            else
                trans = Transform(hit_point, QuatEuler(0,0,0))
            end
            local booster = inst_booster(trans)
            table.insert(boosters, booster)
            PlaySound(spawn_sound,trans.pos, 10)
            table.insert(PB_.outlines, booster.mount)
            table.insert(PB_.outlines, booster.bell)
            PB_.outline_time = 0
            PB_.editing_wp = true
        end
	end
end

function booster_ignition_toggle()
    for i = 1, #boosters do
        local booster = boosters[i]
        if not booster.ignition and booster.waypoint ~= nil then 
            booster.ignition = true
        else
            booster.ignition = false
        end
    end
end

function update_control(booster, dt)
    if not booster.ignition then return end -- don't bother doing anything
    local mount_top = VecAdd(booster.t_mount.pos, Vec(0, PB_.joint_offset, 0))
    local q_actual = booster.t_mount.rot
    local v_actual = QuatRotateVec(q_actual, Vec(0, 1, 0))
    local x_a, y_a, z_a = GetQuatEuler(q_actual)
    local vel = GetBodyVelocity(booster.mount)
    local q_to_target = Quat()

    -- set attitude
    -- waypoint goverened flight
    if booster.nav_mode == nav_mode.fly then 
        -- fly right at the waypoint
        local p_target = booster.waypoint.pos 
        local v_target = VecNormalize(VecSub(p_target, booster.t_mount.pos))
        q_to_target = quat_between_vecs(v_actual, v_target)
    elseif booster.nav_mode == nav_mode.hover then
        -- orient straight up
        q_to_target = quat_between_vecs(v_actual, Vec(0, 1, 0))
        -- adjust gimbal for lateral correction
        local lat_target = VecAdd(booster.waypoint.pos, Vec(0, mount_top[2] + 10, 0))
        local lat_delta = VecSub(lat_target, mount_top)
        local lat_x_pid = PID(booster.lat_x_pid, 0, lat_delta[1])
        local lat_z_pid = PID(booster.lat_z_pid, 0, lat_delta[3])
        local v_lat = VecNormalize(Vec(lat_x_pid, lat_target[2], lat_z_pid))
        local q_lat = quat_between_vecs(v_lat, Vec(0, 1, 0))
        local q_lat = limit_quat(q_lat, PB_.lat_gim_lim)
        q_to_target = quat_add(q_to_target, q_lat)
    end
    if VecLength(VecSub(booster.waypoint.pos, booster.t_mount.pos)) <= booster.waypoint.rad then 
        -- arrived at the waypoint
        if booster.nav_mode ~= nav_mode.hover or boosetr.waypoint.on_ground then 
            -- if flying at the wp or it's on the ground then cut engine
            booster.ignition = false
        end
    end 
    if not booster.ignition then return end -- in case we've just shut down
    -- gimble converge on guide attitude
    local x_s, y_s, z_s = GetQuatEuler(q_to_target)
    booster.gimbal = QuatEuler(
        bracket_value(PID(booster.att_x_pid, x_s, x_a), PB_.gim_lim, -PB_.gim_lim),
        bracket_value(PID(booster.att_y_pid, y_s, y_a), PB_.gim_lim, -PB_.gim_lim),
        bracket_value(PID(booster.att_z_pid, z_s, z_a), PB_.gim_lim, -PB_.gim_lim)
    )    

    -- impulse converge on altitude
    if booster.nav_mode == nav_mode.hover then 
        -- constant asc/desc 
        local sign = 1
        if mount_top[2] > booster.waypoint.pos[2] then sign = -1 end
        local vel_set = (booster.waypoint.degree * sign)
        local vel_diff = vel[2] - vel_set
        local i_pid = PID(booster.i_pid, 0, vel_diff) / 100
        booster.impulse = bracket_value(booster.impulse + i_pid, PB_.att_impulse, PB_.impulse_hover_min)
    elseif booster.nav_mode == nav_mode.fly then
        -- constant impulse 
        booster.impulse = booster.waypoint.degree
    end

    if DEBUG_MODE then 
        DebugLine(booster.t_mount.pos, VecAdd(booster.t_mount.pos, QuatRotateVec(q_actual, Vec(0, 10, 0))))
        DebugLine(booster.t_mount.pos, VecAdd(booster.t_mount.pos, QuatRotateVec(q_to_target, Vec(0, 10, 0))), 0, 1, 0)
        DebugLine(booster.t_mount.pos, VecAdd(booster.t_mount.pos, QuatRotateVec(booster.gimbal, Vec(0, 10, 0))), 0, 0, 1)
    end
end

function waypoint_edit_tick(dt)
    if PB_.editing_wp then 
        local pos = nil
        local camera = GetPlayerCameraTransform()
        local shoot_dir = TransformToParentVec(camera, Vec(0, 0, -1))
        local hit, dist, normal, shape = QueryRaycast(camera.pos, shoot_dir, PB_.edit_wp_dist, 0.025, false)
        if hit then
            pos =  VecAdd(camera.pos, VecScale(shoot_dir, dist))
        else
            pos =  VecAdd(camera.pos, VecScale(shoot_dir, PB_.edit_wp_dist))
        end        
        PB_.edit_wp = inst_waypoint(pos, PB_.edit_wp_rad)
        draw_waypoint(PB_.edit_wp)
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
        if booster.waypoint ~= nil then 
            draw_waypoint_end(booster.waypoint.pos, booster.waypoint.rad, Vec(1, 0, 0))
        end
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
            end
            local center_dir = TransformToParentVec(booster_trans, Vec(0, 1, 0))
            local force_dirs = radiate(center_dir, 60, PB_.injection_count, math.random() * 360)
            for d = 1, #force_dirs do
                -- push on the booster bell the opposite way
                local force_dir = force_dirs[d]
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
    draw_waypoint_end(waypoint.pos, waypoint.rad, Vec(0, 1, 0))
    draw_waypoint_end(waypoint.ground, 1, Vec(1, 0, 0))
    DrawLine(waypoint.pos, waypoint.ground)
end

function draw_waypoint_end(pos, rad, color)
    local t = Transform(pos, QuatEuler(0,0,0))
    draw_square(t, rad, color[1], color[2], color[3])
    t = Transform(pos, QuatEuler(90,0,0))
    draw_square(t, rad,color[1], color[2], color[3])
    t = Transform(pos, QuatEuler(0,0,90))
    draw_square(t, rad, color[1], color[2], color[3])
end

function draw_square(trans, size, r, g, b)
    local half = size / 2
    local ca = TransformToParentPoint(trans, Vec(-half, 0, -half))
    local cb = TransformToParentPoint(trans, Vec(half, 0, -half))
    local cc = TransformToParentPoint(trans, Vec(half, 0, half))
    local cd = TransformToParentPoint(trans, Vec(-half, 0, half))
    DrawLine(ca, cb, r, g, b)
    DrawLine(cb, cc, r, g, b)
    DrawLine(cc, cd, r, g, b)
    DrawLine(cd, ca, r, g, b)
end
