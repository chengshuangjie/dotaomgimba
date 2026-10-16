// ===========================================================================
// OMGAIPlatformFactory.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 平台检测与抽象层入口
// 技术方案 T01 基础设施 / T03 平台抽象层
// ---------------------------------------------------------------------------
// 设计：
//   * 运行时探测 KKAPI 是否可用
//   * 探测成功 → 调用 OMGAIKKPlatformAPI.Install 注册 KK 实现
//   * 探测失败 → 调用 OMGAIPlatform11API.Install 注册 11 降级实现
// ===========================================================================
library OMGAIPlatformFactory requires OMGAIConfig, OMGAIGlobals, OMGAIIPlatformAPI, OMGAIKKPlatformAPI, OMGAILogger, OMGAIPlatform11API

    // 探测 KKAPI 是否可用
    // 简化实现：先假设 KK 可用
    // T03 后续：用 GetUnitAbilityLevel 检测 DzGetMapName 函数符号
    private function ProbeKKPlatform takes nothing returns boolean
        // 探测条件：
        //   1) DzAPI_Map_GetServerString 函数符号可用（KK 平台 memory_hack 注入）
        //   2) DzGetMapName 返回非空（11 平台不支持）
        // 占位：先假设 KK 可用
        return true
    endfunction

    public function Init takes nothing returns nothing
        if ProbeKKPlatform() then
            set OMGAI_CurrentPlatform     = OMGAI_PLATFORM_KK
            set OMGAI_IsCommercialEnabled = true
            call OMGAIKKPlatformAPI_Install()
            call OMGAILogger_I("PlatFact", "Platform=KK, commercial ON")
        else
            set OMGAI_CurrentPlatform     = OMGAI_PLATFORM_11
            set OMGAI_IsCommercialEnabled = false
            call OMGAIPlatform11API_Install()
            call OMGAILogger_I("PlatFact", "Platform=11, commercial OFF (free degrade)")
        endif
    endfunction

endlibrary