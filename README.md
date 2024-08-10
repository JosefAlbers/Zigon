# TerrainZigger

TerrainZigger is a 3D terrain generator written in Zig using the Raylib library. It creates procedurally generated landscapes with dynamic water features, offering an interactive 3D visualization.

![TerrainZigger Screenshot](https://raw.githubusercontent.com/JosefAlbers/TerrainZigger/main/assets/terrain_zigger.gif)

## Features

- Procedural terrain generation using Fractional Brownian Motion (FBM)
- Real-time 3D rendering with Raylib
- Interactive camera controls for exploring the terrain
- Dynamic water level visualization
- On-the-fly terrain regeneration
- Customizable terrain parameters

## Prerequisites

To build and run TerrainZigger, you'll need:

- [Zig](https://ziglang.org/) (latest version recommended)
- [Raylib](https://www.raylib.com/)

## Building and Running

1. Clone the repository:
   ```
   git clone https://github.com/JosefAlbers/TerrainZigger.git
   cd TerrainZigger
   ```

2. Build the project:
   ```
   zig build-exe main.zig -lc $(pkg-config --libs --cflags raylib)
   ```

3. Run the executable:
   ```
   ./main
   ```

## Controls

- **R** or **Left Mouse Click**: Regenerate terrain
- **Mouse Wheel Pressed**: Pan camera
- **Mouse Wheel**: Zoom in/out
- **Z**: Reset camera to origin (0, 0, 0)

## Customization

You can adjust various parameters in the `main.zig` file to customize the terrain generation:

- `TERRAIN_SIZE`: Changes the size of the terrain grid
- `WATER_LEVEL`: Adjusts the height of the water plane
- `CUBE_SIZE`: Modifies the size of individual terrain cubes

Feel free to experiment with the `fbm` function parameters in `generateTerrain` to create different terrain styles.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is open source and available under the [MIT License](LICENSE).

## Acknowledgments

- Terrain generation algorithm inspired by [Perlin Noise](https://en.wikipedia.org/wiki/Perlin_noise)
- 3D rendering made possible by [Raylib](https://www.raylib.com/)

---

Happy terrain generating! 🏞️