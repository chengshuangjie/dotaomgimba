//===========================================================================
// OMGAIGuard.j  --  Dota OMG 超级 AI 崩溃防护
//   对应方案：§10（P1~P9）
//   依赖：OMGAICore, OMGAILog
//   目标：竞品常崩我们零崩；必崩图降档保局；异常现场可转储
//===========================================================================

library OMGAIGuard requires OMGAICore, OMGAILog

    public function OMGAICore_GetTable takes nothing returns hashtable
        return OMGAICore_OMGAI_GetHash()
    endfunction

//---------------------------------------------------------------------------
// 1. 防护计数器
//---------------------------------------------------------------------------

    globals
    integer GUARD_ENUM_COUNT  = 0    // 单 tick 枚举数
    integer GUARD_RECUR_DEPTH = 0    // 递归深度
    integer GUARD_ERROR_SEQ   = 0    // 连续 ERROR 计数

    constant integer MAX_ILLUSIONS   = 4  // 每英雄最大幻象数
    constant integer MAX_SUMMONS     = 8  // 每英雄最大召唤物数

//---------------------------------------------------------------------------
// 2. P2：枚举/递归上限
//---------------------------------------------------------------------------

    endglobals
    public function OMGAI_GuardEnumEnter takes nothing returns nothing
        set GUARD_ENUM_COUNT = GUARD_ENUM_COUNT + 1
    endfunction

    public function OMGAI_GuardEnumCanContinue takes nothing returns boolean
        return GUARD_ENUM_COUNT < GUARD_ENUM_MAX
    endfunction

    public function OMGAI_GuardEnumReset takes nothing returns nothing
        set GUARD_ENUM_COUNT = 0
    endfunction

    public function OMGAI_GuardRecurEnter takes nothing returns boolean
        set GUARD_RECUR_DEPTH = GUARD_RECUR_DEPTH + 1
        if GUARD_RECUR_DEPTH > GUARD_RECUR_MAX then
            set GUARD_RECUR_DEPTH = GUARD_RECUR_DEPTH - 1
            call OMGAILog_LOG_WARN("GUARD", "递归深度超限，强制返回")
            return false
        endif
        return true
    endfunction

    public function OMGAI_GuardRecurExit takes nothing returns nothing
        set GUARD_RECUR_DEPTH = GUARD_RECUR_DEPTH - 1
        if GUARD_RECUR_DEPTH < 0 then
            set GUARD_RECUR_DEPTH = 0
        endif
    endfunction

//---------------------------------------------------------------------------
// 3. P1：句柄生命周期（单位死亡/移除统一回调）
//    所有 AI 单位死亡、被移除时必须调用本函数
//---------------------------------------------------------------------------

    public function OMGAI_GuardUnitRemoved takes unit u returns nothing
        local integer hid = GetHandleId(u)
        if u == null then
            return
        endif
        // 清该单位全部 hashtable 条目
        call FlushChildHashtable(OMGAIGuard_OMGAICore_GetTable(), hid)
        // 移出 AI 单位表
        call OMGAICore_OMGAICore_UnregisterUnit(u)
        // 清仇恨表引用 / 集火 / 目标缓存
        // TODO: 调用 OMGAIEnemyState_ClearUnitRefs(hid)
        // TODO: 调用 OMGAITargetSel_ClearUnitRefs(hid)
        call OMGAILog_LOG_INFO("GUARD", "单位清理: " + I2S(hid))
    endfunction

    // 获取主表（OMGAICore 提供，避免直接依赖内部字段）

//---------------------------------------------------------------------------
// 4. P4：幻象/召唤物治理
//    记录每英雄当前幻象/召唤物数量，超限先清最旧
//---------------------------------------------------------------------------

    // 幻象数量表（主键=英雄hid，槽=数量）
    public function OMGAI_GuardIllusionAdd takes unit hero, unit illu returns boolean
        local integer hid = GetHandleId(hero)
        local integer n = OMGAICore_OMGAI_LoadInt(hid, 90)
        if n >= MAX_ILLUSIONS then
            call OMGAILog_LOG_WARN("GUARD", "幻象超限，拒绝新增")
            return false
        endif
        set n = n + 1
        call OMGAICore_OMGAI_SaveInt(hid, 90, n)
        // TODO: 登记幻象句柄到清理表（死亡时 OMGAI_GuardIllusionRemove）
        return true
    endfunction

    public function OMGAI_GuardIllusionRemove takes unit hero returns nothing
        local integer hid = GetHandleId(hero)
        local integer n = OMGAICore_OMGAI_LoadInt(hid, 90)
        set n = n - 1
        if n < 0 then
            set n = 0
        endif
        call OMGAICore_OMGAI_SaveInt(hid, 90, n)
    endfunction

    // 召唤物数量（同理，槽 91）
    public function OMGAI_GuardSummonAdd takes unit hero returns boolean
        local integer hid = GetHandleId(hero)
        local integer n = OMGAICore_OMGAI_LoadInt(hid, 91)
        if n >= MAX_SUMMONS then
            call OMGAILog_LOG_WARN("GUARD", "召唤物超限，拒绝新增")
            return false
        endif
        set n = n + 1
        call OMGAICore_OMGAI_SaveInt(hid, 91, n)
        return true
    endfunction

    public function OMGAI_GuardSummonRemove takes unit hero returns nothing
        local integer hid = GetHandleId(hero)
        local integer n = OMGAICore_OMGAI_LoadInt(hid, 91)
        set n = n - 1
        if n < 0 then
            set n = 0
        endif
        call OMGAICore_OMGAI_SaveInt(hid, 91, n)
    endfunction

