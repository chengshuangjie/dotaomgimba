//===========================================================================
// OMGAIStrategy.j  --  Dota OMG 超级 AI 竞赛级战术意识层
//   对应方案：§6A（流派识别 / 团战定位 / 秒人判定 / 蹲人针对 / 视野博弈）
//   依赖：OMGAICore（BEH_* 常量/主表/时间源）, OMGAILog, OMGAIEnemyState, OMGAITargetSel
//   设计原则：战术层不改行为层代码----通过"desire 修正因子 + 高优通道 +
//   站位点写入 + 目标覆盖"起作用。行为层照旧跑，战术层决定优先级。
//===========================================================================

library OMGAIStrategy requires OMGAICore, OMGAILog, OMGAIEnemyState, OMGAITargetSel

//---------------------------------------------------------------------------
// 1. 流派与定位常量（§6A.1 / 6A.2）
//---------------------------------------------------------------------------

    // 技能流派标签（位图，挂在 SkillPool 配表新增字段）
    globals
    constant integer ARCH_PHYSICAL = 1    // 物理位：攻击/攻速/暴击/吸血
    constant integer ARCH_MAGIC    = 2    // 法术位：魔法爆发/范围伤害/多重施法
    constant integer ARCH_CONTROL  = 4    // 控制位：眩晕/沉默/减速/缠绕
    constant integer ARCH_SURVIVE  = 8    // 生存位：减伤/回血/魔免/位移
    constant integer ARCH_UTILITY  = 16   // 功能位：召唤/推塔/视野

    // 流派（4+2 聚合结果）
    constant integer BUILD_PHYS    = 1    // 物理流
    constant integer BUILD_MAGIC   = 2    // 法核流
    constant integer BUILD_TANK    = 3    // 肉盾流
    constant integer BUILD_CTRL    = 4    // 控制辅助流
    constant integer BUILD_MIXED   = 5    // 混合（无强倾向）

    // 团战定位（§6A.2）
    constant integer ROLE_VANGUARD = 1    // 前排卖
    constant integer ROLE_DPS      = 2    // 中排输出
    constant integer ROLE_NUKER    = 3    // 中后排法核
    constant integer ROLE_SUPPORT  = 4    // 后排辅助

    // 蹲人状态机（§6A.4）
    constant integer AMBUSH_IDLE      = 0  // 大哥不可见：收敛暴露度
    constant integer AMBUSH_WAIT      = 1  // 待命视野盲区
    constant integer AMBUSH_ENGAGE    = 2  // 大哥出现：集火
    constant integer AMBUSH_PRESS     = 3  // 大哥残血：压杀

    // 阈值
    constant real  BURST_MULT        = 1.10   // 秒人：爆发 ≥ 血量×1.1
    constant real  SECURE_DESIRE_BONUS = 0.50  // 秒人/蹲人 desire 注入
    constant real  VANGUARD_RANGE    = 400.0  // 前排距敌方主力距离
    constant real  DPS_RANGE         = 600.0  // 中排距敌方主力距离
    constant real  KEY_HERO_HP_PRESS = 0.30   // 大哥残血压杀阈值

//---------------------------------------------------------------------------
// 2. 流派识别（§6A.1）
//    技能标签由 SkillPool 配表提供（新增字段），本库做 4+2 聚合
//    数据：主键=英雄 hid，槽 80=流派，槽 81..85=5 类标签计数
//---------------------------------------------------------------------------

    // 读取技能流派标签（SkillPool 配表新增字段，TODO 对接）
    endglobals
