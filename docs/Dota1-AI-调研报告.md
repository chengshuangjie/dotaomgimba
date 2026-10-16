# GitHub Dota1 AI 代码调研报告

> 调研目的：为 Dota1 OMG AI 地图（魔兽争霸3 1.27 / vJASS / YDWE，OMGAI 库 27 模块）"取长补短"提供素材。
> 调研方法：全部仓库经 `git clone --depth 1` 浅克隆到本目录实测分析（GitHub REST API 当时限流，未依赖 API 元数据；规模为 `du -sh` 实测）。
> 标注规则：【已查证】= 实际打开过文件并核实；【仅推断】= 仅从目录结构/描述推测，未逐行核实。
> 下载位置：`/home/user/Doubao/chats/38447272451777282/dota1_ai_ref/<仓库名>/`（本次调研共下载 15 个仓库 + 2 个排除项归档）。

---

## 1. 调研结论速览

GitHub 上魔兽争霸3 Dota1 AI 代码的整体状况是：**可直接阅读的高质量 JASS AI 源码非常稀缺**，绝大多数相关仓库是"地图解包/反编译产物"——AI 逻辑真实存在但变量名被混淆压缩（如 `O5`、`m5`、`AH7`），只能作为"零件"拆用而非通读。真正值得深挖的重点仓库有三个梯队：**第一梯队是 CielAl/dota1_ai_legacy（与 mentalfoundry/DotA-v6.78c-AI-1.5a-Encore 为同一份 AI 核心代码，后者命名可读）**，含完整的英雄职业分类、分路、出装、gank、打钱、技能释放、防守 AI 体系，是"读代码学架构"的教材；**第二梯队是 rbm4/CAAS**，vJASS 原生语法、技能级自动施法引擎，与 OMG 随机技能模式天然对齐，是所有仓库中可移植性最高的一份；**第三梯队是 wrsuperboy/dotaai（vJASS 工程化构建链 + 随机选人）与 OPENXXAI/OpenWar3AI（外部 AI 决策框架，撤退/集火阈值设计可借鉴）**。其余多为混淆脚本（BEN-HUR5 6.88f、kapaez 6.84）、无 AI 地图（shin61、dota688）、空壳（OpenDotA-6.83d、DotA-Allstars-Project）或无关内容（wc3-jass-scripts、warcraft3-jass-ai）。注意：上述核心仓库几乎都**未声明许可证**，复制代码进自有系统前需自行评估合规风险（仅 OpenWar3AI 明确 Apache 2.0、shin61 GPLv3、OpenDotA GPLv2）。

---

## 2. 候选仓库全景表

| # | 仓库 | GitHub 地址 | 内容类型 | 规模(实测) | 语言 | AI 逻辑位置 | 许可证 | 质量评级 |
|---|---|---|---|---|---|---|---|---|
| 1 | CielAl/dota1_ai_legacy | https://github.com/CielAl/dota1_ai_legacy | 纯 JASS 源码（Dota AI 1.4e 反编译工程，6.77c/6.78c 双版本） | 128MB | 纯 JASS（含 1.24+ hashtable native，兼容 1.27/YDWE） | `Arrays.j` + `war3map.j`（145085 行）：选人/分路/gank/打钱/出装/技能/防守全模块 | 未声明 | **B** |
| 2 | mentalfoundry/DotA-v6.78c-AI-1.5a-Encore | https://github.com/mentalfoundry/DotA-v6.78c-AI-1.5a-Encore | w3x 解包（自带可读 `Scripts/war3map.j` + 加密 .w3x） | 16MB | 纯 JASS（plain，可读命名） | `Scripts/war3map.j`（145085 行/6437 函数） | 未声明 | **A** |
| 3 | BEN-HUR5/DotA_6.88f_AI | https://github.com/BEN-HUR5/DotA_6.88f_AI | w3x 解包 | 36MB | 纯 JASS（反编译混淆，单字母命名） | `Scripts/war3map.j`（135554 行） | 未声明 | **C** |
| 4 | kapaez/DotA_6.84_AI | https://github.com/kapaez/DotA_6.84_AI | w3x 解包（实际地图版本 6.89b） | 40MB | 纯 JASS（反编译混淆） | `Scripts/war3map.j`（126042 行） | 未声明 | **C** |
| 5 | wrsuperboy/dotaai | https://github.com/wrsuperboy/dotaai | WC3 Dota 地图 vJASS 工程化工程（非 Java） | 41MB | JASS·vJASS（clijasshelper + MPQEditor 构建链） | `src/main/jass/dota/dota.j`（93069 行；AiPickRD 可读，局内 AI 混淆） | 未声明 | **B** |
| 6 | rbm4/CAAS | https://github.com/rbm4/CAAS---Custom-Ai-Ability-System | 自定义技能自动释放 vJASS 库 | 488K | vJASS（library 语法） | `CustomAiAbilitySystem.j`（CastCustomAbilities 主调度 + 8 类 targetType） | 未声明 | **A-** |
| 7 | OPENXXAI/OpenWar3AI | https://github.com/OPENXXAI/OpenWar3AI | 外部注入 DLL + Python SDK 的 WC3 1.27 AI 运行时 | 27MB | Python + TS | `brains/xwar3/reflex/`（fightodds/battlecommit/mod_combat/itemuse） | Apache 2.0 | **B** |
| 8 | phamtheson01/DotA-Allstars | https://github.com/phamtheson01/DotA-Allstars | 解保护 Dota 6.88a 地图脚本导出 | 4.4MB | JASS（强混淆） | `war3map.j`（103K 行；无可读 AI） | 未声明 | **C** |
| 9 | konstantinB1/wc3-jass-scripts | https://github.com/konstantinB1/wc3-jass-scripts | 个人 JASS 脚本集合（实际仅 1 文件） | 200K | 纯 JASS | 无 AI（`src/spells/holy_damage.jass` 仅 AOE DoT 特效） | 未声明 | **D** |
| 10 | Zadroter274/warcraft3-jass-ai | https://github.com/Zadroter274/warcraft3-jass-ai | wc3 官方 `.ai` 方言 RTS 基地 AI | 200K | `.ai` 方言（非 JASS） | `battle2.ai`（BuildingsAI/ArmyAI/EconomyAI） | 未声明 | **D** |
| 11 | dota688/Dota-6.88 | https://github.com/dota688/Dota-6.88 | 空仓库（0 文件） | 120K | 无 | 无 | 无 | **D** |
| 12 | shin61/dota6.83 | https://github.com/shin61/dota6.83 | 实为《萌英雄》MoeHero 5v5 地图（名字误导） | 63MB | Lua（246 个）+ 极薄 JASS 引导 | 无 AI（war3map.j 仅 7KB 玩家初始化） | GPLv3 | **C** |
| 13 | ifshuaishuai/OpenDotA-6.83d | https://github.com/ifshuaishuai/OpenDotA-6.83d | 空壳（git 内仅 LICENSE+README，真图在 Release） | 224K | 无代码 | 无 | GPLv2 | **C** |
| 14 | anyushun/DotaAI | https://github.com/anyushun/DotaAI | 通关录像归档 + 1 份基准图 | 92MB | 无代码（112×.w3g + DotA_6.88_AI.w3x） | 无源码 | 未声明 | **D** |
| 15 | phamtheson01/DotA-Allstars-Project | https://github.com/phamtheson01/DotA-Allstars-Project | 空壳（README 80 字节） | 192K | 无 | 无 | 未声明 | **D** |

