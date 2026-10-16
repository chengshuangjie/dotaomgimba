// ===========================================================================
// OMGAIConflictRule.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 技能冲突规则定义
// 技术方案 T02 技能系统 / PRD 4.4 技能冲突规则
// ---------------------------------------------------------------------------
// 借鉴竞品踩坑（PRD 4.4.1 冲突规则表）：
//   * 法球/攻击特效组：同组单生效（取优先级最高）
//   * 变身组：同组禁选第二个
//   * 重击组：同组单生效
//   * 切换型技能：架构预防（不能选了用不了）
//   * 卡尔元素/地卜师大招：特殊处理
// 设计：
//   * 冲突组用 integer id 标识
//   * policy: 0=同组单生效  1=同组全禁选  2=特殊处理
//   * members: 技能 ID 数组（最长 16）
//   * 用全局数组+计数方式实现（与 vcccv 风格一致）
// ===========================================================================
library OMGAIConflictRule requires OMGAIConfig, OMGAILogger

    // ---- 冲突策略枚举 ----------------------------------------------------
    globals
        constant integer CONFLICT_POLICY_SINGLE_ACTIVE   = 0   // 同组只生效一个（取优先级）
        constant integer CONFLICT_POLICY_MUTUAL_EXCLUSIVE = 1   // 同组互斥禁选（变身/切换型）
        constant integer CONFLICT_POLICY_SPECIAL_HANDLE  = 2   // 特殊处理（卡尔/地卜师）
    endglobals

    // ---- 冲突规则全局表（数据驱动）--------------------------------------
    // 最多 64 个冲突组，每组最多 16 个成员
    globals
        integer array ConflictRule_GroupId    // 1..64
        integer array ConflictRule_Policy     // 1..64
        integer array ConflictRule_MemberCount // 1..64
        integer array ConflictRule_PriorityA   // 1..1024  (members 平铺，每组 16 个)
        integer array ConflictRule_MemberId    // 1..1024  (members 平铺，每组 16 个)
        integer ConflictRule_Count = 0
        // conflict check input channel (vJASS: no array params, caller fills first)
        integer array ConflictRule_CheckList
        integer ConflictRule_CheckCount = 0
    endglobals

    // 注册一条冲突规则
    // groupId - 冲突组 ID（自定义）
    // policy  - CONFLICT_POLICY_*
    public function Register takes integer groupId, integer policy returns integer
        set ConflictRule_Count = ConflictRule_Count + 1
        set ConflictRule_GroupId[ConflictRule_Count] = groupId
        set ConflictRule_Policy[ConflictRule_Count] = policy
        set ConflictRule_MemberCount[ConflictRule_Count] = 0
        return ConflictRule_Count
    endfunction

    // 向某冲突组追加成员技能
    // ruleIndex - Register 返回的索引
    // skillId   - 成员技能 rawCode
    // priority  - 优先级（同组单生效时取最高）
    public function AddMember takes integer ruleIndex, integer skillId, integer priority returns nothing
        local integer memberIdx
        if ruleIndex < 1 or ruleIndex > ConflictRule_Count then
            call OMGAILogger_E("ConflictRule", "AddMember: invalid ruleIndex=" + I2S(ruleIndex))
            return
        endif
        if ConflictRule_MemberCount[ruleIndex] >= 16 then
            call OMGAILogger_E("ConflictRule", "AddMember: group " + I2S(ConflictRule_GroupId[ruleIndex]) + " max 16 members")
            return
        endif
        set ConflictRule_MemberCount[ruleIndex] = ConflictRule_MemberCount[ruleIndex] + 1
        set memberIdx = (ruleIndex - 1) * 16 + ConflictRule_MemberCount[ruleIndex]
        set ConflictRule_MemberId[memberIdx]   = skillId
        set ConflictRule_PriorityA[memberIdx]  = priority
    endfunction

    // 查询某个技能属于哪个冲突组（返回 ruleIndex，0 表示无冲突）
    public function FindRuleOfSkill takes integer skillId returns integer
        local integer i
        local integer j
        local integer memberIdx
        set i = 1
        loop
            exitwhen i > ConflictRule_Count
            set j = 1
            loop
                exitwhen j > ConflictRule_MemberCount[i]
                set memberIdx = (i - 1) * 16 + j
                if ConflictRule_MemberId[memberIdx] == skillId then
                    return i
                endif
                set j = j + 1
            endloop
            set i = i + 1
        endloop
        return 0
    endfunction

    // 检测待选技能与当前已选技能是否冲突
    // candidateId  - 待校验技能
    // currentSkills - 当前已选技能 ID 数组（含固定技能）
    // currentCount   - 数组有效长度
        public function IsConflictWith takes integer candidateId, integer currentCount returns boolean
        local integer ruleIdx = FindRuleOfSkill(candidateId)
        local integer i
        local integer curRuleIdx
        if ruleIdx == 0 then
            return false
        endif
        // read current skills from ConflictRule_CheckList (pre-filled by caller)
        if ConflictRule_Policy[ruleIdx] == CONFLICT_POLICY_MUTUAL_EXCLUSIVE then
            set i = 1
            loop
                exitwhen i > currentCount
                if ConflictRule_CheckList[i] != 0 then
                    set curRuleIdx = FindRuleOfSkill(ConflictRule_CheckList[i])
                    if curRuleIdx == ruleIdx then
                        return true
                    endif
                endif
                set i = i + 1
            endloop
            return false
        endif

        if ConflictRule_Policy[ruleIdx] == CONFLICT_POLICY_SINGLE_ACTIVE then
            set i = 1
            loop
                exitwhen i > currentCount
                if ConflictRule_CheckList[i] != 0 then
                    set curRuleIdx = FindRuleOfSkill(ConflictRule_CheckList[i])
                    if curRuleIdx == ruleIdx then
                        return true
                    endif
                endif
                set i = i + 1
            endloop
            return false
        endif

        // special handle: default no conflict, resolved by SkillConflictResolver
        return false
    endfunction

    // query group policy (public access for SkillConflictResolver)
    public function GetPolicy takes integer ruleIndex returns integer
        if ruleIndex < 1 or ruleIndex > ConflictRule_Count then
            return -1
        endif
        return ConflictRule_Policy[ruleIndex]
    endfunction

endlibrary