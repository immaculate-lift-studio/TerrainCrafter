# Terrain Crafter
High Performance Procedural Terrain Generation for Godot 4.3

![Terrain Crafter](https://github.com/user-attachments/assets/2ab4ea7f-b77a-49f5-9ba2-da823b0f6cf7)



## Description
This is a procedural terrain generator that emphasizes ease of use and performance. It will create an infinite landscape around the player ship that will continue for as long as you keep flying, with the only limits being floating point errors from traveling too far away from the origin. 

## Features
* Noise-based terrain generation, configurable in editor
* Chunk management that loads/unloads based on player position
* Collisions that are loaded and unloaded with each chunk
* LOD system that switches mesh and collision complexity based on distance
* Customizable terrain shader with 3 texture layers to blend together
* Water shader as a plane mesh that follows the player
* Fun little ship controller with ground effect (air cushion) that can land and zip around

## Installation
It is recommended to download this plugin from the Asset Store, but if you download it from this repository or the Itch.io page, simply copy the terraincrafter folder into the res://addons/ folder in your file system. Make sure to enable the plugin in your project settings and restart the project to clean up any errors. In order to start creating **you will need** the following supporting nodes in your scene tree:
* TerrainCrafter node
* Player node
* Chunks node
## Tool Setup
> #### I highly recommend starting with the example_level to see how everything works
### Dependencies
In order to use this tool, you need to add the "terrain_crafter" node to your scene, then set up the following in the node settings:
* Player - Node that contains your player character. This will manage the loading and unloading of chunks based on how far away you are
* Base Mesh Instance - Reference mesh that the generation uses to populate the world. Use the ![shader included](https://github.com/immaculate-lift-studio/Terrain-Crafter/blob/main/addons/terraincrafter/generator_resources/terrain_shader.gdshader) to change the textures, scale, etc
* Chunks Node - Node that stores the chunks that are generated
* Noise - Select the noise pattern the generation will use. Recommended to have a very low value in the frequency (0.0002-0.0006 on simplex noise for a good starting point)
### Nodes included in example_level
#### Ship
* This is a ship that flies around that I made. See ![input_mappings](https://github.com/immaculate-lift-studio/Terrain-Crafter/blob/main/addons/terraincrafter/assets/example_ship/input_mappings.txt) for the mappings you need to add in your project settings. Lots of settings are exposed for you to play with. In the future, this controller will be released as a separate plugin.  
#### Follow Camera
* If you are using this camera to follow your player, choose the "Target Path" as your player
#### Debug Camera
* You must assign the terrain crafter node as well as the player node
* If you want to disable this, just toggle it in editor or delete it altogether
* Make sure to add a "debug_toggle" input mapping in the project settings to turn it on and off
#### Ocean Mesh
* If "Player" is assigned in the editor settings, the ocean plane will follow the player and provide a consistant water surface as you fly around, just set it to whatever altitude you want in the exposed setting. I have it set to -180 for the example level
#### WorldEnvironment Settings
* Fog - Default is set to depth mode, with Depth End at 5500 and Depth Begin at 3800, with Density at 0.9 and Aerial Perspective at 1; light color of b7bec8. This screens the pop in of the far terrain generation quite nicely. Adjust it per your preference
* Directional Light - Default is set to +50 degrees on the X axis to give a good afternoon glow
    
## Terrain Generation
There are quite a few customization options you should pay attention too
* Chunk Size - Determines the width and depth of each chunk
* Render Distance - Sets the range of chunks that are active around the player to optimize performance
* Noise Amplitude - Scales the noise values to adjust the terrain’s vertical features
* High LOD Distance - Distance at which high detail chunks are used
* Medium LOD Distance - Distance at which medium detail chunks are used
* High Resolution - Sets the number of vertices per chunk for high detail
* Medium Resolution - Sets the number of vertices per chunk for medium detail
* Low Resolution - Sets the number of vertices per chunk for low detail

I have set the default values of these to a point where there is excellent performance with only minor pop in. In my experience, setting the resolution higher than 64 starts to affect performance greatly, but this is dependent on your system (I tested using an RTX 3060 and Ryzen 3700)

## Current Issues
* Render distance only works up to a value of 5, at higher values the terrain doesn't appear visible (but it does get generated) 
* Chunk pooling is not yet implemented, so if you are pushing high resolution terrain with a large render distance, there will be stutters each time a chunk is generated. This is a priority to add in the next version
* Need to tweak the generation system to reduce the harsh vertex angles of high LOD terrain

## Credits
Here is a list of the assets I used in my example level and where you can find their work. Many thanks to them for making their work open and available to the open-source community.

### Textures by: Screaming Brain Studios
https://screamingbrainstudios.itch.io/tiny-texture-pack (CC0)

https://screamingbrainstudios.itch.io/tiny-texture-pack-2 (CC0)

### Spaceship by: Quaternius
https://quaternius.com/packs/ultimatespaceships.html (CC0)

### (Another) Water Shader by: Verssales
https://godotshaders.com/shader/another-water-shader/ (CC0)
### How To Create A Water Shader // Godot 4 Tutorial by: StayAtHomeDev
https://www.youtube.com/watch?v=7L6ZUYj1hs8
### Depth Texture Magic by: Lielay9
https://github.com/godotengine/godot/issues/77798#issuecomment-1575222421

## Contributing
I'm happy to work with others on this. If you have suggestions or want to improve the code, please reach out to me on my ![Itch.io Page](https://immaculate-lift-studio.itch.io/) or submit an issue/pull request on this repository

## License
MIT. I hope this helps somebody in their Godot journey!
