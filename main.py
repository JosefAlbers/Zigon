#{{{ INIT
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
import platform
import math
import numpy as np
import subprocess
from typing import Callable, Optional, Tuple, List, Dict, Any
from hud import *
from sfx import SoundPlayer

#}}} INIT
#{{{ BRIDGE

def get_lib_path():
    system = platform.system()
    ext = {"Darwin": ".dylib", "Linux": ".so", "Windows": ".dll"}.get(system)
    if not ext:
        raise RuntimeError(f"Unsupported OS: {system}")
    lib_name = f"lib_walk{ext}"
    for path in [
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "zig-out", "lib", lib_name),
        os.path.join(os.getcwd(), "zig-out", "lib", lib_name),
        os.path.join(os.getcwd(), lib_name),
    ]:
        if os.path.exists(path):
            return path
    raise FileNotFoundError(f"Could not find {lib_name}")

class ZigBridge:
    def __init__(self):
        self.lib = ctypes.CDLL(get_lib_path())
        self.CALLBACK_TYPE = ctypes.CFUNCTYPE(None, ctypes.c_int, ctypes.c_int)
        self._setup_signatures()

    def _setup_signatures(self):
        L = self.lib
        L.init_state.argtypes = [ctypes.c_int, ctypes.c_uint64]
        L.close_state.argtypes = []
        L.start_loop.argtypes = []
        L.enable_high_dpi.argtypes = []
        L.set_phys_cfg.argtypes = [ctypes.c_float, ctypes.c_float]
        L.get_camera_transform.argtypes = [ctypes.POINTER(ctypes.c_float)] * 9 + [ctypes.POINTER(ctypes.c_int)]
        L.set_camera_transform.argtypes = [ctypes.c_float] * 9 + [ctypes.c_int]
        L.get_screen_size.argtypes = [ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int)]
        L.get_render_size.argtypes = [ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int)]
        L.render_frame.argtypes = []
        L.render_frame.restype = ctypes.c_bool
        L.set_mouse_cursor.argtypes = [ctypes.c_bool]
        L.enable_high_dpi.argtypes = []
        L.capture_frame.argtypes = [ctypes.c_char_p, ctypes.c_size_t]
        L.get_terrain_height.argtypes = [ctypes.c_float, ctypes.c_float]
        L.get_terrain_height.restype = ctypes.c_float
        L.load_map_data.argtypes = [ctypes.POINTER(ctypes.c_float), ctypes.c_size_t]
        L.set_map_cfg.argtypes = [ctypes.c_float, ctypes.c_float, ctypes.c_float, ctypes.c_uint64, ctypes.c_bool]
        L.set_fbm_cfg.argtypes = [ctypes.c_int, ctypes.c_float, ctypes.c_float, ctypes.c_float]
        L.set_world_offset.argtypes = [ctypes.c_float, ctypes.c_float]
        L.load_charm.argtypes = [ctypes.c_uint8, ctypes.c_char_p]
        L.set_charm_init.argtypes = [ctypes.c_uint8] + [ctypes.c_float] * 7
        L.set_charm_transform.argtypes = [ctypes.c_uint8] + [ctypes.c_float] * 9
        L.set_charm_visible.argtypes = [ctypes.c_uint8, ctypes.c_bool]
        L.unload_charm.argtypes = [ctypes.c_uint8]
        L.is_key_down.argtypes = [ctypes.c_int]
        L.is_key_down.restype = ctypes.c_bool
        L.is_mouse_button_down.argtypes = [ctypes.c_int]
        L.is_mouse_button_down.restype = ctypes.c_bool
        L.get_mouse_delta.argtypes = [ctypes.POINTER(ctypes.c_float), ctypes.POINTER(ctypes.c_float)]
        L.spawn_custom_mesh.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_float, ctypes.c_float, ctypes.c_float, ctypes.c_float, ctypes.c_float, ctypes.c_float, ctypes.c_int, ctypes.c_int, ctypes.c_int]
        L.spawn_object.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_float, ctypes.c_float, ctypes.c_float]
        L.set_object_rotation.argtypes = [ctypes.c_int, ctypes.c_float, ctypes.c_float, ctypes.c_float]
        L.spawn_object_by_name.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_float, ctypes.c_float, ctypes.c_float]
        L.despawn_object.argtypes = [ctypes.c_int]
        L.set_object_terrain_bound.argtypes = [ctypes.c_int, ctypes.c_bool]
        L.set_object_target.argtypes = [ctypes.c_int, ctypes.c_float, ctypes.c_float, ctypes.c_float]
        L.stop_object.argtypes = [ctypes.c_int]
        L.get_object_position.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_float), ctypes.POINTER(ctypes.c_float), ctypes.POINTER(ctypes.c_float)]
        L.get_object_position.restype = ctypes.c_bool
        L.set_object_position.argtypes = [ctypes.c_int, ctypes.c_float, ctypes.c_float, ctypes.c_float]
        L.set_object_state.argtypes = [ctypes.c_int, ctypes.c_float]
        L.register_hook.argtypes = [self.CALLBACK_TYPE]
        L.trigger_input_handler.argtypes = [ctypes.c_size_t]
        L.get_last_click_position.argtypes = [ctypes.POINTER(ctypes.c_float)] * 3
        L.get_last_click_position.restype = ctypes.c_bool
        L.get_selected_ids.argtypes = [ctypes.POINTER(ctypes.c_int), ctypes.c_size_t]
        L.get_selected_ids.restype = ctypes.c_int
        L.set_selected_ids.argtypes = [ctypes.POINTER(ctypes.c_int), ctypes.c_size_t]
        L.start_dialogue.argtypes = [ctypes.c_int]
        L.set_chat_portrait.argtypes = [ctypes.c_char_p]
        L.update_chat_text.argtypes = [ctypes.c_char_p]
        L.get_user_input.argtypes = [ctypes.c_char_p, ctypes.c_size_t]
        L.stop_dialogue.argtypes = []
        L.set_city_cfg.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_bool]
        L.set_dungeon_map.argtypes = [ctypes.c_uint64, ctypes.c_int, ctypes.c_int]
        L.set_dungeon_map.restype = None
        L.spawn_glb_model.argtypes = [
            ctypes.c_int,
            ctypes.c_char_p,
            ctypes.c_float,
            ctypes.c_float,
            ctypes.c_float,
            ctypes.c_float,
            ctypes.c_float,
            ctypes.c_float,
            ctypes.c_float,
            ctypes.c_float,
            ctypes.c_float,
            ctypes.c_float,
            ctypes.c_uint8,
            ctypes.c_uint8,
            ctypes.c_uint8,
        ]
        L.spawn_glb_model.restype = None
        L.update_object_model.argtypes = [ctypes.c_int, ctypes.c_char_p]
        L.update_object_model.restype = None
        setup_hud_ctypes_signatures(L)

#}}} BRIDGE

def demo():
    print('wip')
