local function sensor(name, ingredients, prerequisites)
	data:extend({
		{
			type = "item",
			name = "autodrive-"..name.."-sensor",
			placed_as_equipment_result = "autodrive-"..name.."-sensor",
			icon = "__autodrive__/"..name.."-sensor.png",
			icon_size = 32,
			stack_size = 10,
			subgroup = "transport",
			order = "c[z]-s[autodrive-sensor]",
		},
		{
			type = "battery-equipment",
			name = "autodrive-"..name.."-sensor",
			sprite = {
				filename = "__autodrive__/"..name.."-sensor.png",
				width = 32,
				height = 32,
				priority = "medium",
			},
			energy_source = {
				buffer_capacity = "1J",
				input_flow_limit = "1W",
				output_flow_limit = "1W",
				type = "electric",
				usage_priority = "secondary-input"
			},
			shape = {
				type = "full",
				height = 1,
				width = 1
			},
			categories = {
				"armor",
			},
		},
		{
			type = "recipe",
			name = "autodrive-"..name.."-sensor",
			category = "crafting",
			subgroup = "transport",
			enabled = false,
			icon = "__autodrive__/"..name.."-sensor.png",
			icon_size = 32,
			hidden = false,
			energy_required = 1.0,
			ingredients = ingredients,
			results = {
				{ type = "item", name = "autodrive-"..name.."-sensor", amount = 1 },
			},
			order = "c[z]-s[autodrive-sensor]",
		},
		{
			type = "technology",
			name = "autodriving-"..name.."-tech",
			icon = "__autodrive__/"..name.."-sensor.png",
			icon_size = 32,
			effects = {
				{ type = "unlock-recipe", recipe = "autodrive-"..name.."-sensor" },
			},
			prerequisites = prerequisites,
			unit = {
				count = 100,
				ingredients = {
					{"automation-science-pack", 1},
					{"logistic-science-pack", 1},
				},
				time = 30
			},
			order = "autodrive-b",
		},
	})
end

sensor('fuel',
	{{ type = "item", name = "arithmetic-combinator", amount = 1 }},
	{ "automobilism", "circuit-network" }
)

sensor('ammo',
	{{ type = "item", name = "arithmetic-combinator", amount = 1 }},
	{ "automobilism", "military", "circuit-network" }
)

sensor('gate',
	{{ type = "item", name = "power-switch", amount = 1 }},
	{ "automobilism", "autodriving", "gates" }
)

sensor('train',
	{{ type = "item", name = "rail-signal", amount = 1 }, { type = "item", name = "decider-combinator", amount = 1 }},
	{ "automobilism", "rail-signals", "circuit-network" }
)

sensor('enemy',
	{{ type = "item", name = "decider-combinator", amount = 1 }},
	{ "automobilism", "military", "circuit-network" }
)

sensor('logistic',
	{{ type = "item", name = "arithmetic-combinator", amount = 1 }, { type = "item", name = "logistic-chest-storage", amount = 1 }},
	{ "automobilism", "logistic-robotics", "circuit-network" }
)

sensor('circuit',
	{{ type = "item", name = "constant-combinator", amount = 1 }},
	{ "automobilism", "autodriving", "circuit-network" }
)

