-- credit: GigsD4X
-- url: https://gist.github.com/GigsD4X/8513963
-- ..originally based on...
-- url: https://www.cs.rit.edu/~ncs/color/t_convert.html
-- Slightly modified for this application to use vector tables

function RGBToHSV(RBGColor)
	-- Returns the HSV equivalent of the given RGB-defined color
	-- (adapted from some code found around the web)
    local red = RBGColor[1]
    local green = RBGColor[2]
    local blue = RBGColor[3]

	local hue, saturation, value

	local min_value = math.min( red, green, blue )
	local max_value = math.max( red, green, blue )

	value = max_value

	local value_delta = max_value - min_value

	-- If the color is not black
	if max_value ~= 0 then
		saturation = value_delta / max_value

	-- If the color is purely black
	else
		saturation = 0
		hue = -1
		return Vec(hue, saturation, value)
	end

	if red == max_value then
		hue = ( green - blue ) / value_delta
	elseif green == max_value then
		hue = 2 + ( blue - red ) / value_delta
	else
		hue = 4 + ( red - green ) / value_delta
	end

	hue = hue * 60
	if hue < 0 then
		hue = hue + 360
	end

	return Vec(hue, saturation, value)
end

function HSVToRGB(HSVColor)
	-- Returns the RGB equivalent of the given HSV-defined color
	-- (adapted from some code found around the web)
    local hue = HSVColor[1]
    local saturation = HSVColor[2]
    local value = HSVColor[3]

	-- If it's achromatic, just return the value
	if saturation == 0 then
		return Vec(value, value, value)
	end

	-- Get the hue sector
	local hue_sector = math.floor( hue / 60 )
	local hue_sector_offset = ( hue / 60 ) - hue_sector

	local p = value * ( 1 - saturation )
	local q = value * ( 1 - saturation * hue_sector_offset )
	local t = value * ( 1 - saturation * ( 1 - hue_sector_offset ) )

	if hue_sector == 0 then
		return Vec(value, t, p)
	elseif hue_sector == 1 then
		return Vec(q, value, p)
	elseif hue_sector == 2 then
		return Vec(p, value, t)
	elseif hue_sector == 3 then
		return Vec(p, q, value)
	elseif hue_sector == 4 then
		return Vec(t, p, value)
	elseif hue_sector == 5 then
		return Vec(value, p, q)
	end
end