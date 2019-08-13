local mod = nil
local max = math.max
local min = math.min
local abs = math.abs
local ceil = math.ceil
local floor = math.floor

-- bounce backward after crash speed
local BOUNCE_SPEED = -5

-- bounce backward after crash duration
local TICKS_CRASH = 30

-- delay between path attempts
local TICKS_RETRY = 60

local function check_state()
	mod = global
	mod.cars = mod.cars or {}
end

local debug = true

local function note(msg)
	if debug then
		game.print(msg)
	end
end

local function serialize(t)
	local s = {}
	for k,v in pairs(t) do
		if type(v) == "table" then
			v = serialize(v)
		end
		s[#s+1] = tostring(k).." = "..tostring(v)
	end
	return "{ "..table.concat(s, ", ").." }"
end

local function prefixed(str, start)
	return str:sub(1, #start) == start
end

local function distance(a, b)
	local x = b.x - a.x
	local y = b.y - a.y
	return math.sqrt(x*x + y*y)
end

local function notify(state, msg)

	if state.notify_msg == msg
		and (state.notify_tick or 0) > game.tick - 60*5
	then
		return
	end

	if (state.notify_tick or 0) > game.tick - 60 then
		return
	end

	state.notify_msg = msg
	state.notify_tick = game.tick

	state.car.surface.create_entity({
		name = "flying-text",
		position = state.car.position,
		color = {r=1,g=1,b=1},
		text = msg,
	})
end

local function shortwave_state(state)
	if state.link then
		local connected = state.link.circuit_connected_entities
		if not state.circuit_sensor
			or not state.channel
			or state.channel ~= state.link_channel
			or not connected
			or not connected.red
			or #connected.red == 0
			or not connected.green
			or #connected.green == 0
		then
			if state.link.valid then
				state.link.destroy()
			end
			state.link = nil
			note("unlinked "..state.id.." "..(state.link_channel or "nil"))
			state.link_channel = nil
		end
	end
	if state.circuit_sensor and state.channel and (not state.link or not state.link.valid) then
		local relay = remote.call('shortwave', 'get_relay', state.car.force, state.channel)
		if relay and relay.valid then
			local link = state.car.surface.create_entity({
				name = 'autodrive-shortwave-link',
				position = { x = 0, y = 0 },
				force = state.car.force,
			})
			if link and link.valid then
				state.link = link
				state.link_channel = state.channel
				link.connect_neighbour({
					wire = defines.wire_type.red,
					target_entity = relay,
				})
				link.connect_neighbour({
					wire = defines.wire_type.green,
					target_entity = relay,
				})
				note("linked "..state.id.." "..state.link_channel)
			end
		end
	end
end

local function shortwave_signals(state, items, virtuals)
	if not (state.link and state.link.valid) then
		return
	end

	local parameters = {}
	local limit = state.link.get_control_behavior().signals_count

	if items ~= nil then
		for item, count in pairs(items) do
			local index = #parameters+1
			if index > limit then
				break
			end
			parameters[index] = {
				index = index,
				signal = {
					type = "item",
					name = item,
				},
				count = count,
			}
		end
	end

	if virtuals ~= nil then
		for item, count in pairs(virtuals) do
			local index = #parameters+1
			if index > limit then
				break
			end
			parameters[index] = {
				index = index,
				signal = {
					type = "virtual",
					name = item,
				},
				count = count,
			}
		end
	end

	state.link.get_control_behavior().parameters = {
		parameters = parameters
	}
end

local function remove_path(state)
	if state.pointer then
		rendering.destroy(state.pointer)
		state.pointer = nil
	end
	if state.segments then
		for _, segment in ipairs(state.segments) do
			rendering.destroy(segment)
		end
	end
	state.segments = {}
end

local function render_target(state)
	if state.pointer then
		rendering.destroy(state.pointer)
		state.pointer = nil
	end
	state.pointer = rendering.draw_circle({
		color = {r = 0.7, g = 0.7, b = 0.3 },
		radius = 0.25,
		filled = true,
		target = state.goal,
		surface = state.car.surface,
		forces = { state.car.force },
		draw_on_ground = true,
	})
end

local function render_path(state)
	remove_path(state)

	if not state.car.valid then
		return
	end

	render_target(state)

	table.insert(state.segments, rendering.draw_line({
		color = {r = 0.7, g = 0.7, b = 0.3},
		width = 2,
		gap_length = 0.6,
		dash_length = 0.4,
		from = state.car,
		to = state.path[1].position,
		surface = state.car.surface,
		forces = { state.car.force },
		draw_on_ground = true,
	}))

	-- spread out segment rendering over ticks
	state.path_index = 2
end

local function calc_angle(posA, posB)
	local x1 = posA.x
	local y1 = posA.y
	local x2 = posB.x
	local y2 = posB.y
	-- +90 for factorio orientation
	return (math.atan2(y2-y1, x2-x1) * 180/math.pi) + 90
end

local function relative_direction(state, pos)
	local angle = calc_angle(state.car.position, pos)
	return abs(state.car.orientation - angle/360)
end

local function box_size(box)
	local lt = box.left_top or box[1]
	local rb = box.right_bottom or box[2]
	local w = (rb.x or rb[1]) - (lt.x or lt[1])
	local h = (rb.y or rb[2]) - (lt.y or lt[2])
	return max(w, h)
end

local function calc_collision_box(state, mul)
	if not mul then
		mul = max((state.clearance or 1.6) - 0.1, 1.0)
	end
	local size = box_size(state.car.prototype.collision_box) * mul
	return {
		left_top = { x = -size/2, y = -size/2 },
		right_bottom = { x = size/2, y = size/2 },
	}
end

local straight = defines.riding.direction.straight

local brake = function(state)
	local rs = state.car.riding_state
	if rs.acceleration ~= defines.riding.acceleration.braking or rs.acceleration ~= straight then
		state.car.riding_state = { acceleration = defines.riding.acceleration.braking, direction = straight }
	end
end

local brake_hard = function(state)
	state.car.speed = state.car.speed/2
	brake(state)
end

local accelerate = function(state)
	local rs = state.car.riding_state
	if rs.acceleration ~= defines.riding.acceleration.accelerating or rs.acceleration ~= straight then
		state.car.riding_state = { acceleration = defines.riding.acceleration.accelerating, direction = straight }
	end
end

local coast = function(state)
	local rs = state.car.riding_state
	if rs.acceleration ~= defines.riding.acceleration.nothing or rs.acceleration ~= straight then
		state.car.riding_state = { acceleration = defines.riding.acceleration.nothing, direction = straight }
	end
end

local function has_ammo_sensor(car)
	return (car.grid and (car.grid.get_contents())['autodrive-ammo-sensor']) and true or false
end

local function has_fuel_sensor(car)
	return (car.grid and (car.grid.get_contents())['autodrive-fuel-sensor']) and true or false
end

local function has_gate_sensor(car)
	return (car.grid and (car.grid.get_contents())['autodrive-gate-sensor']) and true or false
end

local function has_enemy_sensor(car)
	return (car.grid and (car.grid.get_contents())['autodrive-enemy-sensor']) and true or false
end

local function has_train_sensor(car)
	return (car.grid and (car.grid.get_contents())['autodrive-train-sensor']) and true or false
end

local function has_logistic_sensor(car)
	local contents = car.grid and car.grid.get_contents()
	return contents and contents['autodrive-logistic-sensor'] and not contents['logiquipment']
end

local function has_circuit_sensor(car)
	return (car.grid and (car.grid.get_contents())['autodrive-circuit-sensor']) and true or false
end

local function is_special_stack(stack)
--	if stack and stack.valid and stack.valid_for_read then
--		local dump = {
--			is_item_with_tags = stack.is_item_with_tags,
--			is_item_with_label = stack.is_item_with_label,
--			label = stack.is_item_with_label and stack.label or "",
--			is_item_with_entity_data = stack.is_item_with_entity_data,
--			is_item_with_inventory = stack.is_item_with_inventory,
--		}
--		note(serialize(dump))
--	end
	return stack and stack.valid and stack.valid_for_read and (
		(stack.is_item_with_tags and next(stack.tags))
		or (stack.is_item_with_label and stack.label and stack.label ~= "")
		or stack.is_item_with_entity_data
		or stack.is_item_with_inventory
	)
end

-- work with stacks to retain info for item-with-tags, item-with-entity-data etc
local function transfer_stacks(src, dst, indexes)
	local transfers = {}
	for i = 1,(indexes and #indexes or #src) do
		local stack = src[indexes and indexes[i] or i]
		if stack and stack.valid and stack.valid_for_read then
			if is_special_stack(stack) then
				transfers[#transfers+1] = stack
			else
				local moved = dst.insert({ name = stack.name, count = stack.count })
				if moved > 0 then
					stack.count = stack.count - moved
				end
			end
		end
	end
	local t = 1
	for i = 1,#dst do
		if t > #transfers then
			break
		end
		local dstack = dst[i]
		local filter = dst.get_filter(i)
		if (not filter or filter == transfers[t].name) and dstack and dstack.valid and not dstack.valid_for_read then
			dstack.transfer_stack(transfers[t])
			t = t+1
		end
	end
	dst.sort_and_merge()
end

local function transfer_items(src, dst)
	transfer_stacks(src, dst)
end

local function logistic_ready(state)
	local car = state.car
	local trunk = car.get_inventory(defines.inventory.car_trunk)
	return trunk
		and trunk.is_filtered()
		and car.speed < 0.1
		and car.surface.find_logistic_network_by_position(car.position, car.force) ~= nil
end

local function logistic_packup(state)

	local car = state.car
	local requester = state.requester
	local provider = state.provider
	local trunk = car and car.valid and car.get_inventory(defines.inventory.car_trunk)

	if requester and requester.valid then
		local input = requester.get_inventory(defines.inventory.chest)

		if trunk and trunk.valid then
			transfer_items(input, trunk)
		end

		requester.destroy()
		state.requester = nil
	end

	if provider and provider.valid then
		local output = provider.get_inventory(defines.inventory.chest)

		if trunk and trunk.valid then
			transfer_items(output, trunk)
		end

		provider.destroy()
		state.provider = nil
	end

end

local function logistic_unpack(state)

	local car = state.car
	local requester = state.requester
	local provider = state.provider
	local position = { x = car.position.x - 0.1, y = car.position.y - 0.1 }

	if not (requester and requester.valid) then
		state.requester = car.surface.create_entity({
			name = "autodrive-requester",
			position = position,
			force = car.force,
		})
		requester = state.requester
	end

	if not (provider and provider.valid) then
		state.provider = car.surface.create_entity({
			name = "autodrive-provider",
			position = position,
			force = car.force,
		})
		provider = state.provider
	end

	if requester and requester.valid and distance(requester.position, car.position) > 1 then
		requester.teleport(position)
	end

	if provider and provider.valid and distance(provider.position, car.position) > 1 then
		provider.teleport(position)
	end
end

local function logistic_process(state)
	local car = state.car
	local requester = state.requester
	local provider = state.provider

	if not (requester and requester.valid and provider and provider.valid) then
		return
	end

	if (state.logistic_pause or 0) > game.tick then
		return
	end

	local trunk = car.get_inventory(defines.inventory.car_trunk)
	local input = requester.get_inventory(defines.inventory.chest)
	local output = provider.get_inventory(defines.inventory.chest)

	local trunk_slot = state.logistic_trunk_slot or 1
	local trunk_limit = min(#trunk, trunk_slot+10)

	if trunk_slot == 1 then
		transfer_items(input, trunk)
		for i = 1,requester.request_slot_count,1 do
			requester.clear_request_slot(i)
		end
		state.logistic_specials = {}
		state.logistic_requests = {}
		state.logistic_exports = {}
	end

	local specials = state.logistic_specials
	local requests = state.logistic_requests
	local exports = state.logistic_exports
	local prototypes = game.item_prototypes

	while trunk_slot <= trunk_limit do
		local stack = trunk[trunk_slot]
		local filter = trunk.get_filter(trunk_slot)
		local count = (stack and stack.valid_for_read and stack.count) or 0
		local special = is_special_stack(stack)
		if special and not filter then
			specials[stack.name] = (specials[stack.name] or 0) + 1
		end
		if not special or count == 0 then
			if filter ~= nil then
				local shortfall = max(0, prototypes[filter].stack_size - count)
				if shortfall > 0 then
					requests[filter] = (requests[filter] or 0) + shortfall
				end
			else
				if stack and stack.valid and stack.valid_for_read then
					exports[#exports+1] = trunk_slot
				end
			end
		end
		trunk_slot = trunk_slot+1
	end

	if trunk_slot < #trunk then
		state.logistic_trunk_slot = trunk_slot
		return
	end

	state.logistic_trunk_slot = 1
	state.logistic_pause = game.tick + 180

	for name, count in pairs(specials) do
		if requests[name] then
			requests[name] = requests[name] - count
		end
	end

	transfer_stacks(trunk, output, exports)

	local i = 1
	for name,count in pairs(requests) do
		if i > requester.request_slot_count then
			break
		end
		if count > 0 then
			requester.clear_request_slot(i)
			requester.set_request_slot({ name = name, count = count }, i)
		end
		i = i + 1
	end
end

local function remove_car(state)
	state.channel = nil
	shortwave_state(state)
	remove_path(state)
	mod.cars[state.id] = nil
end

local function reset_car(state)
	remove_path(state)
	mod.cars[state.id] = {
		id = state.id,
		car = state.car,
		heal = state.heal,
		selected = state.selected,
		leader = state.leader,
		channel = state.channel,
		link = state.link,
		link_channel = state.link_channel,
		arrived = state.arrived,
		departed = state.departed,
		moved = state.moved,
		notify_msg = state.notify_msg,
		notify_tick = state.notify_tick,
		requester = state.requester,
		provider = state.provider,
		ammo_sensor = has_ammo_sensor(state.car),
		fuel_sensor = has_fuel_sensor(state.car),
		gate_sensor = has_gate_sensor(state.car),
		enemy_sensor = has_enemy_sensor(state.car),
		train_sensor = has_train_sensor(state.car),
		logistic_sensor = has_logistic_sensor(state.car),
		circuit_sensor = has_circuit_sensor(state.car),
	}
	state = mod.cars[state.id]
	state.car.speed = 0
	state.car.riding_state = { acceleration = defines.riding.acceleration.nothing, direction = defines.riding.direction.straight }
	return state
end

local function request_path(state)

	if not state.car.valid or not state.goal then
		return
	end

	local step = box_size(calc_collision_box(state, state.clearance))
	state.goal = state.car.surface.find_non_colliding_position(state.car.name, state.goal, step*3, step)

	if not state.goal then
		notify("no space!")
		reset_car(state)
		return
	end

	notify(state, "pathing...")

	state.clearance = max((state.clearance or 1.6) - 0.1, 1.0)
	state.request = state.car.surface.request_path({
		bounding_box = calc_collision_box(state, state.clearance),
		collision_mask = state.car.prototype.collision_mask,
		start = state.car.position,
		goal = state.goal,
		force = state.car.force,
		radius = state.radius,
		entity_to_ignore = state.car,
		can_open_gates = state.gate_sensor,
		pathfind_flags = {
			allow_destroy_friendly_entities = false,
			cache = false,
			prefer_straight_paths = true,
			low_priority = false,
		},
	})
end

local function tick_car(state)

	local car = state.car

	if not car.valid then
		remove_car(state)
		return
	end

	if state.crashed and state.crashed > game.tick then
		state.car.speed = BOUNCE_SPEED/216
		return
	end

	if (state.train_sensor or state.train_dodge) and not state.train_safe then
		local range = 32

		local trains = car.surface.count_entities_filtered({
			type = { 'locomotive', 'cargo-wagon', 'fluid-wagon' },
			position = car.position,
			radius = range,
		})

		if trains > 0 then

			trains = car.surface.find_entities_filtered({
				type = { 'locomotive', 'cargo-wagon', 'fluid-wagon' },
				position = car.position,
				radius = range,
			})

			for _, t in ipairs(trains) do
				if t.train and t.train.speed > 0 then

					local rails = car.surface.count_entities_filtered({
						type = { 'straight-rail', 'curved-rail' },
						position = car.position,
						radius = box_size(state.car.prototype.collision_box)*1.5,
					}) > 0

					if rails then
						-- on the rails with a potentially moving train nearby! just floor it and hope to get off in time...
						car.speed = max(-150, min(150, (car.speed*216)+30)) / 216
						accelerate(state)
						return
					end

					notify(state, "train!")
					brake_hard(state)
					return
				end
			end

		else
			state.train_safe = car.surface.count_entities_filtered({
				type = { 'straight-rail', 'curved-rail' },
				position = car.position,
				radius = box_size(state.car.prototype.collision_box)*1.5,
			}) == 0
		end
	end

	local tick = game.tick+(state.id%6)

	local cron_fuel = tick%360 == 0
	local cron_ammo = tick%180 == 0
	local cron_chart = tick%300 == 0
	local cron_enemy = tick%30 == 0
	local cron_logistic = tick%30 == 0
	local cron_circuit = tick%60 == 0

	if state.heal then
		car.health = car.prototype.max_health
		state.heal = nil
	end

	if state.sleepy and tick%30 ~= 0 then
		return
	end

	if cron_chart then
		car.force.chart(car.surface, {
			left_top = { x = car.position.x - 32, y = car.position.y - 32 },
			right_bottom = { x = car.position.x + 32, y = car.position.y + 32 },
		})
	end

	if cron_logistic then

		if state.logistic_sensor then
			if logistic_ready(state) then
				logistic_unpack(state)
				logistic_process(state)
			else
				logistic_packup(state)
			end
		end

		if not state.logistic_sensor and state.requester then
			logistic_packup(state)
		end
	end

	if cron_circuit then
		shortwave_state(state)
	end

	if state.circuit_sensor and cron_circuit and state.channel and not state.manual_goal and state.link and state.link.valid then

		if state.leader then
			local arrived = (state.arrived or 0)
			local departed = (state.departed or 0)
			local D = (departed > arrived) and (game.tick - departed) or 0
			local A = (arrived > departed) and (game.tick - arrived) or 0
			shortwave_signals(state, nil, {
				['signal-V'] = floor(state.car.position.x),
				['signal-W'] = floor(state.car.position.y),
				['signal-D'] = D,
				['signal-E'] = floor(D/60),
				['signal-A'] = A,
				['signal-B'] = floor(A/60),
			})
		end

		--local signals = remote.call('shortwave', 'get_channel_merged_signals', state.car.force, state.channel)
		local signals = state.link.get_merged_signals()
		if signals ~= nil then
			local sigs = {
				['signal-red'] = true,
				['signal-X'] = true,
				['signal-Y'] = true,
			}
			local smap = {}
			for _, s in ipairs(signals) do
				if sigs[s.signal.name] then
					smap[s.signal.name] = s.count
				end
			end
			if smap['signal-red'] then
				state = reset_car(state)
				notify(state, "red!")
				brake(state)
				return
			end
			local x = smap['signal-X']
			local y = smap['signal-Y']
			if x or y then
				x = x or 0
				y = y or 0
				local proximity = box_size(calc_collision_box(state, state.clearance))*2
				local goal = { x = x, y = y }
				if distance(state.car.position, goal) > proximity -- not close enough
					and not (state.goal and goal.x == state.goal.x and goal.y == state.goal.y) -- already en route
				then
					state = reset_car(state)
					state.goal = goal
					state.radius = 0.5
					state.circuit_goal = true
					state.clearance = nil
					render_target(state)
					request_path(state)
					brake(state)
					return
				end
			end
		end
	end

	local enemy = nil
	local gun = nil
	local driver = car.get_driver()
	local passenger = car.get_passenger()
	local trunk = car.get_inventory(defines.inventory.car_trunk)
	local ftank = car.get_fuel_inventory()
	local clip = car.get_inventory(defines.inventory.car_ammo)

	if car.prototype.guns then
		for _, g in pairs(car.prototype.guns) do
			gun = g
			break
		end
	end

	if state.enemy_sensor and gun then
		enemy = car.surface.find_nearest_enemy({
			force = car.force,
			position = car.position,
			max_distance = gun.attack_parameters.range + 3,
		})
	end

	-- reload
	if state.ammo_sensor and gun and trunk and clip and clip.is_empty() then
		for item, count in pairs(trunk.get_contents()) do
			local stack = { name = item, count = count }
			if clip.can_insert(stack) then
				notify(state, "reload")
				trunk.remove({ name = item, count = clip.insert(stack) or 1 })
				break
			end
		end
	end

	-- refuel
	if state.fuel_sensor and trunk and ftank and ftank.is_empty() then
		for item, count in pairs(trunk.get_contents()) do
			local stack = { name = item, count = count }
			if ftank.can_insert(stack) then
				notify(state, "refuel")
				trunk.remove({ name = item, count = ftank.insert(stack) or 1 })
				break
			end
		end
	end

	-- need passenger when no driver, and there are enemies to shoot or gates to open
	local need_passenger = not driver
		and (state.enemy_sensor or state.gate_sensor)
		and (enemy ~= nil or state.path ~= nil)

	if not passenger and need_passenger then
		passenger = car.surface.create_entity({
			name = 'autodrive-passenger',
			position = car.position,
			force = car.force,
		})
		if passenger and passenger.valid then
			car.set_passenger(passenger)
		end
	end

	local shooter = (driver and driver.valid) and driver or passenger

	if gun and enemy and enemy.valid and shooter and shooter.valid then
		shooter.shooting_state = {
			state = defines.shooting.shooting_enemies,
			position = enemy.position,
		}
	end

	-- clear passenger when not in use, for mining entity
	if not need_passenger and passenger and passenger.valid and not passenger.player then
		passenger.destroy()
	end

	state.sleepy = not enemy

	if state.retry then
		if state.retry < game.tick then
			state.retry = nil
			request_path(state)
		end
		return
	end

	if state.request then
		notify(state, "pathing...")
	end

	if not state.path then
		return
	end

	if #state.path == 0 then
		notify(state, "arrived")
		state.arrived = game.tick
		reset_car(state)
		return
	end

	-- incremental path rendering to avoid latency spike creating many segments
	if state.path_index and state.path_index <= #state.path then
		local i = state.path_index
		if i > 1 then
			table.insert(state.segments, rendering.draw_line({
				color = {r = 0.7, g = 0.7, b = 0.3},
				width = 2,
				gap_length = 0.6,
				dash_length = 0.4,
				from = state.path[i-1].position,
				to = state.path[i].position,
				surface = state.car.surface,
				forces = { state.car.force },
				draw_on_ground = true,
			}))
		end
		state.path_index = i+1
	end

	state.sleepy = nil
	state.moved = game.tick
	state.train_safe = nil

	local waypoint = state.path[1].position
	local range = distance(waypoint, car.position)

	local speed = 50
	if range > 8 or rails then
		speed = 100
	elseif range > 4 then
		speed = 50
	end
	speed = speed/216

	if range < 0.5 then
		rendering.destroy(state.segments[1])
		table.remove(state.segments, 1)
		table.remove(state.path, 1)
		state.path_index = max(2, (state.path_index or 3)-1)
		brake(state)
		return
	end

	-- cheat! everything instant tank-steers when in autodrive
	car.orientation = calc_angle(car.position, waypoint)/360

	if abs(car.speed - speed) < 0.01 then
		coast(state)
	elseif car.speed < speed then
		accelerate(state)
	else
		brake(state)
	end
end

local function on_tick(event)
	check_state()
	for _, state in pairs(mod.cars) do
		tick_car(state)
	end
end

local function on_script_path_request_finished(event)
	for _, state in pairs(mod.cars) do
		if state.request == event.id then
			state.request = nil
			if event.try_again_later then
				state.clearance = nil
				request_path(state)
				return
			end
			if event.path then
				-- compress path
				local path = event.path
				local removed = 0
				local i = 1
				while #path > i+2 do
					local waypoint = path[i].position
					local orig_angle = calc_angle(waypoint, path[i+1].position)
					while #path > i+2 and calc_angle(waypoint, path[i+2].position) == orig_angle do
						table.remove(path, i+1)
						removed = removed+1
					end
					i = i+1
				end
				state.path = path
				state.sleepy = nil
				state.departed = game.tick
				render_path(state)
			else

				-- request_path() checks if the goal has enough space, but not the starting point. In case the
				-- car is too close to another entity, bump it to a non-colliding position.
				if not state.bumped then
					local step = box_size(calc_collision_box(state, state.clearance))
					local bump = state.car.surface.find_non_colliding_position(state.car.name, state.car.position, step*5, step)
					state.car.teleport(bump or state.car.position)
					state.bumped = true
				end

				notify(state, "no path...")
				state.radius = 1
				state.retry = game.tick + TICKS_RETRY
			end
			return
		end
	end
end

local function on_player_selected_area(event)

	if not prefixed(event.item, 'autodrive-') then
		return
	end

	local player = game.players[event.player_index]

	if event.item == 'autodrive-control' then

		local dx = abs(event.area.right_bottom.x - event.area.left_top.x)
		local dy = abs(event.area.right_bottom.y - event.area.left_top.y)

		if dx < 0.2 and dy < 0.2 then
			-- click
			for _, state in pairs(mod.cars) do
				if state.selected then
					state.path = nil
					state.goal = event.area.left_top
					state.manual_goal = true
					state.radius = 0.5
					state.clearance = nil
					render_target(state)
					request_path(state)
				end
			end
		else
			-- selection
			local cars = {}
			local radio = nil
			local channel = nil
			for _, entity in ipairs(event.entities) do
				if entity.type == "car" and not prefixed(entity.name, "logicart") then
					cars[#cars+1] = entity
				end
				if entity.name == 'shortwave-radio' then
					radio = entity
					channel = remote.call('shortwave', 'get_channel', radio)
				end
			end
			if #cars > 0 then
				if channel then
					for id, state in pairs(mod.cars) do
						if state.channel == channel then
							state.channel = nil
						end
					end
				end
				for _, state in pairs(mod.cars) do
					if state.selected then
						if type(state.selected) ~= 'boolean' then
							rendering.destroy(state.selected)
						end
						state.selected = nil
					end
				end
				for i, car in ipairs(cars) do
					local id = car.unit_number
					mod.cars[id] = mod.cars[id] or {
						id = id,
						car = car,
						channel = channel,
						ammo_sensor = has_ammo_sensor(car),
						fuel_sensor = has_fuel_sensor(car),
						gate_sensor = has_gate_sensor(car),
						enemy_sensor = has_enemy_sensor(car),
						train_sensor = has_train_sensor(car),
						logistic_sensor = has_logistic_sensor(car),
						circuit_sensor = has_circuit_sensor(car),
					}
					local state = mod.cars[id]
					if channel then
						state.channel = channel
					end
					state.leader = i == 1
					state.selected = rendering.draw_text({
						text = { '', state.channel or '@' },
						alignment = 'center',
						color = {r = 0.7, g = 0.7, b = 0.3},
						target = car,
						surface = car.surface,
						forces = { car.force },
					})
					notify(state, "selected")
				end
			end
		end
	end
end

local function on_entity_damaged(event)

	local entity = event.entity
	local cause = event.cause

	if entity.valid
		and event.damage_type.name == 'impact'
		and cause
		and cause.valid
		and cause.type == 'car'
		and mod.cars[cause.unit_number]
	then

		local state = mod.cars[event.cause.unit_number]

		if state.crashed and state.crashed > game.tick then
			--state.car.speed = BOUNCE_SPEED/216
			return
		end

		state.sleepy = nil
		state.crashed = game.tick + TICKS_CRASH

		-- bulldoze trees
		if entity ~= cause and entity.type == 'tree' then
			entity.destroy()
			state.heal = true
			return
		end

		if entity == cause or entity.force ~= cause.force then
			return
		end

		-- while autodriving we dont't damage our own stuff
		entity.health = entity.prototype.max_health
		state.heal = true

		local goal = state.goal
		state = reset_car(state)

		if goal then
			local proximity = box_size(calc_collision_box(state, state.clearance))*2
			if distance(goal, state.car.position) > proximity then
				state.goal = goal
				state.path = nil
				state.radius = 0.5
				state.retry = game.tick + TICKS_RETRY
			else
				notify(state, "arrived")
				state.arrived = game.tick
				reset_car(state)
			end
		end
	end
end

local function recheck_grid_sensors(grid)
	for _, surface in pairs(game.surfaces) do
		local cars = surface.find_entities_filtered({
			type = 'car',
		})
		for _, car in ipairs(cars) do
			if car.valid and car.grid and car.grid == grid then
				local id = car.unit_number
				mod.cars[id] = mod.cars[id] or {
					id = id,
					car = car,
				}
				local state = mod.cars[id]
				state.ammo_sensor = has_ammo_sensor(state.car)
				state.fuel_sensor = has_fuel_sensor(state.car)
				state.gate_sensor = has_gate_sensor(state.car)
				state.enemy_sensor = has_enemy_sensor(state.car)
				state.train_sensor = has_train_sensor(state.car)
				state.logistic_sensor = has_logistic_sensor(state.car)
				state.circuit_sensor = has_circuit_sensor(state.car)
				break
			end
		end
	end
end

local function on_player_placed_equipment(event)
	if prefixed(event.equipment.name, 'autodrive-') then
		recheck_grid_sensors(event.grid)
	end
end

local function on_player_removed_equipment(event)
	if prefixed(event.equipment, 'autodrive-') then
		recheck_grid_sensors(event.grid)
	end
end

local function on_remove(event)
	local entity = event.entity

	if not entity or not entity.valid then
		return
	end

	if entity.type == 'car' and mod.cars[entity.unit_number] then
		logistic_packup(mod.cars[entity.unit_number])
	end
end

local function attach_events()
	script.on_event(defines.events.on_tick, on_tick)
	script.on_event(defines.events.on_player_selected_area, on_player_selected_area)
	script.on_event(defines.events.on_script_path_request_finished, on_script_path_request_finished)
	script.on_event(defines.events.on_entity_damaged, on_entity_damaged)
	script.on_event(defines.events.on_player_placed_equipment, on_player_placed_equipment)
	script.on_event(defines.events.on_player_removed_equipment, on_player_removed_equipment)
	script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, on_create)
	script.on_event({defines.events.on_player_mined_entity, defines.events.on_robot_mined_entity, defines.events.on_entity_died}, on_remove)
end

local function attach_interfaces()
	remote.add_interface('autodrive', {
		on_entity_replaced = function(event)
			local state = mod.cars[event.old_entity_unit_number]
			if state and event.new_entity.valid then
				mod.cars[state.id] = nil
				state.car = event.new_entity
				state.id = event.new_entity.unit_number
				mod.cars[state.id] = state
			end
			return nil
		end
	})
end

script.on_init(function()
	check_state()
	attach_events()
	attach_interfaces()
end)

script.on_load(function()
	attach_events()
	attach_interfaces()
end)

