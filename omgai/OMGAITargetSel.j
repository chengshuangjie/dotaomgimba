//===========================================================================
// OMGAITargetSel.j  --  Dota OMG 超级 AI 目标选择
//   对应方案：§6.5 + §8（集火评分 / 双向评分 / AOE 落点 / 落单判定）
//   依赖：OMGAICore, OMGAILog, OMGAIActionMask
//   设计：威胁排序由 OMGAIEnemyState 提供（全局一次）；本库做目标细分
//===========================================================================

library OMGAITargetSel requires OMGAICore, OMGAILog, OMGAIActionMask

    private function DistanceBetweenUnits takes unit a, unit b returns real
        local real dx = GetUnitX(a) - GetUnitX(b)
        local real dy = GetUnitY(a) - GetUnitY(b)
        return SquareRoot(dx * dx + dy * dy)
    endfunction

//---------------------------------------------------------------------------
// 1. 常量
//---------------------------------------------------------------------------

    globals
    constant real GANK_LONE_RADIUS = 1200.0  // 落单判定半径
    constant real TEAM_FIGHT_RANGE = 1200.0  // 团战判定半径

//---------------------------------------------------------------------------
// 2. 目标缓存（主键=单位 hid，槽 8=最近目标 9=集火目标 10..12=移动/AOE 点）
//---------------------------------------------------------------------------

    endglobals
    public function OMGAI_SetRecentTarget takes unit u, unit target returns nothing
        if target == null then
            call OMGAICore_OMGAI_SaveInt(GetHandleId(u), 8, 0)
        else
            call OMGAICore_OMGAI_SaveInt(GetHandleId(u), 8, GetHandleId(target))
        endif
    endfunction

    // 最近敌人（简单实现：遍历单位组取最近；生产用 EnemyState 缓存）
        public function OMGAI_GetClosestEnemy takes unit u returns unit
        local group g = null
        local unit it = null
        local unit best = null
        local real dx = 0.0
        local real dy = 0.0
        local real d = 0.0
        local real bestD = 999999.0
        local real x = 0.0
        local real y = 0.0
        if u == null then
            return null
        endif
        set x = GetUnitX(u)
        set y = GetUnitY(u)
        set g = CreateGroup()
        call GroupEnumUnitsInRange(g, x, y, 1600.0, null)
        loop
            set it = FirstOfGroup(g)
            exitwhen it == null
            if IsUnitType(it, UNIT_TYPE_HERO) and IsUnitEnemy(it, GetOwningPlayer(u)) and not IsUnitIllusion(it) and GetWidgetLife(it) > 0.405 and not IsUnitType(it, UNIT_TYPE_DEAD) then
                set dx = GetUnitX(it) - x
                set dy = GetUnitY(it) - y
                set d = SquareRoot(dx * dx + dy * dy)
                if d < bestD then
                    set bestD = d
                    set best = it
                endif
            endif
            call GroupRemoveUnit(g, it)
        endloop
        call DestroyGroup(g)
        return best
    endfunction

//---------------------------------------------------------------------------
// 3. 落单判定（gank 条件，D1 aiAutoGank 思想）
//    目标 1200 码内敌方英雄数 ≤ 1 → 落单
//---------------------------------------------------------------------------

        public function OMGAI_IsLoneEnemy takes unit target returns boolean
        local group g = null
        local unit it = null
        local integer n = 0
        if target == null then
            return false
        endif
        set g = CreateGroup()
        call GroupEnumUnitsInRange(g, GetUnitX(target), GetUnitY(target), GANK_LONE_RADIUS, null)
        loop
            set it = FirstOfGroup(g)
            exitwhen it == null
            if IsUnitType(it, UNIT_TYPE_HERO) and IsUnitEnemy(it, GetOwningPlayer(target)) and not IsUnitIllusion(it) and GetWidgetLife(it) > 0.405 and not IsUnitType(it, UNIT_TYPE_DEAD) then
                set n = n + 1
                if n > 1 then
                    call DestroyGroup(g)
                    return false
                endif
            endif
            call GroupRemoveUnit(g, it)
        endloop
        call DestroyGroup(g)
        return n <= 1
    endfunction

