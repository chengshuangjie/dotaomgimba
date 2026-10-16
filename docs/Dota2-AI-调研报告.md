# GitHub Dota2 AI 代码调研报告（Dota1 OMG AI 地图借鉴版）

> **调研目的**：为 Dota1 OMG AI 地图（魔兽争霸3 1.27 / vJASS / YDWE，OMGAI 库工程，27 个模块：SkillPool / SkillProfile / PlayerSkillState / EventDispatcher / TimerService 等）"取长补短"提供素材——借鉴的是 Dota2 AI 的**决策逻辑、算法与框架设计思想**，不是搬运 Lua 代码。
> **调研方法**：全部候选仓库经 `git clone --depth 1` 浅克隆到本地实测（规模为 `du -sh` 实测、活跃度为 `git log -1 --format=%ci` 实测）；GitHub REST API 当时对当前 IP 限流，星数按任务给定值标注、未独立核实。
> **标注规则**：【已查证】= 实际打开文件并核实（带文件:行号 / 函数名）；【仅推断】= 仅从目录结构 / README / 文件名推测，未逐行核实。
> **下载位置**：`/home/user/Doubao/chats/38447272451777282/dota2ai_ref/<仓库名>/`（浅克隆目录共 15 个，含 LastOrder-Dota2 / dota2bot-OpenHyperAI / Dota2_Bots 三个在"额外发现"批次中重复落地的目录；去重后 12 个不同仓库；JimLambda 仓库 404 未落地，详见附录 B）。

---

## 一、调研结论速览

GitHub 上 Dota2 AI 代码整体分两大阵营：**Valve 官方 Bot Lua API 脚本阵营**（每个行为实现 `GetDesire()`+`Think()`，引擎按 desire 高低抢占控制权，本质是"扁平行为树/模式竞选"范式）与**外部强化学习框架阵营**（游戏进程 ↔ HTTP/protobuf ↔ 外部 Python 推理进程）。前者是本次调研的主体，也是 OMG AI 最直接可借鉴的范式；后者（LastOrder、pydota2、OpenAI Five 教学版）价值在架构思想与特征工程，不在代码。

**第一梯队（A 级，最值得深挖）有三家**：forest0xia/dota2bot-OpenHyperAI（Patch 7.41a、TypeScript→Lua、2026-04 仍活跃，含 5 维位置权重表、敌方战力加权评分、弱英雄帽+指数惩罚曲线、眼位时间窗状态机，`docs/ARCHITECTURE.md` 文档质量全场最佳）；LookinGood/SmartScript-AI-Dota-2-bots（271 文件、2026-08 仍维护，14 个 mode 行为节点 + 2973 行工具函数库，是 mode/desire 范式的成熟样本）；adam3q/dota2ai（100+ 英雄、约 7.9 万行 Lua，覆盖选人→分路→对线→gank→推塔→眼位→出装全链路，团队推线欲望加权打分与 gank 双向评分是全场最完整的团队协作算法）。

**第二梯队（B 级，局部算法可借鉴）**：bilibili/LastOrder-Dota2（PPO 影魔 solo，但"硬规则状态机包内层评分/RL""动作掩码""从伤害事件反演敌方 CD/等级"三个思想对 OMG 极有价值）；chrismcg61/OpenAI-Lite-Dota（上下文 bandit：SCO/NBS/MIS 三元组 + 延迟评估 + miss 重置，是 SkillProfile 自学习的现成范本）；OurGroupProjects/OurDotaBot（显式 5 状态 FSM + Last-hit EHP 估算 + AOE 命中数阈值）；pydota2/pydota2_archive（动作参数抽象、特征三分法、OODA 分层 policy 设计）。

**关键认知——代码不可移植**：几乎所有 Lua bot 都重度依赖 Valve Bot API（`BOT_MODE_*` / `GetNearbyHeroes` / `FindAoELocation` / `GetEstimatedDamageToTarget` 等沙箱接口），Lua 代码本身无法搬到 vJASS；**可迁移的是"决策思路"**——每行为自报 desire 竞选、英雄/技能权重表、加权求和评分、上下文自学习、状态机兜底这五类骨架。

**许可证合规提示**：adam3q 与 Nostrademous/Dota2-FullOverwrite 为 **GPL v3**（强传染，不能把其代码直接抄进 vJASS 工程，只能学思想）；OpenHyperAI 与 LastOrder 为 **MIT**（宽松）；**多数仓库（SmartScript、OpenAI-Lite-Dota、OurDotaBot、Dota2_Bots、lightbringer、phamstered 等）未声明许可证**——默认保留全部权利，同样只能借鉴思想、不能复制代码。星数极低但代码成熟的 SmartScript（约 3 star）提示：星数与代码质量在这个小众领域完全脱钩。

---

## 二、候选仓库全景表

| # | 仓库名 | GitHub 地址 | 内容类型 | 规模（实测） | 语言 | 许可证 | 质量评级 |
|---|---|---|---|---|---|---|---|
| 1 | adam3q/dota2ai | https://github.com/adam3q/dota2ai | 增强版 Valve Bot Lua 脚本（100+ 英雄，可直接实战） | 13 MB / 297 Lua / ~78.8k 行 | Lua | GPL v3 | **A** |
| 2 | forest0xia/dota2bot-OpenHyperAI | https://github.com/forest0xia/dota2bot-OpenHyperAI | 完整 5v5 bot 脚本集（TS→Lua，Patch 7.41a） | 9.5 MB / 13.7k 行 TS 源 + 278 个 Lua | TypeScript→Lua | MIT | **A** |
| 3 | LookinGood/SmartScript-AI-Dota-2-bots | https://github.com/LookinGood/SmartScript-AI-Dota-2-bots | Lua mode 行为树框架（~120 英雄） | 3.4 MB / 271 文件 | Lua | 未声明 | **A** |
| 4 | bilibili/LastOrder-Dota2 | https://github.com/bilibili/LastOrder-Dota2 | Python PPO 强化学习影魔中路 1v1 solo bot（脚本状态机+RL 混合） | 64 MB / ~10k 行手写 Python | Python + Lua 胶水 | MIT | **B** |
| 5 | pydota2/pydota2_archive | https://github.com/pydota2/pydota2_archive | 外部 Python RL 框架（pysc2→Dota2 移植，WIP） | 46 MB | Python + Lua | Apache-2.0 | **B** |
| 6 | chrismcg61/OpenAI-Lite-Dota | https://github.com/chrismcg61/OpenAI-Lite-Dota | Lua bot + 上下文自学习（类 contextual bandit） | 464 KB / 26 个 Lua | Lua | 未声明 | **B** |
| 7 | OurGroupProjects/OurDotaBot | https://github.com/OurGroupProjects/OurDotaBot | Lua 显式 5 状态 FSM bot（单英雄影魔） | 20 MB（含 replay）/ 代码仅 ~844 行 | Lua | 未声明 | **B** |
| 8 | lightbringer/dota2ai | https://github.com/lightbringer/dota2ai | 学术研究框架：Lua 代理 Mod + Java 进程外 bot 骨架，示例 bot 为玩具 | 660 KB / 16 Java + 6 Lua / ~3.0k 行 | Java + Lua | 未声明 | **C** |
| 9 | furiouspuppy/Dota2_Bots | https://github.com/furiouspuppy/Dota2_Bots | 2017 年 Valve 7.00 bot API 早期实验性 Lua 脚本（Meepo/Puck 专用） | 4.1 MB / 161 文件 / 6.8k 行 | Lua | 未声明 | **C** |
| 10 | llSourcell/OpenAI_Five_vs_Dota2_Explained | https://github.com/llSourcell/OpenAI_Five_vs_Dota2_Explained | PPO 教学代码（**非 Dota2**，MuJoCo 环境） | 968 KB / 7 个 py / 655 行 | Python | MIT | **C** |
| 11 | Nostrademous/Dota2-FullOverwrite | https://github.com/Nostrademous/Dota2-FullOverwrite | Lua 全量 bot 重写框架（已死） | 1.5 MB | Lua | GPL-3.0 | **C** |
| 12 | phamstered/Dota2AI_Bot_Scripts | https://github.com/phamstered/Dota2AI_Bot_Scripts | 单文件 Lua desire 片段（仅神符模块，68 行） | 192 KB / 1 文件 | Lua | 未声明 | **D** |
| 13 | JimLambda/dota2_already_existed_bot_script | https://github.com/JimLambda/dota2_already_existed_bot_script | **404 已删除（仓库不可达）** | N/A | Lua(?) | N/A | **D（不可达）** |

> 注：LastOrder-Dota2、dota2bot-OpenHyperAI、Dota2_Bots 三家在第二批"额外发现"批次中被重复发现并重复克隆（目录重复落地），本表已去重，每仓只列一行。

