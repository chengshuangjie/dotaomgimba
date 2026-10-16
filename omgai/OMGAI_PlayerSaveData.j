// ===========================================================================
// OMGAIPlayerSaveData.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 玩家服务器存档数据结构（KKAPI 持久化）
// 技术方案 T03 / PRD 5.4 跨平台降级
// ---------------------------------------------------------------------------
// 字段（PRD 6.2）：
//   * totalRespinVouchers: 累计转技能券（KK 服务器存档）
//   * totalRespinUsed:    累计消耗
//   * currentVoucherBalance: 当前余额（= total - used）
//   * customSkillIds:    玩家解锁的定制技能 ID（V2.0）
//   * customHeroIds:     玩家解锁的定制英雄 ID（V2.0）
//   * stats: 战绩统计
// 设计：KK 平台调 IPlatformAPI.SaveServerData/LoadServerData
// ===========================================================================
library OMGAIPlayerSaveData requires OMGAIConfig, OMGAIIPlatformAPI, OMGAILogger

    // 用 playerId 索引
    globals
        integer array PSD_TotalRespinVouchers
        integer array PSD_TotalRespinUsed
        integer array PSD_CustomSkillCount
        integer array PSD_CustomHeroCount
        integer array PSD_Wins
        integer array PSD_Losses
    endglobals

    // 玩家进入游戏时从服务器存档加载
    public function Load takes integer playerId returns nothing
        local string val
        set val = OMGAIIPlatformAPI_LoadServerData(playerId, "psd_voucher")
        if val != null and val != "" then
            set PSD_TotalRespinVouchers[playerId] = S2I(val)
        else
            set PSD_TotalRespinVouchers[playerId] = 0
        endif

        set val = OMGAIIPlatformAPI_LoadServerData(playerId, "psd_used")
        if val != null and val != "" then
            set PSD_TotalRespinUsed[playerId] = S2I(val)
        else
            set PSD_TotalRespinUsed[playerId] = 0
        endif

        set PSD_Wins[playerId]   = 0
        set PSD_Losses[playerId] = 0
    endfunction

    // 写回存档（券变化时调用）
    public function Save takes integer playerId returns nothing
        call OMGAIIPlatformAPI_SaveServerData(playerId, "psd_voucher", I2S(PSD_TotalRespinVouchers[playerId]))
        call OMGAIIPlatformAPI_SaveServerData(playerId, "psd_used", I2S(PSD_TotalRespinUsed[playerId]))
    endfunction

    // 取当前余额
    public function GetBalance takes integer playerId returns integer
        return PSD_TotalRespinVouchers[playerId] - PSD_TotalRespinUsed[playerId]
    endfunction

    // 购买增加券数量（QuickBuy 成功事件后调用）
    public function AddVouchers takes integer playerId, integer count returns nothing
        set PSD_TotalRespinVouchers[playerId] = PSD_TotalRespinVouchers[playerId] + count
        call Save(playerId)
    endfunction

    // 消耗券
    public function UseVouchers takes integer playerId, integer count returns boolean
        if GetBalance(playerId) < count then
            return false
        endif
        set PSD_TotalRespinUsed[playerId] = PSD_TotalRespinUsed[playerId] + count
        call Save(playerId)
        return true
    endfunction

endlibrary