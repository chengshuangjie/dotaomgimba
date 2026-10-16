//===========================================================================
// OMGAIInit.j  --  Dota OMG 超级 AI 统一初始化入口
//   用法：在工程主入口（main.j / war3map.j）中只 include 本文件即可，
//   地图初始化调用一次 OMGAI_InitAll()。
//   注意：library 之间的依赖（requires）由 vJASS 自动处理编译顺序，
//   这里显式按依赖序调用初始化函数，保证运行期数据就绪。
//===========================================================================

// 一次性 include 全部 11 个 OMGAI 新库（顺序无关，requires 自动处理）

library OMGAISuperAIInit requires OMGAICore, OMGAILog, OMGAIGuard, OMGAIActionMask, OMGAITargetSel, OMGAISpellCast, OMGAIEnemyState, OMGAIBehaviors, OMGAILearn, OMGAIDispatcher, OMGAIStrategy

//---------------------------------------------------------------------------
// 统一初始化（地图初始化时调用一次）
//   [可选] OMGAI_InitAllEx(boolean enableLearning) 可关自学习（测试期）
//---------------------------------------------------------------------------

    public function OMGAI_InitAll takes nothing returns nothing
        // 1) 核心数据（最优先）
        call OMGAICore_OMGAICore_Init()
        // 2) 日志（其余库打日志依赖它）
        call OMGAILog_OMGAILog_Init()
        call OMGAILog_OMGAILog_InitCache()
        // V2.3: 游戏内查日志指令（-omgai_log）
        call OMGAILog_OMGAILog_ChatCommandInit()
        // 3) 崩溃防护（P9 自检：失败则降档，但继续初始化，保证单局不崩全场）
        call OMGAIGuard_OMGAI_GuardInit()
        // 4) 数据/执行层
        call OMGAIActionMask_OMGAI_MaskInit()
        call OMGAITargetSel_OMGAI_TargetSelInit()
        call OMGAISpellCast_OMGAI_SpellCastInit()
        // 5) 感知层
        call OMGAIEnemyState_OMGAI_EnemyStateInit()
        // 6) 行为层
        call OMGAIBehaviors_OMGAI_BehaviorsInit()
        // 7) 战术意识层（V2.2 新增：流派/定位/秒人/蹲人/视野）
        call OMGAIStrategy_OMGAIStrategy_Init()
        // 8) 自学习（可选开关）
        call OMGAILearn_OMGAI_LearnInit()
        // 9) 调度器（最后：启动心跳）
        call OMGAIDispatcher_OMGAIDispatcher_Init()
        // 10) 必崩图自检（P9）：失败 → 本局 AI 降档保局
        if not OMGAIGuard_OMGAI_GuardSelfCheck() then
            call OMGAIGuard_OMGAI_GuardDegrade()
        endif
    endfunction

//---------------------------------------------------------------------------
// 注册一名 AI 英雄（地图生成 AI 英雄/掉线接管时调用）
//   注册后立即做战术初始化（流派识别 + 团战定位）
//---------------------------------------------------------------------------

    public function OMGAI_AddHero takes unit u returns nothing
        call OMGAIDispatcher_OMGAIDispatcher_RegisterAIUnit(u)
        call OMGAIStrategy_OMGAI_StrategyInitHero(u)
    endfunction

endlibrary