---

## 三、重点仓库详析

### 3.1 adam3q/dota2ai（Ranked Matchmaking AI）—— 全链路最完整的社区 bot 分支（A）

- **GitHub 地址**：https://github.com/adam3q/dota2ai （README 中另指向 adamqqqplay/dota2ai，同一项目）
- **内容简介**【已查证】：基于 Valve 官方 Bot Lua API 的"增强版人机脚本"，100+ 英雄可直接替换官方 bot 行为。实测 13 MB、297 个 .lua 约 78,827 行；许可证 **GPL v3**；最近提交 2024-05-23。结构：根目录平铺 ~110 个 `ability_item_usage_<hero>.lua`、~40 个 `bot_<hero>.lua`、`mode_*_generic.lua`（行为模式 desire 函数）、`hero_selection.lua`、`team_desires.lua`，`util/` 19 个工具模块（最大 `AbilityAbstraction.lua` 3538 行、`RoleUtility.lua` 1941 行），`hero/items/<hero>.lua` 固定出装序列。

**AI 功能优缺点逐项**（位置均【已查证】）：

| 功能 | 位置（文件:行号 / 函数名） | 优点 | 缺点 / 局限 |
|---|---|---|---|
| 行为模式 Desire 优先级框架 | `mode_farm_generic.lua:22 GetDesire()`、`mode_team_roam_generic.lua:257 GetTeamRoamDesire()`、`mode_ward_generic.lua:48 GetDesire()`、`mode_push_tower_mid_generic.lua:8` | Valve Bot API 标准"模式抢占"范式：每行为自报 desire∈[0,1]，引擎选最高者执行；可直接映射为 OMGAI 行为优先级调度 | 强依赖 Valve `BOT_MODE_*` 常量与 `bot:GetActiveMode()` 状态机，vJASS 需自行重建调度器 |
| 阵容/分路选人（按位置池补位） | `hero_selection.lua:1007 GetPositionedHero()`、`:1028 GetPositionCounts()`、`:951 PickRightHero()`、`:439-557` 位置池、`:1152 GetLanesTable()`、`:1263 APLaneAssignment()` | 英雄按 1~5 号位硬编码进 5 个池，选人时"随机挑一个未被占的位置"再从该池选英雄，保证阵容不重位 | 纯静态名单，无克制/协同评分；`PickRightHero` 拒绝采样池空时会死循环（作者注释了更稳的固定顺序版 `:1018`） |
| 角色画像表（meta-role tagging） | `util/RoleUtility.lua:1543 IsCarry()` / `:1548 IsDisabler` / `:1558 HasEscape` / `:1563 IsInitiator` / `:1573 IsNuker` / `:1578 IsSupport` / `:1583 IsPusher`；底层 `X.hero_roles[hero][role]` 数值表 | 每英雄打一组"职责标签+权重"，下游所有决策都查这张表——**SkillProfile 画像表的直接范本** | 手填静态表，无自动生成；`CountValue`（:1848）是空壳 TODO |
| 团队推线欲望打分（lane desire scoring） | `team_desires.lua:1 GetCommonPushLaneDesires()`、`:124 UpdatePushLaneDesires()` | 核心亮点：基线 0.20，12 分钟后随时间线性加；团队装按 `造价/time` 加权；死友军按复活时间扣分、死敌人 +0.1；再按每条线双方距离/经济差/塔血量/兵营破损逐项加减，最后归一化 [0,0.8]——典型加权求和评分函数 | 大量魔法数字；`GetEnemyTeam`（:286）用"法力回复/血量回复异常"区分真英雄与幻象，很 hack |
| 真英雄 vs 幻象识别 | `team_desires.lua:342 GetRealHero()`、`:286 GetEnemyTeam()` | 利用"幻象不继承属性带来的回复量"机制，比较同名英雄 `GetManaRegen()/GetHealthRegen()` 反推本体；对 OMG 大量幻象系技能有参考价值 | 依赖 Dota2 具体回复公式，迁移只能借"属性/回复量指纹区分本体与镜像"思路 |
| Gank/游走编排（状态机+双向评分） | `mode_team_roam_generic.lua:279 ConsiderTeamRoam()`、`:314 GetAllyFactor()`、`:375 GetEnemyFactor()`、`:445 FindTarget()`、`:517 TeamRoamThink()` | 带召集点的两阶段状态机：筛可参与队友（`StateFactor*0.7+distFactor*0.3`，:371），对候选目标打分（预估 5 秒总伤害/目标血量×0.7 + 距离因子×0.3，:433-434）选最高；队友到齐开雾，按最后看见位置追踪，目标丢失>5s 重算或解散——**本仓库最完整的团队协作算法** | 当前版本 `GetDesire()` 在 :37 直接 `return 0`，这套 gank 系统在 master 分支已被作者关闭（代码保留不启用） |
| 对线补刀（last-hit） | `mode_farm_generic.lua:151 Think()`（:160-167 用 `GetEstimatedDamageToTarget >= target:GetHealth()` 判断，`t = 2.0*attackPoint + dist/moveSpeed`） | 用"预估伤害≥目标当前血量"且计入攻击前摇+移动时间，比"血量低于阈值"精确 | 依赖 Valve `GetEstimatedDamageToTarget` API，vJASS 需自己估算 |
| 打野/堆野状态机 | `mode_farm_generic.lua:9-13 FARM_STATE_*`、`:196-238 Think()`（`util/CampUtility.lua`） | 拆成 TRAVELLING→NEAR→FARMING→STACKING 显式状态机；每分钟到 stack 时间中断当前攻击去走堆叠点 | 与 CampUtility 耦合紧，距离常量（800/200/400）硬编码 |
| 眼位/视野决策 | `mode_ward_generic.lua:48 GetDesire()`、`:356 IsSuitableToWard()`、`:390 IsEnemyCloserToWardLoc()`、点位表 `:30-42`、`util/WardUtility.lua` | 出门前先查"最近 3 秒是否有敌人比我离眼位更近"（避免送眼）；按距离把 desire 线性映射；支持人类 ping 响应 | 眼位坐标写死 Vector 表，不可配置；大量实验代码被注释 |
| 技能释放优先级链（每英雄 Consider） | `ability_item_usage_lion.lua:104 Consider[1]`（示例）、公共框架 `ability_item_usage_generic.lua:29 RefreshBuildingHealth`、`:43 ConsiderGlyph` | 每技能一个 `Consider[n]()` 返回 `(desire, target, type)`，按链判断：①打断引导（:131）→②击杀确认（:138-163）→③自我保护→④撤退反打（:180）→⑤AoE 找命中≥2 落点（:196）/≥3 兵线（:232）→⑥对线消耗→⑦推/防守塔 | 每英雄一份模板代码（~110 份）维护成本高；阈值全是经验值；AoE 落点依赖 Valve API |
| 出装决策 | `hero/items/lina.lua:7 X.ItemsToBuy`、`util/ItemPurchaseSystem.lua`（781 行）、`item_purchase_generic.lua:13` | 静态优先级队列：按顺序攒钱买，ItemPurchaseSystem 负责大件拆组件按序买；简单可靠 | 无局势自适应（不出针对性装），全靠手填序列 |
| 技能加点/天赋树 | `ability_item_usage_lion.lua:24 AbilityToLevelUp`（24 槽数组）、执行器 `ability_item_usage_generic.lua:119 ExecuteAbilityLevelUp` | 加点顺序编码成一张表，含天赋分支回调与"加点点错容错计数"（:131-136） | 每英雄一份手填表 |
| Glyph/买活/信使/团队装联动 | `ability_item_usage_generic.lua:43 ConsiderGlyph()`、`util/lib/Buyback`、`util/CourierSystem.lua`、`util/TeamItemThink.lua` | 记塔血量滑动窗口（0.5s/1s/1.5s/2s 前）判断"正在被强拆"从而交 Glyph | 仍偏启发式 |
| 战斗/工具库 | `util/AbilityAbstraction.lua`（3538 行：函数式 Map/Filter、`EveryManySeconds` 节流、单位查询 DSL）、`utility.lua:297 GetWeakestUnit` | 函数式集合操作 + 单位查询 DSL，被所有英雄文件复用 | 文件巨大、注释少，阅读门槛高 |

**可迁移算法清单**：

