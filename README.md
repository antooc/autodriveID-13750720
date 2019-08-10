
*Requires one of the vehicle grid mods!* Most should work if they allow regular armor equipment. Or consider [Vehicle Grid](https://mods.factorio.com/mod/VehicleGrid) as an optional dependency.

## Sensors

Autodrive started as a mash-up of ideas for making cars smarter using grid equipment sensors, mix-and-match style:

* *Train sensor*: Car will sense a nearby moving train and brake automatically, or accelerate hard if already crossing rails. Does nothing useful if you're driving along rails!
* *Enemy sensor*: Car will sense and target nearby enemies within range of its guns. Does nothing if vehicle is unarmed.
* *Fuel sensor*: Car will refuel from its inventory.
* *Ammo sensor*: Car will reload ammunition from its inventory.
* *Gate sensor*: Car will open gates without a driver. Enables path finding through gates (see below).
* *Logistic network sensor*: Car will interact with the logistic network when parked. Filtered trunk slots are refilled like a requester chest, and unfiltered slots are exported like an active provider chest. Grew out of my old [Logiquipment](https://mods.factorio.com/mod/logiquipment) mod.

All work when driving a vehicle manually, when a vehicle is parked, and when it's under remote control.

## Trains

The train sensor is your friend... but it's not perfect. For high-traffic train areas block off the rails with walls to force cars to path to gates. When RC driving all the way cross the map, quickly scan the dashed yellow path and ensure there are no long segments where a car will be driving along rails.

The train sensor will accelerate a car very hard to get it off the rails in time to avoid a fast train, so don't stand in front of your car because it might kill you instead of the train :-)

## Logistic Network

1.  Put a logistic network sensor into a car grid
1.  Set some trunk filtered slots. These will be treated like logistic request slots
1.  Park the car inside a logistics zone with robots -- mod won't activate if a car is moving
1.  Robots should arrive...

Note that:

* Sensor only ticks every few seconds, so be patient :)
* There must be at least one trunk filter set for the mod to trigger
* Filtered trunk slots are used to set the request slots of a hidden requester chest
* Unfiltered trunk slots are considered trash and put into a hidden active provider chest
* If the current fuel is requested in a slot, fuel tank will be filled up first
* Entering and starting the car is fine -- items still in hidden chests will be reclaimed

## Remote Control

Autodrive includes a remote-control automatic pathing tool. The RC is similar to the one in [AAI Programmable Vehicles](https://mods.factorio.com/mod/aai-programmable-vehicles). Fine to run both mods in a game, but the sensors only work when AAI vehicle AI is turned off and the Autodrive remote-control is used. Sensors *will not* work for programmed vehicles because the tick handlers will fight for control.

## Vehicle Roboports

One long-time problem with AAI and vehicle grids is [losing robots and some types of grid equipment inventory contents](https://forums.factorio.com/viewtopic.php?f=190&t=38475&start=800#p446221). Autodrive is designed to solve those bugs, so for eg, it's fine to kit out a Hauler with a personal roboport and a burner grid generator, and send it off to build remote mining outposts.

## Pathing

Cars request paths with clearance *max(width, height) x 1.6* which avoids crashes and getting stuck on opther entities. Mostly. The Factorio path-finding API exposed in 0.17 sometimes returns strange paths.

## Bounce Crashing

Cars bounce backward a bit after a crash which usually leaves enough clearance to re-path. You might have seen this behaviour in other RTS games. They also auto-heal themselves and the other entity a bit :-)

## Trees

A car driving with the RC will try to path between trees, bounce-crashing and removing any tree it actually hits. The Hauler can bulldoze it's way, albeit very slowly and at reasonaly high fuel cost, through any forest.

## AAI Programmable Vehicles compatability

Yes, except the RC and AI notes above. AAI stand-alone vehicles like the Hauler, Warden and Chaingunner work with both mods.

## Logistic Carts compatability

Yes, both mods can run together, but sensors don't work on carts.