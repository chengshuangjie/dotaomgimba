// ===========================================================================
// OMGAISkillOfferGenerator.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 选技能面板生成器（8选1）
// 技术方案 T02 技能系统 / PRD 4.1 4+2 分阶段流程
// ---------------------------------------------------------------------------
// 用途：
//   * 4+2 分阶段流程调用此生成器拿 8 个待选技能 ID
//   * 内部：构建排除集（已选+固定） → SkillPool.GetRandomOffers → 冲突校验
// ===========================================================================
library OMGAISkillOfferGenerator requires OMGAIConfig, OMGAIConflictRule, OMGAILogger, OMGAISkillDef, OMGAISkillPool

    globals
        // 复用临时数组（避免每次重新分配）
        integer array OMGAI_TmpExcludeRawCodes
        // data channels (vJASS: no array params, caller fills input first)
        integer array OMGAI_TmpFixedRawCodes   // input: hero fixed skill rawcodes
        integer array OMGAI_TmpExtraRawCodes   // input: selected extra skill rawcodes
        integer array OMGAI_TmpOutOffers       // output: generated SkillDef indices (1..8)
    endglobals

    // 生成 8 个待选 SkillDef index，填入 outArray[1..8]
    // phase: OMGAI_PHASE_SELECT_SMALL / OMGAI_PHASE_SELECT_BIG
    // fixedSkillRawCodes: 当前英雄固定技能 rawcode 数组
    // fixedCount: 数组有效长度
    // extraSelectedRawCodes: 已选的额外技能（重新随机也要排除）
    // extraCount: 数组有效长度
    // 返回实际填充数量
        public function Generate takes integer phase, integer fixedCount, integer extraCount returns integer
        local integer poolType
        local integer totalExclude = 0
        local integer i
        local integer got

        // select pool
        if phase == OMGAI_PHASE_SELECT_SMALL then
            set poolType = 1
        elseif phase == OMGAI_PHASE_SELECT_BIG then
            set poolType = 2
        else
            call OMGAILogger_E("OfferGen", "Generate: invalid phase=" + I2S(phase))
            return 0
        endif

        // build exclude list (fixed + extra)
        set i = 1
        loop
            exitwhen i > fixedCount
            set totalExclude = totalExclude + 1
            set OMGAI_TmpExcludeRawCodes[totalExclude] = OMGAI_TmpFixedRawCodes[i]
            set i = i + 1
        endloop
        set i = 1
        loop
            exitwhen i > extraCount
            set totalExclude = totalExclude + 1
            set OMGAI_TmpExcludeRawCodes[totalExclude] = OMGAI_TmpExtraRawCodes[i]
            set i = i + 1
        endloop

        // fill SkillPool input channel
        set i = 1
        loop
            exitwhen i > totalExclude
            set SkillPool_ExcludeRawCodes[i] = OMGAI_TmpExcludeRawCodes[i]
            set i = i + 1
        endloop

        // call SkillPool random offers (with conflict check inside)
        set got = OMGAISkillPool_GetRandomOffers(poolType, OMGAI_OFFER_COUNT, totalExclude)

        // copy output to this library channel
        set i = 1
        loop
            exitwhen i > got
            set OMGAI_TmpOutOffers[i] = SkillPool_OutIndices[i]
            set i = i + 1
        endloop
        return got
    endfunction

endlibrary