//---------------------------------------------------------------------------
// 5. P5：变身技能状态机（快照/恢复）
//    变身前后保存属性/技能树/装备，恢复失败强制回滚
//---------------------------------------------------------------------------

    globals
    hashtable MORPH_TABLE = null

    endglobals
    public function OMGAI_GuardMorphSave takes unit u returns nothing
        if MORPH_TABLE == null then
            set MORPH_TABLE = InitHashtable()
        endif
        call SaveReal(MORPH_TABLE, GetHandleId(u), 0, GetUnitState(u, UNIT_STATE_MAX_LIFE))
        call SaveReal(MORPH_TABLE, GetHandleId(u), 1, GetUnitState(u, UNIT_STATE_MAX_MANA))
        // TODO: 保存技能等级数组 + 装备栏
        call OMGAILog_LOG_INFO("GUARD", "变身快照: " + I2S(GetHandleId(u)))
    endfunction

    public function OMGAI_GuardMorphRestore takes unit u returns nothing
        local integer hid = GetHandleId(u)
        if MORPH_TABLE == null then
            return
        endif
        if HaveSavedReal(MORPH_TABLE, hid, 0) then
            // 恢复属性
            call SetUnitState(u, UNIT_STATE_MAX_LIFE, LoadReal(MORPH_TABLE, hid, 0))
            call SetUnitState(u, UNIT_STATE_MAX_MANA, LoadReal(MORPH_TABLE, hid, 1))
            call RemoveSavedReal(MORPH_TABLE, hid, 0)
            call RemoveSavedReal(MORPH_TABLE, hid, 1)
        else
            // 快照不存在 = 恢复失败，强制回滚脚本（防残留）
            call OMGAILog_LOG_WARN("GUARD", "变身恢复失败，强制回滚")
            // TODO: 强制恢复技能树/装备
        endif
    endfunction

//---------------------------------------------------------------------------
// 6. P6：持续施法守护（channel 期间屏蔽其它技能决策）
//    被强打断 → 立即清引导状态
//---------------------------------------------------------------------------

    public function OMGAI_GuardChannelBroken takes unit u returns nothing
        // TODO: 清理引导状态标记 + 恢复单位攻击/移动命令
        call OMGAILog_LOG_INFO("GUARD", "持续施法被打断: " + I2S(GetHandleId(u)))
    endfunction

//---------------------------------------------------------------------------
// 7. P7：结算/存档原子性（失败重试 ≤2，不阻塞主线程）
//---------------------------------------------------------------------------

    public function OMGAI_GuardRetry takes nothing returns nothing
        // TODO: 结算/KK 写入失败时重试逻辑（≤2 次）
    endfunction

//---------------------------------------------------------------------------
// 8. P9：必崩图检测（开局 30s 静默自检，失败降档保局）
//---------------------------------------------------------------------------

    public function OMGAI_GuardSelfCheck takes nothing returns boolean
        // 1) SkillPool 配表完整性
        // TODO: call OMGAISkillPool_CheckIntegrity() → 失败返回 false
        // 2) 组合黑名单生效
        // TODO: call OMGAI_CheckBlacklist()
        // 3) 核心组件初始化
        if not OMGAICore_OMGAICore_IsInited() then
            call OMGAILog_LOG_ERROR("GUARD", "自检失败: OMGAICore 未初始化")
            return false
        endif
        return true
    endfunction

    // 降档：AI 最低档（只补刀不出击）
    public function OMGAI_GuardDegrade takes nothing returns nothing
        call OMGAICore_OMGAI_SaveGlobalInt(GSLOT_DIFFICULTY, 0)  // 难度 0 = 最低档
        call OMGAILog_LOG_FATAL("GUARD", "必崩图检测失败，本局 AI 降档")
    endfunction

//---------------------------------------------------------------------------
// 9. 巡检（心跳挂接，每 5 tick 一次单位级 + 1s 一次全局级）
//---------------------------------------------------------------------------

    public function OMGAI_GuardInspect takes unit u returns nothing
        // TODO: 句柄水位检查（该单位相关缓存是否异常增长）
    endfunction

    public function OMGAI_GuardGlobalInspect takes nothing returns nothing
        // 1) 单位表水位
        // TODO: 检查 AIUnitTable 空位
        // 2) 幻象/召唤物总量
        // 3) ERROR 连续计数 → 触发崩溃转储
        // TODO: 由 OMGAILog 提供 ERROR 回调，此处累计
    endfunction

    public function OMGAI_GuardInit takes nothing returns nothing
        call OMGAICore_OMGAI_SaveGlobalInt(GSLOT_GUARD_ENUM, 0)
        call OMGAICore_OMGAI_SaveGlobalInt(GSLOT_GUARD_RECUR, 0)
        call OMGAILog_LOG_INFO("GUARD", "OMGAIGuard 初始化完成")
    endfunction

endlibrary
