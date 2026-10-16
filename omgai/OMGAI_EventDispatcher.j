// ===========================================================================
// OMGAIEventDispatcher.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 内部事件总线
// 技术方案 T01 基础设施
// ---------------------------------------------------------------------------
// 设计：
//   * 用 trigger 数组按事件类型注册（OMGAI_EventTriggers[OMGAI_EVT_*]）
//   * fireEvent 触发对应 trigger，把 payload 通过全局变量传递
//   * payload 用 OMGAI_EvtPayload* 全局变量传值（vJASS 限制：trigger 不能带参）
//   * 注册与触发均线程安全（JASS 单线程，无需锁）
// ===========================================================================
library OMGAIEventDispatcher requires OMGAIConfig, OMGAIGlobals, OMGAILogger

    // ---- Payload 全局变量（事件触发前填充，回调中读取）-----------------------
    globals
        integer OMGAI_EvtPayloadInt1   = 0
        integer OMGAI_EvtPayloadInt2   = 0
        unit   OMGAI_EvtPayloadUnit    = null
        player OMGAI_EvtPayloadPlayer = null
        string OMGAI_EvtPayloadStr    = ""
    endglobals

    // 注册事件回调
    // eventType - OMGAI_EVT_*
    // callback  - 一个 takes nothing returns nothing 的函数
    public function On takes integer eventType, code callback returns nothing
        if eventType < 1 or eventType > 31 then
            call OMGAILogger_E("EvtDisp", "On: invalid eventType=" + I2S(eventType))
            return
        endif
        if OMGAI_EventTriggers[eventType] == null then
            set OMGAI_EventTriggers[eventType] = CreateTrigger()
        endif
        call TriggerAddCondition(OMGAI_EventTriggers[eventType], Condition(callback))
    endfunction

    // 触发事件（payload 在调用前填入全局变量）
    public function Fire takes integer eventType returns nothing
        if eventType < 1 or eventType > 31 then
            call OMGAILogger_E("EvtDisp", "Fire: invalid eventType=" + I2S(eventType))
            return
        endif
        if OMGAI_EventTriggers[eventType] == null then
            return
        endif
        call TriggerEvaluate(OMGAI_EventTriggers[eventType])
    endfunction

    // 清空 payload（回调结束后调用，避免脏读）
    public function ClearPayload takes nothing returns nothing
        set OMGAI_EvtPayloadInt1   = 0
        set OMGAI_EvtPayloadInt2   = 0
        set OMGAI_EvtPayloadUnit    = null
        set OMGAI_EvtPayloadPlayer = null
        set OMGAI_EvtPayloadStr    = ""
    endfunction

endlibrary