// ===========================================================================
// OMGAIGameFlow.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 主流程编排
// 技术方案 T03' / PRD 4.1 流程图
// ---------------------------------------------------------------------------
// 职责：
//   * 地图启动 → 注册 UI Frame 事件 trigger
//   * 玩家英雄出生 → PlayerSkillState.Init → SkillPool 构建完成
//   * 启动小技能阶段 → SkillSelectUI.ShowForPlayer
//   * 监听 OMGAI_EVT_SELECT_DONE → 进入正常 DOTA 对战
//   * 监听 KKAPI QuickBuy 成功事件 → 自动消耗券并刷新
// ---------------------------------------------------------------------------
// 触发流程：
//   * 地图加载完成事件 → GameFlow_OnMapInit
//   * 玩家英雄出生事件 → GameFlow_OnHeroSpawn
//   * FrameEvent 控件点击 → GameFlow_OnFrameClick
//   * DzAPI 实时获得道具事件 → GameFlow_OnQuickBuyOK
// ===========================================================================
library OMGAIGameFlow initializer OnInit requires OMGAIConfig, OMGAIEventDispatcher, OMGAILogger, OMGAIPlayerSaveData, OMGAIPlayerSkillState, OMGAIRespinUI, OMGAISkillSelectUI, OMGAITimerService

    globals
        trigger GameFlow_FrameClickTrigger = null
        trigger GameFlow_HeroSpawnTrigger   = null
        trigger GameFlow_MapInitTrigger    = null
        integer GameFlow_PlayerHeroSpawnedCount = 0
    endglobals

    private function OnFrameClick takes nothing returns nothing
        local framehandle clicked = BlzGetTriggerFrame()
        call OMGAILogger_D("GameFlow", "Frame clicked: " + I2S(GetHandleId(clicked)))
        // 先尝试 SkillSelectUI
        call OMGAISkillSelectUI_OnFrameClick(clicked)
        // 再尝试 RespinUI
        call OMGAIRespinUI_OnFrameClick(clicked)
    endfunction

    private function OnHeroSpawn takes nothing returns nothing
        local unit u = GetTriggerUnit()
        local player p = GetOwningPlayer(u)
        local integer playerId = GetPlayerId(p) + 1
        local integer heroRawCode = GetUnitTypeId(u)
        local integer i

        if not IsUnitType(u, UNIT_TYPE_HERO) then
            // 非英雄单位易主（野怪被控制等）不启动选技能
            return
        endif
        if playerId < 1 or playerId > 10 then
            // AI 单位（11-24 槽）由 AI 模块处理
            return
        endif

        // TODO：实际工程中需从 HeroRegistry 取该英雄固定 4 技能 rawcode
        // 占位：先填 4 个 0（实际为原版 3 小+1 大）
        set i = 1
        loop
            exitwhen i > 4
            call OMGAIPlayerSkillState_SetFixedSkillRawCode(playerId, i, 0)
            set i = i + 1
        endloop

        // 加载玩家存档
        call OMGAIPlayerSaveData_Load(playerId)

        // 初始化技能状态
        call OMGAIPlayerSkillState_Init(playerId, heroRawCode, u)

        // 启动选小技能阶段
        call OMGAIPlayerSkillState_StartSelectSmallPhase(playerId)
        call OMGAISkillSelectUI_ShowForPlayer(playerId, OMGAI_PHASE_SELECT_SMALL)

        set GameFlow_PlayerHeroSpawnedCount = GameFlow_PlayerHeroSpawnedCount + 1
        call OMGAILogger_I("GameFlow", "Hero spawned for player " + I2S(playerId) + " count=" + I2S(GameFlow_PlayerHeroSpawnedCount))
    endfunction

    private function OnSelectDone takes nothing returns nothing
        local player p = OMGAI_EvtPayloadPlayer
        local integer playerId = GetPlayerId(p) + 1
        call OMGAILogger_I("GameFlow", "Player " + I2S(playerId) + " completed 4+2 select")
        // TODO：触发 AI 监听生成画像（T05 阶段实现）
    endfunction

    private function OnQuickBuyOK takes nothing returns nothing
        local player p = OMGAI_EvtPayloadPlayer
        local integer playerId = GetPlayerId(p) + 1
        call OMGAIPlayerSaveData_AddVouchers(playerId, 1)
        call OMGAILogger_I("GameFlow", "QuickBuy success for player " + I2S(playerId) + ", voucher+1")
        // 注意：实际刷新由 SkillSelectUI 当前 player 主动调用 RespManager
    endfunction

    // 地图加载完成时调用
    private function OnMapInit takes nothing returns nothing
        call OMGAILogger_I("GameFlow", "MapInit: creating UI frames")

        // 创建 UI 面板（仅 localplayer，避免异步崩溃）
        call OMGAISkillSelectUI_Create()
        call OMGAIRespinUI_Create()

        // 注册 Frame 点击事件 trigger
        // 注：SkillSelectUI.Create 内部已为每个按钮 TriggerRegisterFrameEvent
        // 此处用一个统一 trigger 来响应所有 Frame 事件
        call TriggerAddAction(GameFlow_FrameClickTrigger, function OnFrameClick)

        call OMGAILogger_I("GameFlow", "MapInit done")
    endfunction

    // ---- 模块初始化（由 initializer 自动调用）-------------------------
    private function OnInit takes nothing returns nothing
        local integer i
        // 1) 注册地图加载完成 trigger（OnMapInit 单独定义，不可嵌套）
        set GameFlow_MapInitTrigger = CreateTrigger()
        call TriggerRegisterTimerEvent(GameFlow_MapInitTrigger, 0.0, false)
        call TriggerAddAction(GameFlow_MapInitTrigger, function OnMapInit)

        // 2) 注册英雄出生 trigger（玩家选英雄后第一帧）
        set GameFlow_HeroSpawnTrigger = CreateTrigger()
        set i = 0
        loop
            exitwhen i > 9
            call TriggerRegisterPlayerUnitEvent(GameFlow_HeroSpawnTrigger, Player(i), EVENT_PLAYER_UNIT_CHANGE_OWNER, null)
            set i = i + 1
        endloop
        call TriggerAddAction(GameFlow_HeroSpawnTrigger, function OnHeroSpawn)
        // TODO: 用 TriggerRegisterAnyUnitEventBJ 或合适的事件

        // 3) 注册 Frame 点击 trigger（一个 trigger 多回调）
        set GameFlow_FrameClickTrigger = CreateTrigger()

        // 4) 注册事件总线回调
        call OMGAIEventDispatcher_On(OMGAI_EVT_SELECT_DONE, function OnSelectDone)
        call OMGAIEventDispatcher_On(OMGAI_EVT_PURCHASE_OK, function OnQuickBuyOK)

        call OMGAILogger_I("GameFlow", "Init done (events registered)")
    endfunction

endlibrary