//---------------------------------------------------------------------------
// 8. 工具（1.27 兼容位测试：JASS 无位运算符，用取模法测位）
//---------------------------------------------------------------------------

    // 判断 value 的 bit 位是否置位（bit = 1/2/4/8/16...）
    private function BitIsSet takes integer value, integer bit returns boolean
        // 例：value=6(110), bit=4(100) → Modulo(6,8)=6 ≥ 4 → true
        return ModuloInteger(value, bit * 2) >= bit
    endfunction
    public function OMGAI_GetSkillArchetype takes integer abilityId returns integer
        // TODO: 对接 SkillPool 配表 arch 字段
        return 0
    endfunction

    // 4+2 聚合：遍历英雄已学技能，累加标签 → 取 max 归流派
    public function OMGAI_ComputeBuild takes unit u returns integer
        local integer hid = GetHandleId(u)
        local integer i = 0
        local integer abilityId = 0
        local integer arch = 0
        local integer phys = 0
        local integer magic = 0
        local integer ctrl = 0
        local integer surv = 0
        // 遍历技能槽（技能槽位：TODO 用既有 SkillPool 的已学技能枚举）
        loop
            exitwhen i >= 6  // 4+2 = 6 个技能
            set abilityId = 0 // TODO: 从英雄技能槽取第 i 个技能
            if abilityId != 0 then
                set arch = OMGAI_GetSkillArchetype(abilityId)
                if BitIsSet(arch, ARCH_PHYSICAL) then
                    set phys = phys + 1
                endif
                if BitIsSet(arch, ARCH_MAGIC) then
                    set magic = magic + 1
                endif
                if BitIsSet(arch, ARCH_CONTROL) then
                    set ctrl = ctrl + 1
                endif
                if BitIsSet(arch, ARCH_SURVIVE) then
                    set surv = surv + 1
                endif
            endif
            set i = i + 1
        endloop
        // 聚合评分（§6A.1：物理流 / 法核流 / 肉盾流 / 控制流）
        call OMGAICore_OMGAI_SaveInt(hid, 81, phys)
        call OMGAICore_OMGAI_SaveInt(hid, 82, magic)
        call OMGAICore_OMGAI_SaveInt(hid, 83, ctrl)
        call OMGAICore_OMGAI_SaveInt(hid, 84, surv)
        if phys >= 2 and ctrl <= 0 then
            call OMGAICore_OMGAI_SaveInt(hid, 80, BUILD_PHYS)
            return BUILD_PHYS
        elseif magic >= 2 and ctrl >= 1 then
            call OMGAICore_OMGAI_SaveInt(hid, 80, BUILD_MAGIC)
            return BUILD_MAGIC
        elseif surv >= 2 then
            call OMGAICore_OMGAI_SaveInt(hid, 80, BUILD_TANK)
            return BUILD_TANK
        elseif ctrl >= 2 then
            call OMGAICore_OMGAI_SaveInt(hid, 80, BUILD_CTRL)
            return BUILD_CTRL
        endif
        call OMGAICore_OMGAI_SaveInt(hid, 80, BUILD_MIXED)
        return BUILD_MIXED
    endfunction

    public function OMGAI_GetBuild takes unit u returns integer
        return OMGAICore_OMGAI_LoadInt(GetHandleId(u), 80)
    endfunction

    // 流派 → 出装矩阵列选择（§4.6 三维矩阵的"流派"维，TODO 对接装备决策表）
    public function OMGAI_BuildItemColumn takes unit u returns integer
        local integer b = OMGAI_GetBuild(u)
        if b == BUILD_PHYS then
            return 1
        endif
        if b == BUILD_MAGIC then
            return 2
        endif
        if b == BUILD_TANK then
            return 3
        endif
        if b == BUILD_CTRL then
            return 4
        endif
        return 0
    endfunction