data:extend({
	{
		type = "selection-tool",
		name = "autodrive-control",
		icon = "__autodrive__/control.png",
		icon_size = 32,
		flags = {},
		subgroup = "tool",
		order = "c[z]-c[autodrive-control]",
		stack_size = 1,
		stackable = false,
		selection_color = {r = 0.3, g = 0.9, b = 0.3},
		alt_selection_color = {r = 0.3, g = 0.3, b = 0.9},
		selection_mode = {"any-entity","same-force"},
		alt_selection_mode = {"any-entity","same-force"},
		selection_cursor_box_type = "entity",
		alt_selection_cursor_box_type = "entity"
	},
	{
		type = "recipe",
		name = "autodrive-control",
		category = "crafting",
		subgroup = "tool",
		enabled = false,
		icon = "__autodrive__/control.png",
		icon_size = 32,
		hidden = false,
		energy_required = 1.0,
		ingredients = {
			{ type = "item", name = "iron-plate", amount = 1 },
			{ type = "item", name = "copper-cable", amount = 1 },
		},
		results = {
			{ type = "item", name = "autodrive-control", amount = 1 },
		},
		order = "c[z]-c[autodrive-control]",
	},
	{
		type = "technology",
		name = "autodriving",
		icon = "__autodrive__/driving.png",
		icon_size = 128,
		effects = {
			{ type = "unlock-recipe", recipe = "autodrive-control" },
		},
		prerequisites = {
			"automobilism",
		},
		unit = {
			count = 100,
			ingredients = {
				{"automation-science-pack", 1},
				{"logistic-science-pack", 1},
			},
			time = 30
		},
		order = "autodrive-a",
	},
})

local r = table.deepcopy(data.raw["logistic-container"]["logistic-chest-requester"])
r.name = "autodrive-requester"
r.place_result = "autodrive-requester"
r.collision_mask = {}
r.minable = nil
r.flags = {
	"player-creation",
	"not-rotatable",
	"not-repairable",
	"not-on-map",
	"not-deconstructable",
	"not-blueprintable",
	"not-flammable",
}
r.animation = {
	layers = {
		{
			filename = "__autodrive__/nothing.png",
			width = 32,
			height = 32,
		},
	},
}
r.selectable_in_game = false
r.logistic_slots_count = 128
r.inventory_size = 32

data:extend({ r })

local r = table.deepcopy(data.raw["logistic-container"]["logistic-chest-active-provider"])
r.name = "autodrive-provider"
r.place_result = "autodrive-provider"
r.collision_mask = {}
r.minable = nil
r.flags = {
	"player-creation",
	"not-rotatable",
	"not-repairable",
	"not-on-map",
	"not-deconstructable",
	"not-blueprintable",
	"not-flammable",
}
r.animation = {
	layers = {
		{
			filename = "__autodrive__/nothing.png",
			width = 32,
			height = 32,
		},
	},
}
r.selectable_in_game = false
r.inventory_size = 32

data:extend({ r })




local cc = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])

for _, point in ipairs(cc.circuit_wire_connection_points) do
	point.shadow = point.wire
end

local nosprites = {
	north = {
		filename = "__shortwave__/nothing.png",
		width = 32,
		height = 32,
		priority = "low",
	},
	south = {
		filename = "__shortwave__/nothing.png",
		width = 32,
		height = 32,
		priority = "low",
	},
	east = {
		filename = "__shortwave__/nothing.png",
		width = 32,
		height = 32,
		priority = "low",
	},
	west = {
		filename = "__shortwave__/nothing.png",
		width = 32,
		height = 32,
		priority = "low",
	},
}

data:extend({
	{
		type = "constant-combinator",
		name = "autodrive-shortwave-link",
		flags = {
			"player-creation",
			"not-flammable",
			"not-blueprintable",
			"not-rotatable",
			"not-deconstructable",
		},
		selectable_in_game = false,
		collision_mask = {},
		collision_box = nil, --{{-0.25,-0.25},{0.25,0.25}},
		selection_box = nil, --{{-0.5,-0.5},{0.5,0.5}},
		icon = "__autodrive__/nothing.png",
		icon_size = 32,
		tile_width = 1,
		tile_height = 1,
		item_slot_count = 10,
		sprites = nosprites,
		activity_led_sprites = cc.activity_led_sprites,
		activity_led_light = { intensity = 0, size = 0 },
		activity_led_light_offsets = cc.activity_led_light_offsets,
		circuit_wire_connection_points = cc.circuit_wire_connection_points,
		circuit_wire_max_distance = 1000000,
		draw_circuit_wires = false,
		corpse = "small-remnants",
	},
})