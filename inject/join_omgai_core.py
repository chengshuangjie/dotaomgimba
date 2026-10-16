# -*- coding: utf-8 -*-
import os, re, io

dirp = r'D:\dota\DOTAOMGAY\scripts\Map\OMGAI'
inc = os.path.join(dirp, '_include')

CUT = {'OMGAI_GameFlow.j', 'OMGAI_RespinUI.j', 'OMGAI_SkillSelectUI.j', 'OMGAI_RespManager.j'}

def read_text(p):
    data = open(p, 'rb').read()
    try:
        return data.decode('utf-8')
    except UnicodeDecodeError:
        pass
    try:
        return data.decode('gbk')
    except UnicodeDecodeError:
        return data.decode('latin-1')

# pjass 不支持前向引用：UnitAlive/B2S 内联替换（YDWE stub 会因 library 展开放最后导致前向引用）
def inline_unit_alive(t):
    # UnitAlive(ident) -> (not IsUnitType(ident, UNIT_TYPE_DEAD) and GetWidgetLife(ident) > 0.405)
    return re.sub(r'UnitAlive\(([a-zA-Z_][a-zA-Z0-9_]*(?:\s*[+\-*/]\s*[a-zA-Z0-9_]+)*)\)',
                  r'(not IsUnitType(\1, UNIT_TYPE_DEAD) and GetWidgetLife(\1) > 0.405)', t)

def inline_b2s(t):
    # 去掉 B2S 日志（Init 行）
    t = re.sub(r'\+ " commercial=" \+ B2S\([^)]*\)', '+ ""', t)
    t = re.sub(r'\+ B2S\([^)]*\) \+', '+ "" +', t)
    t = re.sub(r'B2S\([^)]*\)', '"?"', t)
    return t

# 基图函数名 10512 个（mD/me/mE 等混淆短名）；OMGAI 局部变量/参数与基图函数名冲突仅 'me'
def rename_conflict(t):
    return re.sub(r'\bme\b', 'meOAI', t)

parts = []
cut_list = []
missing = []
for line in open(inc, encoding='utf-8', errors='replace'):
    m = re.match(r'^\s*#include\s+"([^"]+)"', line)
    if m:
        f = m.group(1)
        if f in CUT:
            cut_list.append(f)
            continue
        p = os.path.join(dirp, f)
        if os.path.exists(p):
            txt = read_text(p)
            txt = inline_unit_alive(txt)
            txt = inline_b2s(txt)
            txt = rename_conflict(txt)
            parts.append('// ===== %s =====' % f)
            parts.append(txt)
        else:
            missing.append(f)

initp = os.path.join(dirp, 'OMGAIInit.j')
if os.path.exists(initp):
    parts.append('\n// ===== OMGAIInit.j =====')
    parts.append(read_text(initp))

parts.append('\n// ===== stub main =====\nfunction main takes nothing returns nothing\nendfunction')

out = '\r\n'.join(parts)
outp = r'D:\dota\DOTA69AI\logs\omgai_core_src.j'
with io.open(outp, 'w', encoding='utf-8', newline='') as f:
    f.write(out)

report = 'chars: %d\ncut: %s\nmissing: %s\n' % (len(out), cut_list, missing)
with io.open(r'D:\dota\DOTA69AI\logs\omgai_core_report.txt', 'w', encoding='utf-8') as f:
    f.write(report)
print('done', len(out), 'cut:', cut_list)
