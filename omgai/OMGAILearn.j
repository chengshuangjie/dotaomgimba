//===========================================================================
// OMGAILearn.j  --  Dota OMG 对战 AI 自学习模块（bandit）
//   对应方案 §9 + §12.3（简化 bandit / 延迟结算 / KK 存档持久化）
//   依赖 OMGAICore, OMGAILog
//   设计：
//     key = "OMGAI:hero:<英雄名>:<技能ID>:<场景特征编码>"
//     context 编码：近战/远程 + 敌方主威胁类型 + 己方阵容职责位
//     值 = "SCO|NBS|MIS"（移动均值 SCO=(SCO*NBS+delta)/(NBS+1)）
//     MIS >= 4 则视为"未证实"并重置评分
//   持久化：gamecache 本地 + KK 服务器存档（§12.3）
//   v0.10：接通自学习闭环（施法登记 -> 2s 周期结算 -> 评分更新 -> 优先级修正）
//===========================================================================

library OMGAILearn requires OMGAICore, OMGAILog

//---------------------------------------------------------------------------
// 1. 常量与状态
//---------------------------------------------------------------------------

    globals
    constant integer LEARN_MISS_RESET = 4
    constant real    REWARD_KILL      = 100.0
    constant real    REWARD_ASSIST    = 50.0
    constant real    REWARD_HERODMG   = 25.0
    constant real    REWARD_LH        = 20.0
    constant real    REWARD_WASTE     = -10.0
    constant real    SETTLE_DELAY     = 2.0   // 延迟结算（秒）

    gamecache LEARN_CACHE = null
    boolean   LEARN_INITED = false

    // 待结算队列（容量 32）
    string  array PENDING_KEY
    unit    array PENDING_U
    unit    array PENDING_T
    integer PENDING_N = 0
    integer PENDING_MAX = 32
    timer   LEARN_SETTLE_TIMER = null

    endglobals

    // 字符串工具：找字符位置（1.27 无 Find）
    private function LEARN_FindChar takes string s, string c returns integer
        local integer i = 0
        loop
            exitwhen i >= StringLength(s)
            if SubString(s, i, i + 1) == c then
                return i
            endif
            set i = i + 1
        endloop
        return -1
    endfunction

//---------------------------------------------------------------------------
// 2. key 生成与场景编码
//---------------------------------------------------------------------------

    private function LEARN_MakeKey takes string heroName, integer abilityId, integer context returns string
        return "OMGAI:" + heroName + ":" + I2S(abilityId) + ":" + I2S(context)
    endfunction

    // 上下文特征编码（TODO: 由 OMGAIConfig/EnemyState 填充）
    public function OMGAI_LearnContext takes unit u returns integer
        // 位 0 = 近战；位 1 = 远程
        // 位 2..3 = 敌方主威胁类型
        // 位 4..5 = 己方阵容职责位
        return 0
    endfunction

//---------------------------------------------------------------------------
// 3. 存档读写（gamecache，"SCO|NBS|MIS"）
//---------------------------------------------------------------------------

    public function OMGAI_LearnLoad takes string key, real sco, integer nbs, integer mis returns nothing
        local string s = ""
        local integer i1 = 0
        local integer i2 = 0
        local string tail = ""
        set s = GetStoredString(LEARN_CACHE, "learn", key)
        if s != "" then
            set i1 = OMGAILearn___LEARN_FindChar(s, "|")
            if i1 > 0 then
                set sco = S2R(SubString(s, 0, i1))
                set tail = SubString(s, i1 + 1, StringLength(s))
                set i2 = OMGAILearn___LEARN_FindChar(tail, "|")
                if i2 > 0 then
                    set nbs = S2I(SubString(tail, 0, i2))
                    set mis = S2I(SubString(tail, i2 + 1, StringLength(tail)))
                endif
            endif
        endif
    endfunction

    public function OMGAI_LearnSave takes string key, real sco, integer nbs, integer mis returns nothing
        if LEARN_CACHE == null then
            return
        endif
        call StoreString(LEARN_CACHE, "learn", key, R2S(sco) + "|" + I2S(nbs) + "|" + I2S(mis))
        // 同步到 KK 服务器存档（§12.3）
        // TODO: call DzAPI_Map_SaveServerValue(Player(0), key, R2S(sco)+"|"+I2S(nbs)+"|"+I2S(mis))
    endfunction

