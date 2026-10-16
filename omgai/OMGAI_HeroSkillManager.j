// ===========================================================================
// OMGAIHeroSkillManager.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 英雄技能赋予管理
// 技术方案 T03 / PRD 4.1.2 4+2 流程
// ---------------------------------------------------------------------------
// 关键函数：
//   * GrantSkill(unit, rawCode) - 赋予技能（含冲突保护）
//   * RemoveSkill(unit, rawCode) - 移除技能（含状态清理）
//   * HandlePassiveRebirth(unit, oldRawCode, newRawCode) - 转技能被动重生
// 注意：vcccv 现有 PlayerSkillIndices 全局供参考，本模块独立工作
// ===========================================================================
library OMGAIHeroSkillManager requires OMGAIConfig, OMGAIEventDispatcher, OMGAILogger, OMGAISkillDef, OMGAIStateCleaner

    // 赋予技能到单位
    public function GrantSkill takes unit u, integer rawCode returns nothing
        local integer skillIdx = OMGAISkillDef_FindByRawCode(rawCode)
        if skillIdx == 0 then
            call OMGAILogger_W("HSM", "GrantSkill: unknown rawCode=" + I2S(rawCode))
            return
        endif
        call UnitAddAbility(u, rawCode)
        if OMGAISkillDef_IsUltimate(skillIdx) then
            call SetPlayerAbilityAvailable(GetOwningPlayer(u), rawCode, true)
        endif

        // 触发 SKILL_GRANTED 事件（让 AI Controller 监听生成画像）
        call OMGAIEventDispatcher_ClearPayload()
        set OMGAI_EvtPayloadUnit    = u
        set OMGAI_EvtPayloadInt1   = rawCode
        call OMGAIEventDispatcher_Fire(OMGAI_EVT_SKILL_GRANTED)

        call OMGAILogger_D("HSM", "granted rawCode=" + I2S(rawCode) + " to " + GetUnitName(u))
    endfunction

    // 移除技能（含状态清理，预防竞品 -fixstate 坑）
    public function RemoveSkill takes unit u, integer rawCode returns nothing
        local integer skillIdx = OMGAISkillDef_FindByRawCode(rawCode)
        // 先清理关联 buff
        call OMGAIStateCleaner_CleanForSkillRemoval(u, rawCode)
        call UnitRemoveAbility(u, rawCode)
        call OMGAILogger_D("HSM", "removed rawCode=" + I2S(rawCode))
    endfunction

    // 转技能被动重生：转技能刷新池前移除旧被动、再赋予新被动
    // oldRawCode: 旧技能（被替换或移除）；0 表示无旧技能
    // newRawCode: 新技能 rawcode；0 表示仅移除不新增
    public function HandlePassiveRebirth takes unit u, integer oldRawCode, integer newRawCode returns nothing
        if oldRawCode != 0 then
            call RemoveSkill(u, oldRawCode)
        endif
        if newRawCode != 0 then
            call GrantSkill(u, newRawCode)
        endif
    endfunction

endlibrary