**已核查排除**（均有据，非候选）：alibaltschun/dotaai（Python 爬虫+ML 项目）、CrystalScepter/dota-archive（358 个 .w3x 归档 1.5GB 无源码）、n3k0lai/dota-legacy（49 个 .w3x 归档 213MB 无源码）、wangxiangyao/Dota-minus（实为 Dota2 TypeScript 模板）、puppert/dotaai（空仓库）、anyscoding/DotaAI（不可达）。另 SMUnlimited/AMAI（320★，经典 JASS 对战 AI，非 Dota）建议后续单挖。

---

## 3. 重点仓库详析

### 3.1 CielAl/dota1_ai_legacy —— JASS 源码金矿（⭐最值得深挖）

- **GitHub 地址**：https://github.com/CielAl/dota1_ai_legacy
- **仓库内容简介**：【已查证】Dota AI 1.4e 反编译工程，含两个完整版本：6.78c AI 1.4e（`war3map.j`，145085 行）与 6.77c AI 1.4c（`war3map.j.14c`）；另有独立 .j 文件 `AIfixSimple.j`（一次性施法防卡死）、`AatkTargetRecord.j`（攻击关系双向追踪池）、`SplitFindTarget.j`（AoE 技能目标筛选）、`Arrays.j`（AI 全局状态偏移字典）及 `Item Priority.txt`（物品评分表）。纯 JASS + 1.24+ hashtable native，与 wc3 1.27/YDWE 完全兼容。许可证未声明。
- **AI 功能清单与优缺点**（函数位置均【已查证】）：

| 功能 | 位置 | 优点 | 缺点/局限 |
|---|---|---|---|
| 英雄职业分类 | `war3map.j:4208` aiGetClass | 按 heroId 查表分类 Carry/Fighter/Tanker/Support/Nuker/Pusher，后续出装/gank/分路全部查表驱动 | 混淆变量名（udg_HeroID 尚可读，其余 O5/m5 混淆） |
| CM 选人/禁用 | `war3map.j:35454` AIHeroPicks / `35475` AIHeroBans | 完整的 CM 模式选人逻辑 | 与 dota 固定英雄表耦合 |
| 技能加点 | `war3map.j:73529` AILearnSkill | 逐英雄加点策略表 | 单字母混淆，难直接通读 |
| 分路平衡 | `war3map.j:81158` aiChooseLaneSent / `80869` Scourge | 我方/敌方三路人数差动态分路，逻辑清晰可读 | 依赖全局数组 aiDefInt[] 偏移语义 |
| gank 调度 | `war3map.j:102121` aiAutoGank / `82428` aiGank / `79793` aiGankPoint_Get | 四条件触发：战力差门槛（lv>11+hp>50% 加权）+ 落单判定（1200 码队友≤1）+ 可见 + 70% 随机命中 | 绕后点 h7[] 坐标为固定地图坐标 |
| 打野 | `war3map.j:84868` AIHeroJungle | 完整打野+睡眠唤醒流程 | 与地图野点坐标耦合 |
| 出装 | `war3map.j:76944` AIBuy_Core / `75080` aiBuy_SideShop + `Item Priority.txt` | 物品评分表（神符 101/核心大件 100/草鞋 99/TP 98…）直接可转 hashtable；含边路商店与信使 | 每英雄出装步骤数组内容未逐项核实（仅推断） |
| 技能释放 | `war3map.j:8100` AICastAbilityOnTarget/Point / `90190` AIHeroSpellEffect / `90059` AISpellToDodge | 施法+躲避双体系 | 几百个技能的特殊 case 占 war3map.j 膨胀主因（仅推断） |
| 防守 | `war3map.j:84196` aiDefTowerAttack / `80762` aiLaneTowerNeedHelp | 塔攻击/求援机制完整 | 同上混淆问题 |
| 接战/撤退 | `war3map.j:71847` aiEngage / `71940` aiCancelKill | 接战与"击杀取消"（避免送死）决策 | — |
| 防卡死补丁 | `AIfixSimple.j:1-12` AICasterFix | 一次性施法技能 ENDCAST 后删除技能（白名单复用施法者），**OMG 随机技能必加** | 白名单 abilityId 需替换为 OMG 技能表 |

- **可移植性评估**：纯 JASS（无 struct/method/library），仅用 1.24+ hashtable native——**1.27/YDWE 可直接编译**；逻辑本身可逐行翻译，但变量名混淆 + 与固定地图坐标深度耦合，状态存储需按 vJASS struct 重写。评级 B（框架思想成熟，需清洗）。

### 3.2 mentalfoundry/DotA-v6.78c-AI-1.5a-Encore —— 可读版教材（⭐同源但更好读）

- **GitHub 地址**：https://github.com/mentalfoundry/DotA-v6.78c-AI-1.5a-Encore
- **仓库内容简介**：【已查证】w3x 解包仓库，自带 `Scripts/war3map.j`（145085 行/6437 函数）。**关键事实：该 war3map.j 与 CielAl 仓库的 6.78c AI 1.4e 版逐字节相同（`diff` 实测）**，即 #1 与 #2 的 AI 核心是同一份代码；Encore 的 .w3x 本体是 MPQ 加密的，1.5a 补丁相对 1.4e 的实际差异未能核实【仅推断】。许可证未声明。
- **AI 功能清单与优缺点**（函数位置均【已查证】）：

