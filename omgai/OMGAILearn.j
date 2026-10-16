//===========================================================================
// OMGAILearn.j  --  Dota OMG 超级 AI 自学习引擎（bandit）
//   对应方案：§9 + §12.3（上下文 bandit / 延迟结算 / KK 存档持久化）
//   依赖：OMGAICore, OMGAILog
//   设计：
//     key = "OMGAI:hero:<英雄名>:<技能ID>:<上下文特征串>"
//     context 特征：近战/远程 + 敌方主威胁类型 + 己方阵容职责位
//     值 = "SCO|NBS|MIS"（在线均值 SCO=(SCO*NBS+delta)/(NBS+1)）
//     MIS >= 4 → 重置为"待验证"（防卡劣质技能链）
//   持久化：gamecache（本地）+ KK 服务器存档（SaveServerValue，§12.3）
//===========================================================================

library OMGAILearn requires OMGAICore, OMGAILog

//---------------------------------------------------------------------------
// 1. 常量
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

//---------------------------------------------------------------------------
// 2. key 构造
//---------------------------------------------------------------------------

    endglobals
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
// 3. 存档读写（gamecache）
//---------------------------------------------------------------------------

    public function OMGAI_LearnInit takes nothing returns nothing
        if LEARN_INITED then
            return
        endif
        set LEARN_CACHE = InitGameCache("OMGAI_Learn")
        set LEARN_INITED = true
        call OMGAILog_LOG_INFO("LEARN", "自学习引擎初始化完成")
    endfunction

    // 读取 SCO/NBS/MIS（解析 "SCO|NBS|MIS"）
    public function OMGAI_LearnLoad takes string key, real sco, integer nbs, integer mis returns nothing
        local string s = ""
        // TODO: 用 StringSplit 解析（1.27 无内置 split，需自写解析）
        // 占位：直接读
        set s = GetStoredString(LEARN_CACHE, "learn", key)
        if s != "" then
            // TODO: 解析
        endif
    endfunction

    // 写入（每局结算 + 每 10 局强制）
    public function OMGAI_LearnSave takes string key, real sco, integer nbs, integer mis returns nothing
        if LEARN_CACHE == null then
            return
        endif
        call StoreString(LEARN_CACHE, "learn", key, R2S(sco) + "|" + I2S(nbs) + "|" + I2S(mis))
        // 同步到 KK 服务器存档（§12.3）
        // TODO: call DzAPI_Map_SaveServerValue(Player(0), key, R2S(sco)+"|"+I2S(nbs)+"|"+I2S(mis))
    endfunction

//---------------------------------------------------------------------------
// 4. bandit 更新（在线均值 + miss 重置）
//    delta：本次结算奖励
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
            call OMGAILog_LOG_INFO("LEARN", "miss 重置: " + key)
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
//    由施法事件发起：登记"待结算条目"，TimerService 2s 后回调
//---------------------------------------------------------------------------

    // 待结算队列（简化为单条 TODO；生产用 TimerService + 队列）
    globals
    string  array PENDING_KEY
    integer PENDING_N = 0

    endglobals
    public function OMGAI_LearnOnCast takes unit u, integer abilityId, unit target returns nothing
        local string key = LEARN_MakeKey("hero", abilityId, OMGAILearn_OMGAI_LearnContext(u))
        // TODO: TimerService 延迟 SETTLE_DELAY 后调用 OMGAI_LearnSettle(key, u, target)
        set PENDING_KEY[PENDING_N] = key
        set PENDING_N = PENDING_N + 1
    endfunction

    // 结算（击杀/助攻/英雄伤害/补刀权重）
    public function OMGAI_LearnSettle takes string key, unit u, unit target returns nothing
        local real delta = 0.0
        // TODO: 检查 target 是否死亡（击杀+100）、助攻、造成伤害（+25/1000）、补刀（+20）
        set delta = REWARD_WASTE // 默认无效
        call OMGAILearn_OMGAI_LearnUpdate(key, delta)
    endfunction

//---------------------------------------------------------------------------
// 6. 行为参数自适应（技能×场景评分 → 优先级修正）
//    供 OMGAIActionMask/SpellCast 读取：某技能在 context 下评分低 → 降优先级
//---------------------------------------------------------------------------

    public function OMGAI_LearnPriorityBias takes string key returns real
        // TODO: 读取 SCO，映射为 [-0.5, +0.5] 的优先级修正
        return 0.0
    endfunction

//---------------------------------------------------------------------------
// 7. 崩溃上报（§12.3 ④：FATAL 转储写 KK）
//---------------------------------------------------------------------------

    public function OMGAILearn_ReportCrash takes string crashKey, string summary returns nothing
        // TODO: call DzAPI_Map_SaveServerValue(Player(0), crashKey, summary)
        call OMGAILog_LOG_ERROR("LEARN", "崩溃上报: " + crashKey)
    endfunction

endlibrary
