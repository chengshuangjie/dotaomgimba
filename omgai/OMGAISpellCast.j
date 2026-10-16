//===========================================================================
// OMGAISpellCast.j  --  Dota OMG 超级 AI 施法执行链
//   对应方案：§7.2-7.4（三重守卫 / 8 类 targetType / 取消计数 / 补发 / 防卡死）
//   依赖：OMGAICore, OMGAILog, OMGAIActionMask, OMGAITargetSel
//   目标：随机技能也能被 AI 正确释放（坑#1/26/27），无施法死循环（坑#5/6）
//===========================================================================

library OMGAISpellCast requires OMGAICore, OMGAILog, OMGAIActionMask, OMGAITargetSel

//---------------------------------------------------------------------------
// 1. 取消计数（坑#5：同技能同目标连续取消 2 次 → 强制换目标/放弃）
//    结构：主键=单位 hid，槽=20 存取消计数
//---------------------------------------------------------------------------

    globals
    constant integer SLOT_CANCEL_COUNT = 20
    constant integer CANCEL_MAX = 2

    endglobals
    public function OMGAI_CastCanceled takes unit u, integer abilityId, unit target returns nothing
        local integer hid = GetHandleId(u)
        local integer c = OMGAICore_OMGAI_LoadInt(hid, SLOT_CANCEL_COUNT)
        set c = c + 1
        call OMGAICore_OMGAI_SaveInt(hid, SLOT_CANCEL_COUNT, c)
        call OMGAILog_LOG_WARN("CAST", "施法取消 " + I2S(c) + "/" + I2S(CANCEL_MAX) + " ability=" + I2S(abilityId))
        if c >= CANCEL_MAX then
            // 强制换目标：目标缓存清空
            call OMGAICore_OMGAI_SaveInt(hid, 9, 0)
            call OMGAICore_OMGAI_SaveInt(hid, SLOT_CANCEL_COUNT, 0)
            call OMGAILog_LOG_INFO("CAST", "取消超限，强制换目标")
        endif
    endfunction

    public function OMGAI_CastSuccess takes unit u returns nothing
        call OMGAICore_OMGAI_SaveInt(GetHandleId(u), SLOT_CANCEL_COUNT, 0)
    endfunction

//---------------------------------------------------------------------------
// 2. 8 类 targetType 分发（方案 §7.3）
//    orderId 由 SkillPool 配表提供
//---------------------------------------------------------------------------

        public function OMGAI_IssueOrder takes unit u, integer abilityId, integer tt, unit target, real x, real y returns boolean
        if u == null then
            return false
        endif
        // V2: 直接对接基图 SuijiAI 施法引擎（技能 -> 订单映射 + 执行）
        if tt == TT_UNIT or tt == TT_ALLY or tt == TT_SELF or tt == TT_CORPSE then
            if target != null then
                return SuijiAI_IssueMappedTarget(u, target, abilityId)
            endif
        elseif tt == TT_POINT or tt == TT_AREA then
            return SuijiAI_IssueMappedPoint(u, x, y, abilityId)
        else
            return SuijiAI_IssueMappedImmediate(u, abilityId)
        endif
        return false
    endfunction

//---------------------------------------------------------------------------
// 3. 施法三重守卫（方案 §7.2，D1 CAAS 思想）
//    ① 动作掩码（CD/蓝/血/距离/目标）
//    ② 命令白名单（防吟唱插队，坑#6）
//    ③ 单位级软冷却
//---------------------------------------------------------------------------

    globals
    constant integer SLOT_SOFT_CD = 5

    endglobals
        public function OMGAI_SpellGuard takes unit u, integer abilityId, unit target returns boolean
        local integer hid = GetHandleId(u)
        local real now = OMGAICore_OMGAI_GetGameTime()
        // 1. 单位软冷却（OMGAI 自身）
        if OMGAICore_OMGAI_LoadReal(hid, SLOT_SOFT_CD) > now then
            return false
        endif
        // 2. 动作掩码校验
        if not OMGAIActionMask_OMGAI_ActionMaskValid(u, abilityId, target) then
            return false
        endif
        // 3. 基图蓝耗/资源校验（SuijiAI_CanPayAndCastNormally）
        if not SuijiAI_CanPayAndCastNormally(u, abilityId) then
            return false
        endif
        return true
    endfunction

//---------------------------------------------------------------------------
// 4. 施法入口（行为模块调用）
//    流程：Guard → IssueOrder → 成功则 MarkCooldown + CastSuccess
//          → 失败 OMGAI_CastCanceled
//    施放后 0.5s 补发原命令防站桩（D1 CAAS onAttackOrder 思想）
//---------------------------------------------------------------------------

    public function OMGAI_CastAbility takes unit u, integer abilityId, integer tt, unit target, real x, real y returns boolean
        local boolean ok = false
        if u == null then
            return false
        endif
        // 守卫
        if not OMGAISpellCast_OMGAI_SpellGuard(u, abilityId, target) then
            return false
        endif
        // 下发命令
        set ok = OMGAISpellCast_OMGAI_IssueOrder(u, abilityId, tt, target, x, y)
        if ok then
            // 登记自维护冷却（软冷却 + 技能 CD）
            call OMGAIActionMask_OMGAI_MarkCooldown(u, abilityId, OMGAIActionMask_OMGAI_GetSoftCD(abilityId))
            call OMGAICore_OMGAI_SaveReal(GetHandleId(u), SLOT_SOFT_CD, OMGAICore_OMGAI_GetGameTime() + 0.15)
            call OMGAISpellCast_OMGAI_CastSuccess(u)
            // 补发原命令（0.5s 后若 idle 则补攻击/移动）
            // TODO: TimerService 延迟回调 OMGAI_ReissueCommand(u)
            return true
        else
            call OMGAISpellCast_OMGAI_CastCanceled(u, abilityId, target)
            return false
        endif
    endfunction

//---------------------------------------------------------------------------
// 5. 防卡死补丁（D1 AIfixSimple：一次性施法技能 ENDCAST 后自动删除技能）
//    适用于 OMG 随机技能中的一次性/变身类，防 AI 发呆
//---------------------------------------------------------------------------

    public function OMGAI_EndCastRemove takes unit u, integer abilityId returns nothing
        // TODO: 判断是否一次性技能（SkillPool eventMask）
        call UnitRemoveAbility(u, abilityId)
        call OMGAILog_LOG_INFO("CAST", "ENDCAST 清理技能: " + I2S(abilityId))
    endfunction

//---------------------------------------------------------------------------
// 6. 工具
//---------------------------------------------------------------------------


    public function OMGAI_SpellCastInit takes nothing returns nothing
        call OMGAILog_LOG_INFO("CAST", "OMGAISpellCast 初始化完成")
    endfunction

endlibrary