| 功能 | 位置 | 优点 | 缺点/局限 |
|---|---|---|---|
| 职业分类 | `war3map.j:4208` aiGetClass | 同 CielAl，函数名可读 | — |
| 分路 | `war3map.j:81158` aiChooseLaneSent_t3v | **分路优先级链**：前期固定→中期按塔血量→后期抱团，三地图中最清晰的版本 | — |
| 出装 | `war3map.j:76944` AIBuy_Core | 出装状态机：ItemBuildStep + 边路商店 + 信使 | — |
| gank 发起 | `war3map.j:80122` aiGank_CheckBegin | gank 发起条件判定函数，模块边界清楚 | — |
| 撤退 | `war3map.j:9484` aiRetreat_J1 | 撤退决策独立成函数 | — |
| 连招 | `war3map.j:6655` ai_TimedCombo | **延迟连招框架**（按时间序列放技能组合） | — |
| 物品释放 | `war3map.j:8561` AIDagonFinish | 等级决定 Dagon 等级、血量阈值决定释放时机 | — |
| 难度 | `war3map.j:4195` AI_SetDefaultDifficulty | 难度→AI 行为参数入口 | — |

- **可移植性评估**：纯 JASS plain（无 vJASS 特征），1.27/YDWE 兼容；**唯一函数命名可读的 Dota AI 版本，适合"读代码学架构"**；搬进 vJASS 工程只需把全局数组（eY[]/g_aiItemInt[]）封装成 struct 字段或 hashtable。评级 A。

### 3.3 BEN-HUR5/DotA_6.88f_AI —— 混淆版，可拆零件

- **GitHub 地址**：https://github.com/BEN-HUR5/DotA_6.88f_AI
- **仓库内容简介**：【已查证】w3x 解包，`Scripts/war3map.j` 135554 行/5470 函数；反编译混淆为单字母命名（AH7/AJ7 类）。`[AI]` 聊天串、`PBMN|AI` gamecache key、`g_aiItemInt` 反射证明 AI 框架真实存在（PBMN AI 系后代）但核心决策（选人/出装/分路/gank）不可逐行阅读。许可证未声明。
- **AI 功能清单与优缺点**：

| 功能 | 位置 | 优点 | 缺点/局限 |
|---|---|---|---|
| 线性技能躲避 | `war3map.j:97331` AI_DodgeLineStarter | **向量投影判断是否在技能路径上→垂直位移躲开**，tick 由难度决定；独立可移植小模块 | 需自行解耦周边混淆代码 |
| 难度反应时间 | `N2F(GetAIDifficulty())` | 难度→反应时间/判定频率映射思路 | 混淆 |
| 技能数据表 | `War3map.w3a` | 完整技能数据表可参考 | 需编辑器工具读取 |

- **可移植性评估**：plain JASS，混淆严重，整体不可直接借鉴；`AI_DodgeLineStarter` 算法思路可手工移植（向量投影 + 垂直位移，纯数学逻辑无 native 依赖）。评级 C。

### 3.4 kapaez/DotA_6.84_AI —— 同源混淆版，附技能阈值模板

- **GitHub 地址**：https://github.com/kapaez/DotA_6.84_AI
- **仓库内容简介**：【已查证】w3x 解包，`Scripts/war3map.j` 126042 行/5296 函数；**实际地图版本为 6.89b（wts 确认），与仓库名 6.84 不符**。AI 框架与 6.88f 同源（PBMN 系），比 6.88f 多 AI5/AI6 两个分支。许可证未声明。
- **AI 功能清单与优缺点**：

| 功能 | 位置 | 优点 | 缺点/局限 |
|---|---|---|---|
| 技能释放阈值 | `war3map.j:21721` AI8 | **技能等级 > 目标等级-2 才释放**——OMG 技能释放阈值最小范例 | 单字母命名 |
| 线性躲避 | `war3map.j:90650` AI_DodgeLineStarter | 同 6.88f（PBMN AI 标准组件） | 同上 |
| 技能分支 | AI5(46892)/AI6(117068) | — | 混淆不可读 |

- **可移植性评估**：plain JASS，混淆严重；`AI8` 阈值判断（技能等级 vs 目标等级）可作 SkillProfile 释放阈值的最小模板。评级 C。

### 3.5 wrsuperboy/dotaai —— vJASS 工程化构建链

- **GitHub 地址**：https://github.com/wrsuperboy/dotaai
- **仓库内容简介**：【已查证】41MB/1348 文件，**不是 Java/Maven，是真·Dota AI 地图源码工程**。`build.bat → compile.bat` 把 `src/main/jass/dota/dota.j`（3.49MB/93069 行反编译脚本）经 `clijasshelper common.j blizzard.j` 编译成 war3map.j 再灌入 .w3x。README 自述"暂无AI、动态玩家数"，导入的是既有 AI 版底包。许可证未声明。
- **AI 功能清单与优缺点**：

| 功能 | 位置 | 优点 | 缺点/局限 |
|---|---|---|---|
| 随机选人 | `dota.j:26357` AiPickRD / `26338` AiPickRDDelay | 完整随机选人+延时去重定时器，**可读、可改造 OMG 随机英雄抽取** | — |
| 技能施法系统 | AIM3/AIP3 | 技能 AoE 施法系统（thunderbolt AoE + 哈希表定时器） | 非 AI 大脑，且混淆 |
| 工程化构建 | build.bat/compile.bat | **命令行 clijasshelper + MPQEditor 无 WE 打包链**——用户 vJASS 工程可直接套用 | — |
| 动态玩家数 | README 自述 | 玩家数自适应处理 | 未见对应可读代码（仅推断） |

- **可移植性评估**：vJASS 工程组织（src/main+jass / src/resources）与构建链价值最高（接近 A），局内 AI 逻辑因混淆不能直接抄。评级 B。

### 3.6 rbm4/CAAS — Custom AI Ability System（⭐与 OMG 天然对齐）

- **GitHub 地址**：https://github.com/rbm4/CAAS---Custom-Ai-Ability-System
- **仓库内容简介**：【已查证】488K，vJASS library 语法（YDWE/JassHelper 原生支持），CS 毕业设计。架构 = "技能表驱动 + 事件触发"的**技能级自动施法引擎**：`CustomAiAbilitySystem.j`（1324 行）+ 事件钩子（onAttack/onDamaged/onAcquiresTarget/onAttackOrder/onMoveOrder）+ `globasIds.j`（约 300 条 orderId 查表）。无英雄级决策（不出装/不打钱/不 gank）——正好补 OMG"随机技能怎么自动放"的需求。许可证未声明。
- **AI 功能清单与优缺点**：

