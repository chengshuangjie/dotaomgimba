# -*- coding: utf-8 -*-
import io, re

base = r'D:\dota\DOTA69AI\logs\base_v11.j'
omgai = r'D:\dota\DOTA69AI\logs\omgai_core_compiled.j'
outp = r'D:\dota\DOTA69AI\logs\merged_v6.j'

with io.open(base, 'r', encoding='utf-8', newline='') as f:
    txt = f.read()  # 基图 LF 换行

with io.open(omgai, 'r', encoding='utf-8', newline='') as f:
    omg = f.read()

# 1) 去掉 OMGAI 展开里的 stub main 块（含 5 个 ExecuteFunc）
lines = omg.split('\n')
out_lines = []
i = 0
stub_start = None
while i < len(lines):
    if lines[i].strip().startswith('// ===== stub main ==== ' ) or lines[i].strip() == '// ===== stub main =====':
        stub_start = i
        # 跳到 endfunction（含）
        j = i
        while j < len(lines):
            if lines[j].strip() == 'endfunction':
                break
            j += 1
        i = j + 1
        continue
    out_lines.append(lines[i])
    i += 1
omg_defs = '\n'.join(out_lines)
print('stub removed at line', stub_start, 'defs chars:', len(omg_defs))

# 2) 定位基图 main
main_re = re.search(r'function main takes nothing returns nothing', txt)
assert main_re, 'main not found'
main_idx = main_re.start()
# 找 main 后的第一个独立行 endfunction
after = txt[main_idx:].split('\n')
end_rel = None
for k, ln in enumerate(after):
    if ln.strip() == 'endfunction':
        end_rel = k
        break
assert end_rel is not None, 'main endfunction not found'
end_idx = main_idx + sum(len(x) + 1 for x in after[:end_rel])  # 含 \n
# 更精确：用 split 的行偏移
# 重新用更稳的方式：
txt_lines = txt.split('\n')
# main 所在行号
main_line = None
for k, ln in enumerate(txt_lines):
    if ln.strip().startswith('function main takes'):
        main_line = k
        break
assert main_line is not None
end_line = None
for k in range(main_line + 1, len(txt_lines)):
    if txt_lines[k].strip() == 'endfunction':
        end_line = k
        break
assert end_line is not None
print('base main at line', main_line + 1, 'endfunction at line', end_line + 1)

# 3) 组装
init_calls = [
    'call ExecuteFunc("jasshelper__initstructs98038640")',
    'call ExecuteFunc("OMGAIGameMode___OnInit")',
    'call ExecuteFunc("OMGAIStateCleaner_Init")',
    'call ExecuteFunc("OMGAISkillData___Init")',
    'call ExecuteFunc("OMGAIInit___OnInit")',
    'call OMGAISuperAIInit_OMGAI_InitAll()',
]
head = '\n'.join(txt_lines[:main_line])
body = '\n'.join(txt_lines[main_line:end_line])
tail = '\n'.join(txt_lines[end_line:])

merged = head + '\n\n' + omg_defs + '\n\n' + body + '\n' + '\n'.join(init_calls) + '\n' + tail

# 4) JR2 内注入 AddHero（仅电脑英雄）—— 基图统一英雄创建入口
jr2_marker = 'call RemoveUnit(mu_select_hero[GetPlayerId(p)])'
assert jr2_marker in merged, 'JR2 marker not found'
bridge_code = '''
    // ===== OMGAI Bridge: 注册 AI 英雄（仅电脑）=====
    if GetPlayerController(p) == MAP_CONTROL_COMPUTER then
        call OMGAISuperAIInit_OMGAI_AddHero(M7[GetPlayerId(p)])
    endif'''
merged = merged.replace(jr2_marker, jr2_marker + bridge_code)

with io.open(outp, 'w', encoding='utf-8', newline='') as f:
    f.write(merged)

report = 'merged chars: %d, base lines: %d, omg defs chars: %d\n' % (len(merged), len(txt_lines), len(omg_defs))
with io.open(r'D:\dota\DOTA69AI\logs\merge_report.txt', 'w', encoding='utf-8') as f:
    f.write(report)
print(report)
