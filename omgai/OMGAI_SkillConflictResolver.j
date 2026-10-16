// ===========================================================================
// OMGAISkillConflictResolver.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 技能冲突校验封装
// 技术方案 T02 技能系统 / PRD 4.4 冲突校验时机
// ---------------------------------------------------------------------------
// 职责：
//   * 提供统一接口：candidate vs 已选技能是否冲突
//   * 处理特殊规则（卡尔/地卜师）的二次校验
//   * 在 SkillPool.GetRandomOffers 内部已校验，但选技能赋予与转技能时需再次校验
// 设计：
//   * 此结构对应 PRD 4.4.3 "选技能赋予：再次校验已选技能与待选是否冲突"
// ===========================================================================
library OMGAISkillConflictResolver requires OMGAIConfig, OMGAIConflictRule, OMGAILogger, OMGAISkillDef

    // 对外统一接口：判断待选技能是否与当前已选技能集冲突
    // candidateRawCode - 待选技能 rawcode
    // currentRawCodes  - 当前已选技能 rawcode 数组
    // currentCount     - 数组有效长度
    public function IsConflict takes integer candidateRawCode, integer currentCount returns boolean
        return OMGAIConflictRule_IsConflictWith(candidateRawCode, currentCount)
    endfunction

    // 特殊处理：卡尔元素 + 地卜师大招
    // 这些技能单独走 SPECIAL_HANDLE 分支
    public function IsSpecialHandled takes integer rawCode returns boolean
        local integer ruleIdx = OMGAIConflictRule_FindRuleOfSkill(rawCode)
        if ruleIdx == 0 then
            return false
        endif
        return OMGAIConflictRule_GetPolicy(ruleIdx) == 2
    endfunction

endlibrary