//---------------------------------------------------------------------------
// 4. bandit 更新（移动均值 + miss 重置）
//---------------------------------------------------------------------------

    public function OMGAI_LearnUpdate takes string key, real delta returns nothing
        local real sco = 0.0
        local integer nbs = 0
        local integer mis = 0
        // 读取当前
        call OMGAILearn_OMGAI_LearnLoad(key, sco, nbs, mis)
        // miss 重置检查
        if mis >= LEARN_MISS_RESET then
            set sco = REWARD_WASTE
            set nbs = 1
            set mis = 0
            call OMGAILog_LOG_INFO("LEARN", "miss reset: " + key)
        else
            // SCO = (SCO*NBS + delta)/(NBS+1)
            set sco = (sco * I2R(nbs) + delta) / I2R(nbs + 1)
            set nbs = nbs + 1
            if delta < 0.0 then
                set mis = mis + 1
            else
                set mis = 0
            endif
        endif
        call OMGAILearn_OMGAI_LearnSave(key, sco, nbs, mis)
    endfunction

//---------------------------------------------------------------------------
// 5. 延迟结算（D2 OpenAI-Lite：释放后等 ΔT 按奖励权重结算）
//---------------------------------------------------------------------------

    // 施法事件登记（由 SpellCast.CastAbility 成功分支挂钩）
    public function OMGAI_LearnOnCast takes unit u, integer abilityId, unit target returns nothing
        local string key = LEARN_MakeKey("hero", abilityId, OMGAILearn_OMGAI_LearnContext(u))
        if PENDING_N >= PENDING_MAX then
            return
        endif
        set PENDING_KEY[PENDING_N] = key
        set PENDING_U[PENDING_N] = u
        set PENDING_T[PENDING_N] = target
        set PENDING_N = PENDING_N + 1
    endfunction

    // 结算：击杀+100 / 造成伤害+25 / 空放-10
    public function OMGAI_LearnSettle takes string key, unit u, unit target returns nothing
        local real delta = REWARD_WASTE
        if target != null then
            if GetWidgetLife(target) <= 0.405 or IsUnitType(target, UNIT_TYPE_DEAD) then
                set delta = REWARD_KILL
            elseif GetUnitState(target, UNIT_STATE_MAX_LIFE) > 0.0 then
                set delta = REWARD_HERODMG
            endif
        endif
        call OMGAILearn_OMGAI_LearnUpdate(key, delta)
    endfunction

    // 周期结算（2s）：扫描 PENDING 队列
    private function LEARN_SettleTick takes nothing returns nothing
        local integer i = 0
        local string key = ""
        loop
            exitwhen i >= PENDING_N
            set key = PENDING_KEY[i]
            call OMGAILearn_OMGAI_LearnSettle(key, PENDING_U[i], PENDING_T[i])
            set PENDING_U[i] = null
            set PENDING_T[i] = null
            set PENDING_KEY[i] = ""
            set i = i + 1
        endloop
        set PENDING_N = 0
    endfunction

//---------------------------------------------------------------------------
// 6. 初始化（注册周期结算 timer）
//---------------------------------------------------------------------------

    public function OMGAI_LearnInit takes nothing returns nothing
        if LEARN_INITED then
            return
        endif
        set LEARN_CACHE = InitGameCache("OMGAI_Learn")
        set LEARN_INITED = true
        set LEARN_SETTLE_TIMER = CreateTimer()
        call TimerStart(LEARN_SETTLE_TIMER, SETTLE_DELAY, true, function OMGAILearn___LEARN_SettleTick)
        call OMGAILog_LOG_INFO("LEARN", "OMGAI learn init done")
    endfunction

//---------------------------------------------------------------------------
// 7. 行为参数自适应（技能×场景评分 → 优先级修正）
//    供 OMGAIActionMask/SpellCast 读取：某技能在 context 下评分低 → 降优先级
//---------------------------------------------------------------------------

    public function OMGAI_LearnPriorityBias takes string key returns real
        local real sco = 0.0
        local integer nbs = 0
        local integer mis = 0
        local real bias = 0.0
        call OMGAILearn_OMGAI_LearnLoad(key, sco, nbs, mis)
        if nbs <= 0 then
            return 0.0
        endif
        if sco > 100.0 then
            set sco = 100.0
        endif
        if sco < -100.0 then
            set sco = -100.0
        endif
        set bias = (sco - 50.0) / 100.0
        return bias
    endfunction

//---------------------------------------------------------------------------
// 8. 崩溃上报（§12.3 ④：FATAL 转储写 KK）
//---------------------------------------------------------------------------

    public function OMGAILearn_ReportCrash takes string crashKey, string summary returns nothing
        // TODO: call DzAPI_Map_SaveServerValue(Player(0), crashKey, summary)
        call OMGAILog_LOG_ERROR("LEARN", "crash report: " + crashKey)
    endfunction

endlibrary