| 功能 | 位置 | 优点 | 缺点/局限 |
|---|---|---|---|
| 技能注册表 | `CustomAiAbilitySystem.j` RegisterCustomAbility | **hashtable[abilityId][slot0..11] 存 targetType/range/orderId/isRandom/minMana%/minHp%/minEnemies/事件开关**——OMG 配表直接套 | 无可视化配表工具 |
| 施法主调度 | `CustomAiAbilitySystem.j:502-679` CastCustomAbilities | 三重守卫：单位级软冷却 timer + `GetUnitCurrentOrder` 白名单（防吟唱插队）+ 蓝%/血%/敌人数阈值 | 含 2 个 bug（见下） |
| 目标选择 | `:215-251` GetClosestUnitInGroup 等 | 一次 group 遍历同时算"最近单位"+"最近英雄"，`udg_preferHeroTargets` 集火英雄 → Dota 团战集火 | — |
| 施法分发 | 8 类 targetType→IssueOrder 链 | POINT/AREA/UNIT/NO_TARGET/UNIT_ALLY/SELF/尸体技，覆盖 OMG 全部技能形态 | — |
| orderId 查表 | `globasIds.j` | 约 300 条 orderId 整数↔命令字符串，OMG 自定义技能查 orderId 不用翻数据文件 | — |
| 防站桩 | onAttackOrder.j:21-29 | 放完技能 0.5s 后若单位 idle 补发原命令 | — |

- **⚠ 可移植性硬伤（已查证）**：① `BlzGetUnitAbilityCooldownRemaining`（行 121）与 `BlzGetEventDamageTarget`（onDamaged.j）是 **1.31+ native，1.27 不可用**，需替换为自维护冷却表；② `onMoveOrder.j:47` 两参调用单参函数，编译不过需修；③ SaveStringBJ 参数不一致 bug。
- **可移植性评估**：vJASS library 语法，与用户系统技术栈完全一致；替换 3 处兼容点、修 2 个 bug 后"技能注册表+施法守卫+目标选择+8 类分发"可直接搬。评级 A-。

### 3.7 OPENXXAI/OpenWar3AI —— 外部 AI 决策框架（参考 AMAI）

- **GitHub 地址**：https://github.com/OPENXXAI/OpenWar3AI
- **仓库内容简介**：【已查证】27MB/550 文件（413 个 py），Apache 2.0。外挂进程路线：外部注入 DLL + 共享内存，每 50ms 向外部 AI 推送全图状态、AI 发语义命令。`brains/xwar3/reflex/` 有完整战斗决策：fightodds.py（胜率叫撤）、battlecommit.py（撤退阈值，**注释明确参考 AMAI**）、mod_combat（集火）、itemuse（残血回城）。
- **AI 功能清单与优缺点**：

| 功能 | 位置 | 优点 | 缺点/局限 |
|---|---|---|---|
| 撤退时机 | battlecommit.py | "接触后 5~10 秒再判、明显劣势才整队撤"，避免抖动 | 阈值面向外部 AI 场景 |
| 力量比阈值 | battlecommit.py（FLEE_RATIO=4.0/COLLAPSE=3.0） | 可简化为 vJASS 血量×DPS 比 | — |
| 集火分层 | mod_combat.py | 集火/后排施法/残血读回城的行为分层清单 | — |

- **可移植性评估**：与"地图内 vJASS AI"是两条路线，**代码不能直接搬**；决策阈值与行为分层可作 vJASS AI 心跳的规则思想参考。评级 B。

### 3.8 phamtheson01/DotA-Allstars —— 混淆脚本对照物

- **GitHub 地址**：https://github.com/phamtheson01/DotA-Allstars
- **仓库内容简介**：【已查证】4.4MB，解保护 Dota 6.88a 地图脚本导出，`war3map.j` 103K 行/4820 函数，强混淆（integer001/unit001），依赖 `DotAAllstarsHelper688a.dll`。**无 AI**：grep "Bot" 67 处全是 BotSideShop/GoblinShop_Bot 等"下路商店"命名，"Computer" 0 命中。许可证未声明。
- **AI 功能清单与优缺点**：

| 功能 | 位置 | 优点 | 缺点/局限 |
|---|---|---|---|
| 区域坐标 | 商店/Roshan 矩形区域 | dota 地图关键区域坐标定义可对照 | 混淆 |
| 反 maphack | `war3map.j:4363-4376` MaphackDetected/GUAIDetection | 反作弊检测范式 | 与 AI 无关 |

- **可移植性评估**：强混淆 + DLL 依赖，AI 不可复用；区域坐标与反作弊范式可参考。评级 C。

---

## 4. 「可用于 OMG 仓库的部分」汇总（按 OMGAI 模块映射）

> 目标系统：用户自己的 vJASS OMG AI 地图（OMGAI 库 27 模块，含 SkillPool/SkillProfile/AI 心跳/PlayerSkillState/OMGAIConfig/Globals 等）。以下逐项列出可借鉴点，每条注明出处仓库与文件路径（均【已查证】）。

### 4.1 数据组织层

| 可借鉴点 | 出处（仓库:文件:位置） | 映射到 OMGAI 模块 | 说明 |
|---|---|---|---|
| eY[] 状态字典模式（LANE/FOUNTAIN/DEFEND/GANK/JUNGLE/ROSHAN 状态机偏移语义） | CielAl/dota1_ai_legacy `Arrays.j`；Encore `war3map.j` | **OMGAIConfig / Globals** 数据组织 | 用"偏移字典 + 常量语义"组织 AI 全局状态，替代散落全局变量；转 vJASS 时封装为 struct 字段 |
| 技能数值哈希表（CD/蓝耗/射程/AoE 按偏移 0/4/8/12 存整数） | CielAl `aiAbilities_InitSub` | **SkillProfile** 技能数值画像 | 同一"按偏移存整数"手法可做 OMG 技能数值表（hashtable） |
| 难度→反应时间/判定频率映射 | BEN-HUR5/DotA_6.88f_AI `N2F(GetAIDifficulty())` | **OMGAIConfig** 难度参数 | 难度不再是"调伤害"，而是调 AI 判定节拍 |

### 4.2 画像与决策层

| 可借鉴点 | 出处 | 映射到 OMGAI 模块 | 说明 |
|---|---|---|---|
| aiGetClass 英雄职业分类（按 heroId 查表 6 类） | CielAl/Encore `war3map.j:4208` | **SkillProfile** 画像 | OMG 按英雄模型（而非技能组合）分类，作为技能优先级/出装的画像输入 |
| 物品评分表（Item Priority.txt：神符101/大件100/草鞋99/TP98…） | CielAl `Item Priority.txt` | **SkillProfile / OMGAIConfig** 优先级表 | 直接转 hashtable 评分表；OMG 可推广为"技能评分表" |
| 技能释放阈值（技能等级 > 目标等级-2 才释放） | kapaez/DotA_6.84_AI `war3map.j:21721` AI8 | **SkillProfile** 释放阈值 | OMG 技能释放的最小判断模板 |
| 集火英雄偏好（udg_preferHeroTargets + 一次遍历同算最近单位/英雄） | rbm4/CAAS `CustomAiAbilitySystem.j:215-251` | **AI 心跳**施法目标选择 | Dota 团战集火模式的直接移植 |