//---------------------------------------------------------------------------
// 3. 团战定位（§6A.2）
//    定位分配：按 流派+职业 → VANGUARD/DPS/NUKER/SUPPORT
//    数据：主键=英雄 hid，槽 86=定位
//---------------------------------------------------------------------------

    public function OMGAI_AssignRole takes unit u returns integer
        local integer b = OMGAI_GetBuild(u)
        local integer role = ROLE_DPS
        if b == BUILD_TANK then
            set role = ROLE_VANGUARD
        elseif b == BUILD_MAGIC then
            set role = ROLE_NUKER
        elseif b == BUILD_CTRL then
            set role = ROLE_SUPPORT
        elseif b == BUILD_PHYS then
            set role = ROLE_DPS
        else
            // 混合：按英雄职业模型（TODO: 既有 SkillProfile classId）
            set role = ROLE_DPS
        endif
        call OMGAICore_OMGAI_SaveInt(GetHandleId(u), 86, role)
        return role
    endfunction

    public function OMGAI_GetRole takes unit u returns integer
        return OMGAICore_OMGAI_LoadInt(GetHandleId(u), 86)
    endfunction

    // 站位点计算：相对敌方主力方向取距离（写入目标缓存，行为层优先走向）
    public function OMGAI_ComputeStandPos takes unit u, unit enemyCore returns real
        // TODO: 返回站位距离（VANGUARD=400 / DPS=600 / NUKER=施法距离边缘 / SUPPORT=更远）
        return 0.0
    endfunction

    // 团战 desire 修正：肉盾/辅助在团战中不轻易撤退（保前排）
    public function OMGAI_RoleDesireBias takes unit u, integer behaviorId returns real
        local integer role = OMGAI_GetRole(u)
        // VANGUARD 在撤退行为上降 desire（肉上去卖不跑）
        if behaviorId == BEH_RETREAT and role == ROLE_VANGUARD then
            return -0.4
        endif
        // SUPPORT 在团战中保核心（撤退 desire 升）
        if behaviorId == BEH_RETREAT and role == ROLE_SUPPORT then
            return 0.2
        endif
        return 0.0
    endfunction

//---------------------------------------------------------------------------
// 4. 秒人判定（§6A.3）
//    爆发 ≥ 血量×1.1 → 可秒名单 → gank/团战 desire +0.5 + focusTarget 覆盖
//    数据：主键=英雄 hid，槽 87=当前可秒目标（handle id）
//---------------------------------------------------------------------------

    // 预估当前 CD 就绪的爆发伤害（TODO: 用 SkillProfile 输出技能爆发分）
    public function OMGAI_EstimateBurst takes unit u returns real
        // TODO: 遍历已学技能，CD 就绪的爆发分求和（参考 D2 物品爆发分表）
        return 0.0
    endfunction

    // 秒人判定：返回可秒目标（无则 0）
    public function OMGAI_FindKillTarget takes unit u returns integer
        local integer hid = GetHandleId(u)
        local unit target = OMGAITargetSel_OMGAI_GetClosestEnemy(u) // TODO: 从 EnemyState 取
        local real burst = 0.0
        local real hp = 0.0
        if target == null then
            call OMGAICore_OMGAI_SaveInt(hid, 87, 0)
            return 0
        endif
        set burst = OMGAI_EstimateBurst(u)
        set hp = GetUnitState(target, UNIT_STATE_LIFE)
        if burst >= hp * BURST_MULT then
            call OMGAICore_OMGAI_SaveInt(hid, 87, GetHandleId(target))
            return GetHandleId(target)
        endif
        call OMGAICore_OMGAI_SaveInt(hid, 87, 0)
        return 0
    endfunction

    // 秒人通道：desire 注入（行为层在 gank/团战 desire 后加本修正）
    public function OMGAI_KillDesireBonus takes unit u returns real
        if OMGAICore_OMGAI_LoadInt(GetHandleId(u), 87) != 0 then
            return SECURE_DESIRE_BONUS
        endif
        return 0.0
    endfunction

