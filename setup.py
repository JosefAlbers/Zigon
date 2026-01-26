import os
import sys
import shutil
import subprocess
from setuptools import setup
from setuptools.command.build import build

class BuildZig(build):
    def run(self):
        build.run(self)
        subprocess.check_call([sys.executable, '-m', 'ziglang', 'build', '-Doptimize=ReleaseFast'])
        source_dir = os.path.abspath('zig-out')
        lib_dir = os.path.join(self.build_lib, 'zig-out')
        if os.path.exists(lib_dir):
            shutil.rmtree(lib_dir)
        shutil.copytree(source_dir, lib_dir)

setup(
    name="zigger",
    version="0.0.1a2",
    author="J Joe",
    author_email="albersj66@gmail.com",
    long_description=open('README.md', encoding='utf-8').read(),
    long_description_content_type="text/markdown",
    url="https://github.com/JosefAlbers/TerrainZigger",
    description="Terrain Zigger",
    py_modules=['main'],
    install_requires=['ziglang==0.13.0.post1', 'numpy', 'requests'],
    cmdclass={'build': BuildZig},
    data_files=[
        ('', ['build.zig', 'build.zig.zon', 'walk.zig', 'terrain.zig', 'object.zig', 'dungeon.zig', 'chat.zig', 'index.html']),
    ],
    entry_points={"console_scripts": ["tzg=main:demo"]},
    zip_safe=False,
)
