# Dota OMG Imba — 竞赛级 AI 战术层

基于 **Dota 6.9 AI OMG（11版本）** 基图 + **OMGAI 战术层** 的 OMG 模式地图改造项目。

目标：让电脑 AI 达到竞赛选手级水平——4+2 技能自选与理解、流派定位（物理/法师/肉）、开雾/插眼/反眼、秒人、蹲守针对核心英雄、团战站位、稳定性优先 + 日志可查 + KK 平台部署。

## 项目结构

```
dotaomgimba/
├─ omgai/    # OMGAI 战术层源码（vJASS，12+ 模块）
│            #   Core/Log/Guard/Dispatcher/ActionMask/SpellCast/TargetSel
│            #   Behaviors/EnemyState/Learn/Strategy + 配置与平台适配
├─ inject/   # 注入/拼合/打包脚本（Python）
│            #   inject_omgai.py  = 基图 war3map.j + OMGAI 展开 → merged.j
│            #   join_omgai*.py   = OMGAI 多文件编译拼合
│            #   mpq_patch*.py    = MPQ 重打包
└─ docs/     # PRD / 技术方案 / 调研报告 / 里程碑记录
```

## 注入原理

1. OMGAI 多文件 vJASS 源码 → `clijasshelper` 展开编译为扁平 JASS（`omgai_core_compiled.j`）
2. `inject_omgai.py`：把展开产物拼入基图 `war3map.j`（OMGAI 定义插在 main 前）
3. main 末尾追加 5 个库初始化 `ExecuteFunc` + `OMGAI_InitAll()` 启动调度器
4. 基图统一英雄创建函数 `JR2` 内注入 `OMGAI_AddHero`（仅电脑英雄）→ 战术层接管
5. MPQEditor 重打包 `war3map.j` → 部署地图

## 关键里程碑

| 版本 | 内容 | 状态 |
|---|---|---|
| v0.1 | 最小注入验证（OMG AI INJECT ACTIVE） | ✅ 进图 |
| v0.2/v0.3 | OMGAI 注入（ExecuteFunc 函数名错误） | ❌ 创建游戏弹回 |
| v0.4 | 修复 ExecuteFunc 调用名 | ✅ 进图 |
| v0.5 | + JR2 英雄注册（电脑 AI 战术层接管） | ✅ 待实测 |

## 说明

- 基图与地图产物（`.w3x` 二进制）不入库，本地保留于 `D:\dota\DOTA69AI\`
- 本地路径、注册表/杀软排除等环境脚本不入库
