// ===========================================================================
// OMGAISkillDef.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 技能定义（核心数据结构，数据驱动）
// 技术方案 T02 技能系统 / PRD 4.3.2 AI 标签字段
// ---------------------------------------------------------------------------
// 设计：
//   * 用全局数组 + integer 索引方式实现（与 vcccv 风格一致，避免 vJASS struct 实例数限制）
//   * 每个技能定义为 SkillDef[i]，i=1..N
//   * 数据通过 SkillData.j 的 RegisterSkill 初始化
// ===========================================================================
library OMGAISkillDef requires OMGAIConfig, OMGAILogger, OMGAISkillTag

    globals
        // ---- 技能定义数组（最多 256 个，MVP 60-80）----------------------
        integer array SkillDef_RawCode     // 技能 rawcode（AHfa 之类，存为 integer）
        string  array SkillDef_Name        // 中文名（用于 UI 显示）
        integer array SkillDef_SourceHero  // 源英雄 ID
        integer array SkillDef_Slot         // 槽位 1=小技能/2=大招
        integer array SkillDef_Tags         // AI 标签位掩码（STAG_* OR 组合）
        integer array SkillDef_DmgType    // 0=无伤 1=物 2=法 3=纯
        real    array SkillDef_DmgScale     // 0-10 伤害量级
        integer array SkillDef_CtrlMask   // 控制类型（STAG_CTRL_* OR）
        real    array SkillDef_CtrlDuration // 控制时长（秒）
        real    array SkillDef_HealScale   // 0-10 治疗/续航量级
        boolean array SkillDef_IsPassive
        boolean array SkillDef_IsTransform
        boolean array SkillDef_IsDash
        integer array SkillDef_RangeCat   // SRANGE_*
        integer array SkillDef_CooldownTier // SCOOLDOWN_*
        integer array SkillDef_ConflictGroup // 冲突组 ID（0=无）
        integer SkillDef_Count = 0

        // ---- 索引：rawcode -> SkillDef index（O(1) 查找）-----------------
        hashtable SkillDef_RawCodeTable = null
    endglobals

    // 注册一个技能到 SkillDef
    // 返回 SkillDef index
    public function Register takes integer rawCode, string name, integer sourceHero, integer slot, integer tags, integer dmgType, real dmgScale, integer ctrlMask, real ctrlDuration, real healScale, boolean isPassive, boolean isTransform, boolean isDash, integer rangeCat, integer cooldownTier, integer conflictGroup returns integer
        set SkillDef_Count = SkillDef_Count + 1
        set SkillDef_RawCode[SkillDef_Count]     = rawCode
        set SkillDef_Name[SkillDef_Count]      = name
        set SkillDef_SourceHero[SkillDef_Count] = sourceHero
        set SkillDef_Slot[SkillDef_Count]      = slot
        set SkillDef_Tags[SkillDef_Count]      = tags
        set SkillDef_DmgType[SkillDef_Count]  = dmgType
        set SkillDef_DmgScale[SkillDef_Count]  = dmgScale
        set SkillDef_CtrlMask[SkillDef_Count] = ctrlMask
        set SkillDef_CtrlDuration[SkillDef_Count] = ctrlDuration
        set SkillDef_HealScale[SkillDef_Count] = healScale
        set SkillDef_IsPassive[SkillDef_Count]  = isPassive
        set SkillDef_IsTransform[SkillDef_Count] = isTransform
        set SkillDef_IsDash[SkillDef_Count]    = isDash
        set SkillDef_RangeCat[SkillDef_Count]   = rangeCat
        set SkillDef_CooldownTier[SkillDef_Count] = cooldownTier
        set SkillDef_ConflictGroup[SkillDef_Count] = conflictGroup

        // 入索表
        if SkillDef_RawCodeTable == null then
            set SkillDef_RawCodeTable = InitHashtable()
        endif
        call SaveInteger(SkillDef_RawCodeTable, rawCode, 0, SkillDef_Count)

        return SkillDef_Count
    endfunction

    // rawcode 反查 SkillDef index
    public function FindByRawCode takes integer rawCode returns integer
        if SkillDef_RawCodeTable == null then
            return 0
        endif
        return LoadInteger(SkillDef_RawCodeTable, rawCode, 0)
    endfunction

    // 工具：测试某技能是否含某标签
    public function HasTag takes integer skillIdx, integer testTag returns boolean
        if skillIdx < 1 or skillIdx > SkillDef_Count then
            return false
        endif
        return OMGAISkillTag_HasTag(SkillDef_Tags[skillIdx], testTag)
    endfunction

    // 工具：判断是否大招（用于池分类）
    public function IsUltimate takes integer skillIdx returns boolean
        return SkillDef_Slot[skillIdx] == 2
    endfunction

endlibrary