# -*- coding: utf-8 -*-
import sys
sys.path.insert(0, r'D:\dota\DOTAOMGAY\scripts')
from mpyq import MPQArchive

for label, path in [
    ('OMG_v02', r'D:\百度网盘\网盘下载\Dota omg地图\魔兽1.27版本\Warcraft III Frozen Throne 1.27a publish\Warcraft III Frozen Throne 1.27a publish\Maps\OMG\Dota69-OMGAI-v0.2.w3x'),
    ('OUT_v02', r'D:\dota\DOTA69AI\output\Dota69-OMGAI-v0.2.w3x'),
    ('V01_bak', r'D:\百度网盘\网盘下载\Dota omg地图\魔兽1.27版本\Warcraft III Frozen Throne 1.27a publish\Warcraft III Frozen Throne 1.27a publish\Maps\FrozenThrone\Dota69-OMGAI-v0.1.w3x.bak'),
    ('BASE_bak', r'D:\游戏\Warcraft III\Maps\download\Dota 6.9 AI OMG_B376_11.w3x.bak'),
]:
    try:
        a = MPQArchive(path)
        data = a.read_file('war3map.j')
        print(f'{label}: war3map.j size = {len(data)} bytes')
    except Exception as e:
        print(f'{label}: ERROR {e}')
