# DOTA OMG IMBA 精简版修改与审计说明

## 交付物

- 地图：`DOTA-OMG-IMBA-小生我怕怕-精简版.w3x`
- 本地路径：`D:\dota\DOTA69AI\output\DOTA-OMG-IMBA-小生我怕怕-精简版.w3x`
- 文件大小：184,248,622 字节（175.71 MiB）
- SHA-256：`456eca2e2dcb551274c993ead013443283420bc0a7849fcc98d7f363b1ac377d`

## 本次物理删除

1. 删除车轮战主体、钩子、奖励倍率分支、装备迁移辅助和旧提示。
2. 删除 30 波防守主体、波次机制、难度界面、测试命令、阿克蒙德通关奖励事务链和旧规则提示。
3. 从脚本中实际删除 118 个函数，其中 116 个属于上述模式及其专属辅助；脚本减少 135,318 字节。
4. 从以下 5 张优化物编 SLK 中各删除 86 个防守专属单位记录，并将后续 Y 行号和表尺寸同步重排：
   - `Units\UnitData.slk`
   - `Units\UnitUI.slk`
   - `Units\UnitBalance.slk`
   - `Units\UnitWeapons.slk`
   - `Units\UnitAbilities.slk`
5. 从 `war3map.imp` 删除 6 条专属导入项，并从 MPQ 物理删除对应文件：
   - `AncientSeaTurtleFire.blp`
   - `AncientSeaTurtleFireGlow.blp`
   - `Sc2Baneling_bW.blp`
   - `war3mapimported\A (62).mdx`
   - `war3mapimported\RedTortollanBattlemaster.mdx`
   - `war3mapimported\Sc2Baneling_v2_bW.mdx`

## 刻意保留

- 普通 DOTA OMG 对战、随机技能、技能冲突规避和 AI 主动施法。
- 普通 AI 守塔、回防和基地推进逻辑；它们不是 30 波防守玩法。
- `KKDefense_IsWaveType` 名称作为普通 AI 调用兼容桩，函数体固定返回 `false`。
- `B1004ControlUnit` 名称作为普通英雄初始化兼容包装，函数体直接返回 `GetTriggerUnit()`。
- 普通胜利奖励使用的 `B1069RewardMultiplier`，保留默认值 1。
- 历史账号白名单/权限字符串，因为它们是鉴权数据，不是玩家可见署名。
- 被其他普通模型共享的贴图；没有为了体积盲删共用资源。

## 玩家可见内容

- 地图名称：`DOTA OMG IMBA`
- 玩家可见署名：`小生我怕怕`
- 开局只保留新手、正常、困难三个难度。
- 最终 W3X 内加载图已回读重拼为 1024×768，标题与署名正确，四块接缝正常。
- 地图预览图仍为 256×256 TGA。

## 验证结果

- 最终包内重新提取并逐字节核对：`war3map.j`、`war3map.imp`、5 张 `Units\*.slk` 均与精简源一致。
- 最终 `war3map.imp`：版本 1，导入项从 3302 降为 3296。
- 5 张 SLK：行数边界从 Y3424 调整为 Y3338，防守专属 `qU*`/`qUS*` 记录为 0。
- 脚本残留扫描：车轮战实现函数 0，30 波防守实现函数 0，相关旧提示/测试命令/防守全局变量 0。
- 6 个专属文件逐项尝试从最终 MPQ 提取，均不存在。
- 加载图四块与预览图均可由 Pillow 正常解码。
- PJASS 对最终包内脚本只报告基图既有的 `location_m5` 可能未初始化；没有本次删除引入的未定义符号或新语法错误。

## 体积对比

| 版本 | 大小 |
|---|---:|
| 指定基图 `Dota69-OMGAI-latest.w3x` | 176.24 MiB |
| 第一版修改图 | 178.47 MiB |
| 本次精简版 | 175.71 MiB |

精简版比第一版修改图减少约 2.76 MiB，比指定基图减少约 0.53 MiB。地图仍较大，是因为普通模式仍需保留约 143 MiB 的 `skins` 资源及大量模型/贴图；本次只删除了有依赖证据、且确定专属于已移除玩法的资源。

## 尚未覆盖的验证

当前环境未实际启动 Warcraft III 进入对局，因此未做运行时多人联机与完整一局回归。建议首次试玩重点确认：三档难度选择、普通兵线出生、随机技能、AI 施法、塔/基地推进、存档与胜利结算。
