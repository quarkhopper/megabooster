#include "Utils.lua"

shape_scan_bounds = { Vec(-100, -50, -100), Vec(100, 100, 100) }
-- uncomment this and adjust it if you want your spawns in a specific zone
-- instead of running the shape scan which creates a purely square zone
-- spawnAreaBounds = { Vec(-31.80, 0, -33.50), Vec (26.00, 10, 31.80) } 

spawn_block_h_size = 1
spawn_block_v_size = 1.8

-- what types of materials are acceptable to spawn on
allowed_spawn_mats = {
    ["plaster"] = true,
    ["metal"] = true,
    ["wood"] = true,
    ["masonry"] = true,
    ["dirt"] = true,
}
uneven_floor_tolerance = 0.1 
max_spawn_tries = 1000
spawn_area_bounds = nil
spawn_area_center = nil
spawn_area_size = nil
test_max_cast_dist = 10
test_max_tries = 10
spawn_area_near_box = 100

function bounds_to_string(bounds)
	return vec_to_string(bounds[1]).."->"..vec_to_string(bounds[2])
end

function adjust_bounds(bounds, vec_min, vec_max)
	local min = Vec(math.min(bounds[1][1], vec_min[1]),
		math.min(bounds[1][2], vec_min[2]),
		math.min(bounds[1][3], vec_min[3]))
	local max = Vec(math.max(bounds[2][1], vec_max[1]),
		math.max(bounds[2][2], vec_max[2]),
		math.max(bounds[2][3], vec_max[3]))
	return { min, max }
end

function get_bounds_size(bounds)
	return Vec(bounds[2][1] - bounds[1][1],
		bounds[2][2] - bounds[1][2],
		bounds[2][3] - bounds[1][3])
end

function set_spawn_area_parameters(center_pos, size)
	if center_pos ~= nil then 
		spawn_area_bounds = {
			VecAdd(center_pos, Vec(-1 * size, -1 * size, -1 * size)),
			VecAdd(center_pos, Vec(size, size, size))
		}
	else
		spawn_area_bounds = { Vec(9999,9999,9999), Vec(-9999,-9999,-9999) }

		local shapes = QueryAabbShapes(shape_scan_bounds[1], shape_scan_bounds[2])
		for i=1, #shapes do
			local shape = shapes[i]
			local min, max = GetShapeBounds(shape)
			spawn_area_bounds = adjust_bounds(spawn_area_bounds, min, max)
		end
		spawn_area_bounds[2][2] = spawn_area_bounds[2][2] + (spawn_block_v_size*2) -- leaving enough room for a spawn
	end
	spawn_area_center = VecLerp(spawn_area_bounds[1], spawn_area_bounds[2], 0.5)
	spawn_area_size = get_bounds_size(spawn_area_bounds)
end

function find_spawn_location(exclude_pos, exclusion_rad)
	local exclude_pos = exclude_pos or Vec()
	local exclusion_rad = exclusion_rad or 0
	for i=1, max_spawn_tries, 1 do
		local test_point = get_random_spawn_area_point()
		local location = find_suitable_spawn_nearby(test_point)
		local dist = VecLength(VecSub(exclude_pos, location))
		if location ~= nil and dist > exclusion_rad then 
			return location             
        end
	end
end

function find_suitable_spawn_nearby(test_point)
	-- raycast at random angles downward
	for i=1, test_max_tries do
		local dir = Vec(math.random() * 1 - 0.5, -- [-0.5, 0.5]
			math.random() * -0.5 - 0.5, -- [-0.5, -1]
			math.random() * 1 - 0.5) -- [-0.5, 0.5]
		local hit, dist, normal, shape = QueryRaycast(test_point, dir, test_max_cast_dist)
		if hit then
            local hit_point = VecAdd(test_point, VecScale(dir, dist))
            local mat = GetShapeMaterialAtPosition(shape, hit_point)
			if allowed_spawn_mats[mat] and 
			not IsPointInWater(hit_point) and
			block_is_suitable(hit_point) then
				return hit_point --VecAdd(hit_point, Vec(0, spawn_block_v_size / 2, 0))
            end
		end
	end
end

function block_is_suitable(test_position)
	-- checks from the bottom of the block if 
	-- there's enough clear and level area to spawn 
	-- a smerp

	-- scan for clear level surface
	local hit, dist = QueryRaycast(VecAdd(test_position, Vec(0, spawn_block_v_size, 0)), Vec(0, -1, 0), spawn_block_v_size)
	if math.abs(dist - spawn_block_v_size) > 0.1 then return false end
	local ref_height = dist
	for x=1, 10, 1 do
		for z=1, 10, 1 do
			local pos = VecAdd(test_position, Vec((x/10), spawn_block_v_size, (z/10)))
			hit, dist = QueryRaycast(pos,  Vec(0, -1, 0), spawn_block_v_size)
			if not hit or dist ~= ref_height then return false end
		end
	end
	
	return true
end

function get_random_spawn_area_point()
	local pos = nil
	-- try 5 times to get a sheltered (indoor) position before
	-- giving an outdoor position
	for i=1, 5 do
		pos = Vec(math.random() * spawn_area_size[1] + spawn_area_bounds[1][1],
			math.random() * spawn_area_size[2] + spawn_area_bounds[1][2],
			math.random() * spawn_area_size[3] + spawn_area_bounds[1][3])
		if is_sheltered(pos) then return pos end
	end
	
	return pos
end

function is_sheltered(pos)
	local hit, dist, normal, shape = QueryRaycast(pos, Vec(0,1,0), spawn_area_size[2])
	if hit then
		local hit_point = VecAdd(pos, VecScale(Vec(0,1,0), dist))
		local mat = GetShapeMaterialAtPosition(shape, hit_point)
		if mat ~= "none" then return true end
	end
	return false
end