| 借鉴点 | 出处（文件/函数） | 映射到 OMG 模块 |
|---|---|---|
| 行为模式 desire 抢占调度（每行为自报 0~1，最高者执行） | `mode_farm_generic.lua:22 GetDesire`、`mode_team_roam_generic.lua:257`、`mode_ward_generic.lua:48` | **EventDispatcher**：每个 OMGAI 行为注册 `OnThink()` 返回 desire，调度器每 tick 选 max |
| 英雄职责标签表（carry/support/initiator/nuker/escape） | `util/RoleUtility.lua:1543 IsCarry` 等 | **SkillProfile**：给每个 OMG 技能组合打标签（爆发/控制/治疗/逃生/推塔） |
| 团队推线欲望加权打分（基线+时间+团队装+人员经济+塔/兵营血量，归一化） | `team_desires.lua:1 GetCommonPushLaneDesires`、`:124 UpdatePushLaneDesires` | **PlayerSkillState / 全局决策**：决定"全员推哪路/打 Roshan/回家"时用同构加权求和 |
| 双向 gank 评分（队友可达性×状态分；目标可击杀=预估5秒伤害/血量×0.7+距离×0.3） | `mode_team_roam_generic.lua:314 GetAllyFactor`、`:375 GetEnemyFactor`、`:445 FindTarget` | **团战目标选择 + AI 单位行为控制**：遍历敌方算 `Σ可造成伤害/其血量` 取最高 |
| Gank 两阶段状态机（Assemble→开雾→Roaming→丢失5s重算/解散） | `mode_team_roam_generic.lua:517 TeamRoamThink` | **EventDispatcher 状态机 + TimerService**：枚举 ASSEMBLE/ROAMING/RETREAT，超时判断走计时器 |
| 补刀判断：预估伤害 vs 目标血量，计入前摇+飞行时间 | `mode_farm_generic.lua:160-167` | **AI 单位行为控制（攻击执行层）**：vJASS 用攻击力-护甲估算，等前摇到了再下令 |
| 打野状态机，分钟点 stack | `mode_farm_generic.lua:9-13, 196-238` | **TimerService**：计时器在 :55 秒触发"走出去 stack"事件 |
| 技能释放优先级链：打断引导>击杀确认>自保>撤退反打>AoE命中数≥N>对线消耗>推塔 | `ability_item_usage_lion.lua:104-257 Consider[1]` | **SkillProfile / PlayerSkillState**：每个 OMG 技能注册一组 Consider 规则按同链评估 |
| 静态出装优先级队列 + 组件分解 | `hero/items/lina.lua:7`、`util/ItemPurchaseSystem.lua` | **技能/装备决策表**："技能学习顺序表"和"道具购买顺序表"同构，做成一维队列 |
| 真英雄 vs 幻象指纹识别（回复量异常） | `team_desires.lua:342 GetRealHero` | **团战目标选择**：借"用属性派生数值反推本体"思路（公式换成魔兽的） |
| 眼位"敌人比我近就不插"安全检查 | `mode_ward_generic.lua:390 IsEnemyCloserToWardLoc` | **AI 单位行为控制**：进入危险位置放技能/插眼前先做最近敌人距离检查 |

---

### 3.2 forest0xia/dota2bot-OpenHyperAI（OHA）—— 最现代、文档最佳的完整 5v5 bot（A）

- **GitHub 地址**：https://github.com/forest0xia/dota2bot-OpenHyperAI
- **内容简介**【已查证】：目前最完整的 Dota2 自定义 bot 脚本集（Patch 7.41a）。**TypeScript 源码 → TypeScriptToLua 编译为 Lua**（`tsconfig-tstl.json`），运行时 278 个 Lua 文件，可读源码在 `typescript/bots/`（31 个 .ts 约 13.7k 行）。实测 9.5 MB；`bots/ability_item_usage_generic.lua` 单文件 8429 行、`hero_selection.lua` 1122 行、`item_purchase_generic.lua` 1298 行、`FunLib/aba_matchups.ts` 2870 行。许可证 **MIT**；最近提交 2026-04-02，非常活跃。`docs/ARCHITECTURE.md` 分 13 节，文档质量三仓最高。

**AI 功能优缺点逐项**（位置均【已查证】）：

| 功能 | 位置（文件:行号 / 函数名） | 优点 | 缺点 / 局限 |
|---|---|---|---|
| 位置/角色权重表（5 维向量） | `typescript/bots/FunLib/aba_hero_pos_weights.ts:7-135 HeroPositions`，每英雄 `[pos1..pos5]` 五个 0-100 权重 | **OMG 最该抄的一张表**：不是二元 role 标签而是连续权重（影魔 `[45,80,5,0,0]`、斧王 `[30,5,80,5,0]`、CM `[0,5,10,30,55]`）；选人/分路都靠它打分 | 手工填写，版本更新需人工调；但结构可直接复用 |
| 多约束选池 + 弱英雄帽 | `bots/hero_selection.lua:178 GetPositionedPool()`、弱英雄表 `:117-139 WeakHeroes`、`DEFAULT_WEAK_HERO_CAP = 1`（:82）、惩罚曲线 `DEFAULT_WEAK_PENALTY = {type="exp", base=0.6}`（:89） | 选人不是随机：(a) 按 position 权重过阈值（`ROLE_WEIGHT_THRESHOLD = 50`、`ROLE_LIST_TOP_K_LIMIT = 35`）；(b) 限制每队 Durable/Disabler/Healer 数量；(c) 弱英雄每队最多 1 个、按指数曲线惩罚 | 规则多但都是 Lua 表格，可翻译为 vJASS 字典 |
| 敌方位置/等级反演（加权评分） | `typescript/bots/FunLib/enemy_role_estimation.ts:60-62`（`NET_WORTH_WEIGHT=0.3 / OFFENSIVE_POWER_WEIGHT=0.3 / LEVEL_WEIGHT=0.4`）、`GetHeroOffensivePower()` `:103-134`、`NormalizeSores()` `:159-177` | **不看对手选了谁，只看经济/属性/等级把 5 个敌方英雄排座次**，决定优先集火谁；`ItemOffensiveness` 表 `:10-45` 给每件攻击装打 0-150 分（圣剑 150、Daedalus 88、黯灭 60） | 0.3/0.3/0.4 是拍脑袋权重，但框架可直接搬 |
| role 判定谓词组合 | `typescript/bots/FunLib/aba_role.ts:51-68`（`CanBeOfflaner = IsInitiator && IsDurable` 等）、`GetPositionForCM()` `:279-332` | 用"谓词与"组合判断适合哪条路，比硬编码 role 字段灵活 | 谓词库 `aba_hero_roles_map.ts` 仍是人工标注 |
| 兵线补刀/反补判定 | `bots/mode_laning_generic.lua:138-158 GetBestLastHitCreep()`、`:160-173 GetBestDenyCreep()`（用 `J.WillKillTarget` 预测） | **预判"我这刀下去能不能杀"**，`dmgDelta = attackDamage * 0.7`（:139）预留前摇误差；反补阈值 `GetHP(creep) < 0.49`（:164） | 依赖 Valve bot API 的 `WillKillTarget` |
| 分模式 GetDesire() 评分竞选 | `mode_laning_generic.lua:32`、`mode_assemble_generic.lua:15`、`mode_roshan_generic.lua`、`mode_push_tower_*`、`mode_defend_tower_*`、`mode_retreat_generic.lua` | **Valve bot API 的"行为树"替代品**：每帧每 mode 自报意愿，最高者胜，比硬状态机更软、更可叠加 | 依赖 Valve bot API；OMG 需自己实现 desire 竞选器 |
| 眼位点表（按时间/塔状态分层） | `typescript/bots/FunLib/aba_site.ts:7-74`、`GetMandatorySpot()` `:163-180`、`GetWardSpotWhenTowerFall()` `:181-190`、`GetAggressiveSpot()` `:191-196` | **眼位随时间/塔状态动态切换**：2 分钟前只插河道眼，12 分钟后加一塔野区眼，哪座塔掉了推哪个眼位 | 坐标硬编码 Dota2 地图，OMG 地图要重画点位 |
| 对位/synergy 数据表 | `typescript/bots/FunLib/aba_matchups.ts`（2870 行）、`FretBots/matchups_data.lua`（14876 行 Dotabuff 风格对位优势分） | 选英雄时直接查"我选 X 对敌方已选 Y 是不是 counter" | 数据大但结构简单；OMG 可建"技能 A 克制技能 B"小表 |
| 按 position×射程出装模板 | `typescript/bots/FunLib/advanced_item_strategy.ts:25-46 STARTING_ITEMS[position][melee/ranged]`、`:52-58 BOOTS_BY_POSITION`、`:61-148+ ITEMS_BY_POSITION` | **"position × 近战/远程"二维出装矩阵**，比单英雄 build 表更泛化 | 仍是手工表 |
| invis 敌方存在性全局推断 | `typescript/bots/FunLib/aba_role.ts:104-135 UpdateInvisEnemyStatus()` | 扫敌方英雄是否带隐身技能/道具，全局置 `invisEnemyExist`，影响带粉/真视决策 | 思路简单但实用 |
| TP 防守/刷钱喊话协议 | `typescript/bots/FunLib/aba_role.ts:226-231 ShouldTpToDefend()`、`:249-252 ShouldTpToFarm()` | bot 之间用聊天字符串做隐式通信，触发集体决策 | 字符串协议脆弱 |
| 中立装备按 role×近战远程加权分配 | `docs/ARCHITECTURE.md` 第 6 节（`FretBots/SettingsNeutralItemTable.lua`，`GetBotDesireForItem()` 打分） | 每件中立装备配 `{ranged weight, melee weight, roles:[pos1..5]}`，比随机发聪明 | 仅 FretBots 模式 |

