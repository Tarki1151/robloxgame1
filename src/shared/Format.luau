--!strict
--[[
	Format
	Buyuk sayilari okunur hale getirir: 1500 -> "1.5K", 2400000 -> "2.4M"
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.abbreviate(value: number): string
	local sign = if value < 0 then "-" else ""
	local absolute = math.abs(value)

	if absolute < 1000 then
		return sign .. tostring(math.floor(absolute))
	end

	local index = math.floor(math.log(absolute, 1000))
	index = math.clamp(index, 1, #SUFFIXES - 1)

	local scaled = absolute / (1000 ^ index)
	local text = string.format("%.1f", scaled)
	text = string.gsub(text, "%.0$", "")

	return sign .. text .. SUFFIXES[index + 1]
end

function Format.money(value: number): string
	return "$" .. Format.abbreviate(value)
end

return Format
