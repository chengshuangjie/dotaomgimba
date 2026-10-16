# -*- coding: utf-8 -*-
import os, re, io

dirp = r'D:\dota\DOTAOMGAY\scripts\Map\OMGAI'
inc = os.path.join(dirp, '_include')

def read_text(p):
    data = open(p, 'rb').read()
    # 尝试 UTF-8 严格
    try:
        return data.decode('utf-8')
    except UnicodeDecodeError:
        pass
    # 尝试 GBK
    try:
        return data.decode('gbk')
    except UnicodeDecodeError:
        # 尝试 latin-1 兜底（不破坏字节）
        return data.decode('latin-1')

parts = []
missing = []
for line in open(inc, encoding='utf-8', errors='replace'):
    m = re.match(r'^\s*#include\s+"([^"]+)"', line)
    if m:
        f = m.group(1)
        p = os.path.join(dirp, f)
        if os.path.exists(p):
            parts.append('// ===== %s =====' % f)
            parts.append(read_text(p))
        else:
            missing.append(f)

# OMGAIInit.j
initp = os.path.join(dirp, 'OMGAIInit.j')
if os.path.exists(initp):
    parts.append('\n// ===== OMGAIInit.j =====')
    parts.append(read_text(initp))

out = '\r\n'.join(parts)
outp = r'D:\dota\DOTA69AI\logs\omgai_all_src.j'
with io.open(outp, 'w', encoding='utf-8', newline='') as f:
    f.write(out)

report = 'chars: %d\nfiles joined, missing: %s\n' % (len(out), missing)
with io.open(r'D:\dota\DOTA69AI\logs\omgai_join_report.txt', 'w', encoding='utf-8') as f:
    f.write(report)
print('done', len(out), missing)
