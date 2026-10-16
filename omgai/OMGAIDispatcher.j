//===========================================================================
// OMGAIDispatcher.j  --  Dota OMG 超级 AI 调度器（大脑）
//   对应方案：§5（心跳 / desire 竞选 / 硬规则 / 发呆看门狗）
//   依赖：OMGAICore, OMGAILog, OMGAIGuard, OMGAIBehaviors
//   架构：L1 决策引擎。每个行为模块注册 GetDesire → 竞选取 max → Think
//   注意：8 个行为 Desire/Think 的真实实现在 OMGAIBehaviors.j，
//   Dispatcher 通过 require OMGAIBehaviors 直接调用（不再定义桩函数，防重复定义）。
//===========================================================================

library OMGAIDispatcher requires OMGAICore, OMGAILog, OMGAIGuard, OMGAIBehaviors, OMGAIStrategy

//---------------------------------------------------------------------------
// 1. 行为派发表（behaviorId → desire/think，函数来自 OMGAIBehaviors.j）
//---------------------------------------------------------------------------

    private function OMGAI_DispatchDesire takes integer b, unit u returns real
        if b == BEH_FARM then
            return OMGAIBehaviors_OMGAI_DesireFarm(u)
        elseif b == BEH_JUNGLE then
            return OMGAIBehaviors_OMGAI_DesireJungle(u)
        elseif b == BEH_GANK then
            return OMGAIBehaviors_OMGAI_DesireGank(u)
        elseif b == BEH_PUSH then
            return OMGAIBehaviors_OMGAI_DesirePush(u)
        elseif b == BEH_DEFEND then
            return OMGAIBehaviors_OMGAI_DesireDefend(u)
        elseif b == BEH_TEAM then
            return OMGAIBehaviors_OMGAI_DesireTeam(u)
        elseif b == BEH_RETREAT then
            return OMGAIBehaviors_OMGAI_DesireRetreat(u)
        elseif b == BEH_WARD then
            return OMGAIBehaviors_OMGAI_DesireWard(u)
        endif
        return 0.0
    endfunction

    private function OMGAI_DispatchThink takes integer b, unit u returns nothing
        if b == BEH_FARM then
            call OMGAIBehaviors_OMGAI_ThinkFarm(u)
        elseif b == BEH_JUNGLE then
            call OMGAIBehaviors_OMGAI_ThinkJungle(u)
        elseif b == BEH_GANK then
            call OMGAIBehaviors_OMGAI_ThinkGank(u)
        elseif b == BEH_PUSH then
            call OMGAIBehaviors_OMGAI_ThinkPush(u)
        elseif b == BEH_DEFEND then
            call OMGAIBehaviors_OMGAI_ThinkDefend(u)
        elseif b == BEH_TEAM then
            call OMGAIBehaviors_OMGAI_ThinkTeam(u)
        elseif b == BEH_RETREAT then
            call OMGAIBehaviors_OMGAI_ThinkRetreat(u)
        elseif b == BEH_WARD then
            call OMGAIBehaviors_OMGAI_ThinkWard(u)
        endif
    endfunction

//---------------------------------------------------------------------------
// 3. 硬规则状态机（死亡/回家/买活/集结/掉线接管）---- 高优短路
//    对应方案 §5.3
//---------------------------------------------------------------------------

    private function OMGAI_HardState takes unit u returns integer
        local integer hid = GetHandleId(u)
        // 死亡
        if not UnitAlive(u) then
            return ST_DEAD
        endif
        // 掉线接管（由外部标记，槽 70）
        if OMGAICore_OMGAI_LoadBool(hid, 70) then
            return ST_TAKEOVER
        endif
        // 集结等待（复活后 8s 内，由外部设置，槽 71）
        if OMGAICore_OMGAI_LoadBool(hid, 71) then
            return ST_ASSEMBLE
        endif
        // 回家补给（血 < 25% 或 蓝 < 15%，无战斗）
        // TODO: 战斗状态判断（OMGAIEnemyState 提供）
        if GetUnitState(u, UNIT_STATE_LIFE) < GetUnitState(u, UNIT_STATE_MAX_LIFE) * 0.25 then
            return ST_HOME
        endif
        // 买活（死亡且队友团战，由外部决定，槽 72）
        if OMGAICore_OMGAI_LoadBool(hid, 72) then
            return ST_BUYBACK
        endif
        return 0
    endfunction

    private function OMGAI_RunHardState takes unit u, integer st returns nothing
        if st == ST_HOME then
            // 回泉水
            // TODO: 寻路到己方泉水坐标（OMGAIConfig 提供）
            call OMGAILog_LOG_INFO("DISP", "回家补给")
        elseif st == ST_ASSEMBLE then
            // 等队友到齐（集合点坐标）
            // TODO: 集结逻辑（队友到位后清标记）
            call OMGAILog_LOG_INFO("DISP", "集结等待")
        elseif st == ST_TAKEOVER then
            // 掉线接管：正常 AI 逻辑但装备锁定（由 SpellCast 检查）
            // TODO(骨架): 接管单位触发完整 tick（解除循环依赖，后续用事件/队列接入）
        elseif st == ST_BUYBACK then
            // TODO: 买活并回战场
            call OMGAICore_OMGAI_SaveBool(GetHandleId(u), 72, false)
        endif
    endfunction

