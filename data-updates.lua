local function prefixed(str, start)
	return str:sub(1, #start) == start
end

for _, proto in pairs(data.raw.car) do
	if not prefixed(proto.name, "logicarts") then
		proto.has_belt_immunity = true
	end
end

local passenger = table.deepcopy(data.raw.character.character)
passenger.name = "autodrive-passenger"
passenger.character_corpse  = nil
passenger.selectable_in_game = false
passenger.crafting_categories = nil
passenger.loot_pickup_distance = 0
passenger.alert_when_damaged = true
passenger.collision_mask = { "not-colliding-with-itself" }
data:extend({passenger})

if data.raw.car['vehicle-warden'] then
	data.raw.car['vehicle-warden'].guns = { 'vehicle-machine-gun' }
end

if data.raw.car['vehicle-hauler'] then
	data.raw.car['vehicle-hauler'].guns = { 'vehicle-machine-gun' }
end