### 4.3 施法与行为层（AI 心跳消费）

| 可借鉴点 | 出处 | 映射到 OMGAI 模块 | 说明 |
|---|---|---|---|
| 技能注册表 schema（abilityId→targetType/range/orderId/阈值/事件开关） | rbm4/CAAS `CustomAiAbilitySystem.j` RegisterCustomAbility | **SkillPool** 注册/配表 | OMG 随机技能池按同一 schema 登记，运行时 GetUnitAbilityLevel>0 自动适配随机技能 |
| 施法三重守卫（软冷却 timer + 当前命令白名单 + 蓝/血/敌人数阈值） | rbm4/CAAS `CustomAiAbilitySystem.j:502-679` | **AI 心跳**施法决策 | 防吟唱插队/防连发；替换 Blz native 为自维护冷却表 |
| 8 类 targetType→IssueOrder 分发链 | rbm4/CAAS | **SkillPool** 施法形态 | 覆盖 POINT/AREA/UNIT/NO_TARGET/UNIT_ALLY/SELF/尸体技 |
| 放完技能 0.5s 后 idle 补发原命令 | rbm4/CAAS `onAttackOrder.j:21-29` | **AI 心跳** | 防 AI 站桩 |
| 一次性施法技能 ENDCAST 删除补丁（防 AI 发呆） | CielAl `AIfixSimple.j:1-12` | **SkillPool** 技能生命周期 | OMG 随机技能必加；白名单替换为 OMG 技能 ID |
| 延迟连招框架 ai_TimedCombo | Encore `war3map.j:6655` | **AI 心跳** combo 编排 | 按时间序列编排技能组合，OMG 多技能英雄连招直接可用 |
| 血量阈值物品释放 AIDagonFinish | Encore `war3map.j:8561` | **AI 心跳**物品决策 | 物品释放时机模板 |

### 4.4 宏观调度层（AI 控制器骨架参考）

| 可借鉴点 | 出处 | 映射到 OMGAI 模块 | 说明 |
|---|---|---|---|
| aiAutoGank 四条件调度（战力差门槛+落单判定+可见+随机命中） | CielAl `war3map.j:102121` | **AI 心跳**事件消费 | gank 决策的最小完整范式；落单判定（1200 码队友≤1）可直接翻译 |
| aiBuy_Core 出装状态机（ItemBuildStep+边路商店+信使） | Encore `war3map.j:76944` | **AI 控制器**骨架 | 出装不是"买最贵"，而是状态机分步推进 |
| aiGank_CheckBegin / aiRetreat_J1 / aiChooseLaneSent_t3v 函数体系 | Encore `war3map.j:80122/9484/81158` | **AI 控制器**骨架参考 | 模块边界划分（发起/执行/撤退/分路各一函数）的样板 |
| 撤退时机与力量比阈值（FLEE_RATIO=4.0/COLLAPSE=3.0，参考 AMAI） | OPENXXAI/OpenWar3AI `brains/xwar3/reflex/battlecommit.py` | **AI 心跳**逃跑决策 | 简化为 vJASS 血量×DPS 比，避免撤退抖动 |
| 随机选人+延时去重定时器 AiPickRD | wrsuperboy/dotaai `dota.j:26357` | **SkillPool** 随机抽取 | OMG 随机英雄/随机技能抽取的改造模板 |

### 4.5 工程化层

| 可借鉴点 | 出处 | 映射到 OMGAI 模块 | 说明 |
|---|---|---|---|
| 命令行 clijasshelper + MPQEditor 无 WE 打包链 | wrsuperboy/dotaai `build.bat/compile.bat` | OMGAI 工程构建 | vJASS 工程可脱离 YDWE GUI 一键编译打包 |
| src/main+jass / src/resources 目录布局 | wrsuperboy/dotaai | OMGAI 工程组织 | 源码与资源分离的仓库结构 |

---

## 5. 已查证与推断的区分、下载位置

### 5.1 已查证（实际打开过文件，含行号核实）
- 全部 15 个仓库的克隆落地与 `du -sh` 实测规模、目录结构
- CielAl/Encore：war3map.j 145085 行、两仓库文件逐字节相同（diff 实测）、aiGetClass:4208 / AIBuy_Core:76944 / aiGank_CheckBegin:80122 / aiChooseLaneSent:81158 / AIDagonFinish:8561 / ai_TimedCombo:6655 / aiRetreat_J1:9484、AIfixSimple.j 全文、Arrays.j 状态语义、Item Priority.txt 评分表
- BEN-HUR5 6.88f：135554 行、AI_DodgeLineStarter:97331、[AI]/PBMN/g_aiItemInt 痕迹
- kapaez 6.84：126042 行、AI8:21721、AI_DodgeLineStarter:90650、实际版本 6.89b（wts）
- wrsuperboy/dotaai：93069 行、AiPickRD:26357/AiPickRDDelay:26338、build/compile.bat 内容
- rbm4/CAAS：CastCustomAbilities:502、Blz native 1.31+ 依赖（行 121 与 onDamaged.j）、onMoveOrder.j:47 bug、globasIds.j 存在
- OPENXXAI/OpenWar3AI：Apache 2.0、reflex 目录文件、battlecommit/fightodds 阈值
- 排除项：dota688 空仓库（ls-remote 空）、OpenDotA-6.83d 空壳（仅 LICENSE+README）、DotA-Allstars 无 AI（"Bot"=商店命名）、shin61 无 AI（关键词零命中）、各空壳/无关仓库
- 抽查复核：本报告引用的函数行号已由上级逐一 grep 复核一致

### 5.2 仅推断（未逐行核实，需自行验证）
- Encore 1.5a 相对 1.4e 的实际补丁 diff（.w3x 本体 MPB 加密未解包）
- CielAl 每英雄具体出装步骤数组内容、gank 绕后点 h7[] 坐标、数百个技能释放 special case
- wrsuperboy/dotaai 的"动态玩家数"实现、dota.j 源自某 Dota AI 版反编译
- shin61/dota6.83 的 Lua 内部 AI 实现细节（搜 AI 关键词零命中，但 246 个 lua 未逐一通读）
- SMUnlimited/AMAI 的 JASS 内容（仅据 topics 描述，未克隆）

