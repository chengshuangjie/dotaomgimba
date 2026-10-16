//===========================================================================
// OMGAIActionMask.j  --  Dota OMG 超级 AI 动作掩码
//   对应方案：§7.1（冷却期零寻敌，坑#13）
//   依赖：OMGAICore, OMGAILog
//   功能：技能可行性前置过滤----CD/蓝量/血量/距离/目标存活/命令白名单
//   原则：被 mask 的技能不参与目标搜索，避免无效寻敌开销（坑#13/16）
//===========================================================================

library OMGAIActionMask requires OMGAICore, OMGAILog

    private function DistanceBetweenUnits takes unit a, unit b returns real
        local real dx = GetUnitX(a) - GetUnitX(b)
        local real dy = GetUnitY(a) - GetUnitY(b)
        return SquareRoot(dx * dx + dy * dy)
    endfunction

//---------------------------------------------------------------------------
// 1. 技能配表读取（SkillPool schema 槽位，见方案 §4.4）
//    槽 0 targetType / 1 range / 2 orderId / 3 softCD / 4 minMana% / 5 minHp%
//    6 minEnemies / 7 eventMask / 8 skillLevel / 9 isPassive / 10 优先级
//---------------------------------------------------------------------------

    // 从 SkillPool 读技能等级（既有库对接点）
    public function OMGAI_GetSkillLevel takes unit u, integer abilityId returns integer
        // TODO: 对接既有 SkillPool（GetUnitAbilityLevel）
        return GetUnitAbilityLevel(u, abilityId)
    endfunction

    // 从 SkillPool 读 targetType
    public function OMGAI_GetTargetType takes integer abilityId returns integer
        // TODO: 对接既有 SkillPool 注册表
        return TT_UNIT
    endfunction

    // 从 SkillPool 读施法距离
    public function OMGAI_GetCastRange takes integer abilityId returns real
        // TODO: 对接既有 SkillPool 注册表
        return 600.0
    endfunction

    // 从 SkillPool 读软冷却（秒）
    public function OMGAI_GetSoftCD takes integer abilityId returns real
        // TODO: 对接既有 SkillPool 注册表
        return 5.0
    endfunction

    // 从 SkillPool 读最低蓝量百分比（-1 = 不限）
    public function OMGAI_GetMinManaPct takes integer abilityId returns integer
        // TODO: 对接既有 SkillPool 注册表
        return 15
    endfunction

    // 从 SkillPool 读最低血量百分比（-1 = 不限）
    public function OMGAI_GetMinHpPct takes integer abilityId returns integer
        // TODO: 对接既有 SkillPool 注册表
        return -1
    endfunction

    // 从 SkillPool 读最小命中敌人数
    public function OMGAI_GetMinEnemies takes integer abilityId returns integer
        // TODO: 对接既有 SkillPool 注册表
        return -1
    endfunction

//---------------------------------------------------------------------------
// 2. 自维护冷却表（1.27 无 BlzGetUnitAbilityCooldownRemaining，必须自管）
//    结构：主键=单位 hid，二级槽=1000+abilityId 存"冷却就绪时间"
//    注：abilityId 是整数四字符码，槽位用 1000 + Modulo(abilityId, 8000)
//        避免与 AI 状态槽（0..99）冲突
//---------------------------------------------------------------------------

    private function OMGAI_CDSlot takes integer abilityId returns integer
        return 1000 + ModuloInteger(abilityId, 8000)
    endfunction

    public function OMGAI_MarkCooldown takes unit u, integer abilityId, real cd returns nothing
        local integer hid = GetHandleId(u)
        local real now = OMGAICore_OMGAI_GetGameTime()
        call OMGAICore_OMGAI_SaveReal(hid, OMGAI_CDSlot(abilityId), now + cd)
    endfunction

    public function OMGAI_IsCooldownReady takes unit u, integer abilityId returns boolean
        local integer hid = GetHandleId(u)
        local real now = OMGAICore_OMGAI_GetGameTime()
        return OMGAICore_OMGAI_LoadReal(hid, OMGAI_CDSlot(abilityId)) <= now
    endfunction

//---------------------------------------------------------------------------
// 3. 动作掩码总入口（坑#13：CD/蓝量不足直接 mask，不参与目标搜索）
//    返回 true = 技能当前可评估/可施放
//---------------------------------------------------------------------------

    public function OMGAI_ActionMaskValid takes unit u, integer abilityId, unit target returns boolean
        local integer hid = GetHandleId(u)
        local integer level = 0
        local integer minMana = 0
        local integer minHp = 0
        local real maxMana = 0.0
        local real maxHp = 0.0

        if u == null then
            return false
        endif
        // 1) 技能等级 > 0（已学习）
        set level = OMGAIActionMask_OMGAI_GetSkillLevel(u, abilityId)
        if level <= 0 then
            return false
        endif
        // 2) CD 检查（自维护冷却表）
        if not OMGAIActionMask_OMGAI_IsCooldownReady(u, abilityId) then
            return false
        endif
        // 3) 蓝量阈值
        set minMana = OMGAIActionMask_OMGAI_GetMinManaPct(abilityId)
        if minMana >= 0 then
            set maxMana = GetUnitState(u, UNIT_STATE_MAX_MANA)
            if maxMana > 0.0 and GetUnitState(u, UNIT_STATE_MANA) < maxMana * I2R(minMana) * 0.01 then
                return false
            endif
        endif
        // 4) 血量阈值
        set minHp = OMGAIActionMask_OMGAI_GetMinHpPct(abilityId)
        if minHp >= 0 then
            set maxHp = GetUnitState(u, UNIT_STATE_MAX_LIFE)
            if maxHp > 0.0 and GetUnitState(u, UNIT_STATE_LIFE) < maxHp * I2R(minHp) * 0.01 then
                return false
            endif
        endif
        // 5) 距离检查（单位目标才检查）
        if target != null then
            if OMGAIActionMask_OMGAI_GetCastRange(abilityId) > 0.0 then
                if DistanceBetweenUnits(u, target) > OMGAIActionMask_OMGAI_GetCastRange(abilityId) then
                    return false
                endif
            endif
        endif
        // 6) 目标存活
        if target != null and not UnitAlive(target) then
            return false
        endif
        // 7) 命令白名单（坑#6 施法锁定）：当前正在施法/引导 → 屏蔽
        if GetUnitCurrentOrder(u) != 0 then
            // 若正在移动/攻击可允许打断；若在施法引导则 false（由 SpellCast 判定）
            // TODO: 更精确的 order 判定
        endif
        return true
    endfunction

//---------------------------------------------------------------------------
// 4. 工具函数
//---------------------------------------------------------------------------


    public function OMGAI_MaskInit takes nothing returns nothing
        call OMGAILog_LOG_INFO("MASK", "OMGAIActionMask 初始化完成")
    endfunction

endlibrary
