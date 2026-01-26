# {{{ INIT
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

import os
import time
import platform
import ctypes
import sys
import math
import gzip
import requests
import numpy as np

def get_base_map(out_size, tile=None):
    if tile in ['gradient', 'sinusoid', 'pyramid']:
        x = np.linspace(-1, 1, out_size)
        y = np.linspace(-1, 1, out_size)
        xx, yy = np.meshgrid(x, y)
        if tile == 'gradient': return xx
        if tile == 'sinusoid': return np.sin(xx) * np.cos(yy)
        if tile == 'pyramid': return 1 - np.maximum(np.abs(xx), np.abs(yy))
    elif tile is None:
        tile = "N42W071"
    lat_band = tile[:3]
    url = f"https://s3.amazonaws.com/elevation-tiles-prod/skadi/{lat_band}/{tile}.hgt.gz"
    raw = gzip.decompress(requests.get(url).content)
    arr = np.frombuffer(raw, dtype=">i2")
    n = int(math.sqrt(arr.size))
    h = arr.reshape(n, n).astype(np.float32)
    h[h < -1000] = np.nan
    ys = np.linspace(0, n - 1, out_size)
    xs = np.linspace(0, n - 1, out_size)
    yi, xi = np.meshgrid(ys, xs, indexing='ij')
    coords = np.array([yi, xi])
    from scipy.ndimage import map_coordinates
    out = map_coordinates(h, coords, order=1, mode='nearest', cval=np.nan)
    mn = np.nanmin(out)
    mx = np.nanmax(out)
    return 0.4 + 0.3 * (out - mn) / (mx - mn)

# }}} INIT
# {{{ ZIG

