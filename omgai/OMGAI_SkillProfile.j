// ===========================================================================
// OMGAISkillProfile.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 技能画像（SkillDef 标签汇总）
// 技术方案 T02 技能系统 / PRD 4.3.3 SkillProfile
// ---------------------------------------------------------------------------
// 用途：
//   * AIController 在英雄完成 4+2 选技能后，调用 BuildFromSkills 生成画像
//   * AIEvaluator 根据 5 个分数匹配 ArchetypeStrategy
//   * SkillProfile 是数据中转，无副作用
// ===========================================================================
library OMGAISkillProfile requires OMGAIConfig, OMGAISkillDef, OMGAISkillTag

    // ---- SkillProfile 全局数组（每个玩家一份，按 playerId 索引）---------
    globals
        // 输入通道：待画像的技能 SkillDef index 列表（调用方先填充）
        integer array SkillProfile_InputIndices
        real array SkillProfile_Burst      // 爆发 0-10
        real array SkillProfile_Sustain      // 续航
        real array SkillProfile_Control     // 控制
        real array SkillProfile_Mobility     // 机动
        real array SkillProfile_Durability   // 承伤
        real array SkillProfile_Heal         // 治疗
    endglobals

    // 从一组技能构造画像
    // skillIndices - 技能 SkillDef index 数组
    // count        - 数组有效长度
    // targetPlayerId - 把画像写入对应的 playerId
    public function BuildFromSkills takes integer count, integer targetPlayerId returns nothing
        local integer i
        local integer idx
        local integer tags
        local integer ctrlMask
        local real burst       = 0
        local real sustain      = 0
        local real control       = 0
        local real mobility     = 0
        local real durability    = 0
        local real heal         = 0

        set i = 1
        loop
            exitwhen i > count
            set idx = SkillProfile_InputIndices[i]
            if idx >= 1 and idx <= SkillDef_Count then
                set tags     = SkillDef_Tags[idx]
                set ctrlMask = SkillDef_CtrlMask[idx]

                // 爆发分：含 BURST_HIGH 加 7，含 DMG_MAGICAL 加 2（法系爆发基础分）
                if OMGAISkillTag_HasTag(tags, STAG_BURST_HIGH) then
                    set burst = burst + 7.0
                endif
                if OMGAISkillTag_HasTag(tags, STAG_DMG_MAGICAL) then
                    set burst = burst + 2.0
                endif

                // 持续输出分：含 SUSTAIN_HIGH 加 6，含 DMG_PHYSICAL 加 2
                if OMGAISkillTag_HasTag(tags, STAG_SUSTAIN_HIGH) then
                    set sustain = sustain + 6.0
                endif
                if OMGAISkillTag_HasTag(tags, STAG_DMG_PHYSICAL) then
                    set sustain = sustain + 2.0
                endif

                // 控制分：每种控制 +3，最长持续 +1
                if OMGAISkillTag_HasTag(ctrlMask, STAG_CTRL_STUN) then
                    set control = control + 3.0
                endif
                if OMGAISkillTag_HasTag(ctrlMask, STAG_CTRL_SLOW) then
                    set control = control + 1.5
                endif
                if OMGAISkillTag_HasTag(ctrlMask, STAG_CTRL_SILENCE) then
                    set control = control + 2.0
                endif
                if OMGAISkillTag_HasTag(ctrlMask, STAG_CTRL_ROOT) then
                    set control = control + 2.0
                endif
                set control = control + SkillDef_CtrlDuration[idx] * 0.5

                // 机动分：DASH +2，BLINK +4，ESCAPE +2
                if OMGAISkillTag_HasTag(tags, STAG_DASH) then
                    set mobility = mobility + 2.0
                endif
                if OMGAISkillTag_HasTag(tags, STAG_BLINK) then
                    set mobility = mobility + 4.0
                endif
                if OMGAISkillTag_HasTag(tags, STAG_ESCAPE) then
                    set mobility = mobility + 2.0
                endif

                // 承伤分：DURABILITY 加 5，SHIELD 加 3
                if OMGAISkillTag_HasTag(tags, STAG_DURABILITY) then
                    set durability = durability + 5.0
                endif
                if OMGAISkillTag_HasTag(tags, STAG_SHIELD) then
                    set durability = durability + 3.0
                endif

                // 治疗分：HEAL 加 5，LIFESTEAL 加 2
                if OMGAISkillTag_HasTag(tags, STAG_HEAL) then
                    set heal = heal + 5.0
                endif
                if OMGAISkillTag_HasTag(tags, STAG_LIFESTEAL) then
                    set heal = heal + 2.0
                endif
            endif
            set i = i + 1
        endloop

        // 归一化到 0-10
        if burst > 10.0 then
            set burst = 10.0
        endif
        if sustain > 10.0 then
            set sustain = 10.0
        endif
        if control > 10.0 then
            set control = 10.0
        endif
        if mobility > 10.0 then
            set mobility = 10.0
        endif
        if durability > 10.0 then
            set durability = 10.0
        endif
        if heal > 10.0 then
            set heal = 10.0
        endif

        set SkillProfile_Burst[targetPlayerId]     = burst
        set SkillProfile_Sustain[targetPlayerId]    = sustain
        set SkillProfile_Control[targetPlayerId]  = control
        set SkillProfile_Mobility[targetPlayerId] = mobility
        set SkillProfile_Durability[targetPlayerId] = durability
        set SkillProfile_Heal[targetPlayerId]      = heal
    endfunction

    // 清空画像（玩家离开/重选）
    public function Clear takes integer playerId returns nothing
        set SkillProfile_Burst[playerId]    = 0.0
        set SkillProfile_Sustain[playerId]    = 0.0
        set SkillProfile_Control[playerId]     = 0.0
        set SkillProfile_Mobility[playerId]    = 0.0
        set SkillProfile_Durability[playerId] = 0.0
        set SkillProfile_Heal[playerId]        = 0.0
    endfunction

endlibrary