**可迁移算法清单**：

| 借鉴点 | 出处（文件/函数） | 映射到 OMG 模块 |
|---|---|---|
| 5 维 position 权重表（每英雄 `[pos1..pos5]` 连续分） | `typescript/bots/FunLib/aba_hero_pos_weights.ts:7 HeroPositions` | **SkillProfile**：给每个 OMG 技能组合打"适合 core / support"连续分，而非二元标签 |
| 弱英雄帽 + 指数惩罚曲线 | `bots/hero_selection.lua:82-89` `DEFAULT_WEAK_HERO_CAP` / `Weak_Penalty` | **SkillPool**：标记"实现不完整的 OMG 技能"，限制每局最多抽 N 个 |
| 敌方战力加权评分（netWorth×0.3 + offensivePower×0.3 + level×0.4，归一化排序） | `typescript/bots/FunLib/enemy_role_estimation.ts:60,159` | **PlayerSkillState**：每 5 秒重算敌方英雄威胁排序，决定集火目标 |
| 物品 offensive 评分表（圣剑 150 / Daedalus 88 / 黯灭 60） | `enemy_role_estimation.ts:10-45 ItemOffensiveness` | **SkillProfile**：给 OMG 输出技能打"爆发分"用于目标选择 |
| 谓词与组合 role 判定（`CanBeOfflaner = IsInitiator && IsDurable`） | `typescript/bots/FunLib/aba_role.ts:51-68` | **SkillProfile**：OMG 英雄"适合 gank" = 有硬控 && 有位移 && 有爆发 |
| 补刀预判 WillKillTarget（前摇延迟 + 0.7 伤害余量） | `bots/mode_laning_generic.lua:138 GetBestLastHitCreep()` | **AI 单位行为控制**：vJASS 用 Damage 预测 + 前摇时间，提前 0.3 秒下令 |
| 每帧多 mode GetDesire() 竞选 | `bots/mode_*_generic.lua` 全套 | **EventDispatcher**：注册多个行为候选（对线/刷野/gank/推塔/回家），每 tick 各报 desire 取最大 |
| 眼位随时间/塔状态分层 | `typescript/bots/FunLib/aba_site.ts:163 GetMandatorySpot()` / `:181 GetWardSpotWhenTowerFall()` | **TimerService**：建一张"时间窗 × 塔状态 → 眼位候选点"状态表 |
| position × 近战/远程 出装矩阵 | `typescript/bots/FunLib/advanced_item_strategy.ts:25,52,61` | **技能/装备决策表**：按"本局定位 × 攻击距离"二维查表 |
| 隐身敌方全局标志位 | `typescript/bots/FunLib/aba_role.ts:104 UpdateInvisEnemyStatus()` | **PlayerSkillState**：全局缓存"对面有没有隐身技能"，影响带粉/真视决策 |
| bot 间聊天字符串触发集体 TP | `typescript/bots/FunLib/aba_role.ts:226 ShouldTpToDefend()` | **EventDispatcher**：自定义"信号事件"（守家/刷钱/集合）跨 bot 触发 |

---

### 3.3 LookinGood/SmartScript-AI-Dota-2-bots —— 成熟的 mode/desire 行为树框架（A）

- **GitHub 地址**：https://github.com/LookinGood/SmartScript-AI-Dota-2-bots
- **内容简介**【已查证】：Lua 地图内 bot（Valve Bot API，注释含俄语）。实测 3.4 MB、271 个文件：`ability_item_usage_*.lua` ×~120 英雄、`item_purchase_*.lua` ×~120、`mode_*.lua` ×14（行为树节点）、`utility.lua`（2973 行工具库）、`spell_usage_generic.lua`（1678 行）、`ability_item_usage_generic.lua`（3924 行）、`hero_role_generic.lua`（696 行英雄角色池）。许可证**未声明**；最近提交 **2026-08-31**（仍在维护；星数约 3，代码成熟度远高于星数）。

**AI 功能优缺点逐项**（位置均【已查证】）：

| 功能 | 位置（文件:行号） | 优点 | 缺点 / 局限 |
|---|---|---|---|
| Mode/Desire 行为树框架 | 每个 `mode_*.lua` 实现 `GetDesire()`+`Think()`（14 个模式独立评分） | Valve Bot API 原生模式；结构清晰 | 【仅推断】无全局优先级仲裁器，靠 API 调度 |
| 刷野决策 | `mode_farm_generic.lua:154-246 GetDesire()`、营地发现 `:23-40 UpdateCreepCamps` | 条件丰富：等级<4 不刷、血<30% 不刷、有 aegis 不刷、敌人 1600 内不刷；辅助 vs carry 不同 desire | 硬编码阈值多；每 60s 更新营地列表，仅己方 |
| 防守塔 | `mode_defend_tower_mid_generic.lua`（426 行） | 独立中路防守模式 | 上/下路未实现（只有 mid） |
| 游走/Gank | `mode_roam_generic.lua`（358 行） | 独立游走模式 | 检测玩家 ping tormentor 才响应，依赖人工 ping |
| Roshan / 神符 | `mode_roshan_generic.lua`（262 行）、`mode_rune_generic.lua`（212 行） | 有独立模式 | 【仅推断】内部未逐行读 |
| 眼位 | `mode_ward_generic.lua`（701 行，最大 mode） | 视野决策详尽 | — |
| 撤退 | `mode_retreat_generic.lua`（430 行） | 血线/敌人数量判断 | — |
| 通用工具库 | `utility.lua:7-1030`（~100 个函数） | `GetWeakest/GetStrongest/IsDisabled/IsNight/IsBaseUnderAttack/IsAllyHeroesBetweenMeAndTarget` 等命名规范，可直接抄思路 | — |
| 英雄选择（角色池） | `hero_selection.lua:5-15`（heroesCarry/Tank/Healers/DpsMelee/DpsRanged） | 按角色池选避免重复 | 随机选，无对线克制 |
| 物品使用 | `ability_item_usage_generic.lua:460-600 ItemUsageThink` | 详细：glimmer_cape/shadow_amulet 给低血队友、TP 位置、岗哨反隐 | 顺序硬编码 |
| 信使 / 买活 / Glyph | `ability_item_usage_generic.lua:8-125 CourierUsageThink`、`:126-158 BuybackUsageThink`（复活≥60s 且闲置 5s 才买）、`:160-228 GlyphUsageThink` | 团队资源使用条件明确 | — |
| 技能释放 | `spell_usage_generic.lua`（1678 行） | `ignoredAbility`/`interruptAbility` 黑名单机制 | 硬编码技能名表 |

**可迁移算法清单**：

| 借鉴点 | 出处（文件/函数） | 映射到 OMG 模块 |
|---|---|---|
| Mode/Desire 行为树模式（每模式独立 `GetDesire` 返回 0~1，取最大） | 所有 `mode_*.lua` | **EventDispatcher + 心跳事件驱动**：每个 OMG 行为模块实现 `GetDesire()` |
| 刷野 desire 阈值表 | `mode_farm_generic.lua:154-200` | **技能/装备决策表** |
| 工具函数库（GetWeakest/IsDisabled/IsBaseUnderAttack） | `utility.lua:257-1030` | **SkillProfile / 团战目标选择** |
| 角色英雄池（Carry/Tank/Healer/DPS） | `hero_selection.lua:5-15` | **SkillPool / 阵容规划** |
| 物品使用优先级（glimmer→TP→ward→tango） | `ability_item_usage_generic.lua:460+` | **技能/装备决策表** |
| 技能黑名单（ignoredAbility / interruptAbility） | `spell_usage_generic.lua:7-60` | **SkillProfile 技能释放过滤** |

---

### 3.4 bilibili/LastOrder-Dota2 —— 硬规则包 RL 的混合架构（B）

- **GitHub 地址**：https://github.com/bilibili/LastOrder-Dota2
- **内容简介**【已查证】：Python 强化学习（PPO）影魔（Nevermore）中路 1v1 solo bot，**不是通用 5v5 bot**。通过 `-botworldstatesocket_threaded` 把 Dota2 客户端 `CMsgBotWorldState` protobuf 推给 Python 端，推理后写回 `actions_t<team_id>.lua`，由 `dotaservice/lua/action_processor.lua` 执行。实测 64 MB（含 `trained_model/` 权重）；核心 Python 约 15.6k 行（其中 5.2k 是 protobuf 自动生成，手写逻辑约 10k 行），附 29 个 Lua 胶水文件。许可证 **MIT**；最近提交 2021-08-11（已 4 年多未更新，但自带权重可直接跑）。规则被锁死（只打影魔 vs 影魔中路，10 分钟上限），通用 5v5 策略完全不存在。

