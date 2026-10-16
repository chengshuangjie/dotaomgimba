//===========================================================================
// OMGAIEnemyState.j  --  Dota OMG 超级 AI 敌方状态反演
//   对应方案：§8（威胁排序 / CD 反演 / 仇恨表 / 幻象指纹 / 全局标志）
//   依赖：OMGAICore, OMGAILog
//   设计：全部数据缓存在 hashtable（0.5~1s 刷新一次，全局共享，坑#16）
//===========================================================================

library OMGAIEnemyState requires OMGAICore, OMGAILog

    private function GetOMGAIHash takes nothing returns hashtable
        return OMGAICore_OMGAI_GetHash()
    endfunction

//---------------------------------------------------------------------------
// 1. 常量
//---------------------------------------------------------------------------

    globals
    constant real REFRESH_INTERVAL   = 0.8   // 秒
    constant real HATE_EXPIRE        = 4.0   // 仇恨表过期（秒）
    constant real THREAT_NW_W        = 0.3   // 净财富权重
    constant real THREAT_OFF_W       = 0.3   // 输出能力权重
    constant real THREAT_LVL_W       = 0.4   // 等级权重

//---------------------------------------------------------------------------
// 2. 数据布局（hashtable）
//    主键=敌方英雄 hid：
//      槽 30 威胁分 / 31 净财富 / 32 输出分 / 33 等级 / 34 最后可见时间
//      槽 35 仇恨对象（谁在打我）/ 36 仇恨时间 / 37 是否幻象 / 38 是否隐身
//      槽 39 技能CD反演位图（每技能 1 位，1=冷却中）
//      槽 40..44 最近施法时间（5 个技能槽）
//    全局（主键=0）：
//      槽 GSLOT_THREAT_SORT(3)..7  威胁排序缓存（top5 敌方 heroId）
//      槽 GSLOT_INVIS_ENEMY(2)     隐身存在标志
//---------------------------------------------------------------------------

    // 登记敌方英雄（开局/敌方英雄出现时调用）
    endglobals
    public function OMGAI_EnemyRegister takes unit enemy returns nothing
        local integer hid = GetHandleId(enemy)
        call OMGAICore_OMGAI_SaveReal(hid, 34, OMGAICore_OMGAI_GetGameTime())
        call OMGAILog_LOG_INFO("ENM", "登记敌方: " + I2S(hid))
    endfunction

    // 敌方英雄死亡（清缓存防残留）
    public function OMGAI_EnemyRemove takes unit enemy returns nothing
        local integer hid = GetHandleId(enemy)
        call FlushChildHashtable(GetOMGAIHash(), hid)
    endfunction

//---------------------------------------------------------------------------
// 3. 威胁排序（每 REFRESH_INTERVAL 刷新一次，全局共享）
//    score = netWorth×0.3 + offensivePower×0.3 + level×0.4
//---------------------------------------------------------------------------

    public function OMGAI_UpdateThreatSort takes nothing returns nothing
        // TODO: 遍历全部敌方英雄，算分，排序写入 GSLOT_THREAT_SORT..7
        // 幻象（槽 37）剔除
        call OMGAILog_LOG_DEBUG("ENM", "威胁排序刷新")
    endfunction

    // 取威胁 top1（供集火）
    public function OMGAI_GetTopThreat takes nothing returns unit
        // TODO: LoadInteger(表, 0, GSLOT_THREAT_SORT) → 转 unit
        return null
    endfunction

    // 单英雄威胁分（供 TargetSel 修正）
    public function OMGAI_ThreatScore takes unit enemy returns real
        local integer hid = GetHandleId(enemy)
        return OMGAICore_OMGAI_LoadReal(hid, 30)
    endfunction

//---------------------------------------------------------------------------
// 4. 技能 CD 反演（D2 LastOrder cal_enemy_ability 思想）
//    监听敌方施法事件 → 记录"英雄 X 在 T 施放了技能 Y" → 推定 CD 剩余
//---------------------------------------------------------------------------

    // 由施法事件调用：登记该敌方英雄刚施放技能
    public function OMGAI_EnemyCasted takes unit enemy, integer abilityId returns nothing
        local integer hid = GetHandleId(enemy)
        // TODO: 记录到最近施法时间槽（40..44）
        call OMGAILog_LOG_INFO("ENM", "敌方施法: " + I2S(hid) + " ability=" + I2S(abilityId))
    endfunction

    // 查询：敌方大招是否在 CD（估算）
    public function OMGAI_IsEnemyUltOnCD takes unit enemy returns boolean
        // TODO: 从最近施法时间 + 已知 CD 估算
        return false
    endfunction

//---------------------------------------------------------------------------
// 5. 仇恨表（D1 AatkTargetRecord：谁在打我，4 秒过期）
//---------------------------------------------------------------------------

    // 由受击事件调用：登记攻击者
    public function OMGAI_RegisterHate takes unit me, unit attacker returns nothing
        local integer hid = GetHandleId(me)
        call OMGAICore_OMGAI_SaveInt(hid, 35, GetHandleId(attacker))
        call OMGAICore_OMGAI_SaveReal(hid, 36, OMGAICore_OMGAI_GetGameTime())
    endfunction

    // 查询当前仇恨对象（未过期）
    public function OMGAI_GetHateTarget takes unit me returns unit
        local integer hid = GetHandleId(me)
        local real t = OMGAICore_OMGAI_LoadReal(hid, 36)
        // TODO: 过期判断（t > 0 且 now-t < HATE_EXPIRE）
        return null
    endfunction

//---------------------------------------------------------------------------
// 6. 幻象指纹（D2 adam3q GetRealHero 思想）
//    属性派生值/回复量异常 → 标记幻象；集火前必须剔除（OMG 幻象技能多）
//---------------------------------------------------------------------------

    public function OMGAI_MarkIllusion takes unit enemy, boolean isIllu returns nothing
        call OMGAICore_OMGAI_SaveBool(GetHandleId(enemy), 37, isIllu)
    endfunction

    public function OMGAI_IsIllusion takes unit enemy returns boolean
        return OMGAICore_OMGAI_LoadBool(GetHandleId(enemy), 37)
    endfunction

//---------------------------------------------------------------------------
// 7. 全局标志（隐身存在 → 影响插真视/带粉）
//---------------------------------------------------------------------------

    public function OMGAI_SetInvisEnemyExist takes boolean b returns nothing
        call OMGAICore_OMGAI_SaveGlobalBool(GSLOT_INVIS_ENEMY, b)
    endfunction

    public function OMGAI_InvisEnemyExist takes nothing returns boolean
        return OMGAICore_OMGAI_LoadGlobalBool(GSLOT_INVIS_ENEMY)
    endfunction

//---------------------------------------------------------------------------
// 8. 快照转储（崩溃时调用，OMGAILog_DumpCrash 钩子）
//---------------------------------------------------------------------------

    public function OMGAIEnemyState_DumpSnapshot takes nothing returns nothing
        // TODO: 把威胁排序缓存/仇恨表写入 gamecache 崩溃存档
    endfunction

//---------------------------------------------------------------------------
// 9. 工具与初始化
//---------------------------------------------------------------------------


    // 主表 getter（OMGAICore 提供）

    public function OMGAI_EnemyStateInit takes nothing returns nothing
        call OMGAICore_OMGAI_SaveGlobalBool(GSLOT_INVIS_ENEMY, false)
        call OMGAILog_LOG_INFO("ENM", "OMGAIEnemyState 初始化完成")
    endfunction

endlibrary
