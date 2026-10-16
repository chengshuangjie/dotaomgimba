// ===========================================================================
// OMGAIRespinUI.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 付费转技能弹框（U 币快购确认）
// 技术方案 T03' / PRD 4.2 转技能券付费机制
// ---------------------------------------------------------------------------
// 用途：当免费次数用尽且无券时，弹出确认框让玩家选择
//   1) 用 U 币购买 1 张转技能券（确认 → QuickBuy → 实时事件回调刷新）
//   2) 取消（保留当前 8 个技能不变）
// 注：当前 SkillSelectUI 已有转技能按钮，但免费用尽 + 无券时此弹框接管
// ===========================================================================
library OMGAIRespinUI requires OMGAIConfig, OMGAIIPlatformAPI, OMGAILogger, OMGAIPlayerSaveData

    globals
        framehandle RU_Root       = null
        framehandle RU_Title       = null
        framehandle RU_Message    = null
        framehandle RU_BtnBuy      = null
        framehandle RU_BtnCancel   = null
        boolean     RU_Visible     = false
        integer     RU_TargetPlayer = 0
    endglobals

    // Frame 事件统一回调（自包含，不依赖 GameFlow）


    // 显示弹框（当前 localplayer）


    // 点击事件处理（由 GameFlow 注册的 trigger 调用）
    public function Show takes integer playerId returns nothing
        set RU_TargetPlayer = playerId
        if RU_Root == null then
            return
        endif
        call BlzFrameSetVisible(RU_Root, true)
        set RU_Visible = true
    endfunction
    public function Hide takes nothing returns nothing
        if RU_Root != null then
            call BlzFrameSetVisible(RU_Root, false)
        endif
        set RU_Visible = false
    endfunction
    public function OnFrameClick takes framehandle clickedFrame returns nothing
        if not RU_Visible then
            return
        endif

        if GetHandleId(clickedFrame) == GetHandleId(RU_BtnBuy) then
            // 触发 U 币快购
            call OMGAIIPlatformAPI_QuickBuy(RU_TargetPlayer, OMGAI_VOUCHER_ITEM_KEY, 1)
            call Hide()
            // 实际刷新由 QuickBuy 成功事件回调（KKAPI 内） 触发，调用 RespManager 再执行刷新
            call OMGAILogger_I("RespinUI", "QuickBuy triggered for player " + I2S(RU_TargetPlayer))
        elseif GetHandleId(clickedFrame) == GetHandleId(RU_BtnCancel) then
            call Hide()
            call OMGAILogger_D("RespinUI", "Cancel")
        endif
    endfunction
    private function RU_FrameClickWrapper takes nothing returns nothing
        call OnFrameClick(BlzGetTriggerFrame())
    endfunction
    public function Create takes nothing returns nothing
        local trigger t
        set RU_Root = BlzCreateFrameByType("BACKDROP", "OMGAI_RU_Root", BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0), 0, 0)
        call BlzFrameSetAbsPoint(RU_Root, FRAMEPOINT_TOPLEFT, 0.30, 0.55)
        call BlzFrameSetAbsPoint(RU_Root, FRAMEPOINT_BOTTOMRIGHT, 0.70, 0.35)
        call BlzFrameSetTexture(RU_Root, "ReplaceableTextures\\TeamColor\\TeamColor00.blp", 0, true)
        call BlzFrameSetAlpha(RU_Root, 240)
        call BlzFrameSetVisible(RU_Root, false)

        set RU_Title = BlzCreateFrameByType("TEXT", "OMGAI_RU_Title", RU_Root, 0, 0)
        call BlzFrameSetAbsPoint(RU_Title, FRAMEPOINT_TOPLEFT, 0.31, 0.54)
        call BlzFrameSetText(RU_Title, "|cffffcc00购买转技能券|r")

        set RU_Message = BlzCreateFrameByType("TEXT", "OMGAI_RU_Msg", RU_Root, 0, 0)
        call BlzFrameSetAbsPoint(RU_Message, FRAMEPOINT_TOPLEFT, 0.31, 0.50)
        call BlzFrameSetText(RU_Message, "免费次数已用尽。\n是否花费 3 U 币购买 1 张转技能券？")

        set RU_BtnBuy = BlzCreateFrameByType("BUTTON", "OMGAI_RU_Buy", RU_Root, 0, 0)
        call BlzFrameSetAbsPoint(RU_BtnBuy, FRAMEPOINT_TOPLEFT, 0.31, 0.40)
        call BlzFrameSetAbsPoint(RU_BtnBuy, FRAMEPOINT_BOTTOMRIGHT, 0.49, 0.36)
        set t = CreateTrigger()
        call BlzTriggerRegisterFrameEvent(t, RU_BtnBuy, FRAMEEVENT_CONTROL_CLICK)
        call TriggerAddAction(t, function RU_FrameClickWrapper)

        set RU_BtnCancel = BlzCreateFrameByType("BUTTON", "OMGAI_RU_Cancel", RU_Root, 0, 0)
        call BlzFrameSetAbsPoint(RU_BtnCancel, FRAMEPOINT_TOPLEFT, 0.51, 0.40)
        call BlzFrameSetAbsPoint(RU_BtnCancel, FRAMEPOINT_BOTTOMRIGHT, 0.69, 0.36)
        set t = CreateTrigger()
        call BlzTriggerRegisterFrameEvent(t, RU_BtnCancel, FRAMEEVENT_CONTROL_CLICK)
        call TriggerAddAction(t, function RU_FrameClickWrapper)

        call OMGAILogger_I("RespinUI", "Frames created")
    endfunction
endlibrary
