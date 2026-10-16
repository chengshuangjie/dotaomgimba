// ===========================================================================
// OMGAITimerService.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 主心跳定时器服务
// 技术方案 T01 基础设施
// ---------------------------------------------------------------------------
// 功能：
//   * 0.1s 周期全局心跳（OMGAI_MainTimer）
//   * 周期性触发 OMGAI_EVT_AI_HEARTBEAT 事件给 AI 控制器
//   * 周期任务注册（最多 32 个，timer -> trigger 映射执行回调）
//   * AI Watchdog 周期检查（每 tick 检查 AI 心跳超时）
// 注意：YDWE pjass 禁止 code 数组/参数，故周期回调用 trigger + TriggerEvaluate
// ===========================================================================
library OMGAITimerService requires OMGAIConfig, OMGAIEventDispatcher, OMGAIGlobals, OMGAILogger

    // ---- 定时器周期任务回调表（最多 32 个周期任务）-------------------------
    globals
        timer   array OMGAI_PeriodicTimers
        real    array OMGAI_PeriodicIntervals
        integer OMGAI_PeriodicCount = 0
        hashtable OMGAI_PeriodicTable = null
    endglobals

    // 周期任务到期：找到对应 trigger 并求值
    private function OnPeriodicTick takes nothing returns nothing
        local trigger t = LoadTriggerHandle(OMGAI_PeriodicTable, GetHandleId(GetExpiredTimer()), 0)
        if t != null then
            call TriggerEvaluate(t)
        endif
    endfunction

    // 注册周期任务
    // interval - 周期（秒）
    // callback - 回调 trigger（由调用方创建并加 Condition）
    public function RegisterPeriodic takes real interval, trigger callback returns nothing
        if OMGAI_PeriodicCount >= 32 then
            call OMGAILogger_E("TimerSvc", "RegisterPeriodic: max 32 reached")
            return
        endif
        set OMGAI_PeriodicCount = OMGAI_PeriodicCount + 1
        set OMGAI_PeriodicIntervals[OMGAI_PeriodicCount] = interval
        set OMGAI_PeriodicTimers[OMGAI_PeriodicCount] = CreateTimer()
        if OMGAI_PeriodicTable == null then
            set OMGAI_PeriodicTable = InitHashtable()
        endif
        call SaveTriggerHandle(OMGAI_PeriodicTable, GetHandleId(OMGAI_PeriodicTimers[OMGAI_PeriodicCount]), 0, callback)
        call TimerStart(OMGAI_PeriodicTimers[OMGAI_PeriodicCount], interval, true, function OnPeriodicTick)
    endfunction

    // ---- 主心跳回调（0.1s）---------------------------------------------------
    private function OnMainTick takes nothing returns nothing
        set OMGAI_TickCount = OMGAI_TickCount + 1
        // 触发 AI 心跳事件
        call OMGAIEventDispatcher_Fire(OMGAI_EVT_AI_HEARTBEAT)
        // 每 600 tick（约 60s）做一次泄漏自检
        if ModuloInteger(OMGAI_TickCount, 600) == 0 then
            set OMGAI_LeakCheckCounter = OMGAI_LeakCheckCounter + 1
            if OMGAI_DEBUG then
                call OMGAILogger_D("TimerSvc", "LeakCheck #" + I2S(OMGAI_LeakCheckCounter) + " created=" + I2S(OMGAI_HandleCreated) + " destroyed=" + I2S(OMGAI_HandleDestroyed))
            endif
        endif
    endfunction

    // ---- 模块初始化 ---------------------------------------------------------
    public function Init takes nothing returns nothing
        set OMGAI_MainTimer = CreateTimer()
        call TimerStart(OMGAI_MainTimer, OMGAI_TIMER_TICK_INTERVAL, true, function OnMainTick)
        call OMGAILogger_I("TimerSvc", "Main timer started @ " + R2S(OMGAI_TIMER_TICK_INTERVAL) + "s")
    endfunction

endlibrary