### 5.3 下载位置与状态
- 全部下载至 `/home/user/Doubao/chats/38447272451777282/dota1_ai_ref/`，每仓库一个子目录（浅克隆 `--depth 1`，无历史）。
- 15 个候选/补充仓库：全部下载成功；其中 dota688/Dota-6.88 克隆成功但为空仓库、OpenDotA-6.83d 确认空壳（均如实保留）。
- 排除项 dota-archive（1.5GB）、dota-legacy（213MB）为无源码二进制归档，如需可删除。
- 无失败下载（本次 17 个仓库全部成功，无失败需标注的项）。

---

*报告生成：2026-10-15。配套文件：《对比清单.md》含全量对比表与低价值仓库说明；各仓库独立分析文档见交付列表。*

---

# 附录 A：仓库对比清单（全量）

# GitHub Dota1（魔兽争霸3）AI 仓库对比清单

> 用途：为 Dota1 OMG AI 地图（wc3 1.27 / vJASS / YDWE）"取长补短"提供借鉴素材。
> 方法：全部仓库经 `git clone --depth 1` 浅克隆到本目录实测分析（GitHub REST API 当时限流，未依赖 API 数据）；规模为 `du -sh` 实测值。
> 标注：【已查证】= 实际打开过文件；【仅推断】= 仅从目录结构/描述推测。
> 许可证提醒：绝大多数仓库**未声明许可证**，把代码复制进自己系统前需自行评估合规风险。

## 一、主对比表

| # | 仓库 | 内容类型 | 规模(实测) | 语言 | AI 逻辑位置 | 质量评级 | 许可证 | 下载状态 |
|---|---|---|---|---|---|---|---|---|
| 1 | CielAl/dota1_ai_legacy | 纯 JASS 源码（Dota AI 1.4e 反编译工程，6.77c/6.78c 两版本） | 128MB | 纯 JASS（含 1.24+ hashtable native，兼容 1.27/YDWE） | `Arrays.j` + `war3map.j`（选人/分路/gank/打钱/出装/技能/防守全有） | **B**（框架成熟，变量名混淆需清洗） | 未声明 | ✅ 成功 |
| 2 | mentalfoundry/DotA-v6.78c-AI-1.5a-Encore | w3x 解包（自带可读 `Scripts/war3map.j` + 加密 .w3x） | 16MB | 纯 JASS（plain，可读命名） | `Scripts/war3map.j`（145085 行/6437 函数：职业分类/分路/出装/Gank/撤退/连招全模块） | **A**（三地图中唯一可读版；⚠与 #1 是同一文件，见下方说明） | 未声明 | ✅ 成功 |
| 3 | BEN-HUR5/DotA_6.88f_AI | w3x 解包 | 36MB | 纯 JASS（反编译混淆，单字母命名） | `Scripts/war3map.j`（135554 行：AI_DodgeLineStarter 线性躲避可读，核心决策混淆不可读） | **C**（框架存在但不可读，个别模块可拆） | 未声明 | ✅ 成功 |
| 4 | kapaez/DotA_6.84_AI | w3x 解包（实际地图版本 6.89b，与仓库名不符） | 40MB | 纯 JASS（反编译混淆） | `Scripts/war3map.j`（126042 行：AI8 技能阈值、AI_DodgeLineStarter，混淆不可读） | **C**（同上） | 未声明 | ✅ 成功 |
| 5 | wrsuperboy/dotaai | WC3 Dota 地图 vJASS 工程化工程（非 Java！） | 41MB | JASS·vJASS（clijasshelper 编译 + MPQEditor 打包） | `src/main/jass/dota/dota.j`（3.49MB/93069 行；AiPickRD 选人可读，局内 AI 函数名混淆） | **B**（构建链价值高，脚本混淆难直接抄） | 未声明 | ✅ 成功 |
| 6 | rbm4/CAAS---Custom-Ai-Ability-System | wc3 自定义技能自动释放 vJASS 库 | 488K | vJASS（library 语法） | `CustomAiAbilitySystem.j`：`CastCustomAbilities` 主调度 + 8 类 targetType 目标选择 + 事件钩子 | **A-**（唯一真正"技能级 AI"，与 OMG 天然对齐；含 2 个 bug、Blz native 需替换） | 未声明 | ✅ 成功 |
| 7 | OPENXXAI/OpenWar3AI | 外部注入 DLL + Python SDK 的 WC3 1.27 AI 运行时 | 27MB | Python + TS | `brains/xwar3/reflex/`（fightodds.py 胜率、battlecommit.py 撤退阈值、mod_combat 集火、itemuse 回城，注释参考 AMAI） | **B**（路线不同，决策阈值设计可借鉴） | Apache 2.0 | ✅ 成功 |
| 8 | konstantinB1/wc3-jass-scripts | 个人 JASS 脚本集合（实际仅 1 个文件） | 200K | 纯 JASS | 无 AI（`src/spells/holy_damage.jass` 仅 AOE DoT 特效） | **D**（名不副实） | 未声明 | ✅ 成功 |
| 9 | Zadroter274/warcraft3-jass-ai | wc3 官方 `.ai` 方言 RTS 基地 AI | 200K | `.ai` 方言（非 JASS/vJASS，YDWE 编译不过） | `battle2.ai`（BuildingsAI/ArmyAI/EconomyAI/AttackAI） | **D**（业务是 RTS 对战，与 Dota 零交集） | 未声明 | ✅ 成功 |
| 10 | dota688/Dota-6.88 | **空仓库**（0 个文件） | 120K | 无 | 无 | **D**（无内容） | 无 | ✅ 克隆但为空 |
| 11 | shin61/dota6.83 | 实为《我的英雄不可能那么萌》MoeHero 5v5 地图（名字误导，非 Dota6.83） | 63MB | Lua（246 个）+ 极薄 JASS 引导（war3map.j 仅 7KB） | 无 AI（搜 AIDefend/AIFarm/lasthit 零命中，纯 PvP 图） | **C**（仅工程链参考） | GPLv3 | ✅ 成功 |
| 12 | ifshuaishuai/OpenDotA-6.83d | **空壳**（git 内仅 LICENSE+README 224K，真图在 Release） | 224K | 无代码 | 无 | **C**（README 的"反编译还原方法论"有参考价值） | GPLv2 | ✅ 已克隆确认空壳 |

### 补充发现（3 个）