//---------------------------------------------------------------------------
// 5. 蹲人针对（§6A.4）
//    关键英雄 = 敌方威胁 top1（EnemyState 提供）
//    状态机：AMBUSH_IDLE（收敛）→ AMBUSH_WAIT（盲区待命）→ AMBUSH_ENGAGE（集火）→ AMBUSH_PRESS（压杀）
//    数据：主键=英雄 hid，槽 88=蹲人状态
//---------------------------------------------------------------------------

    public function OMGAI_AmbushThink takes unit u returns integer
        local integer hid = GetHandleId(u)
        local unit keyHero = OMGAIEnemyState_OMGAI_GetTopThreat()  // EnemyState 关键英雄
        local integer st = 0
        if keyHero == null then
            return AMBUSH_IDLE
        endif
        // 大哥状态判定
        if not UnitAlive(keyHero) then
            set st = AMBUSH_PRESS
        elseif IsUnitVisible(keyHero, GetOwningPlayer(u)) then
            // 大哥出现：血量？
            if GetUnitState(keyHero, UNIT_STATE_LIFE) < GetUnitState(keyHero, UNIT_STATE_MAX_LIFE) * KEY_HERO_HP_PRESS then
                set st = AMBUSH_PRESS   // 残血 → 压杀
            else
                set st = AMBUSH_ENGAGE  // 出现 → 集火
            endif
        else
            set st = AMBUSH_IDLE        // 不可见 → 收敛暴露度
        endif
        call OMGAICore_OMGAI_SaveInt(hid, 88, st)
        return st
    endfunction

    // 蹲人 desire 修正：ENGAGE/PRESS 时注入集火高优
    public function OMGAI_AmbushDesireBonus takes unit u returns real
        local integer st = OMGAICore_OMGAI_LoadInt(GetHandleId(u), 88)
        if st == AMBUSH_ENGAGE or st == AMBUSH_PRESS then
            return SECURE_DESIRE_BONUS
        endif
        return 0.0
    endfunction

    // 收敛暴露度：大哥不可见时，AI 不单独深入（对 gank/推塔 desire 降修正）
    public function OMGAI_AmbushRestraint takes unit u, integer behaviorId returns real
        local integer st = OMGAICore_OMGAI_LoadInt(GetHandleId(u), 88)
        if st == AMBUSH_IDLE then
            // 大哥不可见：gank/推塔 desire 降低（躲后边不冒进）
            if behaviorId == BEH_GANK then
                return -0.3
            endif
            if behaviorId == BEH_PUSH then
                return -0.2
            endif
        endif
        return 0.0
    endfunction

    // 针对反制：对面大哥流派 → 反向配装（TODO 对接装备决策表情境列）
    public function OMGAI_CounterBuild takes unit u returns integer
        // TODO: 读 EnemyState 大哥的 Build → 返回反制出装列
        return 0
    endfunction

//---------------------------------------------------------------------------
// 6. 视野博弈（§6A.5）
//    反眼：敌方在可疑眼位停留 → 标记 → 排队眼
//    开雾：gank/秒人集结时雾接近（TODO 对接道具系统）
//---------------------------------------------------------------------------

    // 反眼标记（主键=可疑眼位 hid，槽 92=标记时间，槽 93=可疑次数）
    public function OMGAI_MarkSuspiciousWard takes unit wardLoc, unit enemyNear returns nothing
        // TODO: 检测敌方英雄在眼位附近施放侦查技能/停留 → 标记
    endfunction

    // 排队眼（视野模块在插眼决策前调用：反眼优先级高于插己方眼）
    public function OMGAI_GetWardToDeWard takes unit u returns unit
        // TODO: 返回最近的可疑眼位
        return null
    endfunction

    // 开雾决策：gank/秒人集结 → 有雾类道具则开雾
    public function OMGAI_ShouldUseSmoke takes unit u returns boolean
        // TODO: 检测雾类道具 + 当前 gank/秒人状态
        return false
    endfunction

//---------------------------------------------------------------------------
// 7. 初始化与心跳挂接
//---------------------------------------------------------------------------

    // 开局：给所有 AI 英雄算流派 + 分配定位（地图 AI 英雄生成后调用）
    public function OMGAI_StrategyInitHero takes unit u returns nothing
        call OMGAI_ComputeBuild(u)
        call OMGAI_AssignRole(u)
        call OMGAILog_LOG_INFO("STRAT", "英雄战术初始化: build=" + I2S(OMGAI_GetBuild(u)) + " role=" + I2S(OMGAI_GetRole(u)))
    endfunction

    // 心跳挂接（OMGAIBehaviors 各 Desire/Think 前调用，注入修正因子）
    public function OMGAI_StrategyTick takes unit u returns nothing
        call OMGAI_FindKillTarget(u)      // 秒人判定（每 tick 更新可秒名单）
        call OMGAI_AmbushThink(u)         // 蹲人状态机
    endfunction

    public function OMGAIStrategy_Init takes nothing returns nothing
        call OMGAILog_LOG_INFO("STRAT", "OMGAIStrategy 战术意识层初始化完成")
    endfunction


endlibrary
