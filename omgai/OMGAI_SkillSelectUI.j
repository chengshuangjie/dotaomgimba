// ===========================================================================
// OMGAISkillSelectUI.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 4+2 分阶段选技能 UI 面板
// 技术方案 T03' / PRD 4.1 流程图
// ---------------------------------------------------------------------------
// 设计：
//   * 用原生 BlzCreateFrame 创建 8 个技能按钮（4 列 2 行）
//   * 每个按钮显示技能图标（BlzCreateFrameByType BACKDROP）+ 名称（TEXT）
//   * 点击触发回调（BlzGetTriggerFrame）
//   * 转技能按钮独立窗口，显示当前阶段已用次数/免费上限
//   * 用 BlzFrame API 创建/显示/隐藏（不依赖 vcccv Frame struct）
//   * 单 Frame 仅 localplayer 可见（异步代码）
// ===========================================================================
library OMGAISkillSelectUI requires OMGAIConfig, OMGAIEventDispatcher, OMGAILogger, OMGAIPlayerSkillState, OMGAIRespManager, OMGAISkillDef

    // ---- UI Frame 句柄 ----------------------------------------------
    globals
        // 主面板
        framehandle SU_Root = null
        framehandle SU_Title = null

        // 8 个技能按钮（按钮容器 + 内层背景图 + 名称文本）
        framehandle array SU_SkillBtn        // 1..8
        framehandle array SU_SkillBackdrop    // 1..8
        framehandle array SU_SkillName         // 1..8

        // 转技能按钮
        framehandle SU_RespinBtn = null
        framehandle SU_RespinLabel = null

        // 关闭按钮（玩家放弃选择）
        framehandle SU_CloseBtn = null

        // 状态
        boolean SU_Visible = false
        integer  SU_CurrentPlayerId = 0
        integer  SU_CurrentPhase = 0     // OMGAI_PHASE_*
    endglobals

    // ---- UI 创建占位 -------------------------------------------------
    // 注：纯 BlzCreateFrame 需要在 JAPI 启用后才能调用
    // 实际工程中地图加载时由 GameFlow 调用 Create
    // Frame 事件统一回调（自包含，不依赖 GameFlow）


    // ---- 显示面板：当前玩家进入新阶段时调用 ---------------------------


    // ---- 玩家点击事件回调（由 GameFlow 注册的 trigger 触发）-------------
    // 当用户点击某技能按钮时→ PSS.SelectOffer(playerId, offerIndex)
    // 内部刷新当前玩家面板显示
    private function SkillSelectUI_RefreshPlayer takes integer playerId returns nothing
        local integer phase = PSS_Phase[playerId]
        local integer i
        local integer skillIdx
        set i = 1
        loop
            exitwhen i > 8
            if phase == OMGAI_PHASE_SELECT_SMALL then
                set skillIdx = PSS_SmallOffers[(playerId - 1) * 8 + i]
            else
                set skillIdx = PSS_BigOffers[(playerId - 1) * 8 + i]
            endif
            if skillIdx > 0 then
                call BlzFrameSetText(SU_SkillName[i], SkillDef_Name[skillIdx])
            endif
            set i = i + 1
        endloop
        if phase == OMGAI_PHASE_SELECT_SMALL then
            call BlzFrameSetText(SU_RespinLabel, "转技能 免费(" + I2S(OMGAI_FREE_RESPIN_PER_PHASE - PSS_SmallPhaseRespinUsed[playerId]) + "/" + I2S(OMGAI_FREE_RESPIN_PER_PHASE) + ")")
        else
            call BlzFrameSetText(SU_RespinLabel, "转技能 免费(" + I2S(OMGAI_FREE_RESPIN_PER_PHASE - PSS_BigPhaseRespinUsed[playerId]) + "/" + I2S(OMGAI_FREE_RESPIN_PER_PHASE) + ")")
        endif
    endfunction
    public function Hide takes nothing returns nothing
        if SU_Root != null then
            call BlzFrameSetVisible(SU_Root, false)
        endif
        set SU_Visible = false
    endfunction
    public function OnFrameClick takes framehandle clickedFrame returns nothing
        local integer i
        local integer playerId = SU_CurrentPlayerId

        // 转技能按钮
        if GetHandleId(clickedFrame) == GetHandleId(SU_RespinBtn) then
            call OMGAILogger_D("SU_UI", "Respin clicked for player " + I2S(playerId))
            call OMGAIRespManager_RequestRespin(playerId)
            // 刷新显示
            if SU_CurrentPhase == OMGAI_PHASE_SELECT_SMALL then
                call SkillSelectUI_RefreshPlayer(playerId)
            else
                call SkillSelectUI_RefreshPlayer(playerId)
            endif
            return
        endif

        // 关闭按钮
        if GetHandleId(clickedFrame) == GetHandleId(SU_CloseBtn) then
            call Hide()
            return
        endif

        // 检测点击的是哪个技能按钮
        set i = 1
        loop
            exitwhen i > 8
            if GetHandleId(clickedFrame) == GetHandleId(SU_SkillBtn[i]) then
                if OMGAIPlayerSkillState_SelectOffer(playerId, i) then
                    // 选中后，让 GameFlow 推进下一阶段
                    call OMGAIEventDispatcher_ClearPayload()
                    set OMGAI_EvtPayloadInt1 = i
                    call OMGAIEventDispatcher_Fire(OMGAI_EVT_SKILL_GRANTED)
                    if SU_CurrentPhase == OMGAI_PHASE_SELECT_SMALL then
                        // 自动进入大技能阶段
                        call OMGAIPlayerSkillState_StartSelectBigPhase(playerId)
                        call SkillSelectUI_RefreshPlayer(playerId)
                    else
                        // 选完大技能，关闭面板
                        call Hide()
                    endif
                endif
                exitwhen true
            endif
            set i = i + 1
        endloop
    endfunction
    private function SU_FrameClickWrapper takes nothing returns nothing
        call OnFrameClick(BlzGetTriggerFrame())
    endfunction
    public function Create takes nothing returns nothing
        local integer i
        local trigger t
        // TODO：完整 UI 创建代码，需要带 .fdf 模板文件
        // 简化版：用 BlzCreateFrameByType 创建原生按钮 + 文本

        set SU_Root = BlzCreateFrameByType("BACKDROP", "OMGAI_SU_Root", BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0), 0, 0)
        call BlzFrameSetAbsPoint(SU_Root, FRAMEPOINT_TOPLEFT, 0.20, 0.65)
        call BlzFrameSetAbsPoint(SU_Root, FRAMEPOINT_BOTTOMRIGHT, 0.80, 0.20)
        call BlzFrameSetTexture(SU_Root, "ReplaceableTextures\\TeamColor\\TeamColor15.blp", 0, true)
        call BlzFrameSetAlpha(SU_Root, 220)
        call BlzFrameSetVisible(SU_Root, false)

        // 标题
        set SU_Title = BlzCreateFrameByType("TEXT", "OMGAI_SU_Title", SU_Root, 0, 0)
        call BlzFrameSetAbsPoint(SU_Title, FRAMEPOINT_TOPLEFT, 0.21, 0.64)
        call BlzFrameSetAbsPoint(SU_Title, FRAMEPOINT_TOPRIGHT, 0.79, 0.62)
        call BlzFrameSetText(SU_Title, "OMG 选技能面板")

        // 8 个技能按钮：4 列 x 2 行
        set i = 1
        loop
            exitwhen i > 8
            set SU_SkillBtn[i] = BlzCreateFrameByType("BUTTON", "OMGAI_SU_Btn" + I2S(i), SU_Root, 0, 0)
            set SU_SkillBackdrop[i] = BlzCreateFrameByType("BACKDROP", "OMGAI_SU_Bg" + I2S(i), SU_SkillBtn[i], 0, 0)
            set SU_SkillName[i]  = BlzCreateFrameByType("TEXT", "OMGAI_SU_Name" + I2S(i), SU_SkillBtn[i], 0, 0)
            // 位置：每按钮 0.13 宽 0.15 高，从 0.22 起 2 行
            // 简化布局：左右上排各 4 个，左右下排各 4 个
            call BlzFrameSetAbsPoint(SU_SkillBtn[i], FRAMEPOINT_TOPLEFT, 0.22 + (i - 1) * 0.14, 0.58 - I2R(i / 5) * 0.18)
            call BlzFrameSetAbsPoint(SU_SkillBtn[i], FRAMEPOINT_BOTTOMRIGHT, 0.34 + (i - 1) * 0.14, 0.46 - I2R(i / 5) * 0.18)
            set t = CreateTrigger()
            call BlzTriggerRegisterFrameEvent(t, SU_SkillBtn[i], FRAMEEVENT_CONTROL_CLICK)
            call TriggerAddAction(t, function SU_FrameClickWrapper)
            set i = i + 1
        endloop

        // 转技能按钮
        set SU_RespinBtn = BlzCreateFrameByType("BUTTON", "OMGAI_SU_RespinBtn", SU_Root, 0, 0)
        call BlzFrameSetAbsPoint(SU_RespinBtn, FRAMEPOINT_TOPLEFT, 0.21, 0.20)
        call BlzFrameSetAbsPoint(SU_RespinBtn, FRAMEPOINT_BOTTOMRIGHT, 0.40, 0.13)
        set t = CreateTrigger()
        call BlzTriggerRegisterFrameEvent(t, SU_RespinBtn, FRAMEEVENT_CONTROL_CLICK)
        call TriggerAddAction(t, function SU_FrameClickWrapper)

        set SU_RespinLabel = BlzCreateFrameByType("TEXT", "OMGAI_SU_RespinLabel", SU_RespinBtn, 0, 0)
        call BlzFrameSetText(SU_RespinLabel, "转技能 (3/3)")

        // 关闭按钮
        set SU_CloseBtn = BlzCreateFrameByType("BUTTON", "OMGAI_SU_Close", SU_Root, 0, 0)
        call BlzFrameSetAbsPoint(SU_CloseBtn, FRAMEPOINT_TOPLEFT, 0.75, 0.20)
        call BlzFrameSetAbsPoint(SU_CloseBtn, FRAMEPOINT_BOTTOMRIGHT, 0.79, 0.13)
        set t = CreateTrigger()
        call BlzTriggerRegisterFrameEvent(t, SU_CloseBtn, FRAMEEVENT_CONTROL_CLICK)
        call TriggerAddAction(t, function SU_FrameClickWrapper)

        call OMGAILogger_I("SkillSelectUI", "Frames created")
    endfunction
    public function ShowForPlayer takes integer playerId, integer phase returns nothing
        local integer i
        local integer skillIdx
        local integer rawCode

        set SU_CurrentPlayerId = playerId
        set SU_CurrentPhase = phase

        // 填充 8 个技能名
        set i = 1
        loop
            exitwhen i > 8
            if phase == OMGAI_PHASE_SELECT_SMALL then
                set skillIdx = PSS_SmallOffers[(playerId - 1) * 8 + i]
            else
                set skillIdx = PSS_BigOffers[(playerId - 1) * 8 + i]
            endif
            if skillIdx > 0 then
                call BlzFrameSetText(SU_SkillName[i], SkillDef_Name[skillIdx])
                call BlzFrameSetVisible(SU_SkillBtn[i], true)
            else
                call BlzFrameSetVisible(SU_SkillBtn[i], false)
            endif
            set i = i + 1
        endloop

        // 更新转技能按钮文案：显示剩余免费次数
        if phase == OMGAI_PHASE_SELECT_SMALL then
            call BlzFrameSetText(SU_RespinLabel, "转技能 免费(" + I2S(OMGAI_FREE_RESPIN_PER_PHASE - PSS_SmallPhaseRespinUsed[playerId]) + "/" + I2S(OMGAI_FREE_RESPIN_PER_PHASE) + ")")
        else
            call BlzFrameSetText(SU_RespinLabel, "转技能 免费(" + I2S(OMGAI_FREE_RESPIN_PER_PHASE - PSS_BigPhaseRespinUsed[playerId]) + "/" + I2S(OMGAI_FREE_RESPIN_PER_PHASE) + ")")
        endif

        call BlzFrameSetVisible(SU_Root, true)
        set SU_Visible = true
    endfunction
endlibrary
