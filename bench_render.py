# Copyright 2026 J Joe
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import ctypes
import os
import sys
import time
import math
import json

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def find_lib():
    from main import get_lib_path
    return get_lib_path()

class StressTester:
    def __init__(self, lib_path):
        self.lib = ctypes.CDLL(lib_path)
        self._setup()

    def _setup(self):
        L = self.lib
        L.init_state.argtypes = [ctypes.c_int, ctypes.c_uint64]
        L.close_state.argtypes = []
        L.render_frame.argtypes = []
        L.render_frame.restype = ctypes.c_bool
        L.spawn_object.argtypes = [ctypes.c_int, ctypes.c_int,
                                    ctypes.c_float, ctypes.c_float, ctypes.c_float]
        L.despawn_object.argtypes = [ctypes.c_int]
        L.set_object_target.argtypes = [ctypes.c_int,
                                         ctypes.c_float, ctypes.c_float, ctypes.c_float]
        L.set_map_cfg.argtypes = [ctypes.c_float, ctypes.c_float, ctypes.c_float,
                                   ctypes.c_uint64, ctypes.c_bool]
        L.spawn_custom_mesh.argtypes = [ctypes.c_int, ctypes.c_int,
                                         ctypes.c_float, ctypes.c_float, ctypes.c_float,
                                         ctypes.c_float, ctypes.c_float, ctypes.c_float,
                                         ctypes.c_int, ctypes.c_int, ctypes.c_int]

    def init(self, size=128, seed=42):
        self.lib.init_state(size, seed)
        self.size = size

    def close(self):
        self.lib.close_state()

    def measure_fps(self, n_frames=300, label=""):
        for _ in range(30):
            self.lib.render_frame()

        frame_times = []
        t_start = time.perf_counter()
        for _ in range(n_frames):
            t0 = time.perf_counter()
            running = self.lib.render_frame()
            t1 = time.perf_counter()
            if not running:
                break
            frame_times.append(t1 - t0)
        t_total = time.perf_counter() - t_start

        if not frame_times:
            return None

        avg_fps = len(frame_times) / t_total
        avg_ms = (sum(frame_times) / len(frame_times)) * 1000
        p99_ms = sorted(frame_times)[int(len(frame_times) * 0.99)] * 1000
        min_ms = min(frame_times) * 1000
        max_ms = max(frame_times) * 1000

        result = {
            "label": label,
            "frames": len(frame_times),
            "avg_fps": round(avg_fps, 1),
            "avg_ms": round(avg_ms, 2),
            "p99_ms": round(p99_ms, 2),
            "min_ms": round(min_ms, 2),
            "max_ms": round(max_ms, 2),
        }

        print(f"  {label:<35}  FPS: {avg_fps:>7.1f}  "
              f"avg: {avg_ms:>6.2f}ms  p99: {p99_ms:>6.2f}ms")
        return result

    def spawn_entities(self, n, type_id=0):
        cols = int(math.sqrt(n)) + 1
        for i in range(n):
            x = float((i % cols) * 2 - cols)
            z = float((i // cols) * 2 - cols)
            self.lib.spawn_object(i, type_id, x, z, 0.0)

    def spawn_moving_entities(self, n, type_id=0):
        cols = int(math.sqrt(n)) + 1
        for i in range(n):
            x = float((i % cols) * 2 - cols)
            z = float((i // cols) * 2 - cols)
            self.lib.spawn_object(i, type_id, x, z, 0.0)
            tx = float(((i + cols//2) % cols) * 2 - cols)
            tz = float(((i // cols + cols//2) % cols) * 2 - cols)
            self.lib.set_object_target(i, tx, tz, 5.0)

    def despawn_all(self, n):
        for i in range(n):
            self.lib.despawn_object(i)


def run_stress_test():
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║            ZIGON RENDERING STRESS TEST                     ║")
    print("╚══════════════════════════════════════════════════════════════╝")

    try:
        lib_path = find_lib()
    except FileNotFoundError as e:
        print(f"\n  ❌ {e}")
        print("  Build first: zig build")
        return

    tester = StressTester(lib_path)
    results = []

    print("\n── Test 1: Terrain-Only FPS (no entities) ──\n")
    for size in [64, 128, 256]:
        tester.init(size=size, seed=42)
        r = tester.measure_fps(300, f"Terrain {size}x{size}")
        if r:
            results.append(r)
        tester.close()

    print("\n── Test 2: Entity Scaling (128x128 terrain) ──\n")
    tester.init(size=128, seed=42)

    r = tester.measure_fps(300, "0 entities (baseline)")
    if r: results.append(r)

    for n in [100, 500, 1000, 2000, 5000]:
        tester.spawn_entities(n, type_id=0)
        r = tester.measure_fps(300, f"{n} static entities")
        if r: results.append(r)
        tester.despawn_all(n)

    tester.close()

    print("\n── Test 3: Moving Entities (update + render) ──\n")
    tester.init(size=128, seed=42)

    for n in [100, 500, 1000]:
        tester.spawn_moving_entities(n, type_id=0)
        r = tester.measure_fps(300, f"{n} moving entities")
        if r: results.append(r)
        tester.despawn_all(n)

    tester.close()

    print("\n── Test 4: Mixed Shape Types ──\n")
    tester.init(size=128, seed=42)

    for n in [200, 1000]:
        cols = int(math.sqrt(n)) + 1
        for i in range(n):
            shape = i % 5 
            x = float((i % cols) * 2 - cols)
            z = float((i // cols) * 2 - cols)
            tester.lib.spawn_custom_mesh(
                i, shape, x, 0.0, z,
                1.0, 1.0, 2.0,
                100 + (i*7)%155, 100 + (i*13)%155, 100 + (i*17)%155
            )
        r = tester.measure_fps(300, f"{n} mixed shapes")
        if r: results.append(r)
        tester.despawn_all(n)

    tester.close()

    print("\n" + "="*70)
    print("RESULTS SUMMARY")
    print("="*70)
    print(f"\n  {'Test':<35} {'FPS':>7} {'Avg ms':>8} {'P99 ms':>8}")
    print(f"  {'─'*35} {'─'*7} {'─'*8} {'─'*8}")
    for r in results:
        print(f"  {r['label']:<35} {r['avg_fps']:>7.1f} {r['avg_ms']:>8.2f} {r['p99_ms']:>8.2f}")

    with open("bench_render_results.json", "w") as f:
        json.dump(results, f, indent=2)
    print(f"\n  📄 Raw results: bench_render_results.json")


if __name__ == "__main__":
    run_stress_test()