| # | 仓库 | 内容类型 | 规模 | 语言 | AI 逻辑位置 | 评级 | 许可证 | 下载状态 |
|---|---|---|---|---|---|---|---|---|
| 13 | phamtheson01/DotA-Allstars | 解保护 Dota 6.88a 地图脚本导出 | 4.4MB | JASS（强混淆 integer001/unit001） | 无 AI（grep "Bot" 67 处全为下路商店命名，"Computer" 0 命中） | **C** | 未声明 | ✅ 成功 |
| 14 | anyushun/DotaAI | 中文"单挑 5 疯狂电脑"通关录像归档 + 1 份地图 | 92MB | 无代码（112×.w3g 录像 + DotA_6.88_AI.w3x） | 无源码 | **D**（价值在基准图与录像素材） | 未声明 | ✅ 成功 |
| 15 | phamtheson01/DotA-Allstars-Project | 空壳（README 80 字节） | 192K | 无 | 无 | **D** | 未声明 | ✅ 成功 |

### 已核查排除（均有据）

| 仓库 | 排除原因（已查证） |
|---|---|
| alibaltschun/dotaai | Python/Jupyter 爬虫+ML 项目（App/Crawler/hero/research），非 JASS |
| CrystalScepter/dota-archive | 358 个 .w3x 二进制归档（1.5GB），无源码 |
| n3k0lai/dota-legacy | 49 个 .w3x 归档（213MB），无源码 |
| wangxiangyao/Dota-minus | 实为 Dota2 ModDota TypeScript 模板，描述误导 |
| puppert/dotaai | 空仓库（ls-remote 空输出） |
| anyscoding/DotaAI | 不可达（疑似私有/已删） |
| SMUnlimited/AMAI | 320★ 的 JASS AI，但是对战 melee AI 而非 Dota（仅推断，未克隆；后续值得单挖） |

> 注：排除清单中 dota-archive（1.5GB）、dota-legacy（213MB）已下载到本目录用于核查，属无源码二进制归档，如不需要可删除。

## 二、重点仓库详析

### 1. CielAl/dota1_ai_legacy —— JASS 源码金矿 ⭐最值得深挖
【已查证】6.78c AI 1.4e（`war3map.j` 145085 行）与 6.77c AI 1.4c（`war3map.j.14c`）双版本；`AIfixSimple.j`/`AatkTargetRecord.j`/`SplitFindTarget.j`/`Arrays.j`/`Library/` 独立 .j 文件齐全。纯 JASS + 1.24+ hashtable native，与 1.27/YDWE 完全兼容；缺点是反编译变量名混淆（O5/m5/it/Bz），与 dota 固定地图坐标深度耦合，状态存储需按 vJASS struct 重写。

**可复用点（7 条，均已定位到文件:行号）：**
1. `Arrays.j` 的 eY[] 状态机布局（LANE/FOUNTAIN/DEFEND/GANK/JUNGLE/ROSHAN）→ vJASS AIState struct 骨架
2. `war3map.j:4208` `aiGetClass` 英雄职业分类表（Carry/Fighter/Tanker/Support/Nuker/Pusher，按 heroId 查表，OMG 可按英雄模型分类）
3. `Item Priority.txt` 物品评分表（神符 101/核心大件 100/草鞋 99/TP 98…）→ 直接转 hashtable
4. `AIfixSimple.j` 一次性施法技能 ENDCAST 删除补丁（**OMG 随机技能必加，防 AI 发呆**）
5. `AatkTargetRecord.j` hashtable 攻击关系池（谁在打我，4 秒过期）→ 逃跑决策
6. `war3map.j:102121` `aiAutoGank` 四条件：战力差门槛（lv>11+hp>50% 加权）+ 落单判定（1200 码队友≤1）+ 可见 + 70% 随机命中
7. `aiAbilities_InitSub` 技能数值哈希表（CD/蓝耗/射程/AoE 按偏移 0/4/8/12 存整数）

其他函数坐标：AIHeroPicks/35475（CM 选人）、73529 AILearnSkill（加点）、81158 分路平衡、84868 打野、76944 AIBuy_Core 出装、8100 AICastAbilityOnTarget/Point 技能释放、90190 AIHeroSpellEffect。

### 1b. w3x 地图三件套（#2 mentalfoundry / #3 BEN-HUR5 / #4 kapaez）
【已查证】三个都是 w3x 解包仓库，AI 均在 `Scripts/war3map.j`。**关键发现：Encore 仓库自带的 `Scripts/war3map.j`（145085 行）与 CielAl 仓库的 6.78c AI 1.4e 版逐字节相同**（`diff` 实测），即 #1 与 #2 的 AI 核心是同一份代码；Encore 的 .w3x 本体是 MPQ 加密的，1.5a 补丁相对 1.4e 的实际 diff 未能核实【仅推断】。所以读 AI 只需一份（#1 或 #2 任选），#2 的评级 A 即针对这份可读代码。

- **#2 Encore（A）**：函数命名可读、模块边界清晰——`war3map.j:4208` aiGetClass 职业分类、`81158` aiChooseLaneSent 分路优先级链（前期固定→中期按塔线→后期抱团）、`76944` AIBuy_Core 出装状态机（ItemBuildStep+边路商店+信使）、`80122` aiGank_CheckBegin gank 发起条件、`8561` AIDagonFinish 血量阈值物品释放、`6655` ai_TimedCombo 延迟连招框架。三地图中唯一能"读代码学思路"的。
- **#3 6.88f（C）**：135554 行，核心决策被混淆成 AH7/AJ7 单字母函数（[AI] 聊天串/PBMN gamecache key/g_aiItemInt 反射证明 AI 框架存在但不可读）。可拆零件：`97331` AI_DodgeLineStarter 线性技能躲避（向量投影判断是否在技能路径上→垂直位移躲开→tick 按难度）；N2F(GetAIDifficulty()) 难度→反应时间映射。
- **#4 6.84（C）**：126042 行，实际地图版本 6.89b（wts 确认）。可拆零件：`21721` AI8 技能等级>目标等级-2 才释放的阈值模板（OMG 技能释放阈值最小范例）；`90650` AI_DodgeLineStarter（同 6.88f，PBMN AI 标准组件）。
- **兼容性**：三者均为 plain JASS（无 struct/method/library），搬进 vJASS 工程只需把全局数组（eY[]/g_aiItemInt[]）封装成 struct 字段或 hashtable，逻辑本身可直接翻译【已查证：代码阅读结论】。

### 2. wrsuperboy/dotaai —— vJASS 工程化构建链
【已查证】41MB/1348 文件；`build.bat → compile.bat` 把 `src/main/jass/dota/dota.j`（3.49MB/93069 行反编译脚本）经 `clijasshelper common.j blizzard.j` 编译成 war3map.j 再灌入 .w3x。README 自述"暂无AI、动态玩家数"，导入的是既有 AI 版底包。
**可复用点：** ① src/main+jass / src/resources 目录布局；② 命令行 clijasshelper + MPQEditor 无 WE 打包链；③ `dota.j:26357` AiPickRD 随机选人+延时去重定时器（可改造 OMG 随机英雄）；④ 动态玩家数处理。
**关键片段：** `dota.j:26357`（AiPickRD 随机选人，可读）。