class Zigger:
    def __init__(self, size=128, seed=142):
        system = platform.system()
        if system == "Darwin":
            lib_ext = ".dylib"
        elif system == "Linux":
            lib_ext = ".so"
        elif system == "Windows":
            lib_ext = ".dll"
        else:
            raise RuntimeError(f"Unsupported operating system: {system}")
        lib_name = f"lib_walk{lib_ext}"
        package_dir = os.path.dirname(os.path.abspath(__file__))
        lib_path = os.path.join(package_dir, "zig-out", "lib", lib_name)
        if not os.path.exists(lib_path):
            local_path = os.path.join(os.getcwd(), "zig-out", "lib", lib_name)
            if os.path.exists(local_path):
                lib_path = local_path
        try:
            self.lib = ctypes.CDLL(lib_path)
        except OSError as e:
            raise RuntimeError(f"Failed to load the library at {lib_path}: {e}")
        self.lib.init_state.argtypes = [ctypes.c_int, ctypes.c_int]
        self.lib.load_map_data.argtypes = [ctypes.POINTER(ctypes.c_float), ctypes.c_size_t]
        self.CALLBACK_TYPE = ctypes.CFUNCTYPE(None, ctypes.c_int, ctypes.c_int)
        self.lib.register_hook.argtypes = [self.CALLBACK_TYPE]
        self.lib.get_user_status.argtypes = [ctypes.POINTER(ctypes.c_float), ctypes.POINTER(ctypes.c_float), ctypes.POINTER(ctypes.c_float)]
        self.lib.get_user_status.restype = ctypes.c_bool
        self.lib.start_dialogue.argtypes = [ctypes.c_int]
        self.lib.set_chat_portrait.argtypes = [ctypes.c_char_p]
        self.lib.update_chat_text.argtypes = [ctypes.c_char_p]
        self.lib.get_user_input.argtypes = [ctypes.c_char_p, ctypes.c_size_t]
        self.lib.stop_dialogue.argtypes = []
        self.lib.get_last_click_position.argtypes = [ctypes.POINTER(ctypes.c_float), ctypes.POINTER(ctypes.c_float), ctypes.POINTER(ctypes.c_float)]
        self.lib.get_selected_count.argtypes = []
        self.lib.get_selected_count.restype = ctypes.c_int
        self.lib.get_selected_ids.argtypes = [ctypes.POINTER(ctypes.c_int), ctypes.c_size_t]
        self.lib.set_selected_ids.argtypes = [ctypes.POINTER(ctypes.c_int), ctypes.c_size_t]
        self.lib.spawn_object.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_float, ctypes.c_float, ctypes.c_float]
        self.lib.spawn_object_by_name.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_float, ctypes.c_float, ctypes.c_float]
        self.lib.despawn_object.argtypes = [ctypes.c_int]
        self.lib.get_object_position.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_float), ctypes.POINTER(ctypes.c_float), ctypes.POINTER(ctypes.c_float)]
        self.lib.get_object_position.restype = ctypes.c_bool
        self.lib.set_object_position.argtypes = [ctypes.c_int, ctypes.c_float, ctypes.c_float, ctypes.c_float]
        self.lib.set_object_target.argtypes = [ctypes.c_int, ctypes.c_float, ctypes.c_float, ctypes.c_float]
        self.lib.set_object_state.argtypes = [ctypes.c_int, ctypes.c_float]
        self.lib.stop_object.argtypes = [ctypes.c_int]
        self.lib.init_state(seed, size)
        self.size = size
        self.all_obj_ids = set()

    def start(self):
        self.lib.start_loop()
        self.lib.close_state()

    def load_map(self, numpy_array):
        if numpy_array.size != self.size * self.size:
            print(f"Error: Map must be {self.size}x{self.size}")
            return
        data = numpy_array.astype(np.float32)
        ptr = data.ctypes.data_as(ctypes.POINTER(ctypes.c_float))
        self.lib.load_map_data(ptr, data.size)

    def set_callback(self, python_func):
        self.c_callback = self.CALLBACK_TYPE(python_func)
        self.lib.register_hook(self.c_callback)

    def get_selection(self):
        count = self.lib.get_selected_count()
        if count == 0: return []
        buf_type = ctypes.c_int * count
        buf = buf_type()
        self.lib.get_selected_ids(buf, count)
        return list(buf)

    def set_selection(self, ids):
        if not ids:
            self.lib.set_selected_ids(None, 0)
            return
        ids = [int(i) for i in ids]
        count = len(ids)
        buf_type = ctypes.c_int * count
        buf = buf_type(*ids)
        self.lib.set_selected_ids(buf, count)

    def get_click_pos(self):
        x = ctypes.c_float()
        y = ctypes.c_float()
        z = ctypes.c_float()
        self.lib.get_last_click_position(ctypes.byref(x), ctypes.byref(y), ctypes.byref(z))
        return (x.value, z.value, y.value)

    def start_dialogue(self, npc_id):
        self.lib.start_dialogue(npc_id)

    def set_chat_portrait(self, path):
        b_path = path.encode('utf-8')
        self.lib.set_chat_portrait(b_path)

    def update_chat_text(self, text):
        b_text = text.encode('utf-8')
        self.lib.update_chat_text(b_text)

    def get_user_input(self):
        capacity = 1024
        buf = ctypes.create_string_buffer(capacity)
        self.lib.get_user_input(buf, capacity)
        return buf.value.decode('utf-8', errors='replace')

    def stop_dialogue(self):
        self.lib.stop_dialogue()

    def get_user_pos(self):
        x = ctypes.c_float()
        y = ctypes.c_float()
        z = ctypes.c_float()
        is_spawned = self.lib.get_user_status(ctypes.byref(x), ctypes.byref(y), ctypes.byref(z))
        if is_spawned:
            return (x.value, y.value, z.value)
        return None

    def get_obj_pos(self, obj_id):
        x = ctypes.c_float()
        z = ctypes.c_float()
        y = ctypes.c_float()
        if self.lib.get_object_position(obj_id, ctypes.byref(x), ctypes.byref(z), ctypes.byref(y)):
            return (x.value, z.value, y.value)
        return None

    def spawn(self, type_id, x, z, y_off=0.0, obj_id=None):
        if obj_id is not None:
            if obj_id in self.all_obj_ids:
                raise ValueError(f"Object ID {obj_id} already exists.")
        else:
            obj_id = max(self.all_obj_ids) + 1 if self.all_obj_ids else 0
        self.all_obj_ids.add(obj_id)
        if isinstance(type_id, str):
            self.lib.spawn_object_by_name(obj_id, type_id.encode('utf-8'), float(x), float(z), float(y_off))
        else:
            self.lib.spawn_object(obj_id, type_id, float(x), float(z), float(y_off))
        return obj_id

    def despawn(self, obj_id):
        if obj_id in self.all_obj_ids:
            self.lib.despawn_object(obj_id)
            self.all_obj_ids.remove(obj_id)

    def set_target(self, obj_id, x, z, speed):
        self.lib.set_object_target(obj_id, float(x), float(z), float(speed))

    def set_obj_pos(self, obj_id, x, z, y_off):
        self.lib.set_object_position(obj_id, float(x), float(z), float(y_off))

    def set_obj_state(self, obj_id, state_val):
        self.lib.set_object_state(obj_id, float(state_val))