//---------------------------------------------------------------------------
// 4. desire 竞选器（核心，方案 §5.2）
//---------------------------------------------------------------------------

    private function OMGAI_SelectBehavior takes unit u returns nothing
        local integer hid = GetHandleId(u)
        local integer b = 0
        local integer best = 0
        local real maxD = 0.0
        local real d = 0.0
        local real curD = 0.0
        local real now = 0.0

        // 遍历 8 个行为取 max
        set b = BEH_FARM
        loop
            set d = OMGAI_DispatchDesire(b, u)
            if d > maxD then
                set maxD = d
                set best = b
            endif
            set b = b + 1
            exitwhen b > BEH_WARD
        endloop

        // 防抖：当前行为 desire 高于新 max×0.85 且距切换 < 0.8s → 保持
        set curD = OMGAICore_OMGAI_LoadReal(hid, 1)
        set now = OMGAICore_OMGAI_GetGameTime()
        if OMGAICore_OMGAI_LoadInt(hid, 0) > 0 then
            if curD >= maxD * (1.0 - DESIRE_HYSTERESIS) and (now - OMGAICore_OMGAI_LoadReal(hid, 2)) < BEHAVIOR_MIN_HOLD then
                return
            endif
        endif

        // 切换行为
        call OMGAICore_OMGAI_SaveInt(hid, 0, best)
        call OMGAICore_OMGAI_SaveReal(hid, 1, maxD)
        call OMGAICore_OMGAI_SaveReal(hid, 2, now)
        call OMGAILog_LOG_DEBUG("DISP", "行为切换 → " + I2S(best) + " desire=" + R2S(maxD))
    endfunction

    globals
    timer TICK_TIMER = null

//---------------------------------------------------------------------------
// 5. 发呆看门狗（坑#4：AI 可能在家挂机）
//---------------------------------------------------------------------------

    endglobals
    private function OMGAI_AntiIdle takes unit u returns nothing
        local integer hid = GetHandleId(u)
        local real now = OMGAICore_OMGAI_GetGameTime()
        // GetUnitCurrentOrder 为 0 = idle
        if GetUnitCurrentOrder(u) == 0 then
            // 距上次空闲开始
            if OMGAICore_OMGAI_LoadReal(hid, 3) == 0.0 then
                call OMGAICore_OMGAI_SaveReal(hid, 3, now)
            endif
            if now - OMGAICore_OMGAI_LoadReal(hid, 3) > IDLE_TIMEOUT then
                call OMGAILog_LOG_WARN("DISP", "发呆超时，强制换行为")
                // 强制切到对线/跟随（BEH_FARM）
                call OMGAICore_OMGAI_SaveInt(hid, 0, BEH_FARM)
                call OMGAICore_OMGAI_SaveReal(hid, 3, 0.0)
            endif
        else
            call OMGAICore_OMGAI_SaveReal(hid, 3, 0.0)
        endif
    endfunction

//---------------------------------------------------------------------------
// 6. 心跳主循环（方案 §5.1）
//---------------------------------------------------------------------------

    private function OMGAI_TickUnit takes unit u returns nothing
        local integer hid = GetHandleId(u)
        local integer st = 0
        if not UnitAlive(u) then
            return
        endif
        set st = OMGAI_HardState(u)
        if st != 0 then
            call OMGAI_RunHardState(u, st)
        else
            // V2: 战术层周期（秒杀目标/蹲守/团战标记，2s 节流在 StrategyTick 内部）
            call OMGAIStrategy_OMGAI_StrategyTick(u)
            call OMGAI_AntiIdle(u)
            call OMGAI_SelectBehavior(u)
            call OMGAI_DispatchThink(OMGAICore_OMGAI_LoadInt(hid, 0), u)
        endif
    endfunction

    private function OMGAI_Tick takes unit u returns nothing
        call OMGAI_TickUnit(u)
    endfunction

    // 全局 tick（注册单位循环）
    private function OMGAI_TickAll takes nothing returns nothing
        local integer i = 0
        local unit u = null
        loop
            exitwhen i >= MAX_AI_UNITS
            set u = OMGAICore_OMGAICore_GetUnitTable(i)
            if u != null then
                // V2.1：每 5 tick 崩溃防护巡检（简化：每单位每 tick 调一次）
                if ModuloInteger(i, 5) == 0 then
                    call OMGAIGuard_OMGAI_GuardInspect(u)
                endif
                call OMGAI_TickUnit(u)
            endif
            set i = i + 1
        endloop
        // 全局巡检（低频）
        call OMGAIGuard_OMGAI_GuardGlobalInspect()
        set u = null
    endfunction

//---------------------------------------------------------------------------
// 7. 初始化（地图初始化时调用；注册心跳 timer）
//---------------------------------------------------------------------------

    public function OMGAIDispatcher_Init takes nothing returns nothing
        call OMGAICore_OMGAICore_Init()
        set TICK_TIMER = CreateTimer()
        call TimerStart(TICK_TIMER, AI_TICK_INTERVAL, true, function OMGAI_TickAll)
        call OMGAILog_LOG_INFO("DISP", "OMGAIDispatcher 心跳启动 tick=" + R2S(AI_TICK_INTERVAL))
    endfunction

    // 外部：注册一个 AI 单位
    public function OMGAIDispatcher_RegisterAIUnit takes unit u returns nothing
        if u == null then
            return
        endif
        call OMGAICore_OMGAICore_RegisterUnit(u)
        call OMGAICore_OMGAI_SaveReal(GetHandleId(u), 2, 0.0) // switchTime 初始化
        call OMGAILog_LOG_INFO("DISP", "注册 AI 单位: " + I2S(GetHandleId(u)))
    endfunction

endlibrary
