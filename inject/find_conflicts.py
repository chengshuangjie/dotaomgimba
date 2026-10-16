# -*- coding: utf-8 -*-
import io, re, json

base = r'D:\dota\DOTA69AI\src\war3map.j'
omgai = r'D:\dota\DOTA69AI\logs\omgai_core_compiled.j'

with io.open(base, 'r', encoding='utf-8', newline='') as f:
    bt = f.read()
with io.open(omgai, 'r', encoding='utf-8', newline='') as f:
    ot = f.read()

# 基图函数名：function NAME takes ...
base_funcs = set(re.findall(r'function\s+([A-Za-z0-9_]+)\s+takes', bt))

# OMGAI 局部变量：local TYPE NAME (= 或 行尾)
omg_locals = set()
for m in re.finditer(r'local\s+([A-Za-z0-9_\.]+(?:\s*\[[^\]]*\])?)\s+([A-Za-z0-9_]+)\s*(?:=|$)', ot, re.M):
    omg_locals.add(m.group(2))

# OMGAI 参数：function NAME takes ... returns -> 提取 takes 后的参数段
omg_params = set()
for m in re.finditer(r'function\s+[A-Za-z0-9_]+\s+takes\s+(.*?)\s+returns\s+\w+', ot, re.S):
    sig = m.group(1)
    for seg in sig.split(','):
        seg = seg.strip()
        if not seg:
            continue
        parts = seg.split()
        if len(parts) >= 2:
            omg_params.add(parts[-1].strip())

conflict = base_funcs & (omg_locals | omg_params)
report = {
    'base_func_count': len(base_funcs),
    'omg_local_count': len(omg_locals),
    'omg_param_count': len(omg_params),
    'conflicts': sorted(conflict),
    'conflict_funcs': sorted(conflict & base_funcs)[:20],
}
with io.open(r'D:\dota\DOTA69AI\logs\symbol_conflict.json', 'w', encoding='utf-8') as f:
    json.dump(report, f, ensure_ascii=False, indent=2)
print('base funcs:', len(base_funcs), '| omg locals:', len(omg_locals), '| params:', len(omg_params))
print('conflicts:', sorted(conflict))