### 3. rbm4/CAAS — Custom AI Ability System —— 与 OMG 天然对齐 ⭐重点
【已查证】488K；vJASS library 语法（YDWE/JassHelper 原生支持）。架构 = "技能表驱动 + 事件触发"的**技能级施法引擎**，无英雄级决策（不出装/不打钱/不 gank）——正好补用户 OMG 系统"随机技能怎么自动放"的需求。
**可复用点（6 条）：**
1. `CustomAiAbilitySystem.j` 技能注册表 schema（hashtable[abilityId][slot0..11] 存 targetType/range/orderId/isRandom/minMana%/minHp%/minEnemies/事件开关）→ OMG 配表直接套
2. `CastCustomAbilities`（行 502-679）三重守卫：单位级软冷却 timer + `GetUnitCurrentOrder` 白名单（防吟唱插队）+ 蓝%/血%/敌人数阈值
3. 目标选择（行 215-251）：一次 group 遍历同时算"最近单位"和"最近英雄"，`udg_preferHeroTargets` 集火英雄 → Dota 团战集火
4. 8 类 targetType→IssueOrder 分发链（POINT/AREA/UNIT/NO_TARGET/UNIT_ALLY/SELF/尸体技）覆盖 OMG 全部技能形态
5. `globasIds.j` 约 300 条 orderId 整数↔命令字符串查表（O-M-G 自定义技能查 orderId 不用翻数据文件）
6. onAttackOrder/onMoveOrder 的"放完技能 0.5s 后若单位 idle 补发原命令"timer 模式（行 21-29），防 AI 站桩
**⚠ 兼容注意（已查证）：** 用了 `BlzGetUnitAbilityCooldownRemaining`（行 121）与 `BlzGetEventDamageTarget`（onDamaged.j），是 1.31+ native，**1.27 不可用必须替换**（自维护冷却表替代）；onMoveOrder.j:47 两参调单参函数（编译不过）需修。

### 4. OPENXXAI/OpenWar3AI —— 外部 AI 决策框架（参考 AMAI）
【已查证】Apache 2.0；外挂进程路线（每 50ms 共享内存推全图状态、外部 AI 发语义命令），与地图内 vJASS AI 是两条路，代码不能直接搬。
**可复用点：** ① "接触后 5~10 秒再判、明显劣势才整队撤"的撤退时机；② 力量比撤退阈值（FLEE_RATIO=4.0/COLLAPSE=3.0，可简化为 vJASS 血量×DPS 比）；③ 集火/后排施法/残血读回城的行为分层清单。注释明确参考 AMAI 撤退控制（battlecommit.py）。

### 5. shin61/dota6.83 —— 名不副实，仅工程链
【已查证】实为 actboy168/sumneko《萌英雄》MoeHero 5v5 地图（YDWE + w3x2lni + Lua），`map/war3map.j` 仅 7KB 玩家初始化，逻辑全在 Lua；搜 AI 关键词零命中。**无 Dota AI**。仅 w3x2lni 文本化地图+调试流、slk/txt 数据文本化组织可参考（语言栈 Lua 与 vJASS 不同）。

### 6. phamtheson01/DotA-Allstars —— 混淆脚本对照物
【已查证】真 103K 行 Dota 6.88a 脚本、4820 函数，但强混淆 + 依赖 DotAAllstarsHelper688a.dll；无可读 AI（"Bot" 实为下路商店命名）。可复用：商店/Roshan 矩形区域与坐标定义、反 maphack 检测范式（GUAIDetection/MaphackDetected，行 4363-4376）。

### 7. anyushun/DotaAI —— 基准图素材
【已查证】92MB：112 份人机通关录像（.w3g）+ `地图/DotA_6.88_AI.w3x`（8.1MB 基准图本体）。可做对照基准图与 AI 行为录像参考，无源码。

## 三、低价值/排除项一句话

- **wc3-jass-scripts**：仓库名"集合"实际仅 1 个 106 行技能特效文件，D。
- **warcraft3-jass-ai**：wc3 内置 AI 虚拟机的 `.ai` 方言（非 JASS），RTS 基地建造 AI，与 Dota1 OMG 零交集，D。
- **dota688/Dota-6.88**：空仓库（0 文件），D。
- **OpenDotA-6.83d**：空壳，方法论（拆触发段→重命名→美化 的清洗流程）可用来清洗 dota1_ai_legacy / dotaai 的混淆脚本，C。
- **DotA-Allstars-Project**：80 字节 README 空壳，D。

## 四、汇总建议（取长补短优先级）

| 优先级 | 仓库 | 取什么 |
|---|---|---|
| ★★★ | CielAl/dota1_ai_legacy（=Encore 同一份 AI 核心） | 状态机骨架 + 职业表 + 物品评分表 + gank 四条件 + 攻击关系池 + 防卡死补丁；读代码学架构用 Encore（命名可读），照抄改写成套用 #1（多 6.77c 版本与独立 .j） |
| ★★★ | rbm4/CAAS | 技能注册表 schema + 施法三重守卫 + 8 类 targetType 分发 + orderId 表（替换 Blz native、修 2 个 bug 后直接可用） |
| ★★ | BEN-HUR5/DotA_6.88f_AI + kapaez/DotA_6.84_AI | AI_DodgeLineStarter 线性技能躲避算法 + AI8 技能释放阈值模板（独立可移植小模块，混淆不影响取用） |
| ★★ | wrsuperboy/dotaai | clijasshelper 命令行构建链 + AiPickRD 随机选人（OMG 随机英雄改造） |
| ★★ | OPENXXAI/OpenWar3AI | 撤退阈值/集火分层决策框架（参考 AMAI 的规则思想，非代码） |
| ★ | DotA-Allstars / OpenDotA | 区域坐标 / 反作弊范式 / 混淆脚本清洗方法论 |
| — | 其余 | 无实际 AI 可借鉴 |

**下一步建议**：OpenWar3AI 反复引用的 **SMUnlimited/AMAI**（320★，经典 JASS 对战 AI，含撤退/兵力调度逻辑）值得单独挖掘一次——它是地图内 JASS AI 的另一重要参照系（虽非 Dota，但决策范式可移植）。

---

*文件生成：2026-10-15。全部 15 个仓库已浅克隆至本目录；排除项 dota-archive/dota-legacy 为二进制归档如需可删。*
