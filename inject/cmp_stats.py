# -*- coding: utf-8 -*-
import io

def stats(path, label):
    with io.open(path, 'r', encoding='utf-8', errors='replace') as f:
        data = f.read()
    lines = data.split('\n')
    # 统计非 ASCII 字符比例
    non_ascii = sum(1 for ch in data if ord(ch) > 127)
    print(f'{label}:')
    print(f'  bytes={__import__("os").path.getsize(path)}')
    print(f'  chars={len(data)}')
    print(f'  lines={len(lines)}')
    print(f'  non_ascii_chars={non_ascii} ({100*non_ascii/len(data):.2f}%)')
    print()

stats(r'D:\dota\DOTA69AI\logs\cmp_base\war3map.j', 'BASE (基图原版)')
stats(r'D:\dota\DOTA69AI\logs\cmp_v01c\war3map.j', 'V01 (M2最小注入)')
stats(r'D:\dota\DOTA69AI\logs\cmp_v02c\war3map.j', 'V02 (M3 OMGAI注入)')
stats(r'D:\dota\DOTA69AI\logs\merged_war3map.j', 'MERGED (拼合中间产物)')
stats(r'D:\dota\DOTA69AI\logs\omgai_core_compiled.j', 'OMGAI_CORE_COMPILED')
stats(r'D:\dota\DOTA69AI\src\war3map.j', 'SRC (M1逆向提取)')
