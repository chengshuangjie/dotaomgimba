//===========================================================================
// OMGAIBehaviors.j  --  Dota OMG 超级 AI 8 个行为模块
//   对应方案：§6（Desire 公式 + Think 状态机 + 阈值表）
//   依赖：OMGAICore, OMGAILog, OMGAISpellCast, OMGAITargetSel, OMGAIActionMask
//   每个模块 = OMGAI_Desire<X>(unit)→real + OMGAI_Think<X>(unit)
//   阈值集中在文件头常量区（调参入口 OMGAIConfig）
//===========================================================================

library OMGAIBehaviors requires OMGAICore, OMGAILog, OMGAISpellCast, OMGAITargetSel, OMGAIActionMask

//---------------------------------------------------------------------------
// 0. 阈值常量（集中可调）
//---------------------------------------------------------------------------

    // 对线（§6.1）
    globals
    constant real FARM_DESIRE_BASE   = 0.50
    constant real DENY_HP_THRESHOLD  = 0.49  // 反补阈值（D2 OpenHyperAI:160）
    constant real DANGER_HERO_RANGE  = 800.0
    // 打野（§6.2）
    constant real JUNGLE_WINDOW_MIN  = 6.0   // 分钟
    constant real JUNGLE_WINDOW_MAX  = 10.0
    // gank（§6.3）
    constant real GANK_TARGET_HP     = 0.50
    // 推塔（§6.4）
    constant real PUSH_BASE          = 0.20
    constant real PUSH_TIME_START    = 12.0
    // 团战（§6.5）
    constant real TEAM_FIGHT_COUNT   = 5
    // 撤退（§6.6）
    constant real RETREAT_HP_PCT     = 0.25
    constant real RETREAT_ENEMY_RANGE = 600.0
    // 回家补给（§5.3 硬状态用）
    constant real HOME_HP_PCT        = 0.25
    constant real HOME_MANA_PCT      = 0.15

//---------------------------------------------------------------------------
// 1. 对线 Farm（§6.1）
//    状态机 LANE→PUSH→DEFEND；Desire = 基础 + 小兵权重 - 危险修正
//---------------------------------------------------------------------------

    endglobals
    public function OMGAI_DesireFarm takes unit u returns real
        local real d = FARM_DESIRE_BASE
        // 敌方小兵可补数 × 0.05（TODO: 遍历线上小兵计数）
        // 己方小兵数 × 0.02
        // 危险修正：敌英雄 800 内且我方劣势 → 降 desire
        // TODO: 用 EnemyState 计算
        return d
    endfunction

    public function OMGAI_ThinkFarm takes unit u returns nothing
        // TODO: FSM LANE/PUSH/DEFEND
        // 补刀：预估伤害 ≥ 目标当前血量（前摇+弹道补偿 t=2.0*attackPoint+dist/moveSpeed）
        // 反补：己方小兵 < 49% → 攻击己方小兵
        // 卡兵：开局 30s 兵线切线拟合
        // 走位防抖：目标点变化 < 120 码不改命令
        // 消耗：按距离带选技能（近/中/远三档）
        call OMGAILog_LOG_DEBUG("BEH", "Farm Think")
    endfunction

//---------------------------------------------------------------------------
// 2. 打钱/打野（§6.2）
//    TRAVELLING→NEAR→FARMING→STACKING；每分钟 :55 堆野事件
//---------------------------------------------------------------------------

    public function OMGAI_DesireJungle takes unit u returns real
        local real d = 0.0
        local real t = OMGAICore_OMGAI_GetGameTime() / 60.0
        // 6~10 分钟野区黄金期 → 提升
        if t >= JUNGLE_WINDOW_MIN and t <= JUNGLE_WINDOW_MAX then
            set d = 0.4
        endif
        // 神符争夺：刷新倒计时 <30s 且距离 <5000 → +0.3
        // TODO: Rune 时间窗
        return d
    endfunction

    public function OMGAI_ThinkJungle takes unit u returns nothing
        // TODO: TRAVELLING→NEAR→FARMING→STACKING 状态机（D2 adam3q）
        call OMGAILog_LOG_DEBUG("BEH", "Jungle Think")
    endfunction

