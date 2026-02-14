# Zigon - Procedural 3D World Builder

Zigon is a 3D procedural generation engine built in Zig with Raylib, designed for instant web deployment and python scripting.

[![Zigon Terrain](https://raw.githubusercontent.com/JosefAlbers/Zigon/main/assets/intro1.png)](https://josefalbers.github.io/Zigon/)

[![Zigon Terrain](https://raw.githubusercontent.com/JosefAlbers/Zigon/main/assets/zigon.gif)](https://josefalbers.github.io/Zigon/)

**[Live Web Demo](https://josefalbers.github.io/Zigon/)** • **[YouTube Demos](https://www.youtube.com/playlist?list=PL9S8vGIQARIjJsAg3WpS49gjECYQDEHje)** • **[PyPI Package](https://pypi.org/project/zigon/)**

## Running Zig Executables

| Command | Description |
|---------|-------------|
| `zig build run` | 3D render demo |
| `zig build run-terrain` | Terrain generation demo |
| `zig build run-dungeon` | Dungeon generation demo |
| `zig build run-bench` | Benchmarking |
| `zig build` | Python scripting library |

Configure terrain, dungeons, and rendering with compile-time flags:

| Option | Description | Default |
|--------|-------------|---------|
| `-Dmap-size=<size>` | Terrain grid size (64, 128, 256, 512, 1024) | 128 |
| `-Ddungeon-type=<type>` | Dungeon archetype: -1=none, 0=rooms, 1=rogue, 2=cavern, 3=maze, 4=labyrinth, 5=arena | -1 |
| `-Ddungeon-magnify=<factor>` | Dungeon upscaling factor | 4 |
| `-Dseed=<number>` | Initial random seed (0=timestamp) | 0 |
| `-Dwindow-width=<pixels>` | Window width | 800 |
| `-Dwindow-height=<pixels>` | Window height | 600 |
| `-Draylib-include=<path>` | Custom raylib include directory | system default |
| `-Draylib-lib=<path>` | Custom raylib library directory | system default |

### Dungeon Generation

Zigon implements Wave Function Collapse (wfc) with backtracking for procedural dungeon generation. Six archetypes are supported:

```
zig build run -Ddungeon-type=4 -Dseed=86
```

The WFC solver maintains adjacency rules from example layouts, ensuring generated dungeons are traversable and aesthetically consistent.

![Labyrinth Dungeon](https://raw.githubusercontent.com/JosefAlbers/Zigon/main/assets/dungeon.gif)

### Terrain Generation

Zigon uses Fractional Brownian Motion (fbm) to synthesize organic landscapes by layering multiple iterations of noise at varying frequencies:

```
Zig build run-terrain
```

- Octaves: Defines the number of detail layers; more octaves create more complex terrain.
- Persistence: Determines how much the amplitude (height) decreases each layer, controlling surface roughness.
- Lacunarity: Sets the frequency (density) increase per layer, dictating the scale of fine details.

![Terrain with Zigger](https://raw.githubusercontent.com/JosefAlbers/Zigon/main/assets/terrain.gif)

## Python Scripting

Zigon exposes a full Python API via ctypes. Write game logic in Python while terrain generation, rendering, and physics run at native speed.

```bash
python main.py
```

![python main.py](https://raw.githubusercontent.com/JosefAlbers/Zigon/main/assets/tui.gif)

### Basic Example

```python
from zigon import Zigon

# Initialize engine
game = Zigon(size=128)

# Load procedural or real-world terrain data
game.load_map(get_base_map(128, 'gradient'))

# Spawn entities
game.spawn("House", 100, 100)
game.spawn_shape("Cube", -10, -10, size=2.0, height=20.0, color=(100, 100, 100))

# Register event callbacks
@game.set_callback
def on_frame(event_key, event_val):
    if event_key == 0:  # Frame update
        # Update game state
        pass
    elif event_key == 2:  # Mouse click
        pos = game.get_click_pos()
        print(f"Clicked at {pos}")

# Start main loop
game.start()
```

### Advanced: Entity Management

```python
from rpg import Objects

# Spawn NPC with patrol path
npc = Objects(game, "Human", 0, 0)
npc.set_path([(-20, 0), (-20, 20), (-10, 20)], speed=3.0, loop=True)

# React to clicks
@npc.on_click
def handle_interaction(obj):
    print(f"NPC clicked at {obj.get_pos()}")
    # Spawn visual effect
    x, z, _ = obj.get_pos()
    Objects(game, "Beam", x, z, duration=2.0)
```

## Performance

All benchmarks measured on Apple M1 Max at 1920×1000 resolution. See `actual_benchmark_results.out` for raw data.

```bash
# Build Zig terrain benchmark
zig build bench
./zig-out/bin/bench_terrain

# Run full comparison suite (Python + Zig)
python bench_zigon.py

# Rendering stress test (opens window)
python bench_render.py

# Generate markdown report
python bench_zigon.py --report BENCHMARKS.md
```

<details><summary>Click to expand output</summary><pre>

~/D/tzg> python bench_render.py                                                                                                                                                                               (tzg)
╔══════════════════════════════════════════════════════════════╗
║            ZIGON RENDERING STRESS TEST                     ║
╚══════════════════════════════════════════════════════════════╝

── Test 1: Terrain-Only FPS (no entities) ──

INFO: Initializing raylib 5.5
INFO: Platform backend: DESKTOP (GLFW)
INFO: Supported raylib modules:
INFO:     > rcore:..... loaded (mandatory)
INFO:     > rlgl:...... loaded (mandatory)
INFO:     > rshapes:... loaded (optional)
INFO:     > rtextures:. loaded (optional)
INFO:     > rtext:..... loaded (optional)
INFO:     > rmodels:... loaded (optional)
INFO:     > raudio:.... loaded (optional)
INFO: DISPLAY: Device initialized successfully
INFO:     > Display size: 1920 x 1080
INFO:     > Screen size:  1920 x 1000
INFO:     > Render size:  1920 x 1000
INFO:     > Viewport offsets: 0, 0
INFO: GLAD: OpenGL extensions loaded successfully
INFO: GL: Supported extensions count: 43
INFO: GL: OpenGL device information:
INFO:     > Vendor:   Apple
INFO:     > Renderer: Apple M1 Max
INFO:     > Version:  4.1 Metal - 89.4
INFO:     > GLSL:     4.10
INFO: GL: VAO extension detected, VAO functions loaded successfully
INFO: GL: NPOT textures extension detected, full NPOT textures supported
INFO: GL: DXT compressed textures supported
INFO: PLATFORM: DESKTOP (GLFW - Cocoa): Initialized successfully
INFO: TEXTURE: [ID 1] Texture loaded successfully (1x1 | R8G8B8A8 | 1 mipmaps)
INFO: TEXTURE: [ID 1] Default texture loaded successfully
INFO: SHADER: [ID 1] Vertex shader compiled successfully
INFO: SHADER: [ID 2] Fragment shader compiled successfully
INFO: SHADER: [ID 3] Program shader loaded successfully
INFO: SHADER: [ID 3] Default shader loaded successfully
INFO: RLGL: Render batch vertex buffers loaded successfully in RAM (CPU)
INFO: RLGL: Render batch vertex buffers loaded successfully in VRAM (GPU)
INFO: RLGL: Default OpenGL state initialized successfully
INFO: TEXTURE: [ID 2] Texture loaded successfully (128x128 | GRAY_ALPHA | 1 mipmaps)
INFO: FONT: Default font loaded successfully (224 glyphs)
INFO: SYSTEM: Working Directory: /Users/jjms/Downloads/tzg
INFO: TIMER: Target time per frame: 16.667 milliseconds
INFO: VAO: [ID 2] Mesh uploaded successfully to VRAM (GPU)
INFO: TEXTURE: [ID 3] Texture loaded successfully (63x63 | R8G8B8A8 | 1 mipmaps)
  Terrain 64x64                        FPS:    59.1  avg:  16.93ms  p99:  17.82ms
INFO: VAO: [ID 2] Unloaded vertex array data from VRAM (GPU)
INFO: MODEL: Unloaded model (and meshes) from RAM and VRAM
INFO: TEXTURE: [ID 3] Unloaded texture data from VRAM (GPU)
INFO: TEXTURE: [ID 2] Unloaded texture data from VRAM (GPU)
INFO: SHADER: [ID 3] Default shader unloaded successfully
INFO: TEXTURE: [ID 1] Default texture unloaded successfully
INFO: Window closed successfully
INFO: Initializing raylib 5.5
INFO: Platform backend: DESKTOP (GLFW)
INFO: Supported raylib modules:
INFO:     > rcore:..... loaded (mandatory)
INFO:     > rlgl:...... loaded (mandatory)
INFO:     > rshapes:... loaded (optional)
INFO:     > rtextures:. loaded (optional)
INFO:     > rtext:..... loaded (optional)
INFO:     > rmodels:... loaded (optional)
INFO:     > raudio:.... loaded (optional)
INFO: DISPLAY: Device initialized successfully
INFO:     > Display size: 1920 x 1080
INFO:     > Screen size:  1920 x 1000
INFO:     > Render size:  1920 x 1000
INFO:     > Viewport offsets: 0, 0
INFO: GLAD: OpenGL extensions loaded successfully
INFO: GL: Supported extensions count: 43
INFO: GL: OpenGL device information:
INFO:     > Vendor:   Apple
INFO:     > Renderer: Apple M1 Max
INFO:     > Version:  4.1 Metal - 89.4
INFO:     > GLSL:     4.10
INFO: GL: VAO extension detected, VAO functions loaded successfully
INFO: GL: NPOT textures extension detected, full NPOT textures supported
INFO: GL: DXT compressed textures supported
INFO: PLATFORM: DESKTOP (GLFW - Cocoa): Initialized successfully
INFO: TEXTURE: [ID 1] Texture loaded successfully (1x1 | R8G8B8A8 | 1 mipmaps)
INFO: TEXTURE: [ID 1] Default texture loaded successfully
INFO: SHADER: [ID 1] Vertex shader compiled successfully
INFO: SHADER: [ID 2] Fragment shader compiled successfully
INFO: SHADER: [ID 3] Program shader loaded successfully
INFO: SHADER: [ID 3] Default shader loaded successfully
INFO: RLGL: Render batch vertex buffers loaded successfully in RAM (CPU)
INFO: RLGL: Render batch vertex buffers loaded successfully in VRAM (GPU)
INFO: RLGL: Default OpenGL state initialized successfully
INFO: TEXTURE: [ID 2] Texture loaded successfully (128x128 | GRAY_ALPHA | 1 mipmaps)
INFO: FONT: Default font loaded successfully (224 glyphs)
INFO: SYSTEM: Working Directory: /Users/jjms/Downloads/tzg
INFO: TIMER: Target time per frame: 16.667 milliseconds
INFO: VAO: [ID 2] Mesh uploaded successfully to VRAM (GPU)
INFO: TEXTURE: [ID 3] Texture loaded successfully (127x127 | R8G8B8A8 | 1 mipmaps)
  Terrain 128x128                      FPS:    59.2  avg:  16.90ms  p99:  17.60ms
INFO: VAO: [ID 2] Unloaded vertex array data from VRAM (GPU)
INFO: MODEL: Unloaded model (and meshes) from RAM and VRAM
INFO: TEXTURE: [ID 3] Unloaded texture data from VRAM (GPU)
INFO: TEXTURE: [ID 2] Unloaded texture data from VRAM (GPU)
INFO: SHADER: [ID 3] Default shader unloaded successfully
INFO: TEXTURE: [ID 1] Default texture unloaded successfully
INFO: Window closed successfully
INFO: Initializing raylib 5.5
INFO: Platform backend: DESKTOP (GLFW)
INFO: Supported raylib modules:
INFO:     > rcore:..... loaded (mandatory)
INFO:     > rlgl:...... loaded (mandatory)
INFO:     > rshapes:... loaded (optional)
INFO:     > rtextures:. loaded (optional)
INFO:     > rtext:..... loaded (optional)
INFO:     > rmodels:... loaded (optional)
INFO:     > raudio:.... loaded (optional)
INFO: DISPLAY: Device initialized successfully
INFO:     > Display size: 1920 x 1080
INFO:     > Screen size:  1920 x 1000
INFO:     > Render size:  1920 x 1000
INFO:     > Viewport offsets: 0, 0
INFO: GLAD: OpenGL extensions loaded successfully
INFO: GL: Supported extensions count: 43
INFO: GL: OpenGL device information:
INFO:     > Vendor:   Apple
INFO:     > Renderer: Apple M1 Max
INFO:     > Version:  4.1 Metal - 89.4
INFO:     > GLSL:     4.10
INFO: GL: VAO extension detected, VAO functions loaded successfully
INFO: GL: NPOT textures extension detected, full NPOT textures supported
INFO: GL: DXT compressed textures supported
INFO: PLATFORM: DESKTOP (GLFW - Cocoa): Initialized successfully
INFO: TEXTURE: [ID 1] Texture loaded successfully (1x1 | R8G8B8A8 | 1 mipmaps)
INFO: TEXTURE: [ID 1] Default texture loaded successfully
INFO: SHADER: [ID 1] Vertex shader compiled successfully
INFO: SHADER: [ID 2] Fragment shader compiled successfully
INFO: SHADER: [ID 3] Program shader loaded successfully
INFO: SHADER: [ID 3] Default shader loaded successfully
INFO: RLGL: Render batch vertex buffers loaded successfully in RAM (CPU)
INFO: RLGL: Render batch vertex buffers loaded successfully in VRAM (GPU)
INFO: RLGL: Default OpenGL state initialized successfully
INFO: TEXTURE: [ID 2] Texture loaded successfully (128x128 | GRAY_ALPHA | 1 mipmaps)
INFO: FONT: Default font loaded successfully (224 glyphs)
INFO: SYSTEM: Working Directory: /Users/jjms/Downloads/tzg
INFO: TIMER: Target time per frame: 16.667 milliseconds
INFO: VAO: [ID 2] Mesh uploaded successfully to VRAM (GPU)
INFO: TEXTURE: [ID 3] Texture loaded successfully (255x255 | R8G8B8A8 | 1 mipmaps)
  Terrain 256x256                      FPS:    59.0  avg:  16.95ms  p99:  17.50ms
INFO: VAO: [ID 2] Unloaded vertex array data from VRAM (GPU)
INFO: MODEL: Unloaded model (and meshes) from RAM and VRAM
INFO: TEXTURE: [ID 3] Unloaded texture data from VRAM (GPU)
INFO: TEXTURE: [ID 2] Unloaded texture data from VRAM (GPU)
INFO: SHADER: [ID 3] Default shader unloaded successfully
INFO: TEXTURE: [ID 1] Default texture unloaded successfully
INFO: Window closed successfully

── Test 2: Entity Scaling (128x128 terrain) ──

INFO: Initializing raylib 5.5
INFO: Platform backend: DESKTOP (GLFW)
INFO: Supported raylib modules:
INFO:     > rcore:..... loaded (mandatory)
INFO:     > rlgl:...... loaded (mandatory)
INFO:     > rshapes:... loaded (optional)
INFO:     > rtextures:. loaded (optional)
INFO:     > rtext:..... loaded (optional)
INFO:     > rmodels:... loaded (optional)
INFO:     > raudio:.... loaded (optional)
INFO: DISPLAY: Device initialized successfully
INFO:     > Display size: 1920 x 1080
INFO:     > Screen size:  1920 x 1000
INFO:     > Render size:  1920 x 1000
INFO:     > Viewport offsets: 0, 0
INFO: GLAD: OpenGL extensions loaded successfully
INFO: GL: Supported extensions count: 43
INFO: GL: OpenGL device information:
INFO:     > Vendor:   Apple
INFO:     > Renderer: Apple M1 Max
INFO:     > Version:  4.1 Metal - 89.4
INFO:     > GLSL:     4.10
INFO: GL: VAO extension detected, VAO functions loaded successfully
INFO: GL: NPOT textures extension detected, full NPOT textures supported
INFO: GL: DXT compressed textures supported
INFO: PLATFORM: DESKTOP (GLFW - Cocoa): Initialized successfully
INFO: TEXTURE: [ID 1] Texture loaded successfully (1x1 | R8G8B8A8 | 1 mipmaps)
INFO: TEXTURE: [ID 1] Default texture loaded successfully
INFO: SHADER: [ID 1] Vertex shader compiled successfully
INFO: SHADER: [ID 2] Fragment shader compiled successfully
INFO: SHADER: [ID 3] Program shader loaded successfully
INFO: SHADER: [ID 3] Default shader loaded successfully
INFO: RLGL: Render batch vertex buffers loaded successfully in RAM (CPU)
INFO: RLGL: Render batch vertex buffers loaded successfully in VRAM (GPU)
INFO: RLGL: Default OpenGL state initialized successfully
INFO: TEXTURE: [ID 2] Texture loaded successfully (128x128 | GRAY_ALPHA | 1 mipmaps)
INFO: FONT: Default font loaded successfully (224 glyphs)
INFO: SYSTEM: Working Directory: /Users/jjms/Downloads/tzg
INFO: TIMER: Target time per frame: 16.667 milliseconds
INFO: VAO: [ID 2] Mesh uploaded successfully to VRAM (GPU)
INFO: TEXTURE: [ID 3] Texture loaded successfully (127x127 | R8G8B8A8 | 1 mipmaps)
  0 entities (baseline)                FPS:    59.0  avg:  16.93ms  p99:  17.46ms
  100 static entities                  FPS:    58.6  avg:  17.06ms  p99:  17.68ms
  500 static entities                  FPS:    58.1  avg:  17.21ms  p99:  17.30ms
  1000 static entities                 FPS:    46.4  avg:  21.57ms  p99:  22.59ms
  2000 static entities                 FPS:    12.6  avg:  79.54ms  p99:  80.67ms
  5000 static entities                 FPS:     2.6  avg: 379.21ms  p99: 390.51ms
INFO: VAO: [ID 2] Unloaded vertex array data from VRAM (GPU)
INFO: MODEL: Unloaded model (and meshes) from RAM and VRAM
INFO: TEXTURE: [ID 3] Unloaded texture data from VRAM (GPU)
INFO: TEXTURE: [ID 2] Unloaded texture data from VRAM (GPU)
INFO: SHADER: [ID 3] Default shader unloaded successfully
INFO: TEXTURE: [ID 1] Default texture unloaded successfully
INFO: Window closed successfully

── Test 3: Moving Entities (update + render) ──

INFO: Initializing raylib 5.5
INFO: Platform backend: DESKTOP (GLFW)
INFO: Supported raylib modules:
INFO:     > rcore:..... loaded (mandatory)
INFO:     > rlgl:...... loaded (mandatory)
INFO:     > rshapes:... loaded (optional)
INFO:     > rtextures:. loaded (optional)
INFO:     > rtext:..... loaded (optional)
INFO:     > rmodels:... loaded (optional)
INFO:     > raudio:.... loaded (optional)
INFO: DISPLAY: Device initialized successfully
INFO:     > Display size: 1920 x 1080
INFO:     > Screen size:  1920 x 1000
INFO:     > Render size:  1920 x 1000
INFO:     > Viewport offsets: 0, 0
INFO: GLAD: OpenGL extensions loaded successfully
INFO: GL: Supported extensions count: 43
INFO: GL: OpenGL device information:
INFO:     > Vendor:   Apple
INFO:     > Renderer: Apple M1 Max
INFO:     > Version:  4.1 Metal - 89.4
INFO:     > GLSL:     4.10
INFO: GL: VAO extension detected, VAO functions loaded successfully
INFO: GL: NPOT textures extension detected, full NPOT textures supported
INFO: GL: DXT compressed textures supported
INFO: PLATFORM: DESKTOP (GLFW - Cocoa): Initialized successfully
INFO: TEXTURE: [ID 1] Texture loaded successfully (1x1 | R8G8B8A8 | 1 mipmaps)
INFO: TEXTURE: [ID 1] Default texture loaded successfully
INFO: SHADER: [ID 1] Vertex shader compiled successfully
INFO: SHADER: [ID 2] Fragment shader compiled successfully
INFO: SHADER: [ID 3] Program shader loaded successfully
INFO: SHADER: [ID 3] Default shader loaded successfully
INFO: RLGL: Render batch vertex buffers loaded successfully in RAM (CPU)
INFO: RLGL: Render batch vertex buffers loaded successfully in VRAM (GPU)
INFO: RLGL: Default OpenGL state initialized successfully
INFO: TEXTURE: [ID 2] Texture loaded successfully (128x128 | GRAY_ALPHA | 1 mipmaps)
INFO: FONT: Default font loaded successfully (224 glyphs)
INFO: SYSTEM: Working Directory: /Users/jjms/Downloads/tzg
INFO: TIMER: Target time per frame: 16.667 milliseconds
INFO: VAO: [ID 2] Mesh uploaded successfully to VRAM (GPU)
INFO: TEXTURE: [ID 3] Texture loaded successfully (127x127 | R8G8B8A8 | 1 mipmaps)
  100 moving entities                  FPS:    58.6  avg:  17.06ms  p99:  17.77ms
  500 moving entities                  FPS:    58.1  avg:  17.22ms  p99:  17.29ms
  1000 moving entities                 FPS:    46.3  avg:  21.60ms  p99:  21.80ms
INFO: VAO: [ID 2] Unloaded vertex array data from VRAM (GPU)
INFO: MODEL: Unloaded model (and meshes) from RAM and VRAM
INFO: TEXTURE: [ID 3] Unloaded texture data from VRAM (GPU)
INFO: TEXTURE: [ID 2] Unloaded texture data from VRAM (GPU)
INFO: SHADER: [ID 3] Default shader unloaded successfully
INFO: TEXTURE: [ID 1] Default texture unloaded successfully
INFO: Window closed successfully

── Test 4: Mixed Shape Types ──

INFO: Initializing raylib 5.5
INFO: Platform backend: DESKTOP (GLFW)
INFO: Supported raylib modules:
INFO:     > rcore:..... loaded (mandatory)
INFO:     > rlgl:...... loaded (mandatory)
INFO:     > rshapes:... loaded (optional)
INFO:     > rtextures:. loaded (optional)
INFO:     > rtext:..... loaded (optional)
INFO:     > rmodels:... loaded (optional)
INFO:     > raudio:.... loaded (optional)
INFO: DISPLAY: Device initialized successfully
INFO:     > Display size: 1920 x 1080
INFO:     > Screen size:  1920 x 1000
INFO:     > Render size:  1920 x 1000
INFO:     > Viewport offsets: 0, 0
INFO: GLAD: OpenGL extensions loaded successfully
INFO: GL: Supported extensions count: 43
INFO: GL: OpenGL device information:
INFO:     > Vendor:   Apple
INFO:     > Renderer: Apple M1 Max
INFO:     > Version:  4.1 Metal - 89.4
INFO:     > GLSL:     4.10
INFO: GL: VAO extension detected, VAO functions loaded successfully
INFO: GL: NPOT textures extension detected, full NPOT textures supported
INFO: GL: DXT compressed textures supported
INFO: PLATFORM: DESKTOP (GLFW - Cocoa): Initialized successfully
INFO: TEXTURE: [ID 1] Texture loaded successfully (1x1 | R8G8B8A8 | 1 mipmaps)
INFO: TEXTURE: [ID 1] Default texture loaded successfully
INFO: SHADER: [ID 1] Vertex shader compiled successfully
INFO: SHADER: [ID 2] Fragment shader compiled successfully
INFO: SHADER: [ID 3] Program shader loaded successfully
INFO: SHADER: [ID 3] Default shader loaded successfully
INFO: RLGL: Render batch vertex buffers loaded successfully in RAM (CPU)
INFO: RLGL: Render batch vertex buffers loaded successfully in VRAM (GPU)
INFO: RLGL: Default OpenGL state initialized successfully
INFO: TEXTURE: [ID 2] Texture loaded successfully (128x128 | GRAY_ALPHA | 1 mipmaps)
INFO: FONT: Default font loaded successfully (224 glyphs)
INFO: SYSTEM: Working Directory: /Users/jjms/Downloads/tzg
INFO: TIMER: Target time per frame: 16.667 milliseconds
INFO: VAO: [ID 2] Mesh uploaded successfully to VRAM (GPU)
INFO: TEXTURE: [ID 3] Texture loaded successfully (127x127 | R8G8B8A8 | 1 mipmaps)
  200 mixed shapes                     FPS:    58.5  avg:  17.09ms  p99:  17.23ms
  1000 mixed shapes                    FPS:    36.6  avg:  27.33ms  p99:  27.73ms
INFO: VAO: [ID 2] Unloaded vertex array data from VRAM (GPU)
INFO: MODEL: Unloaded model (and meshes) from RAM and VRAM
INFO: TEXTURE: [ID 3] Unloaded texture data from VRAM (GPU)
INFO: TEXTURE: [ID 2] Unloaded texture data from VRAM (GPU)
INFO: SHADER: [ID 3] Default shader unloaded successfully
INFO: TEXTURE: [ID 1] Default texture unloaded successfully
INFO: Window closed successfully

======================================================================
RESULTS SUMMARY
======================================================================

  Test                                    FPS   Avg ms   P99 ms
  ─────────────────────────────────── ─────── ──────── ────────
  Terrain 64x64                          59.1    16.93    17.82
  Terrain 128x128                        59.2    16.90    17.60
  Terrain 256x256                        59.0    16.95    17.50
  0 entities (baseline)                  59.0    16.93    17.46
  100 static entities                    58.6    17.06    17.68
  500 static entities                    58.1    17.21    17.30
  1000 static entities                   46.4    21.57    22.59
  2000 static entities                   12.6    79.54    80.67
  5000 static entities                    2.6   379.21   390.51
  100 moving entities                    58.6    17.06    17.77
  500 moving entities                    58.1    17.22    17.29
  1000 moving entities                   46.3    21.60    21.80
  200 mixed shapes                       58.5    17.09    17.23
  1000 mixed shapes                      36.6    27.33    27.73

  📄 Raw results: bench_render_results.json
~/D/tzg> python bench_zigon.py                                                                                                                                                                                (tzg)
╔══════════════════════════════════════════════════════════════╗
║              ZIGON PERFORMANCE BENCHMARK SUITE             ║
║         Zig + Raylib Engine vs Python Baselines            ║
╚══════════════════════════════════════════════════════════════╝

======================================================================
BENCHMARK 1: FBM Terrain Generation (heightmap)
  Comparison: Zig (native) vs NumPy (vectorized) vs Pure Python
======================================================================

  [64x64] Pure Python:       131.8 ms  (31,077 px/s)
  [64x64] NumPy:               1.3 ms  (3,040,549 px/s)
  [64x64] Zig (native):        0.8 ms  (5,132,832 px/s)

  [128x128] Pure Python:       481.5 ms  (34,026 px/s)
  [128x128] NumPy:               4.6 ms  (3,591,538 px/s)
  [128x128] Zig (native):        3.2 ms  (5,140,884 px/s)

  [256x256] Pure Python:      1921.3 ms  (34,110 px/s)
  [256x256] NumPy:              19.0 ms  (3,444,700 px/s)
  [256x256] Zig (native):       12.7 ms  (5,153,821 px/s)

  [512x512] Pure Python:  SKIPPED (too slow)
  [512x512] NumPy:              85.2 ms  (3,075,368 px/s)
  [512x512] Zig (native):       51.7 ms  (5,069,012 px/s)

  [1024x1024] Pure Python:  SKIPPED (too slow)
  [1024x1024] NumPy:             414.6 ms  (2,528,933 px/s)
  [1024x1024] Zig (native):      214.2 ms  (4,894,764 px/s)

======================================================================
BENCHMARK 2: Terrain Height Query Throughput
  Simulates per-frame lookups for physics/AI (10,000 queries)
======================================================================

  Pure Python:  1.42 ms  (7,060,276 queries/sec)
  NumPy bulk:   0.03 ms  (306,512,990 queries/sec)

  → NumPy vs Python: 43x faster
  → Zig (native) expected: ~10-50x faster than NumPy (zero-copy, no GIL)

======================================================================
BENCHMARK 3: Entity Management Throughput
  Spawn → Update (60 ticks) → Despawn cycle
======================================================================

  [   100 entities] Python:      0.3 ms  (924,379 ops/sec)
  [   100 entities] Zig:    → Expected ~20-100x via HashMap + no GC

  [ 1,000 entities] Python:      3.3 ms  (896,503 ops/sec)
  [ 1,000 entities] Zig:    → Expected ~20-100x via HashMap + no GC

  [10,000 entities] Python:     33.6 ms  (893,390 ops/sec)
  [10,000 entities] Zig:    → Expected ~20-100x via HashMap + no GC

======================================================================
BENCHMARK 4: Memory Footprint
======================================================================

  [128x128] Python/NumPy peak: 3215.3 KB
  [128x128] Zig estimated:     64.0 KB  (bare f32 array)
  [128x128] Ratio:             50.2x

  [256x256] Python/NumPy peak: 12815.3 KB
  [256x256] Zig estimated:     256.0 KB  (bare f32 array)
  [256x256] Ratio:             50.1x

  [512x512] Python/NumPy peak: 51215.3 KB
  [512x512] Zig estimated:     1024.0 KB  (bare f32 array)
  [512x512] Ratio:             50.0x

======================================================================
BENCHMARK 5: Deployment Size Comparison
======================================================================

  Zigon (lib_walk.dylib): 1.04 MB

  Comparison (typical minimal 3D web app):
    Unity WebGL (minimal 3D)            30-50 MB
    Godot Web (minimal 3D)              15-25 MB
    Three.js + bundler                  ~1-3 MB (no physics)
    Electron (minimal)                  ~150 MB
    Zigon WASM (Zig+Raylib)             ~1.0 MB ◄

======================================================================
SUMMARY
======================================================================

  Zigon's architecture (Zig core + Python scripting + WASM export) wins:

  ✓ Terrain Generation:  100-500x faster than pure Python
                         5-20x faster than NumPy
  ✓ Height Queries:      Zero-overhead native lookups (no GIL, no boxing)
  ✓ Entity Management:   Native HashMap, no GC pauses
  ✓ Memory:              2-10x less RAM (bare arrays vs Python objects)
  ✓ WASM Bundle:         ~2-3 MB vs 30+ MB (Unity) or 150 MB (Electron)
  ✓ Single Codebase:     Desktop native + Web WASM from one Zig source


  📄 Report saved to BENCHMARKS.md
~/D/tzg> zig build run-bench                                                                                                                                                                                  (tzg)

╔══════════════════════════════════════════════════════╗
║       ZIGON TERRAIN GENERATION BENCHMARK (Zig)      ║
╚══════════════════════════════════════════════════════╝

  FBM: 6 octaves, persistence=0.5, lacunarity=2.0, scale=50.0
  Optimization: ReleaseFast
  Runs: 2 warmup + 5 measured (reporting median)

  Grid Size     Median (ms)       Pixels/sec       Total px
  ------------ ------------ ---------------- --------------
  64                0.805 ms        5,088,198          4,096
  128               5.032 ms        3,255,961         16,384
  256              12.734 ms        5,146,536         65,536
  512              51.777 ms        5,062,943        262,144
  1024            213.943 ms        4,901,193      1,048,576
  2048            874.860 ms        4,794,257      4,194,304

---JSON---
[{"size":64,"median_ms":0.8050,"pixels_per_sec":5088198},{"size":128,"median_ms":5.0320,"pixels_per_sec":3255961},{"size":256,"median_ms":12.7340,"pixels_per_sec":5146536},{"size":512,"median_ms":51.7770,"pixels_per_sec":5062943},{"size":1024,"median_ms":213.9430,"pixels_per_sec":4901193},{"size":2048,"median_ms":874.8600,"pixels_per_sec":4794257}]
---END---

  Done.

~/D/tzg> zig build bench_native                                                                                                                                                                               (tzg)
~/D/tzg> ./zig-out/bin/bench_native                                                                                                                                                                           (tzg)


╔═══════════════════════════════════════════════════════════╗
║       ZIGON NATIVE TERRAIN BENCHMARK (Pure Zig)         ║
╚═══════════════════════════════════════════════════════════╝

  FBM: 6 octaves, persistence=0.5, lacunarity=2.0, scale=50.0
  Optimization: ReleaseFast
  Runs: 3 warmup + 10 measured (reporting median)
  Note: This is PURE Zig with zero FFI overhead

  Grid Size     Median (ms)       Pixels/sec       Total px
  ------------ ------------ ---------------- --------------
  64                1.487 ms        2,754,539          4,096
  128               3.772 ms        4,343,584         16,384
  256              12.723 ms        5,150,986         65,536
  512              51.714 ms        5,069,110        262,144
  1024            214.049 ms        4,898,766      1,048,576
  2048            874.555 ms        4,795,929      4,194,304

---JSON---
[{"size":64,"median_ms":1.4870,"median_ns":1487000,"pixels_per_sec":2754539},{"size":128,"median_ms":3.7720,"median_ns":3772000,"pixels_per_sec":4343584},{"size":256,"median_ms":12.7230,"median_ns":12723000,"pixels_per_sec":5150986},{"size":512,"median_ms":51.7140,"median_ns":51714000,"pixels_per_sec":5069110},{"size":1024,"median_ms":214.0490,"median_ns":214049000,"pixels_per_sec":4898766},{"size":2048,"median_ms":874.5550,"median_ns":874555000,"pixels_per_sec":4795929}]
---END---

  Performance Analysis:
  ────────────────────────────────────────────────────────────
  • 256×256 terrain generates in 12.72ms
  • That's 78.6 FPS if regenerating every frame
  • Processing 5,150,986 pixels/second

  ✓ These are PURE Zig numbers (no FFI overhead)
  ✓ Compare with bench_zigon.py for FFI impact measurement

~/D/tzg> ffmpeg -i output.mp4 -vf "scale=out_color_matrix=bt709:out_range=full,format=yuv420p" -c:v libx264 -crf 10 -preset slow -x264opts colorprim=bt709:transfer=bt709:colormatrix=bt709:fullrange=on -c:a copy reddit_fixed.mp4      (tzg)
~/D/tzg> python bench_zigon_enhanced.py --with-native                                                                                                                                                         (tzg)

╔══════════════════════════════════════════════════════════════╗
║        ZIGON PERFORMANCE BENCHMARK SUITE (Enhanced)        ║
║    Pure Python | NumPy | Zig-FFI | Zig-Native Comparison   ║
╚══════════════════════════════════════════════════════════════╝

  Mode: Including NATIVE Zig benchmark for zero-overhead comparison

======================================================================
BENCHMARK 1: FBM Terrain Generation (6 octaves)
======================================================================

  Running native Zig benchmark: zig-out/bin/bench_native
  ✓ Zigon library loaded (FFI mode)

  [64×64]
    Pure Python:     120.0 ms
    NumPy:             1.3 ms
    Zig (FFI):         2.7 ms  ← includes ctypes overhead
    Zig (native):      0.8 ms  ← zero overhead
      → FFI overhead: ~1844.0 µs per call

  [128×128]
    Pure Python:     481.0 ms
    NumPy:             4.5 ms
    Zig (FFI):        10.8 ms  ← includes ctypes overhead
    Zig (native):      3.2 ms  ← zero overhead
      → FFI overhead: ~7649.2 µs per call

  [256×256]
    Pure Python:    1921.6 ms
    NumPy:            19.0 ms
    Zig (FFI):        44.1 ms  ← includes ctypes overhead
    Zig (native):     12.7 ms  ← zero overhead
      → FFI overhead: ~31413.0 µs per call

  [512×512]
    NumPy:            89.7 ms
    Zig (FFI):       180.8 ms  ← includes ctypes overhead
    Zig (native):     51.7 ms  ← zero overhead
      → FFI overhead: ~129016.1 µs per call

  [1024×1024]
    NumPy:           427.6 ms
    Zig (FFI):       735.0 ms  ← includes ctypes overhead
    Zig (native):    214.0 ms  ← zero overhead
      → FFI overhead: ~520969.8 µs per call

  ────────────────────────────────────────────────────────────────────
  Size     Python       NumPy        Zig-FFI      Zig-Native
  ────────────────────────────────────────────────────────────────────
  64       120 ms       1.3 ms       2.7 ms       0.8 ms
  128      481 ms       4.5 ms       10.8 ms      3.2 ms
  256      1922 ms      19.0 ms      44.1 ms      12.7 ms
  512      —            89.7 ms      180.8 ms     51.7 ms
  1024     —            427.6 ms     735.0 ms     214.0 ms

======================================================================
KEY FINDINGS
======================================================================

  At 256×256 (typical game map):
    • Pure Python:  1922 ms
    • NumPy:        19.0 ms
    • Zig (FFI):    44.1 ms  ← adds ~1-2µs overhead
    • Zig (native): 12.7 ms  ← PURE performance

  Real-time generation: 79 FPS

  Architecture wins:
    ✓ Pure Zig:      100-150× faster than Python
    ✓ FFI overhead:  Negligible (~1-2µs) for high-value operations
    ✓ Best of both:  Python scripting + Native performance
~/D/tzg>                                                                                                                                                                                                      (tzg)
</pre></details>
### Terrain Generation

Zig-native FBM heightmap vs Python alternatives (same algorithm, 6 octaves):

| Grid Size | Pure Python | NumPy | Zig (native) |
|-----------|-------------|-------|--------------|
| 64×64 | 146 ms | 1.4 ms | **1.8 ms** |
| 128×128 | 481 ms | 4.5 ms | **4.5 ms** |
| 256×256 | 1,919 ms | 18.9 ms | **12.7 ms** |

### Rendering Stress Test

Frames per second under increasing entity load (128×128 terrain, vsync on):

| Scenario | FPS | Avg Frame | P99 Frame |
|----------|-----|-----------|-----------|
| Terrain only | 59.0 | 16.9 ms | 17.7 ms |
| 100 static entities | 58.5 | 17.1 ms | 18.4 ms |
| 500 static entities | 58.0 | 17.2 ms | 17.3 ms |
| 1,000 static entities | 46.3 | 21.6 ms | 22.4 ms |
| 1,000 moving entities | 46.3 | 21.6 ms | 22.1 ms |
| 200 mixed shapes | 58.5 | 17.1 ms | 17.4 ms |
| 1,000 mixed shapes | 36.6 | 27.3 ms | 28.3 ms |

### Memory & Deployment Size

| Metric | Zigon | Python/NumPy |
|--------|-------|-------------|
| 128×128 terrain RAM | 64 KB | 3,215 KB |
| 256×256 terrain RAM | 256 KB | 12,815 KB |
| Native library | 1.04 MB | — | — |
| **WASM web build** | **386 KB** | — | — |

For comparison, Unity WebGL is 30–50 MB, Godot Web is 15–25 MB, Electron is 150+ MB. Zigon's WASM bundle (compiled Zig + Raylib) is **386 KB**. With Zigon, you can host a complete 3D terrain explorer as a [static web page](https://josefalbers.github.io/Zigon/).

## Design Philosophy

Zigon is built around three core principles:

1. **Native performance where it matters** — Terrain generation, mesh construction, and rendering happen in compiled Zig. No interpreter overhead.
2. **Scripting flexibility where it helps** — Game logic, entity behavior, and UI can be written in Python. Iterate without recompiling.
3. **Single-command deployment** — One `zig build` produces a native app, a Python library, and a WASM web bundle from the same source.

This architecture enables:
- **Rapid prototyping** — tweak game logic in Python, see changes instantly
- **Production performance** — ship native binaries with zero Python runtime overhead
- **Universal deployment** — embed the same engine in web pages, desktop apps, or Jupyter notebooks

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

Apache License 2.0 — see [LICENSE](LICENSE) for details.

## Acknowledgments

- Terrain generation inspired by [Perlin Noise](https://en.wikipedia.org/wiki/Perlin_noise) and [FastNoiseLite](https://github.com/Auburn/FastNoiseLite)
- Dungeon generation using [Wave Function Collapse](https://github.com/mxgmn/WaveFunctionCollapse)
- 3D assets from
  - [FPS Hands + Sig Sauer 225](https://skfb.ly/NVBt) by Ulrik Langvandsbråten licensed under [Creative Commons Attribution](http://creativecommons.org/licenses/by/4.0/)
  - [Lockheed Martin F-22 "Raptor"](https://skfb.ly/pqCLv) by andertan licensed under [Creative Commons Attribution](http://creativecommons.org/licenses/by/4.0/)
- 3D rendering powered by [Raylib](https://www.raylib.com/)
- Zig programming language by [Zig Software Foundation](https://ziglang.org/)

