local function prefixed(str, start)
	return str:sub(1, #start) == start
end

local function sensors_in_equipment_category(category)
	if data.raw['equipment-category'][category] then
		for name, proto in pairs(data.raw['battery-equipment']) do
			if prefixed(name, 'autodrive-') then
				table.insert(proto.categories, category)
			end
		end
	end
end

-- Krastorio
sensors_in_equipment_category('vehicle-equipment')
