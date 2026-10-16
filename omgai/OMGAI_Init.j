// ===========================================================================
// OMGAIInit.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 模块初始化入口
// 技术方案 T01 基础设施
// ---------------------------------------------------------------------------
// 调用顺序（依赖关系）：
//   1) OMGAIPlatformFactory.Init     - 平台探测（无依赖）
//   2) OMGAITimerService.Init        - 主心跳（依赖 Logger + EventDispatcher）
//   3) 后续 T02-T05 的子模块 Init 由各模块的 initializer 自行触发
// ---------------------------------------------------------------------------
// 接入主入口：
//   由 war3map.j 的某个 init trigger 在地图加载时调用 OMGAIInit.Initialize
//   或通过 YDWE 的 initializer 机制自动调用（推荐）
// ===========================================================================
library OMGAIInit initializer OnInit requires OMGAIConfig, OMGAIEventDispatcher, OMGAIGlobals, OMGAILogger, OMGAIPlatformFactory, OMGAITimerService

    private function OnInit takes nothing returns nothing
        // 1) 日志先启动
        call OMGAILogger_I("Init", "===== OMGAI v" + OMGAI_VERSION + " init start =====")

        // 2) 平台探测
        call OMGAIPlatformFactory_Init()

        // 3) 主心跳
        call OMGAITimerService_Init()

        // 4) 标记初始化完成（后续模块检查此标记防止重入）
        set OMGAI_Initialized = true
        call OMGAILogger_I("Init", "===== OMGAI init done, platform=" + I2S(OMGAI_CurrentPlatform) + " commercial=" + B2S(OMGAI_IsCommercialEnabled) + " =====")
    endfunction

endlibrary