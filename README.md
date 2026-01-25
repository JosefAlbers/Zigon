# TerrainZigger: Procedural 3D World Builder

![TerrainZigger](https://raw.githubusercontent.com/JosefAlbers/TerrainZigger/main/assets/terrain_zigger.gif)

A lightweight, cross-platform 3D terrain generator and game engine built in Zig, with Python scripting for dynamic behaviors like NPC pathing, dialogues, and interactions. Powered by Raylib for rendering procedural worlds from noise to explorable scenes in minutes.

## Why ZigTerrain?

- **Performance-First**: Zig's safety + speed for real-time 3D.
- **Scriptable**: Python integration via ctypes for AI, events, and mods.
- **Procedural Magic**: Perlin/FBM terrain, foliage via Poisson Disk, and dungeons generated with wave function collapse.
- **Interactive**: Raycasting, pathfinding, dialogues.

## Features

- Procedural terrain gen (noise, base maps, biomes)
- Object spawning/movement (humans, birds, rain, beams)
- User controls: Orbit/FPV camera, selection, spawning
- Python hooks: Callbacks for clicks, chats, ticks
- Exports: WASM-ready for web demos

## Quick Start

## Prerequisites

To build and run TerrainZigger, you'll need:

- [Zig](https://ziglang.org/)
- [Raylib](https://www.raylib.com/)

### Build & Run

`zig build run`: Builds and runs the main game (walk.zig).
`zig build run-chat`: Runs the standalone Chat UI test (chat.zig).
`zig build run-object`: Runs the 3D Object/Primitive viewer (object.zig).
`zig build run-dungeon`: Runs the Dungeon generation demo (dungeon.zig).
`zig build run-wasm`: WebAssembly compilation of terrain.zig (demo index.html).
`pip install zigger`: Python scripting (see below)

### Usage Example (Python)

```python
from zigger import Zigger

game = Zigger(size=terrain_size) 
game.load_map(get_base_map(terrain_size, 'N42W071')) # Procedural or real topo data
game.spawn(2, 20, 20)                                # Spawn object (house)
game.start()                                         # Start game
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is open source and available under the [Apache License 2.0](LICENSE).

## Acknowledgments

- Terrain generation algorithm inspired by [Perlin Noise](https://en.wikipedia.org/wiki/Perlin_noise)
- 3D rendering made possible by [Raylib](https://www.raylib.com/)