//---------------------------------------------------------------------------
// 3. Gank（§6.3）
//    Desire 四条件：战力差门槛 / 落单(1200 码队友≤1) / 可见 / 70% 随机命中
//    Think：ASSEMBLE→ROAMING→目标丢失5s重算
//---------------------------------------------------------------------------

        public function OMGAI_DesireGank takes unit u returns real
        local unit target = OMGAICore_OMGAI_LoadUnitHandle(GetHandleId(u), 94)
        local real d = 0.0
        if target == null then
            return 0.0
        endif
        // 有秒杀目标（FindKillTarget 已判残血+爆发够）→ 基础 0.7
        set d = 0.7
        // 落单 + 0.2
        if OMGAITargetSel_OMGAI_IsLoneEnemy(target) then
            set d = d + 0.2
        endif
        // 随机命中（70%）
        if GetRandomInt(1, 100) > 70 then
            set d = 0.0
        endif
        return d
    endfunction

        public function OMGAI_ThinkGank takes unit u returns nothing
        local unit target = OMGAITargetSel_OMGAI_GetFocusTarget(u)
        local integer hid = GetHandleId(u)
        local real now = OMGAICore_OMGAI_GetGameTime()
        local real last = OMGAICore_OMGAI_LoadReal(hid, 95)
        if target == null then
            return
        endif
        if now - last < 0.6 then
            return
        endif
        call OMGAICore_OMGAI_SaveReal(hid, 95, now)
        // 已在攻击目标则不发新命令（避免打断基图 AI）
        if GetUnitCurrentOrder(u) != OrderId("smart") then
            call IssueTargetOrder(u, "smart", target)
            call OMGAILog_LOG_WARN("GANK", "集火 " + I2S(GetUnitTypeId(target)) + " hp%=" + R2S(GetUnitState(target, UNIT_STATE_LIFE) / GetUnitState(target, UNIT_STATE_MAX_LIFE)))
        endif
    endfunction

//---------------------------------------------------------------------------
// 4. 推塔/防守（§6.4）
//---------------------------------------------------------------------------

    public function OMGAI_DesirePush takes unit u returns real
        local real d = PUSH_BASE
        local real t = OMGAICore_OMGAI_GetGameTime() / 60.0
        // 12 分钟后随时间线性增长
        if t > PUSH_TIME_START then
            set d = d + (t - PUSH_TIME_START) * 0.01
        endif
        // 塔/兵营/经济差逐项加减（TODO）
        if d > 0.8 then
            set d = 0.8
        endif
        return d
    endfunction

    public function OMGAI_ThinkPush takes unit u returns nothing
        // TODO: 推线加权打分取最高路（D2 GetCommonPushLaneDesires）
        call OMGAILog_LOG_DEBUG("BEH", "Push Think")
    endfunction

    public function OMGAI_DesireDefend takes unit u returns real
        // TODO: 己方塔被攻击 → 求援事件触发高 desire
        return 0.0
    endfunction

    public function OMGAI_ThinkDefend takes unit u returns nothing
        // TODO: DEFEND_Tower→ClearWave→Return 状态机（D1 aiDefTowerAttack）
        call OMGAILog_LOG_DEBUG("BEH", "Defend Think")
    endfunction

//---------------------------------------------------------------------------
// 5. 团战（§6.5）
//---------------------------------------------------------------------------

        public function OMGAI_DesireTeam takes unit u returns real
        if OMGAICore_OMGAI_LoadInt(GetHandleId(u), 93) == 1 then
            return 1.0
        endif
        return 0.0
    endfunction

        public function OMGAI_ThinkTeam takes unit u returns nothing
        local unit target = OMGAITargetSel_OMGAI_GetFocusTarget(u)
        local integer hid = GetHandleId(u)
        local integer role = OMGAICore_OMGAI_LoadInt(hid, 86)
        local real now = OMGAICore_OMGAI_GetGameTime()
        local real last = OMGAICore_OMGAI_LoadReal(hid, 96)
        local real want = 600.0
        local real dx = 0.0
        local real dy = 0.0
        local real dist = 0.0
        if now - last < 1.0 then
            return
        endif
        call OMGAICore_OMGAI_SaveReal(hid, 96, now)
        // 按角色站位：坦克(2)贴前 / 近战(1)中 / 法师辅助(3/4)拉后 / 其他中
        if role == 2 then
            set want = 350.0
        elseif role == 1 then
            set want = 450.0
        elseif role == 3 or role == 4 then
            set want = 800.0
        endif
        if target != null then
            set dx = GetUnitX(u) - GetUnitX(target)
            set dy = GetUnitY(u) - GetUnitY(target)
            set dist = SquareRoot(dx * dx + dy * dy)
            if dist > want + 200.0 and dist > 1.0 then
                // 太远：向目标靠近到 want 距离
                call IssuePointOrder(u, "move", GetUnitX(target) + dx / dist * want, GetUnitY(target) + dy / dist * want)
            elseif dist < want - 200.0 and dist > 1.0 then
                // 太近：后撤拉开
                call IssuePointOrder(u, "move", GetUnitX(u) + dx / dist * 250.0, GetUnitY(u) + dy / dist * 250.0)
            endif
            // 集火
            if GetUnitCurrentOrder(u) != OrderId("smart") then
                call IssueTargetOrder(u, "smart", target)
            endif
        endif
        call OMGAILog_LOG_WARN("TEAM", "团战站位 role=" + I2S(role) + " want=" + R2S(want))
    endfunction

