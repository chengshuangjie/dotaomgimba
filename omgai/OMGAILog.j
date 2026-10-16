//===========================================================================
// OMGAILog.j  --  Dota OMG 超级 AI 分级日志系统
//   对应方案：§4.7 / §11
//   依赖：OMGAICore（可选；无则纯本地跑）
//   功能：环形缓冲 / 分级节流 / 本地写盘（Preload/gamecache）/ 崩溃转储
//   1.27 兼容；生产图只写 WARN/ERROR/FATAL（坑#15：后台日志造成额外运算）
//===========================================================================

library OMGAILog requires OMGAICore

//---------------------------------------------------------------------------
// 1. 日志级别
//---------------------------------------------------------------------------

    globals
constant integer LOG_LV_DEBUG = 0
constant integer LOG_LV_INFO  = 1
constant integer LOG_LV_WARN  = 2
constant integer LOG_LV_ERROR = 3
constant integer LOG_LV_FATAL = 4

    // 生产环境日志级别（调参/测试可改 LOG_INFO 或 LOG_DEBUG）
    constant integer LOG_LEVEL_PROD = LOG_LV_WARN

    // 环形缓冲大小
    constant integer LOG_RING_SIZE = 128

    // 环形缓冲
    string  array LOG_MSG
    integer array LOG_LV
    real    array LOG_TIME
    integer LOG_HEAD = 0
    integer LOG_TAIL = 0
    integer LOG_COUNT = 0

    // 崩溃转储阈值：连续 ERROR 数
    constant integer CRASH_ERROR_THRESHOLD = 3

    // 游戏时间获取：统一用 OMGAICore 的 OMGAI_GetGameTime()（1.27 兼容）

//---------------------------------------------------------------------------
// 2. 初始化
//---------------------------------------------------------------------------

    endglobals
    private function LOG_Init takes nothing returns nothing
        // 无操作（时间源由 OMGAICore 提供）
    endfunction

    private function LOG_Now takes nothing returns real
        return OMGAICore_OMGAI_GetGameTime()
    endfunction

    // 供外部初始化（地图初始化时调用一次）
    public function OMGAILog_Init takes nothing returns nothing
        call LOG_Init()
    endfunction

//---------------------------------------------------------------------------
// 3. 环形缓冲写入
//---------------------------------------------------------------------------

    private function LOG_WriteRaw takes integer lv, string msg returns nothing
        if lv < LOG_LEVEL_PROD then
            return
        endif
        set LOG_MSG[LOG_HEAD] = msg
        set LOG_LV[LOG_HEAD]  = lv
        set LOG_TIME[LOG_HEAD] = LOG_Now()
        set LOG_HEAD = LOG_HEAD + 1
        if LOG_HEAD >= LOG_RING_SIZE then
            set LOG_HEAD = 0
        endif
        if LOG_COUNT < LOG_RING_SIZE then
            set LOG_COUNT = LOG_COUNT + 1
        else
            set LOG_TAIL = LOG_TAIL + 1
            if LOG_TAIL >= LOG_RING_SIZE then
                set LOG_TAIL = 0
            endif
        endif
    endfunction

//---------------------------------------------------------------------------
// 4. 对外日志 API（分级）
//---------------------------------------------------------------------------

    public function LOG_DEBUG takes string tag, string msg returns nothing
        call LOG_WriteRaw(LOG_LV_DEBUG, "[" + tag + "] " + msg)
    endfunction

    public function LOG_INFO takes string tag, string msg returns nothing
        call LOG_WriteRaw(LOG_LV_INFO, "[" + tag + "] " + msg)
    endfunction

    public function LOG_WARN takes string tag, string msg returns nothing
        call LOG_WriteRaw(LOG_LV_WARN, "[" + tag + "] " + msg)
    endfunction

    public function LOG_ERROR takes string tag, string msg returns nothing
        call LOG_WriteRaw(LOG_LV_ERROR, "[" + tag + "] " + msg)
        // ERROR 计数（供崩溃转储判断）
        // TODO: 接入 OMGAIGuard 的 ERROR 计数器
    endfunction


