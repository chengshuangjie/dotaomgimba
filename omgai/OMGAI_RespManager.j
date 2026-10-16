// ===========================================================================
// OMGAIRespManager.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 转技能管理器（免费 3 次 + 付费刷新）
// 技术方案 T03 / PRD 4.2 转技能券付费机制
// ---------------------------------------------------------------------------
// 流程（PRD 4.2.2 时序图）：
//   1) 查免费次数（freeRespinUsed < 3）→ 免费刷新 → used++
//   2) 否则查券余额 → 券消耗 → 刷新
//   3) 否则触发 KK QuickBuy → 实时事件回调 → 券到账 → 消耗 → 刷新
//   4) 11 平台 IsCommercialEnabled=false → 全部免费无限刷新
// ===========================================================================
library OMGAIRespManager requires OMGAIConfig, OMGAIGlobals, OMGAIHeroSkillManager, OMGAIIPlatformAPI, OMGAILogger, OMGAIPlayerSaveData, OMGAIPlayerSkillState, OMGAISkillOfferGenerator, OMGAIRespinUI
    globals
        constant integer RESKIN_SUCCESS_FREE    = 0
        constant integer RESKIN_SUCCESS_PAID     = 1
        constant integer RESKIN_FAIL_NO_VOUCHER   = 2
        constant integer RESKIN_FAIL_PURCHASE_CANCEL = 3
        constant integer RESKIN_FAIL_FREE_DEGRADED_OK = 4   // 11平台降级时也成功
    endglobals

    // 请求转技能（刷新当前阶段 offers）
    // playerId - 玩家 ID
    // 返回 RESKIN_* 枚举
    // 内部：执行刷新（重新随机 8 个）
    private function DoRefresh takes integer playerId, integer phase returns nothing
        local integer got
        local integer i

        // exclude list: fixed 4 + selected small 1 -> fill Generate input channel
        set i = 1
        loop
            exitwhen i > 4
            set OMGAI_TmpFixedRawCodes[i] = OMGAIPlayerSkillState_GetFixedSkillRawCode(playerId, i)
            set i = i + 1
        endloop
        set OMGAI_TmpExtraRawCodes[1] = PSS_ExtraSmall[playerId]

        // call SkillOfferGenerator to generate new 8 offers
        set got = OMGAISkillOfferGenerator_Generate(phase, 4, 1)
        if got == 0 then
            call OMGAILogger_E("ResManager", "DoRefresh: no offers generated")
            return
        endif

        // write into PSS_SmallOffers / PSS_BigOffers
        set i = 1
        loop
            exitwhen i > 8
            if phase == OMGAI_PHASE_SELECT_SMALL then
                set PSS_SmallOffers[(playerId - 1) * 8 + i] = OMGAI_TmpOutOffers[i]
            else
                set PSS_BigOffers[(playerId - 1) * 8 + i] = OMGAI_TmpOutOffers[i]
            endif
            set i = i + 1
        endloop
    endfunction

    // 请求转技能（刷新当前阶段 offers）
    // playerId - 玩家 ID
    // 返回 RESKIN_* 枚举
    public function RequestRespin takes integer playerId returns integer
        local integer phase = PSS_Phase[playerId]
        local integer used
        local integer balance
        local integer oldRaw
        local integer got
        local integer i

        // 11 平台降级：永久免费无限转
        if not OMGAIIPlatformAPI_IsCommercialEnabled() then
            call DoRefresh(playerId, phase)
            return RESKIN_FAIL_FREE_DEGRADED_OK
        endif

        // 1) 检查免费次数
        if phase == OMGAI_PHASE_SELECT_SMALL then
            set used = PSS_SmallPhaseRespinUsed[playerId]
        elseif phase == OMGAI_PHASE_SELECT_BIG then
            set used = PSS_BigPhaseRespinUsed[playerId]
        else
            return RESKIN_FAIL_NO_VOUCHER
        endif

        if used < OMGAI_FREE_RESPIN_PER_PHASE then
            // 免费刷新
            call DoRefresh(playerId, phase)
            call OMGAIPlayerSkillState_IncrementRespinUsed(playerId, phase)
            return RESKIN_SUCCESS_FREE
        endif

        // 2) 查券余额
        set balance = OMGAIPlayerSaveData_GetBalance(playerId)
        if balance > 0 then
            call DoRefresh(playerId, phase)
            call OMGAIPlayerSaveData_UseVouchers(playerId, 1)
            return RESKIN_SUCCESS_PAID
        endif

        // 3) 免费用尽且无券：弹出 RespinUI 购买确认框（玩家点 Buy 才触发 QuickBuy）
        call OMGAIRespinUI_Show(playerId)
        return RESKIN_FAIL_PURCHASE_CANCEL
    endfunction

endlibrary