# }}} ZIG
# {{{ OBJ

class Objects:
    registry = {}

    def __init__(self, engine, type_id, x, z, y=0, obj_id=None, duration=None, on_click=None):
        self.engine = engine
        self.obj_id = engine.spawn(type_id, x, z, y, obj_id)
        self.path = []
        self.path_idx = 0
        self.speed = 5.0
        self.loop = False
        self.expiry = time.time() + duration if duration else None
        self._on_click_callback = None
        self.state = {}
        if on_click:
            self.on_click(on_click)
        Objects.registry[self.obj_id] = self

    def on_click(self, func):
        self._on_click_callback = func
        return func

    def handle_click(self):
        if self._on_click_callback:
            self._on_click_callback(self)

    def set_path(self, waypoints, speed=5.0, loop=False):
        self.path = waypoints
        self.path_idx = 0
        self.speed = speed
        self.loop = loop
        self._move_to_next_waypoint()

    def _move_to_next_waypoint(self):
        if self.path and self.path_idx < len(self.path):
            x, z = self.path[self.path_idx][:2]
            self.engine.set_target(self.obj_id, x, z, self.speed)

    def update(self):
        if self.expiry and time.time() > self.expiry:
            self.despawn()
            return False
        if self.path:
            pos = self.engine.get_obj_pos(self.obj_id)
            if pos:
                tx, tz = self.path[self.path_idx][:2]
                if (tx - pos[0])**2 + (tz - pos[1])**2 < 0.5:
                    self.path_idx += 1
                    if self.path_idx >= len(self.path):
                        if self.loop:
                            self.path_idx = 0
                        else:
                            self.path = []
                    self._move_to_next_waypoint()
        if len(self.path) > 0:
            self.engine.set_obj_state(self.obj_id, 1.0)
        elif self.obj_id in self.engine.get_selection():
            self.engine.set_obj_state(self.obj_id, 0.5)
        else:
            self.engine.set_obj_state(self.obj_id, 0.0)
        return True

    def despawn(self):
        self.engine.despawn(self.obj_id)
        if self.obj_id in Objects.registry:
            del Objects.registry[self.obj_id]

    def get_pos(self):
        return self.engine.get_obj_pos(self.obj_id)

# }}} OBJ
# {{{ RUN

