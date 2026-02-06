# Zigon: Procedural 3D World Builder

![Zigon](https://raw.githubusercontent.com/JosefAlbers/Zigon/main/assets/zigon.gif)

A procedural generation engine written in Zig and Raylib, with a Python scripting layer.

I built this to experiment with different procedural algorithms in a native environment without sacrificing the flexibility of scripting. It currently generates noise-based terrain and Wave Function Collapse (WFC) dungeons, rendered in real-time.

## The Tech

* **Core:** ZigLang (Native compilation, build system)
* **Renderer:** Raylib (via C ABI)
* **Scripting:** Python (ctypes bindings for hot-reloading logic)
* **Algorithms:**
  * **Terrain:** FBM/Perlin noise with erosion simulation.
  * **Dungeons:** Wave Function Collapse (WFC) with backtracking. Support for 6 archetypes (rogue, maze, arena, etc.).
  * **Foliage:** Poisson Disk Sampling for distribution.

## Quick Start

### Prerequisites

- [Zig](https://ziglang.org/)
- [Raylib](https://www.raylib.com/)

### Installation

```bash
# Clone the repository
git clone https://github.com/JosefAlbers/Zigon.git
cd Zigon

# Build and run the main application
zig build run

# For Python scripting support
pip install zigon
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

![zig build run -Ddungeon-type=4](https://raw.githubusercontent.com/JosefAlbers/Zigon/main/assets/maze.png)

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

Use the `zigon` Python package to script behaviors, load real-world topography, and control the game:

```python
from zigon import Zigon

# Initialize with custom terrain size
game = Zigon(size=128)

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

![Zigon](https://raw.githubusercontent.com/JosefAlbers/Zigon/main/assets/terrain_zigger.gif)

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

## Project Layout

* `src/walk.zig`: Entry point and main loop.
* `src/terrain.zig`: Noise functions and mesh generation.
* `src/dungeon.zig`: WFC implementation and solver.
* `src/bindings.zig`: C-ABI export for Python ctypes.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the [Apache License 2.0](LICENSE).

## Acknowledgments

- Terrain generation inspired by [Perlin Noise](https://en.wikipedia.org/wiki/Perlin_noise) and [FastNoiseLite](https://github.com/Auburn/FastNoiseLite)
- Dungeon generation using [Wave Function Collapse](https://github.com/mxgmn/WaveFunctionCollapse)
- 3D rendering powered by [Raylib](https://www.raylib.com/)
- Zig programming language by [Zig Software Foundation](https://ziglang.org/)
