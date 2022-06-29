#include "Utils.lua"

FF = {} -- library constants
FF.LOW_MAG_LIMIT = 0.0001

function inst_force_field_ff()
    -- create a force field instance.
    local inst = {}
    -- The field is a hashed multidim array for fast location searching
    inst.field = {}
    -- These are "hit" events when a vector force tries to propagate into 
    -- a shape. This list is cleared before every propagation. This field is 
    -- regenerated regularly from the base field.
    inst.contacts = {}
    inst.resolution = 0.5
    inst.extend_scale = 1.5
    inst.max_sim_points = 500
    inst.max_force = 1000 -- mag
    inst.dead_force = FF.LOW_MAG_LIMIT
    inst.thermo_loss = 0.01
    -- values for debug display
    inst.energy = 0
    inst.num_points = 0
    return inst
end

function reset_ff(ff)
    ff.field = {}
    ff.contacts = {}
end

function inst_field_contact(point, hit_point, normal, shape)
    -- A contact is a record of any time a force is propagated into a coordinates
    -- that is occupied by shape voxels. This is interpreted as a "hit" event by 
    -- the force. No new vector is created to occupy that coordinate, though if 
    -- a hole is created by a higher level process the force may be able to spread
    -- into the unnoccupied coordinate in the next tick.
    local inst = {}
    inst.point = point
    inst.hit_point = hit_point
    inst.normal = normal
    inst.shape = shape
    return inst
end

function inst_field_point(coord, resolution, ff)
    local inst = {}
    inst.resolution = resolution
    inst.coord = coord
    local half_res = resolution/2
    inst.pos = VecAdd(VecScale(coord, inst.resolution), VecScale(Vec(1,1,1), half_res))
    inst.mag = 0
    inst.power = 1
    inst.cull = false
    return inst
end

function apply_force(ff, pos, force) 
    local coord = pos_to_coord(pos, ff.resolution)
    local point = field_get(ff.field, coord)
    if point == nil then 
        point = inst_field_point(coord, ff.resolution, ff)
        -- insert a point into the field
        field_put(ff.field, point, point.coord)
    end
    point.mag = force
end

function propagate_field_forces(ff, dt)
    ff.energy = 0
    local points = flatten(ff.field)    
    ff.num_points = #points
    for i = 1, #points do
        local point = points[i]
        if point.mag < math.max(FF.LOW_MAG_LIMIT, ff.dead_force) then 
            point.cull = true
        else
            propagate_point_force(ff, point, dt)
        end
        ff.energy = ff.energy + point.mag
    end
end

function propagate_point_force(ff, point, dt)
    local sample_dirs = burst_patter_dirs(20, 60, 0.2)
    local resultant_dir = Vec(0,0,0)
    local dir_found = false
    -- sample for the direction that experiences the most transfer
    for i = 1, #sample_dirs do
        local trans_dir = sample_dirs[i]
        local hit, dist, normal, shape = QueryRaycast(point.pos, trans_dir, 2 * ff.resolution * ff.extend_scale)
        if not hit then 
            local coord_prime = round_vec(VecAdd(point.coord, VecScale(trans_dir, ff.extend_scale)))
            local point_prime = field_get(ff.field, coord_prime)
            local trans_mag = point.mag
            if point_prime ~= nil then 
                trans_mag = math.min(point.mag, ff.max_force - point_prime.mag)
            end
            dir_found = true
            resultant_dir = VecAdd(resultant_dir, VecScale(trans_dir, trans_mag))
        else
            local hit_point = VecAdd(point.pos, VecScale(trans_dir, dist))
            resultant_dir = VecAdd(resultant_dir, VecScale(normal, point.mag))
            -- table.insert(ff.contacts, inst_field_contact(point, hit_point, normal, shape))
            -- point.mag = point.mag * (1 - ff.thermo_loss)        
            point.cull = true
            if DEBUG_MODE then 
                DebugCross(point.pos, 0, 1, 0)
            end
        end
    end

    if dir_found then 
        local trans_dir = VecNormalize(resultant_dir)
        local hit, dist, normal, shape = QueryRaycast(point.pos, trans_dir, 2 * ff.resolution * ff.extend_scale)
        if not hit then 
            local coord_prime = round_vec(VecAdd(point.coord, VecScale(trans_dir,  ff.extend_scale)))
            if not vecs_equal(coord_prime, point.coord) then 
                local point_prime = field_get(ff.field, coord_prime)
                if point_prime ~= nil then 
                    local trans_mag = math.min(point.mag, ff.max_force - point_prime.mag)
                    point_prime.mag = point_prime.mag + (trans_mag * (1 - ff.thermo_loss))
                    point.mag = math.max(0, point.mag - trans_mag)
                else
                    point_prime = inst_field_point(coord_prime, ff.resolution)
                    point_prime.mag = point.mag * (1 - ff.thermo_loss)
                    field_put(ff.field, point_prime, point_prime.coord)
                    point.cull = true
                end
            end
        end
    else
        point.mag = point.mag * (1 - ff.thermo_loss)
    end
