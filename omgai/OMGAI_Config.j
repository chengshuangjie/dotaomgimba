// ===========================================================================
// OMGAIConfig.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 全局配置常量
// 技术方案 T01 基础设施 - 配置层（数据驱动基础）
// ---------------------------------------------------------------------------
// 说明：
//   * 所有 OMGAI 模块用 OMGAI_ 前缀避免与 vcccv 现有库冲突
//   * 本文件只定义常量，不含运行时逻辑
//   * 修改行为改这里，不改业务代码（数据驱动原则）
// ===========================================================================
library OMGAIConfig

    globals
    // ---- 版本与模式 ----------------------------------------------------------
    constant string  OMGAI_VERSION               = "0.1.0-mvp"
    constant boolean OMGAI_DEBUG                 = true        // 开发期开启详细日志
    constant boolean OMGAI_CRASHLOG_ENABLED      = false       // 崩溃日志 P2 上线，先留桩

    // ---- 玩家槽位 -----------------------------------------------------------
    // 1-5 天灾，6-10 近卫（人类槽位）；11-12 留观战；16-26 AI 槽位
    constant integer OMGAI_MAX_HUMAN_PLAYERS     = 10
    constant integer OMGAI_AI_SLOT_START         = 16          // 与 vcccv 工程 AI 习惯对齐

    // ---- 4+2 技能系统（PRD 4.1.3 关键规则）----------------------------------
    constant integer OMGAI_HERO_FIXED_SKILL_COUNT = 4           // 英雄固定技能数（3小+1大）
    constant integer OMGAI_HERO_FIXED_SMALL_COUNT = 3
    constant integer OMGAI_HERO_FIXED_BIG_COUNT   = 1
    constant integer OMGAI_EXTRA_SMALL_COUNT      = 1           // 额外选 1 小
    constant integer OMGAI_EXTRA_BIG_COUNT        = 1           // 额外选 1 大
    constant integer OMGAI_TOTAL_SKILL_SLOTS      = 6           // 4小+2大 = 6 槽
    constant integer OMGAI_OFFER_COUNT            = 8           // 每次随机发 8 个

    // ---- 转技能次数（PRD 4.1.2 / 4.2）--------------------------------------
    constant integer OMGAI_FREE_RESPIN_PER_PHASE = 3           // 每阶段免费 3 次/局
    constant string  OMGAI_VOUCHER_ITEM_KEY      = "omgai_reskin_voucher"  // KK 商城道具 key

    // ---- 技能池规模（T02 起步）-----------------------------------------------
    constant integer OMGAI_SKILL_POOL_MVP_SIZE   = 80           // MVP 起步 60-80 个技能

    // ---- 时序与心跳 ---------------------------------------------------------
    constant real    OMGAI_TIMER_TICK_INTERVAL   = 0.10         // 全局心跳周期（秒）
    constant real    OMGAI_AI_HEARTBEAT_INTERVAL = 0.10         // AI 决策频率
    constant real    OMGAI_AI_WATCHDOG_TIMEOUT    = 5.00         // AI 卡死超时（借鉴竞品 -aiunstuck）
    constant real    OMGAI_SELECT_PHASE_TIMEOUT  = 120.0        // 选技能每阶段超时（秒）

    // ---- 内存与性能 ---------------------------------------------------------
    constant real    OMGAI_LEAK_CHECK_INTERVAL  = 60.0         // 内存泄漏扫描周期
    constant integer OMGAI_MAX_CONCURRENT_GAMES  = 10           // 连续运行验证局数

    // ---- 平台类型枚举（用整数代替真实 enum，避免 vJASS 限制）--------------
    constant integer OMGAI_PLATFORM_UNKNOWN     = 0
    constant integer OMGAI_PLATFORM_KK          = 1
    constant integer OMGAI_PLATFORM_11         = 2

    // ---- AI 原型枚举 --------------------------------------------------------
    constant integer OMGAI_ARCH_NONE           = 0
    constant integer OMGAI_ARCH_BURST_MAGE     = 1
    constant integer OMGAI_ARCH_TANK_CONTROL  = 2
    constant integer OMGAI_ARCH_CORE_SUSTAIN  = 3
    constant integer OMGAI_ARCH_ROAM_ASSASSIN = 4
    constant integer OMGAI_ARCH_SUPPORT_CTRL   = 5

    // ---- SelectPhase 状态枚举 ----------------------------------------------
    constant integer OMGAI_PHASE_INIT         = 0
    constant integer OMGAI_PHASE_SELECT_SMALL = 1
    constant integer OMGAI_PHASE_SELECT_BIG   = 2
    constant integer OMGAI_PHASE_DONE        = 3

    // ---- 事件类型常量（OMGAI 内部事件总线）----------------------------------
    constant integer OMGAI_EVT_SKILL_GRANTED     = 1   // 技能赋予完成
    constant integer OMGAI_EVT_RESPIN_DONE       = 2   // 转技能完成
    constant integer OMGAI_EVT_SELECT_DONE       = 3   // 整个 4+2 选技能完成
    constant integer OMGAI_EVT_AI_HEARTBEAT     = 4   // AI 心跳
    constant integer OMGAI_EVT_AI_STUCK          = 5   // AI 卡死警告
    constant integer OMGAI_EVT_UNIT_TRANSFORM    = 6   // 单位变身（守卫触发）
    constant integer OMGAI_EVT_UNIT_ILLUSION     = 7   // 单位分身（守卫触发）
    constant integer OMGAI_EVT_PURCHASE_OK       = 8   // 充值成功
    constant integer OMGAI_EVT_PURCHASE_CANCEL   = 9   // 取消充值

    // ---- KKAPI 接口探测 -----------------------------------------------------
    // 运行时若 DzAPI_Map_SaveServerData 等函数符号存在则判定为 KK 平台
    // 探测通过 try-catch（vJASS 不支持，用 SystemError 是否抛出来判定）
    // 简化方案：用内存特征检测 - DzGetClientPlayerId 在 KK 平台返回有效玩家 ID
    constant integer OMGAI_PLATFORM_PROBE_PLAYER = 0  // 占位，OMGAIPlatformFactory 运行时填充
    endglobals

endlibrary