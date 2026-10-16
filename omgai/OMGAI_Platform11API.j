// ===========================================================================
// OMGAIPlatform11API.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 11 平台 API 实现（免费降级）
// 技术方案 T03 / PRD 5.4 跨平台降级
// ---------------------------------------------------------------------------
// 策略（PRD 4.2.3 11平台降级方案）：
//   * IsCommercialEnabled -> false
//   * GetVoucherBalance -> 999999（无限）
//   * ConsumeVoucher -> true（永远成功）
//   * QuickBuy -> false（不弹框）
//   * SaveServerData / LoadServerData -> 占位
// 实现集中在 OMGAIIPlatformAPI（YDWE jasshelper 不支持 code 指针点语法）
// ===========================================================================
library OMGAIPlatform11API requires OMGAIConfig, OMGAILogger, OMGAIIPlatformAPI

    // 注册 11 降级实现（设置平台状态）
    public function Install takes nothing returns nothing
        set IPlatformAPI_Active = 2
        call OMGAILogger_I("P11Plat", "11 PlatformAPI installed (free degrade)")
    endfunction

endlibrary