//---------------------------------------------------------------------------
// 6. 撤退（§6.6）
//---------------------------------------------------------------------------

    public function OMGAI_DesireRetreat takes unit u returns real
        local real hpPct = 0.0
        set hpPct = GetUnitState(u, UNIT_STATE_LIFE) / GetUnitState(u, UNIT_STATE_MAX_LIFE)
        if hpPct < RETREAT_HP_PCT then
            return 1.0
        endif
        // TODO: 敌方威胁 top1 距 < 300 且我方血 < 40%
        return 0.0
    endfunction

        public function OMGAI_ThinkRetreat takes unit u returns nothing
        local integer hid = GetHandleId(u)
        local real now = OMGAICore_OMGAI_GetGameTime()
        local real last = OMGAICore_OMGAI_LoadReal(hid, 97)
        local player p = GetOwningPlayer(u)
        local real fx = 0.0
        local real fy = 0.0
        if now - last < 2.0 then
            return
        endif
        call OMGAICore_OMGAI_SaveReal(hid, 97, now)
        set fx = GetStartLocationX(GetPlayerStartLocation(p))
        set fy = GetStartLocationY(GetPlayerStartLocation(p))
        // 死亡或已回家则不重复发命令
        if not UnitAlive(u) then
            return
        endif
        if GetUnitCurrentOrder(u) != OrderId("move") or OMGAICore_OMGAI_LoadInt(hid, 97) == 0 then
            call IssuePointOrder(u, "move", fx, fy)
            call OMGAILog_LOG_WARN("RETR", "低血撤退 hp%=" + R2S(GetUnitState(u, UNIT_STATE_LIFE) / GetUnitState(u, UNIT_STATE_MAX_LIFE)))
        endif
    endfunction

//---------------------------------------------------------------------------
// 7. 视野/插眼（§6.7）
//---------------------------------------------------------------------------

        public function OMGAI_DesireWard takes unit u returns real
        local real now = OMGAICore_OMGAI_GetGameTime()
        local real last = OMGAICore_OMGAI_LoadReal(GetHandleId(u), 98)
        if now - last < 60.0 then
            return 0.0
        endif
        return 0.1
    endfunction

        public function OMGAI_ThinkWard takes unit u returns nothing
        local integer hid = GetHandleId(u)
        local real now = OMGAICore_OMGAI_GetGameTime()
        local real last = OMGAICore_OMGAI_LoadReal(hid, 98)
        if now - last < 60.0 then
            return
        endif
        call OMGAICore_OMGAI_SaveReal(hid, 98, now)
        // 反眼：Strategy 标记的可疑眼位（槽 92）→ 日志提示
        if OMGAICore_OMGAI_LoadInt(hid, 92) != 0 then
            call OMGAILog_LOG_WARN("WARD", "反眼：可疑眼位已标记，待真眼反制")
        endif
        // 视野检查（基图守卫物品对接后续版本，先记日志）
        call OMGAILog_LOG_WARN("WARD", "视野窗口：插眼/反眼巡检")
    endfunction

//---------------------------------------------------------------------------
// 8. 工具
//---------------------------------------------------------------------------


    public function OMGAI_BehaviorsInit takes nothing returns nothing
        call OMGAILog_LOG_INFO("BEH", "OMGAIBehaviors 初始化完成")
    endfunction

endlibrary