def demo(terrain_size=128):
    game = Zigger(size=terrain_size)
    # game.load_map(get_base_map(terrain_size, 'gradient')) #: mock
    game.load_map(get_base_map(terrain_size)) #: boston

    # 0. Raw
    game.spawn("House", 100, 100)

    # 1. Move
    for i in range(3):
        npc = Objects(game, "Human", 0 + i*2, 0)
        path = [(0 + i*2, 0, 0), (0 + i*2, 20, 0), (10 + i*2, 20, 0), (0 + i*2, 0, 0)]
        npc.set_path(path, speed=3.0, loop=True)

    bird = Objects(game, "Bird", 64, 64, 20)
    bird_path = []
    import math
    for i in range(36):
        angle = (i / 36) * 2 * math.pi
        x = 64 + math.cos(angle) * 40
        z = 64 + math.sin(angle) * 40
        bird_path.append((x, z, 20.0))
    bird.set_path(bird_path, speed=20.0, loop=True)

    # 2. Interact
    def handle_rain(obj):
        import random
        x, z, _ = obj.get_pos()
        print(f"Rock at ({x}, {z}) summons rain!")
        for _ in range(100):
            rx, rz, ry = x + random.uniform(-1,1), z + random.uniform(-1,1), 5 + random.uniform(-5,5)
            Objects(game, "Rain", rx, rz, ry, duration=2.0)

    rain_rock = Objects(game, "Rock", 80, 80, on_click=handle_rain)

    # 3. Chat
    chatter = Objects(game, "Human", 70, 60)

    @chatter.on_click
    def handle_chat(obj):
        game.set_selection([obj.obj_id])
        if 'dialogue' not in obj.state:
            # obj.state['dialogue'] = # → {{
            obj.state['dialogue'] = [dict(role='system', content='This is a role play chat. You play the role of a laconic oracle.')]
            # }}
            game.start_dialogue(obj.obj_id)
            game.set_chat_portrait("assets/example-adventure.gif")
            greet_str = "I am the Oracle. Speak."
            game.update_chat_text(greet_str)
            obj.state['dialogue'].append(dict(role='assistant', content=greet_str))
        else:
            text = game.get_user_input()
            obj.state['dialogue'].append(dict(role='user', content=text))
            if text.lower() in ["bye", "exit"]:
                game.stop_dialogue()
                obj.state.pop('dialogue', None)
                game.set_selection(None)
            else:
                # response = f'You said "{text}"? Interesting..' # → {{
                from rcrlm import load, infer
                import re
                m = load()
                # o = infer(text, **m, max_new_tokens=30, chat_template_kwargs=dict(enable_thinking=False)) # → {{
                o = infer(m['tokenizer'].apply_chat_template(obj.state['dialogue'], enable_thinking=False, add_generation_prompt=True)
, **m, max_new_tokens=10, use_chat_template=False)
                # }}
                # response = o['out_str'][0].split('<', 1)[0] # → {{
                response = re.split(r'(?<=.{20}[.?!<])\s*', o['out_str'][0])[0]
                # }}
                # }}
                game.update_chat_text(response)
                obj.state['dialogue'].append(dict(role='assistant', content=response))

    user_spawned = False
    last_user_pos = None

    def on_game_event(ev_key, ev_val):
        nonlocal user_spawned, last_user_pos
        import random
        if ev_key == 0:
            for oid in list(Objects.registry.keys()):
                Objects.registry[oid].update()
            pos = game.get_user_pos()
            if pos:
                if not user_spawned:
                    user_spawned = True
                    for _ in range(100):
                        rx, rz, ry = pos[0] + random.uniform(-1,1), pos[2] + random.uniform(-1,1), 10 + random.uniform(-10,10)
                        Objects(game, "Rain", rx, rz, ry, duration=5.0)
                last_user_pos = pos
            elif user_spawned:
                user_spawned = False
                if last_user_pos:
                    Objects(game, "Beam", last_user_pos[0], last_user_pos[2], 0, duration=3.0)
        elif ev_key == 2:
            current_selection = game.get_selection()
            game.set_selection(None)
            if len(current_selection) == 1:
                oid = current_selection[0]
                if oid in Objects.registry:
                    Objects.registry[oid].handle_click()
            elif current_selection:
                target_x, target_z, _ = game.get_click_pos()
                for oid in current_selection:
                    if oid in Objects.registry:
                        Objects.registry[oid].set_path([(target_x, target_z)])

    game.set_callback(on_game_event)
    game.start()

if __name__ == "__main__":
    demo(128)

# }}} RUN