**AI 功能优缺点逐项**（位置均【已查证】）：

| 功能 | 位置（文件:行号 / 函数名） | 优点 | 缺点 / 局限 |
|---|---|---|---|
| 分层状态机（脚本+RL 混合） | `dotaservice/state_machine.py:14-206 class StateMachine`；状态枚举 `:8-11`；主分发器 `dispatcher()` `:65` | **本仓最有借鉴价值的设计**：硬规则状态机（买眼/回家/吃树/死亡/TP）包在 RL 模型外面，只有 `MODEL` 状态才把控制权交给神经网络——既保证底线行为不崩，又让 ML 学难的微操 | 状态转移条件全部硬编码坐标，影魔专用，不能跨英雄 |
| 卡兵（creep block）几何求解 | `dotaservice/state_machine.py:208-292 block()`（`np.polyfit` 拟合兵线轴线 `:223-228`，点到直线距离 `:275-288`） | 把"卡兵"建模成"兵线切线 + 队伍重心偏移 + 两列兵识别"的解析几何问题，是规则解不是 RL | 仅开局 30 秒内生效；坐标硬编码，只适用中路 |
| PPO 主循环 + LSTM 历史 | `agents/dota_agent.py:34 PPOAgent`、`_act()` `:578`、模型推理 `:753-755`、LSTM 隐状态 `:144` | 用 LSTM 编码历史帧解决 POMDP 部分可观测；动作空间离散 18 类（`choose_action()` `:211-274`） | 只服务影魔 1v1；动作枚举写死，OMG 随机技能池不适用 |
| 动作掩码（Action Mask） | `model/action_mask.py:11 ActionMask`、`valid()` `:83-232`、`unit_attack_valid()` `:70-81` | **纯函数式可行性过滤**：每帧按蓝量/CD/攻击间隔/前摇/目标是否在塔射程/身上是否有回复 buff 把不可行动作 mask 成 0；明确"反补条件=我方小兵血量≤50%""打塔条件=距离<750" | 掩码表只覆盖影魔 4 技能 + 少量消耗品，OMG 需重做 |
| 敌方技能 CD/等级推断 | `agents/dota_agent.py:959-1018 cal_enemy_ability()`（初始表 `:159-172`） | 通过 `obs.damage_events`/`obs.ability_events` 反推敌方影压等级（查表 `:984-986`），并把 CD 重置为 10 秒——**从观测反演对手状态的典型例子** | 只针对影魔三连压，不可直接复用 |
| 出装/加点策略表（脚本） | `nevermore.py:16-34 item_route`、`:40-46 routes`、`can_buy_new_item()` `:104-108`、`need_item()` `:110-111` | **"按金币阈值弹出下一件装备"的队列模型**：每条 `{enough_gold=300, items=[...]}`，钱够整组买走 | 影魔专用 build 表；但"阈值队列"结构本身可迁移 |
| 补给/眼位/背包整理脚本 | `agents/dota_agent.py:276-513 choose_item()`（买药 `:292-353`、买眼 `:386-396`、背包 swap `:417-512`） | 把"什么时候该买药"写成显式规则：对比 `loss_health` 与 `400*flask_count + 112*tango_count + healing_health`，避免重复买 | 大量特判（树枝种树人/魔棒/仙灵之火），OMG 要泛化 |
| 多维度 reward 分解 | `agents/dota_agent.py:817-880 compute_episode_reward()` | 总 reward 拆成 health/mana/exp/gold/lasthits/denies/tower 七个分量各自 discounted return，便于调试 | solo 场景；团战/推塔 reward 未建模 |
| 反推对手动画/动作 | `agents/dota_agent.py:939-957 get_enemy_action()`（`anim_activity - 1500` clip 到 0-19） | 从动画状态反推对手在干嘛（攻击/施法/移动）作为 feature | 20 个 bucket 是拍脑袋的 |

**可迁移算法清单**：

| 借鉴点 | 出处（文件/函数） | 映射到 OMG 模块 |
|---|---|---|
| 硬规则状态机包内层评分/RL：外层确定性状态（回家/买活/买眼/卡兵/死亡）兜底，内层才走评分 | `dotaservice/state_machine.py:14 StateMachine.dispatcher()` | **EventDispatcher**：把"死亡/回家/买活/补装"做成高优先级状态，屏蔽底层 SkillProfile 评分 |
| 动作掩码（可行性过滤）：每帧先按 CD/蓝量/距离/前摇/目标存活过滤不可行动作，再评分 | `model/action_mask.py:83 valid()` | **PlayerSkillState**：每 tick 先跑 `CanCast(skill)` 过滤，再让 SkillProfile 打分 |
| 按金币阈值弹出的出装队列 `[{enough_gold, items}]` | `nevermore.py:16 item_route` + `:110 need_item()` | **技能/装备决策表**：给每个 OMG 技能配"经济阈值解锁顺序"队列 |
| 从 damage/ability 事件反演敌方 CD 与等级 | `agents/dota_agent.py:959 cal_enemy_ability()` | **PlayerSkillState**：镜像一份"敌方技能冷却预测表"，用于 gank/反打时机判断 |
| 多维度 reward 分解（health/mana/exp/gold/lasthits/denies 各自 discounted return） | `agents/dota_agent.py:817 compute_episode_reward()` | **SkillProfile**：即使不做 RL，也可作为"行为目标评分"的多分量加权参考 |
| 解析几何解卡兵/走位（兵线切线 + 点到直线距离） | `dotaservice/state_machine.py:208 block()` | **AI 单位行为控制**：OMG 对线阶段用 vJASS 向量库算"英雄应站在兵线切线哪一侧" |

---

### 3.5 pydota2/pydota2_archive —— 外部 RL 框架的动作/特征抽象设计（B）

- **GitHub 地址**：https://github.com/pydota2/pydota2_archive
- **内容简介**【已查证】：Python RL 框架（pysc2→Dota2 移植），外部框架 + Lua bot 桥接。实测 46 MB（含 PDF 文档、replay 工具、protobuf）；目录：`agents/`（base/random/smart/hero_select agent）、`env/`、`lib/`（actions.py 289 行 / features.py 305 行 / world_data.py 672 行）、`ml_algo/q_learn.py`、`bot_code/bots/` Lua 桥接。许可证 **Apache-2.0**；最近提交 2018-12-04；README 自述 WIP。

**AI 功能优缺点逐项**（位置均【已查证】）：

| 功能 | 位置（文件:行号） | 优点 | 缺点 / 局限 |
|---|---|---|---|
| 动作空间枚举 | `lib/actions.py:24-80`（ArgumentType.enum/scalar/location/handle） | 仿 pysc2 的动作参数抽象 | 文件头注 "THIS FILE IS NOT COMPLETE" |
| 特征层定义 | `lib/features.py:38-90`（FeatureType.SCALAR/CATEGORICAL/VECTOR） | 明确特征三分法 | 文件头注 "WILL NOT COMPILE CURRENTLY" |
| 世界状态模型 | `lib/world_data.py`（672 行） | player/unit/location 查询 API | 【仅推断】未跑通 |
| Q-Learning agent | `ml_algo/q_learn.py:14-57 QLearning` | 标准 ε-greedy Q-table，lr=0.1, ε=0.95 | gamma=0.0（不考虑未来回报，退化为单步） |
| 离散化移动 agent | `agents/smart_agent.py:23-130 MoveAgent`（8 方向 + 100 单位网格；状态空间约 156,800 × 11 动作） | 状态空间估算明确 | 只学"走到地图中心"，非完整 Dota AI |
| 状态离散化 | `smart_agent.py:115-120`（`x_grid = int(loc.x/100)`） | 网格粒度可调 | 硬编码 100.0 |
| 奖励设计 | `smart_agent.py:33-37`（DEFAULT_REWARD=-2 / TIME_STEP=-1 / CLOSER=-0.5 / ARRIVED=10） | immediate/near-term 分层明确 | 仅移动任务 |
| OODA 思考 | README "How It Works" 段 | 明确 Observe-Orient-Decide-Act 循环；提出"objective/lane/hero 三套独立 policy" | 仅停留在设计文档 |
| Lua 动作桥 | `bot_code/bots/actions/*.lua` | Python→Lua 指令下发 | 【仅推断】WIP |

**可迁移算法清单**：

