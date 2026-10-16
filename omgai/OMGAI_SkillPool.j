// ===========================================================================
// OMGAISkillPool.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 技能总池（小池 + 大池）构建
// 技术方案 T02 技能系统 / PRD 4.1.3 技能池=所有英雄技能汇总
// ---------------------------------------------------------------------------
// 职责：
//   * BuildSmallPool(): 遍历 SkillDef，把 slot=1（小技能）的 ID 收集进 SmallPool
//   * BuildBigPool():   遍历 SkillDef，把 slot=2（大招）的 ID 收集进 BigPool
//   * GetRandomOffers(): 从指定池随机抽 N 个，过滤禁选+排除已选+冲突校验
// 设计：
//   * 池为数组 + count 计数
//   * GetRandomOffers 用 Fisher-Yates 洗牌子集
// ===========================================================================
library OMGAISkillPool requires OMGAIConfig, OMGAIConflictRule, OMGAILogger, OMGAISkillDef

    globals
        // ---- 小技能池（slot=1），最多 256 --------------------------------
        integer array SmallPool_Indices       // 存 SkillDef index
        integer SmallPool_Count = 0
        // ---- 大招池（slot=2）
        integer array BigPool_Indices
        integer BigPool_Count = 0
        // data channels (vJASS: no array params / local arrays)
        integer array SkillPool_ExcludeRawCodes   // input: exclude rawcode list
        integer array SkillPool_Candidates        // internal: candidate buffer
        integer array SkillPool_OutIndices        // output: picked SkillDef indices (1..count)
    endglobals

    // 构建两个子池（在 SkillData.init 之后调用）
    public function BuildPools takes nothing returns nothing
        local integer i
        local integer slot
        set SmallPool_Count = 0
        set BigPool_Count   = 0
        set i = 1
        loop
            exitwhen i > SkillDef_Count
            set slot = SkillDef_Slot[i]
            if slot == 1 then
                set SmallPool_Count = SmallPool_Count + 1
                set SmallPool_Indices[SmallPool_Count] = i
            elseif slot == 2 then
                set BigPool_Count = BigPool_Count + 1
                set BigPool_Indices[BigPool_Count] = i
            endif
            set i = i + 1
        endloop
        call OMGAILogger_I("SkillPool", "SmallPool=" + I2S(SmallPool_Count) + " BigPool=" + I2S(BigPool_Count))
    endfunction

    // 从指定池随机抽 N 个 SkillDef index，返回填充到 outArray
    // poolType: 1=小池 2=大池
    // count:    抽取数量
    // excludeRawCodes: 已选/固定的技能 rawcode 数组（这些不能出现）
    // excludeCount: excludeRawCodes 有效长度
    // outArray: 输出数组（填充 1..count）
    // 返回 实际成功抽取的数量（若池不足可能小于 count）
    public function GetRandomOffers takes integer poolType, integer count, integer excludeCount returns integer
        local integer poolStart
        local integer poolCount
        local integer candidateCount = 0
        local integer i
        local integer j
        local integer idx
        local integer rawCode
        local integer result
        local integer picked
        local boolean excluded
        local boolean conflict

        // 选用池
        if poolType == 1 then
            set poolCount = SmallPool_Count
        else
            set poolCount = BigPool_Count
        endif

        if poolCount == 0 then
            call OMGAILogger_W("SkillPool", "GetRandomOffers: empty pool")
            return 0
        endif

        // 预填充冲突校验输入通道（exclude 列表在整个筛选过程中不变）
        set i = 1
        loop
            exitwhen i > excludeCount
            set ConflictRule_CheckList[i] = SkillPool_ExcludeRawCodes[i]
            set i = i + 1
        endloop

        // 第一阶段：遍历池，过滤禁选/排除/冲突
        set i = 1
        loop
            exitwhen i > poolCount
            set idx = 0
            if poolType == 1 then
                set idx = SmallPool_Indices[i]
            else
                set idx = BigPool_Indices[i]
            endif

            set rawCode = SkillDef_RawCode[idx]

            // 排除已选
            set excluded = false
            set j = 1
            loop
                exitwhen j > excludeCount
                if SkillPool_ExcludeRawCodes[j] == rawCode then
                    set excluded = true
                    exitwhen true
                endif
                set j = j + 1
            endloop

            // 排除冲突（与当前已选技能）
            set conflict = false
            if not excluded then
                set conflict = OMGAIConflictRule_IsConflictWith(rawCode, excludeCount)
            endif

            if not excluded and not conflict then
                set candidateCount = candidateCount + 1
                set SkillPool_Candidates[candidateCount] = idx
            endif

            set i = i + 1
        endloop

        if candidateCount == 0 then
            call OMGAILogger_W("SkillPool", "GetRandomOffers: no valid candidates after filter")
            return 0
        endif

        // 第二阶段：Fisher-Yates 部分洗牌取前 count 个
        set i = 1
        loop
            exitwhen i > count or i >= candidateCount
            // 随机选 j in [i, candidateCount]
            set j = i + GetRandomInt(0, candidateCount - i)
            // 交换 candidates[i] 与 candidates[j]
            set picked      = SkillPool_Candidates[i]
            set SkillPool_Candidates[i] = SkillPool_Candidates[j]
            set SkillPool_Candidates[j] = picked
            set SkillPool_OutIndices[i] = SkillPool_Candidates[i]
            set i = i + 1
        endloop
        // 若 i 不足 count，把剩余 candidates[i..] 填入
        loop
            exitwhen i > count or i > candidateCount
            set SkillPool_OutIndices[i] = SkillPool_Candidates[i]
            set i = i + 1
        endloop

        return i - 1
    endfunction

endlibrary