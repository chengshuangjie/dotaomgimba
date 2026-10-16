// ===========================================================================
// OMGAISkillData.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 技能数据初始化（数据驱动核心）
// 技术方案 T02 技能系统 / 技术方案 7.1 技能 ID 命名
// ---------------------------------------------------------------------------
// 用途：
//   * 注册 MVP 起步的技能定义（先放约 25 个示例占位，T05 阶段扩展到 60-80）
//   * 注册冲突规则（法球、变身、重击、切换型）
//   * SkillData 是数据层，新增技能只改这里，不改业务逻辑
// ---------------------------------------------------------------------------
// rawcode 说明：原版技能用 4 字符码（如 AHfa=影魔被动），存为 integer
// 实际工程中用 'AHfa' 字面量即可被 jasshelper 解释为整数 rawcode
// ===========================================================================
library OMGAISkillData initializer Init requires OMGAIConfig, OMGAIConflictRule, OMGAILogger, OMGAISkillDef, OMGAISkillPool

    // ---- 冲突组 ID 常量（自定义）----------------------------------------
    globals
        constant integer CGROUP_ORB_EFFECT    = 100   // 法球/攻击特效组
        constant integer CGROUP_TRANSFORM     = 101   // 变身组
        constant integer CGROUP_BASH          = 102   // 重击组
        constant integer CGROUP_TOGGLE       = 103   // 切换型组
    endglobals

    private function Init takes nothing returns nothing
        local integer ruleIdx

        // ============== 1. 注册冲突规则 ==============
        // 法球组（同组单生效）
        set ruleIdx = OMGAIConflictRule_Register(CGROUP_ORB_EFFECT, CONFLICT_POLICY_SINGLE_ACTIVE)

        // 变身组（互斥禁选，借鉴竞品踩坑）
        set ruleIdx = OMGAIConflictRule_Register(CGROUP_TRANSFORM, CONFLICT_POLICY_MUTUAL_EXCLUSIVE)

        // 重击组（同组单生效）
        set ruleIdx = OMGAIConflictRule_Register(CGROUP_BASH, CONFLICT_POLICY_SINGLE_ACTIVE)

        // 切换型组（架构预防，互斥禁选）
        set ruleIdx = OMGAIConflictRule_Register(CGROUP_TOGGLE, CONFLICT_POLICY_MUTUAL_EXCLUSIVE)

        call OMGAILogger_I("SkillData", "Conflict rules registered: " + I2S(ConflictRule_Count))

        // ============== 2. 注册 MVP 起步技能（约 25 个示例占位）==============
        // 注：以下 rawcode 为示意值，工程落地时需对照 war3map.w3a 物编实际 ID 替换
        // 字段顺序：rawCode, name, sourceHero, slot, tags, dmgType, dmgScale,
        //          ctrlMask, ctrlDuration, healScale, isPassive, isTransform, isDash,
        //          rangeCat, cooldownTier, conflictGroup

        // ---- 例：影魔·魔王降临（个人标记，简化为占位）-------------------
        call OMGAISkillDef_Register('ANcl', "魔王降临", 1, 1, STAG_DMG_MAGICAL + STAG_BURST_HIGH, 2, 8.0, 0, 0.0, 0.0, false, false, false, SRANGE_SHORT, SCOOLDOWN_MID, 0)

        // ---- 例：火女·龙破斩（爆发法师代表）----------------------------
        call OMGAISkillDef_Register('AHfs', "龙破斩", 2, 1, STAG_DMG_MAGICAL + STAG_BURST_HIGH, 2, 7.5, 0, 0.0, 0.0, false, false, false, SRANGE_LONG, SCOOLDOWN_MID, 0)

        // ---- 例：火女·神灭斩（大招，爆发）-----------------------------
        call OMGAISkillDef_Register('AHfa', "神灭斩", 2, 2, STAG_DMG_MAGICAL + STAG_BURST_HIGH + STAG_ULTIMATE, 2, 10.0, STAG_CTRL_STUN, 1.0, 0.0, false, false, false, SRANGE_LONG, SCOOLDOWN_HUGE, 0)

        // ---- 例：谜团·黑洞（大招，控）---------------------------------
        call OMGAISkillDef_Register('AEnf', "黑洞", 3, 2, STAG_CTRL_STUN + STAG_ULTIMATE, 0, 4.0, STAG_CTRL_STUN, 4.0, 0.0, false, false, false, SRANGE_SHORT, SCOOLDOWN_HUGE, 0)

        // ---- 例：钢背兽·刚毛（AOE）-----------------------------------
        call OMGAISkillDef_Register('Abrg', "刚毛飞射", 4, 1, STAG_DMG_PHYSICAL + STAG_SUSTAIN_HIGH + STAG_AOE, 1, 5.0, 0, 0.0, 0.0, false, false, false, SRANGE_SHORT, SCOOLDOWN_SHORT, 0)

        // ---- 例：火枪手·爆头（重击组）---------------------------------
        call OMGAISkillDef_Register('AHeh', "爆头", 5, 1, STAG_DMG_PHYSICAL + STAG_BURST_HIGH + STAG_PASSIVE, 1, 6.0, 0, 0.0, 0.0, true, false, false, SRANGE_LONG, SCOOLDOWN_NONE, CGROUP_BASH)

        // ---- 例：虚空·时间锁定（重击组）-------------------------------
        call OMGAISkillDef_Register('A0LK', "时间锁定", 6, 1, STAG_DMG_PHYSICAL + STAG_CTRL_STUN + STAG_PASSIVE, 1, 4.0, STAG_CTRL_STUN, 0.4, 0.0, true, false, false, SRANGE_MELEE, SCOOLDOWN_NONE, CGROUP_BASH)

        // ---- 例：龙骑·真龙形态（变身组，互斥禁选）---------------------
        call OMGAISkillDef_Register('AEdk', "真龙形态", 7, 2, STAG_TRANSFORM + STAG_DMG_PHYSICAL + STAG_DURABILITY + STAG_ULTIMATE, 1, 6.0, 0, 0.0, 3.0, true, true, false, SRANGE_MELEE, SCOOLDOWN_HUGE, CGROUP_TRANSFORM)

        // ---- 例：德鲁伊·熊形态（变身组，互斥禁选）---------------------
        call OMGAISkillDef_Register('Aelf', "熊形态", 8, 2, STAG_TRANSFORM + STAG_DURABILITY + STAG_ULTIMATE, 0, 0.0, 0, 0.0, 5.0, true, true, false, SRANGE_MELEE, SCOOLDOWN_HUGE, CGROUP_TRANSFORM)

        // ---- 例：智慧之刃（法球组）------------------------------------
        call OMGAISkillDef_Register('Aslw', "智慧之刃", 9, 1, STAG_DMG_PURE + STAG_PASSIVE + STAG_ORB_EFFECT, 3, 5.0, 0, 0.0, 0.0, true, false, false, SRANGE_SHORT, SCOOLDOWN_NONE, CGROUP_ORB_EFFECT)

        // ---- 例：法力损毁（法球组）------------------------------------
        call OMGAISkillDef_Register('Aamn', "法力损毁", 10, 1, STAG_DMG_MAGICAL + STAG_PASSIVE + STAG_ORB_EFFECT, 2, 4.0, 0, 0.0, 0.0, true, false, false, SRANGE_SHORT, SCOOLDOWN_NONE, CGROUP_ORB_EFFECT)

        // ---- 例：敌法师·闪烁（机动）-----------------------------------
        call OMGAISkillDef_Register('Ablk', "闪烁", 11, 1, STAG_BLINK + STAG_ESCAPE, 0, 0.0, 0, 0.0, 0.0, false, false, true, SRANGE_GLOBAL, SCOOLDOWN_MID, 0)

        // ---- 例：辅助·治疗术（治疗）----------------------------------
        call OMGAISkillDef_Register('Ahea', "治疗术", 12, 1, STAG_HEAL, 0, 0.0, 0, 0.0, 8.0, false, false, false, SRANGE_LONG, SCOOLDOWN_MID, 0)

        // ---- 例：水晶室女·光辉之环（光环）----------------------------
        call OMGAISkillDef_Register('Aaur', "光辉光环", 13, 1, STAG_AURA, 0, 0.0, 0, 0.0, 4.0, true, false, false, SRANGE_GLOBAL, SCOOLDOWN_NONE, 0)

        call OMGAILogger_I("SkillData", "Skills registered: " + I2S(SkillDef_Count))

        // ============== 3. 构建小池/大池 ==============
        call OMGAISkillPool_BuildPools()
    endfunction

endlibrary