| 借鉴点 | 出处（文件/函数） | 映射到 OMG 模块 |
|---|---|---|
| 动作参数抽象（enum/scalar/location/handle） | `actions.py:35-80` | **EventDispatcher** 的动作派发参数表 |
| 特征三分法（SCALAR/CATEGORICAL/VECTOR） | `features.py:38-50` | **SkillProfile** 画像的属性分类 |
| 状态空间离散化粒度讨论 | `smart_agent.py:115-125` 注释 | **SkillPool / PlayerSkillState** 的状态编码 |
| 多 policy 分层（objective / lane / hero） | README "Machine Learning Thoughts" | **EventDispatcher**：全局策略 vs 单位行为分层 |
| OODA 循环 + immediate/near/long 奖励 | README + `smart_agent.py:33-37` | **EventDispatcher** 心跳驱动 + 短期/中期评分 |
| Q-learning ε-greedy 表 | `q_learn.py:25-40` | 【仅推断】若 OMG 要做"技能使用偏好自学习"可借鉴 |

---

### 3.6 chrismcg61/OpenAI-Lite-Dota —— 上下文自学习 bandit 范本（B）

- **GitHub 地址**：https://github.com/chrismcg61/OpenAI-Lite-Dota
- **内容简介**【已查证】：Lua 地图内 bot，带自学习上下文评分（类 contextual bandit）。实测 464 KB、26 个 Lua：核心在 `MyLibs/MyOpenAI/OpenAI.lua`（97 行上下文表）、`OpenAI_Ability.lua`（326 行技能考虑/执行/评估循环）、`MyUtility.lua`（839 行物品/商店/视野）；覆盖 8 个英雄。许可证**未声明**；最近提交 2019-12-22。

**AI 功能优缺点逐项**（位置均【已查证】）：

| 功能 | 位置（文件:行号） | 优点 | 缺点 / 局限 |
|---|---|---|---|
| 上下文记录结构 | `MyOpenAI/OpenAI.lua:14-38 FindOrCreateContext` | 每个 (技能×上下文) 存 `SCO/NBS/MIS` 三元组 | 上下文 key 完全由调用方定义 |
| 运行均值评分 | `OpenAI_Ability.lua:265-268`（`SCO = (SCO*NBS + delta) / (NBS+1)`） | 在线平均，无需历史表 | 纯增量平均，无时间衰减 |
| miss 重置机制 | `OpenAI_Ability.lua:270-285`（`MIS==hiMiss` 时 NBS=1, SCO=hiMiss*minScore） | 连续失败后重置为"待验证" | 硬编码 maxMisses=4 |
| 延迟评估循环 | `OpenAI_Ability.lua:145-155`（`bEvalWaiting` + `lastAbilityDeltaT`） | 释放技能后等 `DELTA_T` 再结算 | 评估窗口是常数 |
| 奖励加权 | `OpenAI_Ability.lua:24-30`（lhScore=20, heroDmgScore=25, assistScore=50, killScore=100） | 权重清晰，可直接抄为 OMG 技能评分 | 无经济/塔/视野分 |
| AOE 目标搜索 | `OpenAI_Ability.lua:226-237 myFindAoeLoc`（用 `npcBot:FindAoELocation`） | 自动找命中数最多的落点 | count>2 时 cap 为 2 |
| 上下文特征 | `OpenAI_Ability.lua:206-224 GetContextDataAbility`（`ctxParams[].FUNC`） | 每个技能可自定义上下文函数 | 框架通用但仅 8 英雄用 |
| 商店坐标 / 背包 / 信使 | `MyUtility.lua:47-52 shopLocations`、`:98-135 IsItemAvailable`、`:252-280 UseCour` | 直接可用 | 地图改版即失效；背包丢弃逻辑较粗糙 |

**可迁移算法清单**：

| 借鉴点 | 出处（文件/函数） | 映射到 OMG 模块 |
|---|---|---|
| 上下文 bandit 三元组 (SCO/NBS/MIS) | `OpenAI.lua:14-38` + `OpenAI_Ability.lua:265-285` | **SkillProfile 画像自学习核心**：对"技能×场景"组合做在线评分 |
| 延迟评估（释放后等 ΔT 再算分） | `OpenAI_Ability.lua:145-155` | **TimerService** 的延迟回调 |
| 奖励权重表（LH/Dmg/Assist/Kill） | `OpenAI_Ability.lua:24-30` | **SkillProfile** 的评分函数权重 |
| miss 重置（连续失败→重新探索） | `OpenAI_Ability.lua:270-285` | 防止 OMG AI 卡在劣质技能链 |
| AOE 落点搜索 | `OpenAI_Ability.lua:226-237` | **团战目标选择** |
| 上下文特征函数注入（`ctxParams[].FUNC`） | `OpenAI_Ability.lua:206-224` | **SkillPool** 的技能决策表 |

---

### 3.7 OurGroupProjects/OurDotaBot —— 显式 5 状态 FSM 骨架（B）

- **GitHub 地址**：https://github.com/OurGroupProjects/OurDotaBot
- **内容简介**【已查证】：Lua 地图内 bot，显式 5 状态有限状态机（FSM）。实测 20 MB（绝大部分是 `replays/*.dem` 录像），代码仅 ~844 行：核心是 `bot_nevermore.lua`（672 行），`bot_lina.lua` 仅 9 行空壳。许可证**未声明**；最近提交 2017-12-14；README 引用 Nostrademous/Dota2-FullOverwrite。

**AI 功能优缺点逐项**（位置均【已查证】）：

| 功能 | 位置（文件:行号） | 优点 | 缺点 / 局限 |
|---|---|---|---|
| 显式 5 状态 FSM | `bot_nevermore.lua:9-18`（LANE=1/PUSH=2/DEFEND=3/ATTACK=4/RETREAT=5） | 状态枚举清晰，教科书级 | 仅影魔单英雄 |
| 状态切换 dispatcher | `bot_nevermore.lua:76-93 updateState` + Think `:96-120` | `if currentState==X then XUpdateState()` 模式 | 无优先级仲裁 |
| Last-hit EHP 估算 | `bot_nevermore.lua:228-240`（`creep:WasRecentlyDamagedByCreep(5)` + `TimeSinceDamagedByCreep()` + `rangedCreepBonus=40`） | 考虑小兵已受击时间窗口，估算真实血量 | 硬编码 17 伤害 / 0.6-1.0s 窗口 |
| Shadowraze 距离带 | `bot_nevermore.lua:280-300`（450 / 200-700 / 450-950 三档） | 按距离带选 raze1/2/3 | 仅影魔 |
| AOE 命中数阈值 | `bot_nevermore.lua:307`（`MIN_CREEP_TO_RAZE = 2`） | 至少命中 2 个才放 | 硬编码 |
| 技能 build 表 | `bot_nevermore.lua:30-52 SKILL_BUILD 数组` | 线性升级表 | 无自适应 |
| 敌人消失检测 | `bot_nevermore.lua:642 enemyGone`（`GONE_DISTANCE_CONSTANT=2000`） | 视野丢失距离阈值 | — |

**可迁移算法清单**：

| 借鉴点 | 出处（文件/函数） | 映射到 OMG 模块 |
|---|---|---|
| 显式状态机（LANE/PUSH/DEFEND/ATTACK/RETREAT） | `bot_nevermore.lua:9-18, 76-120` | **AI 单位行为控制的 FSM 骨架** |
| Last-hit EHP 估算（考虑已受击时间） | `bot_nevermore.lua:228-240` | **AI 单位行为控制**：补刀/技能补刀的命中时机判断 |
| 距离带技能选择（按目标距离挑技能档） | `bot_nevermore.lua:280-300` | **SkillProfile** 画像匹配（近/中/远） |
| AOE 命中数阈值（至少 N 个才放） | `bot_nevermore.lua:307` | **团战技能释放阈值** |
| 线性技能 build 表 | `bot_nevermore.lua:30-52` | **技能/装备决策表** |

---

### 3.8 低价值 / 参考仓库简评（C/D 级）

以下仓库算法价值有限或年代久远，每仓 2~3 行概述（元数据均【已查证】，内部逻辑未深读者标【仅推断】）：

