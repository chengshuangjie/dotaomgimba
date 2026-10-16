// ===========================================================================
// OMGAILogger.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 日志与崩溃上报接口
// 技术方案 T01 基础设施
// ---------------------------------------------------------------------------
// 功能：
//   * 开发期： BJDebugMsg 屏幕实时打印 + 写入日志环形缓冲
//   * P2：崩溃日志上报（KKAPI 服务端 / Preload 文件兜底）
//   * 等级：DEBUG / INFO / WARN / ERROR / FATAL
//   * 防爆：ERROR 累计上限 50 条触发降级（仅 FATAL 通过屏幕）
// ===========================================================================
library OMGAILogger requires OMGAIConfig, OMGAIGlobals

    // ---- 日志级别常量 ------------------------------------------------------
    globals
        constant integer LL_DEBUG = 1
        constant integer LL_INFO  = 2
        constant integer LL_WARN  = 3
        constant integer LL_ERROR = 4
        constant integer LL_FATAL = 5
    endglobals

    // 把日志级别转字符串
    private function LevelToStr takes integer lvl returns string
        if lvl == LL_DEBUG then
            return "DEBUG"
        elseif lvl == LL_INFO then
            return "INFO"
        elseif lvl == LL_WARN then
            return "WARN"
        elseif lvl == LL_ERROR then
            return "ERROR"
        elseif lvl == LL_FATAL then
            return "FATAL"
        endif
        return "?"
    endfunction

    // 把日志级别转颜色（用于屏幕显示）
    private function LevelToColor takes integer lvl returns string
        if lvl == LL_DEBUG then
            return "|cff808080"          // 灰
        elseif lvl == LL_INFO then
            return "|cffc0c0c0"          // 浅灰
        elseif lvl == LL_WARN then
            return "|cffffff00"          // 黄
        elseif lvl == LL_ERROR then
            return "|cffff6060"          // 红
        elseif lvl == LL_FATAL then
            return "|cffff0000"          // 亮红
        endif
        return "|cffffffff"
    endfunction

    // 环形缓冲：写最近 8 条
    private function PushLastError takes string msg returns nothing
        set OMGAI_LastErrorIndex = ModuloInteger(OMGAI_LastErrorIndex + 1, 8)
        set OMGAI_LastErrors[OMGAI_LastErrorIndex] = msg
    endfunction

    // 主日志函数
    // level - 日志级别
    // tag   - 模块标签（如 "SkillPool"）
    // msg   - 消息
    public function Log takes integer lvl, string tag, string msg returns nothing
        local string formatted
        local string full

        // 降级：ERROR 超过 50 条后只放行 FATAL
        if lvl < LL_FATAL and OMGAI_ErrorCount >= 50 then
            return
        endif

        set formatted = "[" + LevelToStr(lvl) + "][" + tag + "] " + msg
        set full      = LevelToColor(lvl) + formatted + "|r"

        // DEBUG 仅在调试模式输出
        if lvl == LL_DEBUG and not OMGAI_DEBUG then
            return
        endif

        // ERROR/FATAL 写入环形缓冲
        if lvl >= LL_ERROR then
            set OMGAI_ErrorCount = OMGAI_ErrorCount + 1
            call PushLastError(formatted)
        endif

        // 屏幕实时打印（永远只对本地玩家）
        call BJDebugMsg(full)

        // 崩溃日志上报（P2 上线，先留桩）
        if lvl == LL_FATAL and OMGAI_CRASHLOG_ENABLED then
            // TODO P2: 接入 KKAPI 服务端 上报 或 Preload 文件兜底
        endif
    endfunction

    // 便捷封装
    public function D takes string tag, string msg returns nothing
        call Log(LL_DEBUG, tag, msg)
    endfunction
    public function I takes string tag, string msg returns nothing
        call Log(LL_INFO, tag, msg)
    endfunction
    public function W takes string tag, string msg returns nothing
        call Log(LL_WARN, tag, msg)
    endfunction
    public function E takes string tag, string msg returns nothing
        call Log(LL_ERROR, tag, msg)
    endfunction
    public function F takes string tag, string msg returns nothing
        call Log(LL_FATAL, tag, msg)
    endfunction

    // 取最近错误（用于排查）
    public function GetRecentErrors takes nothing returns string
        local string out = ""
        local integer i = 0
        loop
            exitwhen i >= 8
            if OMGAI_LastErrors[i] != null and OMGAI_LastErrors[i] != "" then
                set out = out + OMGAI_LastErrors[i] + "\n"
            endif
            set i = i + 1
        endloop
        return out
    endfunction

endlibrary