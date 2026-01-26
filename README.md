# TerrainZigger: Procedural 3D World Builder

![TerrainZigger](https://raw.githubusercontent.com/JosefAlbers/TerrainZigger/main/assets/terrain_zigger.gif)

A lightweight, cross-platform 3D terrain generator and game engine built in Zig with Python scripting support. Create procedural worlds—from noise-based terrain to wave function collapse dungeons—and bring them to life with dynamic NPCs, pathfinding, and interactive dialogues. Powered by Raylib for high-performance 3D rendering.

## Why TerrainZigger?

- **Performance-First**: Zig's compile-time safety meets runtime speed for smooth real-time 3D
- **Scriptable**: Python integration via ctypes for AI behaviors, events, and gameplay logic
- **Procedural Generation**: Perlin/FBM noise terrain, Poisson disk foliage distribution, and wave function collapse dungeons
- **Interactive**: Built-in raycasting, pathfinding, unit selection, and dialogue system
- **Cross-Platform**: Runs on macOS, Linux, and Windows with configurable build options

## Features

- **Terrain Generation**: Procedural noise-based terrain with support for custom base maps and biomes
- **Dungeon Generation**: Six dungeon archetypes (rooms, rogue, cavern, maze, labyrinth, arena) using wave function collapse
- **Object System**: Spawn and animate humans, birds, particles, and 3D primitives
- **Camera Modes**: Orbit camera for overview, first-person mode for exploration
- **User Interactions**: Click-to-select units, drag selection boxes, ground targeting
- **Python Hooks**: Event callbacks for clicks, chat submissions, and game ticks
- **Web Export**: WASM-ready for browser-based demos

## Quick Start

### Prerequisites

- [Zig](https://ziglang.org/)
- [Raylib](https://www.raylib.com/)

### Installation

```bash
# Clone the repository
git clone https://github.com/JosefAlbers/TerrainZigger.git
cd TerrainZigger

# Build and run the main application
zig build run

# For Python scripting support
pip install zigger
```

### Build Commands

| Command | Description |
|---------|-------------|
| `zig build run` | Main terrain application |
| `zig build run-chat` | Standalone chat UI test |
| `zig build run-object` | 3D object/primitive viewer |
| `zig build run-dungeon` | Dungeon generation demo |

```output
Generating 30×30 dungeon using labyrinth archetype...
Extracted 140 unique patterns
Success on attempt 1 after 169 steps

      ██  ██  ████████  ██  ██        ██    ██  ████  ██  ██
██        ██  ██        ██████  ████  ████  ██    ██  ██
██  ████████  ██  ██        ██    ██        ████  ██  ██████
██  ██        ██████  ██████████████████      ██  ██  ██  ██
██  ██  ██        ██                  ██  ██████  ██████  ██
██  ██████  ████████████████████████  ██  ██  ██  ██      ██
██      ██    ██                  ██  ██  ██  ██  ██  ██████
██████  ████  ██████████████████████████  ██████  ██████
    ██    ██      ██      ██  ██          ██      ██      ██
████████████████  ██████████  ██████████████  ██████████████
██            ██      ██  ██      ██  ██      ██      ██
██  ████████        ████  ██████████  ██████████████  ██████
██        ████████  ██    ██  ██      ██  ██      ██  ██  ██
████████            ████████  ██████████  ██████  ██  ██
      ██████████              ██  ██      ██  ██  ██  ██████
  ██          ██  ██████████████  ████        ██  ██  ██  ██
  ██████████████  ██      ██  ██    ██  ████████  ██████  ██
        ██        ██████████  ████  ██    ██  ██  ██      ██
██████  ██████        ██  ██    ██  ████████  ██████████████
        ██  ██  ████████  ████  ██            ██
██████████  ██    ██  ██        ████████████████████████████
    ██  ██  ████████  ██████        ██            ██  ██
██████  ██            ██  ██  ████████  ████████████  ██████
██  ██        ██████████  ██████        ██            ██  ██
██  ████████  ██  ██      ██      ██        ████████████
██        ██  ██  ████        ██████  ████████
████████████  ██    ██  ████████  ██    ██      ██████████
      ██  ██  ████████████        ████  ██████████  ██
  ██████  ██                ██          ██  ██      ████
  ██  ██        ██████████████  ██████████  ████      ██  ██
```

### Build Options

**Available Options:**
- `-Dmap-size=<size>` - Terrain grid size (default: 128)
- `-Ddungeon-type=<type>` - Dungeon archetype: -1=none, 0=rooms, 1=rogue, 2=cavern, 3=maze, 4=labyrinth, 5=arena (default: -1)
- `-Ddungeon-magnify=<factor>` - Dungeon upscaling factor (default: 4)
- `-Dseed=<number>` - Initial random seed (0=timestamp, default: 0)
- `-Dwindow-width=<pixels>` - Window width (default: 800)
- `-Dwindow-height=<pixels>` - Window height (default: 600)
- `-Draylib-include=<path>` - Custom raylib include directory
- `-Draylib-lib=<path>` - Custom raylib library directory

```bash
# Random terrain (default)
zig build run

# Rogue dungeon with custom seed
zig build run -Ddungeon-type=1 -Dseed=12345

# Large cavern map with bigger window
zig build run -Ddungeon-type=2 -Dmap-size=256 -Dwindow-width=1920 -Dwindow-height=1080

# Arena with custom magnification
zig build run -Ddungeon-type=5 -Ddungeon-magnify=8
```

![zig build run -Ddungeon-type=4](https://raw.githubusercontent.com/JosefAlbers/TerrainZigger/main/assets/maze.png)

### Cross-Platform Setup

**macOS (Homebrew):**
```bash
brew install raylib
zig build run -Draylib-include=/opt/homebrew/include -Draylib-lib=/opt/homebrew/lib
```

**Linux:**
```bash
sudo apt install libraylib-dev  # Debian/Ubuntu
zig build run -Draylib-include=/usr/include -Draylib-lib=/usr/lib
```

**Windows (MSYS2):**
```bash
pacman -S mingw-w64-x86_64-raylib
zig build run -Draylib-include=C:/msys64/mingw64/include -Draylib-lib=C:/msys64/mingw64/lib
```

## Python Integration

Use the `zigger` Python package to script behaviors, load real-world topography, and control the game:

```python
from zigger import Zigger

# Initialize with custom terrain size
game = Zigger(size=128)

# Load procedural or real topographic data
game.load_map(get_base_map(128))

# Spawn objects
game.spawn("House", 100, 100)

# Register event callbacks
@game.set_callback
def on_click(k, v):
    if k == 2:
        print(f"Clicked: {game.get_click_pos()}")

# Start the game loop
game.start()
```

## Controls

- **H** - Toggle help overlay
- **Right Mouse** - Regenerate terrain with new seed
- **Left Mouse** - Rotate camera (or select units with Shift held)
- **Mouse Wheel** - Zoom in/out
- **Middle Mouse** - Toggle first-person mode
- **WASD** - Move in first-person mode
- **Z** - Reset camera to initial position
- **,** / **.** - Decrease/increase water level
- **[** / **]** - Decrease/increase terrain roughness
- **F** / **C** - Increase/decrease texture scale
- **D** / **N** - Lighter/darker sky

## Project Structure

```
TerrainZigger/
├── walk.zig          # Main application and game state
├── terrain.zig       # Procedural terrain generation
├── dungeon.zig       # Wave function collapse dungeon generator
├── object.zig        # 3D object rendering and animation
├── chat.zig          # Dialogue system UI
└── build.zig         # Build configuration
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the [Apache License 2.0](LICENSE).

## Acknowledgments

- Terrain generation inspired by [Perlin Noise](https://en.wikipedia.org/wiki/Perlin_noise) and [FastNoiseLite](https://github.com/Auburn/FastNoiseLite)
- Dungeon generation using [Wave Function Collapse](https://github.com/mxgmn/WaveFunctionCollapse)
- 3D rendering powered by [Raylib](https://www.raylib.com/)
- Zig programming language by [Zig Software Foundation](https://ziglang.org/)
