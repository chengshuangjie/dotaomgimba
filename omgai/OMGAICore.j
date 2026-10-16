//===========================================================================
// OMGAICore.j  --  Dota OMG 超级 AI 数据定义核心
//   DOTAOMGAY / 魔兽争霸3 1.27 / YDWE / vJASS
//   对应方案：OMG-超级AI技术方案.md §4（主表布局 / struct / 常量枚举）
//   依赖：无（被所有 OMGAI 新库 require）
//   说明：本文件为可编译骨架，与既有 OMGAI 27 库的对接点用 TODO 标注。
//===========================================================================

library OMGAICore

//---------------------------------------------------------------------------
// 0. 全局常量
//---------------------------------------------------------------------------

    // 行为 ID（L2 行为模块）
    globals
    constant integer BEH_FARM     = 1
    constant integer BEH_JUNGLE   = 2
    constant integer BEH_GANK     = 3
    constant integer BEH_PUSH     = 4
    constant integer BEH_DEFEND   = 5
    constant integer BEH_TEAM     = 6
    constant integer BEH_RETREAT  = 7
    constant integer BEH_WARD     = 8
    constant integer BEH_SHOP     = 9

    // 高优硬状态（不进 desire 竞选，直接短路）
    constant integer ST_DEAD      = 10
    constant integer ST_HOME      = 11
    constant integer ST_BUYBACK   = 12
    constant integer ST_ASSEMBLE  = 13
    constant integer ST_TAKEOVER  = 14

    // 技能 targetType（8 类，对应方案 §4.3 / §7.3）
    constant integer TT_POINT     = 1
    constant integer TT_AREA      = 2
    constant integer TT_UNIT      = 3
    constant integer TT_NO_TARGET = 4
    constant integer TT_ALLY      = 5
    constant integer TT_SELF      = 6
    constant integer TT_CORPSE    = 7
    constant integer TT_TOGGLE    = 8

    // 职业分类（对应 D1 aiGetClass 6 类）
    constant integer CLS_CARRY    = 0
    constant integer CLS_FIGHTER  = 1
    constant integer CLS_TANKER   = 2
    constant integer CLS_SUPPORT  = 3
    constant integer CLS_NUKER    = 4
    constant integer CLS_PUSHER   = 5

    // AI 单位上限（护栏 8：单位数治理）
    constant integer MAX_AI_UNITS = 12
    // 单 tick 枚举上限（护栏 2 / P2）
    constant integer GUARD_ENUM_MAX = 256
    // 递归深度上限（P2）
    constant integer GUARD_RECUR_MAX = 8

    // 心跳周期（秒）
    constant real    AI_TICK_INTERVAL  = 0.40
    // desire 防抖滞回带（方案 §5.2）
    constant real    DESIRE_HYSTERESIS = 0.15
    // 行为最小持续时长（秒）
    constant real    BEHAVIOR_MIN_HOLD = 0.80
    // 发呆看门狗阈值（秒）
    constant real    IDLE_TIMEOUT      = 2.50

//---------------------------------------------------------------------------
// 1. 全局 handle 表
//   主表 OMGAI_H 为 AI 数据唯一载体（hashtable），key 分配见方案 §4.1
//---------------------------------------------------------------------------

    hashtable OMGAI_H = null
    boolean   inited = false

    // 单位表（AI 登记的英雄列表）
    unit array AIUnitTable

    // 数组访问校验计数（P3 观测用）
    integer array arrGuardHits

//---------------------------------------------------------------------------
// 2. AIHeroState struct（方案 §4.2）
//   实际落地：hashtable 为主载体（1.27 无原生 struct 持久化），
//   struct 仅作编译期类型组织；读写全部走 OMGAI_Load/Save 函数。
//---------------------------------------------------------------------------

    endglobals
    struct AIHeroState
        integer heroId          // GetHandleId(unit)
        integer behaviorId      // 当前行为 BEH_*
        real    behaviorDesire  // 当前行为 desire
        real    switchTime      // 距上次切换（游戏时间）
        real    idleTimer       // 发呆计时
        integer cancelCount     // 施法取消计数
        real    softCooldown    // 单位级软冷却截止时间
        real    lastHurtTime    // 受击时间戳
        boolean assembling      // 集结等待
        integer currentTarget   // 最近目标（handle id）
        integer focusTarget     // 集火目标（handle id）
        integer posW1
        integer posW2
        integer posW3
        integer posW4
        integer posW5
        integer classId         // CLS_*
        integer lanePlan        // 分路计划（1 上 / 2 中 / 3 下）
        integer hurtBy          // 当前仇恨对象（handle id）
    endstruct

//---------------------------------------------------------------------------
// 3. hashtable key 分配（方案 §4.1，保持与文档一致）
//   主键 = 单位 handle id
//   二级 key = 槽位：
//   0..4   行为状态（0=behaviorId 1=behaviorDesire 2=switchTime 3=idleTimer 4=cancelCount）
//   5       软冷却截止时间
//   6       受击时间戳
//   7       集结标记
//   8       最近目标
//   9       集火目标
//   10      位置权重数组起点（10..14）
//   15      职业 / 16 分路
//   17      仇恨对象
//   二级主键 = 全局索引（0 固定全局，1..5 玩家槽，6=护盾计数 7=枚举计数 8=递归深度）
//---------------------------------------------------------------------------

    // 全局槽（二级主键 0）
    globals
    constant integer GSLOT_MATCHMODE    = 0
    constant integer GSLOT_DIFFICULTY   = 1
    constant integer GSLOT_INVIS_ENEMY  = 2
    constant integer GSLOT_THREAT_SORT  = 3   // 敌方威胁排序缓存（5 个 heroId 从 3 起连续 5 槽）
    constant integer GSLOT_GUARD_ENUM   = 9   // 枚举计数
    constant integer GSLOT_GUARD_RECUR  = 10  // 递归深度
    constant integer GSLOT_CRASH_FLAG   = 11  // 崩溃转储标记

