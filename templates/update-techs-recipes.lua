local check = function(force, techname)
  if force.technologies[techname] ~= nil and force.technologies[techname].researched then
    force.technologies[techname].researched = false
    force.technologies[techname].researched = true
  end
end

for i, force in pairs(game.forces) do
  force.reset_recipes()
  force.reset_technologies()
	check(force, 'autodriving')
	check(force, 'automobilism')
	check(force, 'circuit-network')
	check(force, 'gates')
	check(force, 'logistic-robotics')
	check(force, 'military')
	check(force, 'rail-signals')
end