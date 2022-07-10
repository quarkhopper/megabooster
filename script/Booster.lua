#include "Defs.lua"

rumble_sound = LoadLoop("MOD/snd/rumble.ogg")
fire_sound = LoadLoop("MOD/snd/rocketfire.ogg")
spawn_sound = LoadSound("MOD/snd/clang.ogg")
debugline = {Vec(), Vec()}

PB_ = {}
PB_.boosters = {}
PB_.wp_cursor = nil
PB_.wp_cursor_on = false
PB_.injection_count = 100
PB_.burn_radius = 0.5
PB_.impulse_const = 100 
PB_.impulse_hover_min = 0.05
PB_.max_impulse = 0
PB_.joint_offset = 4.7 -- from bottom of bell
PB_.inj_center = Vec(0, 2, 0)
PB_.stand_body = nil
PB_.att_gim_lim = 10
PB_.hover_velocity = 0.5
PB_.real_flames = false
PB_.pretty_flame_amount = 0.5
PB_.outline_time = 0
PB_.outlines = {}
PB_.gimb_att_kp = 3
PB_.gimb_att_ki = 0.001
PB_.gimb_att_kd = 0.4


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
    inst.att_x_pid = inst_pid(PB_.gimb_att_kp, PB_.gimb_att_ki, PB_.gimb_att_kd)
    inst.att_y_pid = inst_pid(PB_.gimb_att_kp, PB_.gimb_att_ki, PB_.gimb_att_kd)
    inst.att_z_pid = inst_pid(PB_.gimb_att_kp, PB_.gimb_att_ki, PB_.gimb_att_kd)
    inst.gimbal = QuatEuler(0, 0, 0)
    inst.impulse = PB_.max_impulse
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
	for i = 1, #PB_.boosters do
		delete_booster_bodies(PB_.boosters[i])
	end
	PB_.boosters = {}
end

function magnetize_boosters()
    for i = 1, #PB_.boosters do
        local booster = PB_.boosters[i]
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
        table.insert(PB_.boosters, booster)
        PlaySound(spawn_sound,trans.pos, 10)
        table.insert(PB_.outlines, booster.mount)
        table.insert(PB_.outlines, booster.bell)
        PB_.outline_time = 0
        PB_.wp_cursor_on = true
	end
end

function booster_ignition_toggle()
    for i = 1, #PB_.boosters do
        local booster = PB_.boosters[i]
        booster.ignition = not booster.ignition
    end
end

function fly_to_target()
    for i = 1, #PB_.boosters do
        local booster = PB_.boosters[i]
        booster.waypoint = PB_.wp_cursor
        booster.ignition = true
    end
end

function update_control(booster, dt)
    if not booster.ignition then return end -- don't bother doing anything
    local mount_top = VecAdd(booster.t_mount.pos, Vec(0, PB_.joint_offset, 0))
    local q_actual = booster.t_mount.rot
    local v_actual = QuatRotateVec(q_actual, Vec(0, 1, 0))
    local x_a, y_a, z_a = GetQuatEuler(q_actual)
    local vel = GetBodyVelocity(booster.mount)

    -- gimbal control
    local v_target = Vec()
    if booster.waypoint ~= nil then
        -- fly right at the waypoint 
        v_target = VecNormalize(VecSub(booster.waypoint.pos, mount_top))
    else
        v_target = booster.v_home
    end
    local q_to_target = quat_between_vecs(v_actual, v_target)
    local x_s, y_s, z_s = GetQuatEuler(q_to_target)
    booster.gimbal = QuatEuler(
        bracket_value(PID(booster.att_x_pid, x_s, x_a), PB_.att_gim_lim, -PB_.att_gim_lim),
        bracket_value(PID(booster.att_y_pid, y_s, y_a), PB_.att_gim_lim, -PB_.att_gim_lim),
        bracket_value(PID(booster.att_z_pid, z_s, z_a), PB_.att_gim_lim, -PB_.att_gim_lim)
    ) 

    -- check if arrived at target
    if booster.waypoint ~= nil and 
        VecLength(VecSub(booster.waypoint.pos, mount_top)) <= booster.waypoint.rad then 
        -- arrived at the waypoint
        booster.ignition = false
    end 
end

function waypoint_edit_tick(dt)
    if PB_.wp_cursor_on then 
        local camera = GetPlayerCameraTransform()
        local shoot_dir = TransformToParentVec(camera, Vec(0, 0, -1))
        local hit, dist, normal, shape = QueryRaycast(camera.pos, shoot_dir, 2000)
        if hit then
            local hit_point = VecAdd(camera.pos, VecScale(shoot_dir, dist))
            PB_.wp_cursor = inst_waypoint(hit_point, 10)
            draw_waypoint(PB_.wp_cursor)
        else
            PB_.wp_cursor = nil
            local square_pos = TransformToParentPoint(camera, Vec(0, 0, -1))
            draw_square(Transform(square_pos, QuatRotateQuat(camera.rot, QuatEuler(90, 0, 0))), 0.2, 1, 0, 0)
        end
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
    for b = 1, #PB_.boosters do
        local booster = PB_.boosters[b]
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
            local magnitude = TOOL.BOOSTER.pyro.ff.max_force / 2
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
