// ===========================================================================
// OMGAIGlobals.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 全局变量（运行时状态）
// 技术方案 T01 基础设施
// ---------------------------------------------------------------------------
// 设计原则：
//   * vcccv 现有 war3map.j 已有大量全局（PlayerSkillIndices 等），不修改其结构
//   * 本文件仅放 OMGAI 新增的运行时句柄与计数器
//   * 模块内的 struct 实例放 struct 内部，不放此处
// ===========================================================================
library OMGAIGlobals requires OMGAIConfig

    globals

        // ---- 平台检测结果（OMGAIPlatformFactory.init 后填充）-----------------
        integer OMGAI_CurrentPlatform       = OMGAI_PLATFORM_UNKNOWN
        boolean OMGAI_IsCommercialEnabled   = false        // 商业化是否启动（11平台 false）

        // ---- 模块初始化状态 -------------------------------------------------
        boolean OMGAI_Initialized           = false

        // ---- 主心跳定时器句柄 -----------------------------------------------
        timer OMGAI_MainTimer               = null
        integer OMGAI_TickCount             = 0          // 总心跳计数（10Hz，约 0.1s/tick）

        // ---- 事件分发器句柄（OMGAIEventDispatcher 用）-----------------------
        trigger array OMGAI_EventTriggers    // 每个事件类型一个 trigger（OMGAI_EVT_*，上限 32）

        // ---- 选技能阶段超时句柄 ---------------------------------------------
        timer OMGAI_SelectPhaseTimer        = null
        boolean OMGAI_SelectPhaseTimedOut   = false

        // ---- AI 心跳注册表 --------------------------------------------------
        // 每个 AI 单位注册一个 heartbeat，watchdog 周期检查
        unit   array OMGAI_AIUnits           // index 1..24
        real   array OMGAI_AIHeartbeats      // 上次心跳时间戳
        integer OMGAI_AICount                = 0

        // ---- 内存泄漏审计 ---------------------------------------------------
        integer OMGAI_HandleCreated         = 0     // 开发期统计
        integer OMGAI_HandleDestroyed      = 0
        integer OMGAI_LeakCheckCounter      = 0

        // ---- 调试与崩溃日志 ------------------------------------------------
        integer OMGAI_ErrorCount            = 0
        string array OMGAI_LastErrors      // 环形缓冲，最近 8 条
        integer OMGAI_LastErrorIndex        = 0

    endglobals

endlibrary