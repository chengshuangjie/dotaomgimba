// ===========================================================================
// OMGAIKKPlatformAPI.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - KK 平台 API 实现（完整商业化）
// 技术方案 T03 / PRD 4.2 转技能券付费机制
// ---------------------------------------------------------------------------
// 用法：
//   * OMGAIPlatformFactory.Init 探测到 KK 后调用 OMGAIKKPlatformAPI.Install
//   * 实现代码集中在 OMGAIIPlatformAPI（YDWE jasshelper 不支持 code 指针点语法）
//   * 所有 DzAPI_* 调用都在 OMGAIIPlatformAPI 内，业务代码不直接调
// ===========================================================================
library OMGAIKKPlatformAPI requires OMGAIConfig, OMGAILogger, OMGAIIPlatformAPI

    // 注册 KK 实现（设置平台状态）
    public function Install takes nothing returns nothing
        set IPlatformAPI_Active = 1
        call OMGAILogger_I("KKPlat", "KK PlatformAPI installed")
    endfunction

endlibrary