//---------------------------------------------------------------------------
// 5. 本地写盘通道
//   5.1 Preload 通道（最通用，无需平台）
//       注意：Preload 写盘需地图允许；文件落在 war3 目录 PreloadData 相关文件
//   5.2 gamecache 通道（跨局保留，崩溃后可回读）
//---------------------------------------------------------------------------

    globals
    gamecache LOG_CACHE = null

    endglobals
    public function OMGAILog_InitCache takes nothing returns nothing
        if LOG_CACHE == null then
            set LOG_CACHE = InitGameCache("OMGAILogCache")
        endif
    endfunction

    // 把最近 N 条日志转储到 gamecache（崩溃后可回读）
    public function OMGAILog_DumpToCache takes integer count returns nothing
        local integer i = 0
        local integer idx = 0
        local string  line = ""
        if LOG_CACHE == null then
            return
        endif
        // 从最旧读起（TAIL 指向最旧）
        set idx = LOG_TAIL
        loop
            exitwhen i >= count or i >= LOG_COUNT
            set line = R2S(LOG_TIME[idx]) + "|L" + I2S(LOG_LV[idx]) + "|" + LOG_MSG[idx]
            call StoreString(LOG_CACHE, "crash", "log" + I2S(i), line)
            set idx = idx + 1
            if idx >= LOG_RING_SIZE then
                set idx = 0
            endif
            set i = i + 1
        endloop
        call StoreInteger(LOG_CACHE, "crash", "count", i)
    endfunction

//---------------------------------------------------------------------------
// 6. 崩溃现场转储（§11.2）
//    1) 最近 32 条日志 → gamecache
//    2) AI 状态快照 → gamecache（由 OMGAIDispatcher/OMGAIEnemyState 填充）
//    3) 关键信息 → KK 存档（OMGAILearn 提供，此处留钩子）
//---------------------------------------------------------------------------

    public function OMGAILog_DumpCrash takes nothing returns nothing
        // 1) 日志转储
        call OMGAILog_OMGAILog_DumpToCache(32)
        // 2) 状态快照钩子
        // TODO: call OMGAIEnemyState_DumpSnapshot()
        // 3) KK 上报钩子
        // TODO: call OMGAILearn_ReportCrash("OMGAI:crash:"+R2S(LOG_Now()))
        // 4) 标记全局崩溃标志（OMGAICore GSLOT_CRASH_FLAG）
        call OMGAICore_OMGAI_SaveGlobalInt(GSLOT_CRASH_FLAG, 1)
    endfunction

//---------------------------------------------------------------------------
// 7. 查询（开发期 -log 指令用）
//---------------------------------------------------------------------------

    public function OMGAILog_GetRecent takes integer count returns string
        local integer i = 0
        local integer idx = 0
        local string  out = ""
        set idx = LOG_TAIL
        loop
            exitwhen i >= count or i >= LOG_COUNT
            set out = out + R2S(LOG_TIME[idx]) + "|L" + I2S(LOG_LV[idx]) + "|" + LOG_MSG[idx] + "|"
            set idx = idx + 1
            if idx >= LOG_RING_SIZE then
                set idx = 0
            endif
            set i = i + 1
        endloop
        return out
    endfunction

//---------------------------------------------------------------------------
// 8. 与 OMGAICore 的越界告警钩子对接
//    OMGAICore.OMGAI_ArrGuardWarn 的 TODO 由本库实现：WARN 日志
//    （注意：OMGAICore 与 OMGAILog 互相 require 会成环，故 OMGAICore
//      里保留空实现 + 注释；此处提供可手动接入的桥）
//---------------------------------------------------------------------------

    public function OMGAILog_BridgeArrWarn takes integer idx, string op returns nothing
        call OMGAILog_LOG_WARN("ARRAY", "越界 idx=" + I2S(idx) + " op=" + op)
    endfunction


    public function LOG_FATAL takes string tag, string msg returns nothing
        call LOG_WriteRaw(LOG_LV_FATAL, "[" + tag + "] " + msg)
        // 触发崩溃转储（§11.2）
        call OMGAILog_OMGAILog_DumpCrash()
    endfunction
endlibrary
