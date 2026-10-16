// ===========================================================================
// OMGAIPlayerSkillState.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 玩家技能状态机（4+2 分阶段）
// 技术方案 T03 / PRD 4.1 4+2 分阶段流程
// ---------------------------------------------------------------------------
// 字段（PRD 4.1.3 + 技术方案 3.2 PlayerSkillState）：
//   * playerId, heroId, heroUnit
//   * fixedSkills[4]: 固定技能 rawcode（3小+1大）
//   * extraSmall, extraBig: 已选额外技能 rawcode
//   * smallOffers[8], bigOffers[8]: 当前阶段下发的待选池
//   * smallPhaseRespinUsed, bigPhaseRespinUsed: 本阶段已用免费转次数
//   * phase: INIT → SELECT_SMALL → SELECT_BIG → DONE
// 设计：用全局数组 + playerId 索引（与 vcccv PlayerSkillIndices 风格一致）
// ===========================================================================
library OMGAIPlayerSkillState requires OMGAIConfig, OMGAIEventDispatcher, OMGAILogger, OMGAIHeroSkillManager, OMGAISkillConflictResolver, OMGAISkillDef, OMGAISkillOfferGenerator
    globals
        // 共享空数组（vJASS 不能返回 array，所有需要"空"数组的地方都传它）
        integer array PSS_EmptyArray
    endglobals

    globals
        // ---- 用 playerId 索引（1..24）-----------------------------------
        integer array PSS_HeroId
        unit   array PSS_HeroUnit
        integer array PSS_Phase

        // 固定技能 rawcode（每玩家 4 个，平铺，每个玩家占 4 槽）
        // 槽位约定：[1-4]=玩家1固定，[5-8]=玩家2固定，... [93-96]=玩家24固定
        integer array PSS_FixedSkills_RawCode

        // 已选额外技能 rawcode
        integer array PSS_ExtraSmall
        integer array PSS_ExtraBig

        // 当前阶段下发的待选池 SkillDef index 数组
        // 每玩家 8 个槽，平铺
        integer array PSS_SmallOffers
        integer array PSS_BigOffers

        // 本阶段已用免费转次数
        integer array PSS_SmallPhaseRespinUsed
        integer array PSS_BigPhaseRespinUsed
    endglobals

    // 计算玩家固定技能在 PSS_FixedSkills_RawCode 数组中的起始位置
    public function GetFixedSkillRawCode takes integer playerId, integer slot returns integer
        return PSS_FixedSkills_RawCode[(playerId - 1) * 4 + slot]
    endfunction

    public function SetFixedSkillRawCode takes integer playerId, integer slot, integer rawCode returns nothing
        set PSS_FixedSkills_RawCode[(playerId - 1) * 4 + slot] = rawCode
    endfunction

    // 初始化玩家技能状态（英雄出生时调用）
        public function Init takes integer playerId, integer heroId, unit heroUnit returns nothing
        set PSS_HeroId[playerId]    = heroId
        set PSS_HeroUnit[playerId]  = heroUnit
        set PSS_Phase[playerId]    = OMGAI_PHASE_INIT
        set PSS_ExtraSmall[playerId] = 0
        set PSS_ExtraBig[playerId]   = 0
        set PSS_SmallPhaseRespinUsed[playerId] = 0
        set PSS_BigPhaseRespinUsed[playerId]   = 0
        // fixed skills must be pre-written by caller via SetFixedSkillRawCode
        call OMGAILogger_I("PSS", "init player=" + I2S(playerId) + " hero=" + I2S(heroId) + " phase=INIT")
    endfunction

    // 进入选小技能阶段：生成 8 个待选
        public function StartSelectSmallPhase takes integer playerId returns nothing
        local integer got
        local integer i
        // exclude list: hero fixed 4 skills -> fill Generate input channel
        set i = 1
        loop
            exitwhen i > 4
            set OMGAI_TmpFixedRawCodes[i] = GetFixedSkillRawCode(playerId, i)
            set i = i + 1
        endloop
        // generate
        set got = OMGAISkillOfferGenerator_Generate(OMGAI_PHASE_SELECT_SMALL, 4, 0)
        if got == 0 then
            call OMGAILogger_E("PSS", "StartSelectSmallPhase: 0 offers")
            return
        endif
        set i = 1
        loop
            exitwhen i > 8
            set PSS_SmallOffers[(playerId - 1) * 8 + i] = OMGAI_TmpOutOffers[i]
            set i = i + 1
        endloop
        set PSS_Phase[playerId] = OMGAI_PHASE_SELECT_SMALL
        call OMGAILogger_D("PSS", "player=" + I2S(playerId) + " entered SELECT_SMALL, offers=" + I2S(got))
    endfunction

    // 占位辅助移除：用 PSS_EmptyArray 全局变量替代返回 array

    // 进入选大技能阶段
        public function StartSelectBigPhase takes integer playerId returns nothing
        local integer got
        local integer i
        // exclude list: fixed 4 + selected small 1 -> fill Generate input channel
        set i = 1
        loop
            exitwhen i > 4
            set OMGAI_TmpFixedRawCodes[i] = GetFixedSkillRawCode(playerId, i)
            set i = i + 1
        endloop
        set OMGAI_TmpExtraRawCodes[1] = PSS_ExtraSmall[playerId]
        set got = OMGAISkillOfferGenerator_Generate(OMGAI_PHASE_SELECT_BIG, 4, 1)
        if got == 0 then
            call OMGAILogger_E("PSS", "StartSelectBigPhase: 0 offers")
            return
        endif
        set i = 1
        loop
            exitwhen i > 8
            set PSS_BigOffers[(playerId - 1) * 8 + i] = OMGAI_TmpOutOffers[i]
            set i = i + 1
        endloop
        set PSS_Phase[playerId] = OMGAI_PHASE_SELECT_BIG
    endfunction

    // 玩家选某技能：从当前阶段 offers 中选第几个
    // offerIndex: 1..8
    // 返回 true 成功
    public function SelectOffer takes integer playerId, integer offerIndex returns boolean
        local integer skillIdx
        local integer rawCode
        if offerIndex < 1 or offerIndex > OMGAI_OFFER_COUNT then
            return false
        endif
        if PSS_Phase[playerId] == OMGAI_PHASE_SELECT_SMALL then
            set skillIdx = PSS_SmallOffers[(playerId - 1) * 8 + offerIndex]
            set rawCode = SkillDef_RawCode[skillIdx]
            set PSS_ExtraSmall[playerId] = rawCode
            call OMGAIHeroSkillManager_GrantSkill(PSS_HeroUnit[playerId], rawCode)
            call OMGAILogger_D("PSS", "player=" + I2S(playerId) + " selected small skill rawCode=" + I2S(rawCode))
            // 赋予技能（HeroSkillManager 在 T03 后续实现，先直接调）
            set PSS_Phase[playerId] = OMGAI_PHASE_SELECT_BIG
            return true
        elseif PSS_Phase[playerId] == OMGAI_PHASE_SELECT_BIG then
            set skillIdx = PSS_BigOffers[(playerId - 1) * 8 + offerIndex]
            set rawCode = SkillDef_RawCode[skillIdx]
            set PSS_ExtraBig[playerId] = rawCode
            call OMGAIHeroSkillManager_GrantSkill(PSS_HeroUnit[playerId], rawCode)
            call OMGAILogger_D("PSS", "player=" + I2S(playerId) + " selected big skill rawCode=" + I2S(rawCode))
            set PSS_Phase[playerId] = OMGAI_PHASE_DONE
            // 触发选技能完成事件（让 AI Controller 监听生成画像）
            call OMGAIEventDispatcher_ClearPayload()
            set OMGAI_EvtPayloadPlayer = Player(playerId - 1)
            call OMGAIEventDispatcher_Fire(OMGAI_EVT_SELECT_DONE)
            return true
        endif
        return false
    endfunction

    // 是否完成全部 4+2 选技能
    public function IsComplete takes integer playerId returns boolean
        return PSS_Phase[playerId] == OMGAI_PHASE_DONE
    endfunction

    // 当前阶段已用免费转次数
    public function GetRespinUsed takes integer playerId, integer phase returns integer
        if phase == OMGAI_PHASE_SELECT_SMALL then
            return PSS_SmallPhaseRespinUsed[playerId]
        elseif phase == OMGAI_PHASE_SELECT_BIG then
            return PSS_BigPhaseRespinUsed[playerId]
        endif
        return 0
    endfunction

    // 增加当前阶段免费转次数计数
    public function IncrementRespinUsed takes integer playerId, integer phase returns nothing
        if phase == OMGAI_PHASE_SELECT_SMALL then
            set PSS_SmallPhaseRespinUsed[playerId] = PSS_SmallPhaseRespinUsed[playerId] + 1
        elseif phase == OMGAI_PHASE_SELECT_BIG then
            set PSS_BigPhaseRespinUsed[playerId] = PSS_BigPhaseRespinUsed[playerId] + 1
        endif
    endfunction

    // 取当前 phase 下的小/大技能 offers index
    public function GetSmallOfferIdx takes integer playerId, integer offerIndex returns integer
        return PSS_SmallOffers[(playerId - 1) * 8 + offerIndex]
    endfunction

    public function GetBigOfferIdx takes integer playerId, integer offerIndex returns integer
        return PSS_BigOffers[(playerId - 1) * 8 + offerIndex]
    endfunction

endlibrary