//---------------------------------------------------------------------------
// 4. 团战触发检测（D2 Dota2_Bots：附近友+敌 ≥ 5）
//---------------------------------------------------------------------------

        public function OMGAI_IsTeamFight takes unit u returns boolean
        local group g = null
        local unit it = null
        local integer allyN = 0
        local integer enemyN = 0
        if u == null then
            return false
        endif
        set g = CreateGroup()
        call GroupEnumUnitsInRange(g, GetUnitX(u), GetUnitY(u), TEAM_FIGHT_RANGE, null)
        loop
            set it = FirstOfGroup(g)
            exitwhen it == null
            if IsUnitType(it, UNIT_TYPE_HERO) and not IsUnitIllusion(it) and GetWidgetLife(it) > 0.405 and not IsUnitType(it, UNIT_TYPE_DEAD) then
                if IsUnitAlly(it, GetOwningPlayer(u)) then
                    set allyN = allyN + 1
                elseif IsUnitEnemy(it, GetOwningPlayer(u)) then
                    set enemyN = enemyN + 1
                endif
            endif
            call GroupRemoveUnit(g, it)
        endloop
        call DestroyGroup(g)
        if allyN >= 2 and enemyN >= 2 then
            return true
        endif
        if allyN + enemyN >= 5 then
            return true
        endif
        return false
    endfunction

//---------------------------------------------------------------------------
// 5. 双向评分（D2 adam3q GetAllyFactor/GetEnemyFactor 思想）
//    目标可击杀分 = 预估5秒伤害/血量×0.7 + 距离因子×0.3
//---------------------------------------------------------------------------

    public function OMGAI_TargetKillScore takes unit u, unit target returns real
        local real dmg5 = 0.0
        local real hp = 0.0
        local real dist = 0.0
        local real distF = 0.0
        if u == null or target == null then
            return 0.0
        endif
        // TODO: 预估 5 秒伤害（SkillProfile 输出能力分）
        set dmg5 = 200.0 // 占位
        set hp = GetUnitState(target, UNIT_STATE_MAX_LIFE)
        if hp <= 0.0 then
            return 0.0
        endif
        set dist = DistanceBetweenUnits(u, target)
        set distF = 1.0 - dist / 2000.0
        if distF < 0.0 then
            set distF = 0.0
        endif
        return (dmg5 / hp) * 0.7 + distF * 0.3
    endfunction

//---------------------------------------------------------------------------
// 6. AOE 落点搜索（找命中敌人最多的落点，至少命中 N 个才放）
//    D2 OpenAI-Lite myFindAoeLoc 思想 + D1 SplitFindTarget
//---------------------------------------------------------------------------

    // AOE 落点（outX/outY 传出，vJASS 不支持多返回值，用引用传参）
    public function OMGAI_FindAoeLoc takes unit u, real range, integer minEnemies, real outX, real outY returns integer
        // TODO: 实现网格采样；返回可命中敌人数，outX/outY 写最优落点
        return 0
    endfunction

//---------------------------------------------------------------------------
// 7. 集火目标（EnemyState 威胁排序 top1 + 可击杀分修正）
//---------------------------------------------------------------------------

        public function OMGAI_GetFocusTarget takes unit u returns unit
        local unit t = null
        if u == null then
            return null
        endif
        set t = OMGAICore_OMGAI_LoadUnitHandle(GetHandleId(u), 94)
        if t != null and GetWidgetLife(t) > 0.405 and not IsUnitType(t, UNIT_TYPE_DEAD) and IsUnitEnemy(t, GetOwningPlayer(u)) then
            return t
        endif
        return OMGAI_GetClosestEnemy(u)
    endfunction

//---------------------------------------------------------------------------
// 8. 工具
//---------------------------------------------------------------------------


    public function OMGAI_TargetSelInit takes nothing returns nothing
        call OMGAILog_LOG_INFO("TGSEL", "OMGAITargetSel 初始化完成")
    endfunction

endlibrary
