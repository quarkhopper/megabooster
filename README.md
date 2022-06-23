# Options for Pyromania
## Brief introduction to the physics system
The Pyromania engine uses a 3D vector grid, a meta-grid that averages those values on a larger resolution, and a library for controlling fire and physics effects that wraps those vector fields. Vector fields automatically propagate, extend, and cull based on parameters set by the player in the options menu. Operations are staggered somewhat to help with performance. Each subtool (bomb, rocket, and flamethrower) uses its own separate field. 

Certain effects such as the appearance of flames (points of light in smoke particles), and contact damage (holes) are tied directly to the base vector field, while other effects, such as impulse (push) and spawning fires are tied to the meta-field for performance reasons. Flame particles spawn when vector field constraints are met, such as reaching a minimum vector (force) magnitude, while other aspects are tied to the normalized value of the force, such as the magnitude of damage and the color/intensity of flame particles.

PyroField.lua is encapsulated and can be exported with ForceField.lua and Utils.lua to other projects for reuse. Logic related to mod-specific weapons, UI, and settings reside above this level. 

## Options controlling the engine
### General options
#### Rainbow mode (rainbow_mode)
All flames and resulting smoke particles in the pyro field cycle hue values. 
### Common tool options
#### Hot flame color (flame_color_hot)
The HSV color of a flame when the controlling vector field force is at its maximum and blends towards flame_color_cool linearly as the vector force falls to flame_dead_force.
#### Cool flame color (flame_color_cool)
The HSV color of a flame when the controlling vector field force is at its minimum (flame_dead_force).
#### Performance (boomness)
Allows you to choose from parameters that match the kind of performance you need. The principle means of adjusting the scale and quality of fire and explosion effects. 
#### Physical damage modifier (physical_damage_factor)
Adjust how distructive the fire is on surfaces. 0 for not destructive. 1 for maximum destructive. Note: destruction will still occurr from initial primer explosion and rocket burrowing. Additionaly, objects that are hurled might cause physical destruction. 
### Bomb tool options
#### Maximum radius of random explosions (max_random_radius)
Sets a bounding box for where a random explosion can spawn to a box centered on the player with sides this far from the player.
#### Minimum radius of random explosions (min_random_radius)
The minimum distance from the player that a random explosion can spawn. 
### Rocket options
#### Rate of fire (rate_of_fire)
The pause (in seconds) between when the player can fire rockets. Setting this lower will result in more rapid fire. 
#### Speed (speed)
The speed that a rocket flies. Setting this higher will result in a faster rocket. NOTE: in order for rockets to properly penetrate the outer surface of an object, a minimum speed of 1 should be used. Slower than that and most rocket detonations will occur at the surface of objects. Higher than the default will result in rockets penetrating deeper into them before detonating.
#### Max flight distance (max_dist)
The maximum distance the rocket can travel before it self-destructs.
### Flamethrower tool options
#### Rate of fire (rate_of_fire)
The pause between spray being fired. A higher value will result in small fireball-puffs being emitted instead of a steady stream. Could be interesting… with the right flame settings…
#### Spray velocity (speed)
How fast spray particles fly. Higher values result in faster spray.
#### Max distance (max_dist)
How far spray flies before it stops. 