- **lightbringer/dota2ai（C，未声明许可证，最近提交 2024-12-28）**：学术研究框架——Lua 侧只做"世界状态→JSON HTTP POST 出去 / 命令 JSON→回写游戏"的代理（`events.lua:108 BotThink`），真正 bot 逻辑跑在外部 Java 进程（`BaseBot.java:14`）；唯一示例 bot 是 264 行的 Lina（随机放技能、随机买 tango），**决策算法本身为空**。仅"感知→决策→执行三层分离"与"命令模式（Command 对象+枚举码，`BotCommands.java:7`）"两个架构思想可借。
- **furiouspuppy/Dota2_Bots（C，未声明许可证，最近提交 2017-06-09）**：Valve 7.00 bot API 刚开放时的早期实验（作者 README 自认 "on hold / non-functional"），只深度实现 Meepo/Puck/Rattletrap/MonkeyKing 4 个英雄。可借鉴的小经验公式：role 数值越小越 core → 买眼时间越晚（`item_purchase_generic.lua:84 wardTimer = DotaTime() + 25 - 5*Roles`）；"附近友+敌总数≥5"粗判团战（`team_status.lua:135-150`）；用队友当沙包反推物理/法术输出上限（`team_status.lua:96-104`）；每技能独立 `ConsiderXxx()→(desire,target)` 竞选（`ability_item_usage_puck.lua:82-176`）是 Valve API 标准模板的早期样本。
- **llSourcell/OpenAI_Five_vs_Dota2_Explained（C，MIT，最近提交 2018-08-12）**：**不是 Dota2 代码**——本质是 `alexis-jacq/Pytorch-DPPO` 的镜像，跑 MuJoCo 控制环境（HalfCheetah 等），仅 OpenAI Five 算法教学（PPO-Clip `ppo.py:160`、GAE `:120`）。对 vJASS 工程无直接价值；【仅推断】若未来做数值优化可参考其回报/优势分解思想。
- **Nostrademous/Dota2-FullOverwrite（C，GPL-3.0，最近提交 2017-06-12）**：OurDotaBot README 推荐的"全量 bot 重写"项目（1.5 MB，`bot_*.lua` + `abilityUse/`），年代久远且 GPL 传染；【仅推断】结构与 SmartScript 同类，仅作历史参考，不建议读码。
- **phamstered/Dota2AI_Bot_Scripts（D，未声明许可证，最近提交 2018-04-26）**：整库就一个文件 `mode_rune_lina.lua`（68 行），仅"神符刷新倒计时 <30s 或距离 <5000 就去"的 desire 片段。可借的只有神符/资源刷新倒计时公式（:26-29）与"最近且可用"目标选择（:32-54）两个极小点。
- **JimLambda/dota2_already_existed_bot_script（D，不可达）**：**404 Not Found（仓库已删除/转私有）**【已查证】——`git clone` 报认证错误、`curl -sIL` 返回 HTTP 404。任务给定其类型为"Lua 天地星 AI 修改版"【仅推断】，无法做任何代码级评估，**不建议依赖**。

---

## 四、可用于 OMG 仓库的部分（按 OMGAI 模块归集）

> 以下条目全部来自第三章已核实内容；每条注明出处仓库 + 文件 + 函数名/行号。

### 4.1 EventDispatcher（行为调度 / 状态机 / 信号事件）

| 借鉴点 | 出处（仓库 / 文件 / 函数） |
|---|---|
| **mode desire 竞选器**：每个行为模块每 tick 自报 0~1 分，调度器选 max 执行（把 vJASS 里 if-else 串改成优先级表） | adam3q `mode_farm_generic.lua:22 GetDesire`；OpenHyperAI `bots/mode_*_generic.lua` 全套；SmartScript 所有 `mode_*.lua` |
| **硬规则状态机包内层评分**：高优先级确定性状态（死亡/回家/买活/补装）兜底，屏蔽底层评分 | LastOrder `dotaservice/state_machine.py:14 StateMachine.dispatcher()` |
| **gank 两阶段状态机**（ASSEMBLE→开雾→ROAMING→目标丢失 5s 重算或解散） | adam3q `mode_team_roam_generic.lua:517 TeamRoamThink` |
| **显式 5 状态 FSM**（LANE/PUSH/DEFEND/ATTACK/RETREAT + updateState 分发） | OurDotaBot `bot_nevermore.lua:9-18, 76-120` |
| **多 policy 分层**（objective / lane / hero 三套独立 policy；OODA 循环 + 短/中/长期奖励分层） | pydota2 README "Machine Learning Thoughts" + `smart_agent.py:33-37` |
| **"附近友+敌总数≥5"计数器事件触发团战模式切换** | Dota2_Bots `team_status.lua:135-150` |
| **bot 间字符串信号事件**（守家/刷钱/集合触发集体决策） | OpenHyperAI `aba_role.ts:226 ShouldTpToDefend()` |
| **动作参数抽象**（enum/scalar/location/handle 四类派发参数） | pydota2 `lib/actions.py:35-80` |

### 4.2 SkillProfile（画像权重表 / 自学习 / 技能评分）

| 借鉴点 | 出处（仓库 / 文件 / 函数） |
|---|---|
| **5 维 position 连续权重表**（每英雄 `[pos1..pos5]` 0-100 分，代替二元标签） | OpenHyperAI `typescript/bots/FunLib/aba_hero_pos_weights.ts:7 HeroPositions` |
| **英雄职责标签表**（carry/support/initiator/nuker/escape/disabler/pusher + 数值权重） | adam3q `util/RoleUtility.lua:1543 IsCarry` 等 |
| **谓词与 role 判定**（`CanBeOfflaner = IsInitiator && IsDurable`；OMG 版"适合 gank = 有硬控 && 有位移 && 有爆发"） | OpenHyperAI `aba_role.ts:51-68` |
| **上下文 bandit 自学习三元组 (SCO/NBS/MIS)**：对"技能×场景"组合做在线均值评分 `SCO = (SCO*NBS + delta)/(NBS+1)` | OpenAI-Lite-Dota `OpenAI.lua:14-38` + `OpenAI_Ability.lua:265-268` |
| **miss 重置机制**（连续失败 N 次后重置为"待验证"，防止卡在劣质技能链） | OpenAI-Lite-Dota `OpenAI_Ability.lua:270-285` |
| **奖励权重表**（LH=20 / heroDmg=25 / assist=50 / kill=100） | OpenAI-Lite-Dota `OpenAI_Ability.lua:24-30` |
| **多分量目标评分**（health/mana/exp/gold/lasthits/denies 各自加权） | LastOrder `agents/dota_agent.py:817 compute_episode_reward()` |
| **特征三分法**（SCALAR/CATEGORICAL/VECTOR）指导画像属性分类 | pydota2 `lib/features.py:38-50` |
| **技能释放优先级链**：打断引导 > 击杀确认 > 自保 > 撤退反打 > AoE 命中数≥N > 对线消耗 > 推塔 | adam3q `ability_item_usage_lion.lua:104-257 Consider[1]` |
| **技能黑名单**（ignoredAbility / interruptAbility） | SmartScript `spell_usage_generic.lua:7-60` |
| **物品 offensive 评分表**（圣剑 150 / Daedalus 88 / 黯灭 60，给输出技能打"爆发分"） | OpenHyperAI `enemy_role_estimation.ts:10-45 ItemOffensiveness` |
| **距离带技能选择**（近/中/远三档选技能） | OurDotaBot `bot_nevermore.lua:280-300` |

### 4.3 PlayerSkillState（敌方状态 / 可行性过滤 / 全局标志）

| 借鉴点 | 出处（仓库 / 文件 / 函数） |
|---|---|
| **敌方战力加权评分**（netWorth×0.3 + offensivePower×0.3 + level×0.4，归一化排序定集火目标） | OpenHyperAI `enemy_role_estimation.ts:60,159` |
| **从伤害/施法事件反演敌方技能 CD 与等级**（观测反演对手状态） | LastOrder `agents/dota_agent.py:959 cal_enemy_ability()` |
| **动作掩码前置过滤**：每 tick 先按 CD/蓝量/距离/前摇/目标存活过滤不可行的技能动作，再让评分层打分 | LastOrder `model/action_mask.py:83 valid()` |
| **隐身敌方存在性全局标志位**（扫技能+道具后置 invisEnemyExist，影响带粉/真视决策） | OpenHyperAI `aba_role.ts:104 UpdateInvisEnemyStatus()` |
| **敌方输出画像刷新**（用自己人当沙包反推物理/法术输出上限） | Dota2_Bots `team_status.lua:96-104 attackPower/magicPower` |
| **真英雄 vs 幻象指纹识别**（用属性派生数值/回复量异常反推本体） | adam3q `team_desires.lua:342 GetRealHero` |
| **团战目标选择双向评分**（队友可达性×状态分；目标可击杀=预估5秒伤害/血量×0.7+距离×0.3） | adam3q `mode_team_roam_generic.lua:314 GetAllyFactor` / `:375 GetEnemyFactor` / `:445 FindTarget` |

### 4.4 TimerService（定时器 / 延迟回调 / 时间窗状态表）