//---------------------------------------------------------------------------
// 4. 主表初始化
//---------------------------------------------------------------------------

    timer CORE_TIMER = null

    endglobals
    public function OMGAICore_Init takes nothing returns boolean
        if inited then
            return true
        endif
        set OMGAI_H = InitHashtable()
        if OMGAI_H == null then
            return false
        endif
        // 统一游戏时间源（供全部 AI 库使用，避免各自 null timer）
        set CORE_TIMER = CreateTimer()
        call TimerStart(CORE_TIMER, 999999.0, false, null)
        set inited = true
        return true
    endfunction

    public function OMGAICore_IsInited takes nothing returns boolean
        return inited
    endfunction

    // 统一游戏时间（秒）：所有 AI 库的时间戳应使用本函数
    public function OMGAI_GetGameTime takes nothing returns real
        if CORE_TIMER == null then
            return 0.0
        endif
        return TimerGetElapsed(CORE_TIMER)
    endfunction

    // 主表公开 getter（供 OMGAIEnemyState/OMGAIGuard 等做 FlushChildHashtable）
    public function OMGAI_GetHash takes nothing returns hashtable
        return OMGAI_H
    endfunction

//---------------------------------------------------------------------------
// 5. 状态读写封装（全部走 hashtable，P3 数组/索引越界统一校验入口）
//---------------------------------------------------------------------------

    public function OMGAI_LoadInt takes integer heroId, integer slot returns integer
        if heroId == 0 or OMGAI_H == null then
            return 0
        endif
        return LoadInteger(OMGAI_H, heroId, slot)
    endfunction

    public function OMGAI_SaveInt takes integer heroId, integer slot, integer value returns nothing
        if heroId == 0 or OMGAI_H == null then
            return
        endif
        call SaveInteger(OMGAI_H, heroId, slot, value)
    endfunction

    public function OMGAI_LoadReal takes integer heroId, integer slot returns real
        if heroId == 0 or OMGAI_H == null then
            return 0.0
        endif
        return LoadReal(OMGAI_H, heroId, slot)
    endfunction

    public function OMGAI_SaveReal takes integer heroId, integer slot, real value returns nothing
        if heroId == 0 or OMGAI_H == null then
            return
        endif
        call SaveReal(OMGAI_H, heroId, slot, value)
    endfunction

    public function OMGAI_LoadBool takes integer heroId, integer slot returns boolean
        if heroId == 0 or OMGAI_H == null then
            return false
        endif
        return LoadBoolean(OMGAI_H, heroId, slot)
    endfunction

    public function OMGAI_SaveBool takes integer heroId, integer slot, boolean value returns nothing
        if heroId == 0 or OMGAI_H == null then
            return
        endif
        call SaveBoolean(OMGAI_H, heroId, slot, value)
    endfunction

    // 全局槽读写（二级主键 = GLOBAL_KEY）
    public function OMGAI_LoadGlobalInt takes integer slot returns integer
        if OMGAI_H == null then
            return 0
        endif
        return LoadInteger(OMGAI_H, 0, slot)
    endfunction

    public function OMGAI_SaveGlobalInt takes integer slot, integer value returns nothing
        if OMGAI_H == null then
            return
        endif
        call SaveInteger(OMGAI_H, 0, slot, value)
    endfunction

    public function OMGAI_LoadGlobalBool takes integer slot returns boolean
        if OMGAI_H == null then
            return false
        endif
        return LoadBoolean(OMGAI_H, 0, slot)
    endfunction

    public function OMGAI_SaveGlobalBool takes integer slot, boolean value returns nothing
        if OMGAI_H == null then
            return
        endif
        call SaveBoolean(OMGAI_H, 0, slot, value)
    endfunction

//---------------------------------------------------------------------------
// 6. 单位表管理（护栏 8 + P1 句柄清理配合）
//---------------------------------------------------------------------------

    public function OMGAICore_RegisterUnit takes unit u returns integer
        local integer i = 0
        if u == null then
            return -1
        endif
        loop
            exitwhen i >= MAX_AI_UNITS
            if AIUnitTable[i] == null then
                set AIUnitTable[i] = u
                return i
            endif
            set i = i + 1
        endloop
        return -1
    endfunction

    public function OMGAICore_UnregisterUnit takes unit u returns nothing
        local integer i = 0
        if u == null then
            return
        endif
        loop
            exitwhen i >= MAX_AI_UNITS
            if AIUnitTable[i] == u then
                // P1：清理该单位全部 hashtable 条目（句柄生命周期）
                call FlushChildHashtable(OMGAI_H, GetHandleId(u))
                set AIUnitTable[i] = null
                return
            endif
            set i = i + 1
        endloop
    endfunction

    public function OMGAICore_GetUnitTable takes integer index returns unit
        if index < 0 or index >= MAX_AI_UNITS then
            return null
        endif
        return AIUnitTable[index]
    endfunction

//---------------------------------------------------------------------------
// 7. 数组访问校验（P3：vJASS 数组无边界检查，越界即静默崩）
//    所有索引型访问建议走此处；日志写入见 OMGAILog（WARN 记一次）
//---------------------------------------------------------------------------



    // 越界告警钩子（由 OMGAILog.j 实现；此处空实现保证可独立编译）
    public function OMGAI_ArrGuardWarn takes integer idx, string op returns nothing
        // TODO: 接入 OMGAILog 后替换为 LOG_WARN("ARRAY", "越界 idx="+I2S(idx)+" op="+op)
    endfunction

endlibrary