end

function cull_field(ff)
    -- Remove points above the set limit of points to simulate in the field. 
    local points = flatten(ff.field)
    if #points > ff.max_sim_points then
        while #points > ff.max_sim_points do
            local index = math.random(#points)
            if index ~= 0 then 
                local remove_point = points[index]
                field_put(ff.field, nil, remove_point.coord)
                table.remove(points, index)
            end
        end
    end

    for i = 1, #points do
        local point = points[i]
        if point.cull then 
            field_put(ff.field, nil, point.coord)
        end
    end
end

function pos_to_coord(pos, resolution)
    return Vec(
        math.floor(pos[1] / resolution),
        math.floor(pos[2] / resolution),
        math.floor(pos[3] / resolution))
end

function field_put(field, value, coord)
    -- Puts a value into a field at a coordinate.
    -- Fields are a hashed multidim array. They automatically allocate when 
    -- needed and will automatically deallocate when elements are set to nil.
    -- Optimized for fast access.

    -- field["points"] is a cache of the flattened
    -- multidimensional array. Clearing it forces
    -- regeneration. This is cleared whenever the field changes. 

    local xk = tostring(coord[1])
    local yk = tostring(coord[2])
    local zk = tostring(coord[3])

    -- allocate
    if field[xk] == nil then
        field[xk] = {}
    end

    if field[xk][yk] == nil then
        field[xk][yk] = {}
    end

    if field[xk][yk][zk] == nil then 
        field["points"] = nil
    end

    -- set
    field[xk][yk][zk] = value

    -- deallocate
    if value == nil then 
        field["points"] = nil
        local count = pairs(field[xk][yk])
        if count == 0 then 
            field[xk][yk] = nil
        end

        count = pairs(field[xk])
        if count == 0 then 
            field[xk] = nil
        end
    end
end

function field_get(field, coord)
    -- Get a value from a field coordinate.
    -- See field_put() for description of what a field is and how it
    -- operates.
    local xk = tostring(coord[1])
    local yk = tostring(coord[2])
    local zk = tostring(coord[3])
    if field[xk] == nil then
        return nil
    end
    if field[xk][yk] == nil then
        return nil
    end
    if field[xk][yk][zk] == nil then
        return nil
    end
    return field[xk][yk][zk]
end

function flatten(field)
    -- flatten the entire field into a list of points (values at coordinates).
    -- Will return a cached list unless that list is nil.
    if field["points"] == nil then 
        local points = {}
        for x, yt in pairs(field) do
            for y, zt in pairs(yt) do
                for z, point in pairs (zt) do
                    table.insert(points, point)
                end
            end
        end
        field["points"] = points
    end

    return shallow_copy(field["points"])
end

function debug_field(ff)
    -- debug the field by showing vector line indicators
    local points = flatten(ff.field)
    for i = 1, #points do
        local point = points[i]
        local color = debug_color(ff, point)
        DebugCross(point.pos, color[1], color[2], color[3])
    end
    for i = 1, #ff.contacts do
        DebugCross(ff.contacts[i].hit_point, 0, 1, 0)
    end
end

function debug_color(ff, point)
    -- color code the debug vector line by the proportion 
    -- of maximum force it is. 
    local r = point.mag / ff.max_force
    local b = 1 - r
    return Vec(r, 0, b)
end


function force_field_ff_tick(ff, dt)

    if DEBUG_MODE then
        debug_field(ff)
    end
    propagate_field_forces(ff, dt)
    cull_field(ff)
end

point_type = enum {
	"base",
	"meta"
}

curve_type = enum {
    "linear",
    "sqrt",
    "square"
}