| 借鉴点 | 出处（仓库 / 文件 / 函数） |
|---|---|
| **眼位时间窗×塔状态状态表**（2 分钟前只插河道，12 分钟后扩一塔，塔掉了换点位） | OpenHyperAI `aba_site.ts:163 GetMandatorySpot()` / `:181 GetWardSpotWhenTowerFall()` |
| **按金币阈值弹出的队列**（`[{enough_gold, items}]`，钱够整组买走） | LastOrder `nevermore.py:16 item_route` + `:110 need_item()` |
| **延迟评估回调**（释放技能后等 ΔT 再结算评分） | OpenAI-Lite-Dota `OpenAI_Ability.lua:145-155` |
| **打野分钟点 stack**（每分钟 :55 秒触发"走出去堆叠"事件） | adam3q `mode_farm_generic.lua:9-13, 196-238` |
| **推线欲望随时间线性增长**（基线 0.20，12 分钟后随时间加） | adam3q `team_desires.lua:1 GetCommonPushLaneDesires()` |
| **神符/资源刷新倒计时公式** | phamstered `mode_rune_lina.lua:26-29` |
| **目标丢失超时判断**（目标丢失>5s 重新找目标或解散） | adam3q `mode_team_roam_generic.lua:517 TeamRoamThink` |

### 4.5 AI 单位行为控制（FSM / Consider 链 / 补刀 / 走位）

| 借鉴点 | 出处（仓库 / 文件 / 函数） |
|---|---|
| **每技能独立 Consider → (desire, target) 竞选** | Dota2_Bots `ability_item_usage_puck.lua:82-176`；adam3q 所有 `ability_item_usage_*.lua` |
| **补刀预判**：预估伤害 vs 目标血量，计入攻击前摇+飞行时间（`t = 2.0*attackPoint + dist/moveSpeed`） | adam3q `mode_farm_generic.lua:160-167`；OpenHyperAI `mode_laning_generic.lua:138 GetBestLastHitCreep()`（`dmgDelta = attackDamage * 0.7` 留余量） |
| **Last-hit EHP 估算**（考虑小兵已受击时间窗口） | OurDotaBot `bot_nevermore.lua:228-240` |
| **解析几何解走位**（兵线切线拟合 + 点到直线距离） | LastOrder `dotaservice/state_machine.py:208 block()` |
| **AOE 落点搜索**（找命中敌人最多的落点；至少命中 N 个才放） | OpenAI-Lite-Dota `OpenAI_Ability.lua:226-237`；OurDotaBot `bot_nevermore.lua:307 MIN_CREEP_TO_RAZE=2` |
| **危险位置安全检查**（"敌人比我近就不插眼/不放技能"前置距离检查） | adam3q `mode_ward_generic.lua:390 IsEnemyCloserToWardLoc` |
| **命令封装下发**（一个 tick 想做的事封装成命令对象，统一由执行层下发） | lightbringer `BotCommands.java:7-249`（架构思想，vJASS 同进程跑不需 HTTP） |
| **工具函数库**（GetWeakest / IsDisabled / IsBaseUnderAttack / IsAllyHeroesBetweenMeAndTarget） | SmartScript `utility.lua:257-1030` |

### 4.6 技能 / 装备决策表（出装 / 加点 / role 联动）

| 借鉴点 | 出处（仓库 / 文件 / 函数） |
|---|---|
| **静态出装优先级队列 + 大件拆组件按序买** | adam3q `hero/items/lina.lua:7` + `util/ItemPurchaseSystem.lua` |
| **position × 近战/远程 二维出装矩阵** | OpenHyperAI `advanced_item_strategy.ts:25,52,61` |
| **role 联动购买时机**（数值越小越 core → 买眼/TP 越晚：`wardTimer = DotaTime() + 25 - 5*Roles`） | Dota2_Bots `item_purchase_generic.lua:84` |
| **线性技能加点表**（含天赋分支回调与点错容错计数） | adam3q `ability_item_usage_lion.lua:24 AbilityToLevelUp`；OurDotaBot `bot_nevermore.lua:30-52 SKILL_BUILD` |
| **对位/counter 数据表**（"技能 A 克制技能 B"小表） | OpenHyperAI `aba_matchups.ts`（2870 行）+ `FretBots/matchups_data.lua`（14876 行） |
| **补给购买显式规则**（损失血量 vs 已有回复量，避免重复买） | LastOrder `agents/dota_agent.py:276-353 choose_item()` |
| **角色英雄池选阵容**（Carry/Tank/Healer/DPS-Melee/DPS-Ranged 分池） | SmartScript `hero_selection.lua:5-15` |

### 4.7 SkillPool（选池 / 弱技能帽 / 多约束）

| 借鉴点 | 出处（仓库 / 文件 / 函数） |
|---|---|
| **弱英雄帽 + 指数惩罚曲线**（技术不完备的英雄每队最多 N 个，`{type="exp", base=0.6}`） | OpenHyperAI `bots/hero_selection.lua:82-89 DEFAULT_WEAK_HERO_CAP / Weak_Penalty` |
| **多约束选池**（按权重过阈值 `ROLE_WEIGHT_THRESHOLD=50` + 限制 Durable/Disabler/Healer 数量 + Top-K 截断） | OpenHyperAI `bots/hero_selection.lua:178 GetPositionedPool()` |
| **位置池补位选人**（5 个号位池，"先占位置再从池里选"保证不重位） | adam3q `hero_selection.lua:1007 GetPositionedHero()` / `:439-557` 位置池 |
| **状态空间离散化粒度**（状态编码网格粒度可调的讨论） | pydota2 `smart_agent.py:115-125` |

---

## 附录

### A. 已查证与仅推断的区分

- **【已查证】**：规模（`du -sh`）、活跃度（`git log -1 --format=%ci`）、许可证（仓库根目录 LICENSE 文件 / ls 核实）、所有表格中出现的文件路径、函数名与行号——均在浅克隆后打开文件 / grep 核实。星数**不在此列**：GitHub REST API 当时被限流，全部星数为任务给定值，统一按【仅推断】处理，且本报告未引用任何星数作为评级依据。
- **【仅推断】**：① SmartScript `mode_roshan_generic.lua` 内部实现、lightbringer Wiki 链接、pydota2 `world_data.py` 是否跑通、Nostrademous/Dota2-FullOverwrite 内部逻辑；② OpenAI-Five 教学版对 OMG 的迁移价值；③ JimLambda 仓库的内容（仅任务给定"天地星 AI 修改版"）；④ adam3q 角色画像表下游的完整决策链路中未逐行打开的部分。
- **评级依据**：质量评级基于"决策算法完整度 + 可迁移思想密度 + 文档/活跃度"，与星数无关（SmartScript 约 3 star 仍评 A 即为明证）。

### B. 下载位置与状态

- 下载根目录：`/home/user/Doubao/chats/38447272451777282/dota2ai_ref/`。
- **浅克隆成功 15 个目录**：`adam3q-dota2ai`、`lightbringer-dota2ai`、`LastOrder-Dota2`、`dota2bot-OpenHyperAI`、`Dota2_Bots`、`OpenAI_Five_vs_Dota2_Explained`、`pydota2_archive`、`OpenAI-Lite-Dota`、`SmartScript-AI-Dota-2-bots`、`OurDotaBot`、`Dota2AI_Bot_Scripts`（以上根目录 11 个）+ `extra/` 下 `LastOrder-Dota2`、`dota2bot-OpenHyperAI`、`Dota2_Bots`、`Dota2-FullOverwrite` 4 个。
- **去重后 12 个不同仓库**（LastOrder / OpenHyperAI / Dota2_Bots 三个在"额外发现"批次重复落地）。
- **1 个不可达**：JimLambda/dota2_already_existed_bot_script——`git clone` 报认证错误、`curl -sIL` 返回 HTTP 404，仓库已删除/转私有，未落地任何代码。
- 本报告所有引用的文件均可在上述目录内复核。

### C. 许可证合规小结

| 许可证 | 仓库 | 对 vJASS 工程的含义 |
|---|---|---|
| GPL v3（强传染） | adam3q/dota2ai、Nostrademous/Dota2-FullOverwrite | **不可复制代码进自有工程**；只借鉴决策思想与算法结构 |
| MIT（宽松） | OpenHyperAI、LastOrder、OpenAI-Five 教学版 | 可较自由地参考实现（仍建议保留出处说明） |
| Apache-2.0 | pydota2_archive | 可较自由参考（注意专利授权条款） |
| 未声明（默认保留全部权利） | SmartScript、OpenAI-Lite-Dota、OurDotaBot、Dota2_Bots、lightbringer、phamstered | **不可复制代码**；只能借鉴思想（事实/算法不受版权保护） |
| 不可达 | JimLambda | 无法评估，不建议依赖 |

> 最终建议：vJASS OMG AI 系统落地时，所有算法均以"思想重写"方式实现（vJASS 语言、本地单位/伤害 API、OMG 技能表），不引入任何上游仓库代码原文。
