# 注入最小实验：把 OMG AI 骨架注入 Dota 6.9 的 war3map.j 并重打包
# 步骤：1) 读 Dota69 src/war3map.j；2) 在 main 末尾插入 Init 调用；3) 追加注入代码；4) 写入输出

import io, re, os

SRC_J = r'D:\dota\DOTA69AI\src\war3map.j'
OUT_J = r'D:\dota\DOTA69AI\logs\injected.j'
SRC_MAP = r'D:\游戏\Warcraft III\Maps\download\Dota 6.9 AI OMG_B376_11.w3x'
OUT_MAP = r'D:\dota\DOTA69AI\output\Dota69-OMGAI-v0.1.w3x'
MPQEDIT = r'D:\dota\DOTAOMGAY\compiler\mpqeditorhhb\MPQEditor.exe'

INJECT = r'''
// ============ OMG AI INJECT (v0.1 test) START ============
// 最小验证：每 5 秒给所有电脑玩家发日志，证明注入链路可用
function OMGAI_Inject_Tick takes nothing returns nothing
    call BJDebugMsg("OMG AI INJECT ACTIVE")
endfunction

function OMGAI_Inject_Init takes nothing returns nothing
    local trigger t = CreateTrigger()
    call TriggerRegisterTimerEvent(t, 5.0, true)
    call TriggerAddAction(t, function OMGAI_Inject_Tick)
    set t = null
endfunction
// ============ OMG AI INJECT END ============
'''

# 读：newline='' 保留原文件换行符（\r\n 不被转换）
j = open(SRC_J, encoding='utf-8', errors='replace', newline='').read()
print('原 j 大小:', len(j))

# 找 main 函数定义位置
main_idx = j.find('\nfunction main takes')
if main_idx < 0:
    main_idx = j.find('function main takes')
if main_idx < 0:
    print('ERROR: 找不到 main')
    raise SystemExit(1)
# main 的 endfunction
end_idx = j.find('\nendfunction', main_idx)
if end_idx < 0:
    print('ERROR: 找不到 main 结尾')
    raise SystemExit(1)
# 注入块定义插在 main 之前（先定义后调用，避免 pjass 后向引用报错）
inject_def = INJECT + '\n'
new_j = j[:main_idx] + inject_def + j[main_idx:]

# 在 main 的 endfunction 前插入 Init 调用
insert_line = '\n    call OMGAI_Inject_Init()'
call_idx = new_j.find('\nendfunction', new_j.find('function main takes'))
if call_idx < 0:
    print('ERROR: 找不到 main 结尾(二次)')
    raise SystemExit(1)
new_j = new_j[:call_idx] + insert_line + new_j[call_idx:]

# 写入：newline='' 保留原文件的换行风格（避免把首行 CRLF 变 LF）
open(OUT_J, 'w', encoding='utf-8', newline='').write(new_j)
print('注入后 j 大小:', len(new_j))
print('写入:', OUT_J)

# 重打包：复制原图 + MPQEditor add 替换 war3map.j
import shutil
shutil.copy(SRC_MAP, OUT_MAP)
print('已复制原图 ->', OUT_MAP, os.path.getsize(OUT_MAP))
