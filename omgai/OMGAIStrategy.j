// ===========================================================================
// OMGAIStrategy.j  --  Dota OMG 超级 AI 战术意识层（V2.4 基图运行时对接版）
//   对应 PRD 6A.1 流派识别 / 6A.2 团战定位 / 6A.3 秒人判断 / 6A.4 蹲守针对 / 6A.5 视野
//   依赖 OMGAICore、OMGAILog、OMGAIEnemyState、OMGAITargetSel、
//        OMGAISkillDef、OMGAIPlayerSkillState、OMGAISkillTag、OMGAIBaseSkillTable
//   设计原则：战术层不直接施法——通过"desire 加减权 + 行为通道 + 站位写入 + 目标覆盖"驱动行为
//   V2.4 升级：native 对接基图 SuijiMode 运行时（物理/魔法技能分类），
//              英雄实际技能枚举（GetUnitAbility + 基图 OMG 技能池全集 528）写入 PSS，
//              流派识别/爆发估算基于真实技能而非空槽
// ===========================================================================

library OMGAIStrategy requires OMGAICore, OMGAILog, OMGAIEnemyState, OMGAITargetSel, OMGAISkillDef, OMGAIPlayerSkillState, OMGAISkillTag, OMGAIBaseSkillTable

// ---- 基图运行时函数对接（native 声明：编译期不检查，运行时真实调用基图函数）----
// 签名来源：基图 war3map.j（SuijiMode 随机OMG模块）
    native SuijiMode_GetStableHeroIndex takes unit u returns integer
    native SuijiMode_SkillClass takes integer skill returns integer
    native SuijiMode_IsPhysicalSkill takes integer skill returns boolean

//---------------------------------------------------------------------------
// 1. 流派与定位（对应 6A.1 / 6A.2）
//---------------------------------------------------------------------------

    globals
    constant integer ARCH_PHYSICAL = 1    // 物理流：攻击/暴击/吸血/减甲
    constant integer ARCH_MAGIC    = 2    // 法师流：魔法伤害/范围伤害/多重施法
    constant integer ARCH_CONTROL  = 4    // 控制流：眩晕/沉默/减速/压制
    constant integer ARCH_SURVIVE  = 8    // 生存流：护盾/回血/魔抗/位移
    constant integer ARCH_UTILITY  = 16   // 功能流：召唤/光环/视野

    // 流派（4+2 综合判定）
    constant integer BUILD_PHYS    = 1    // 物理流
    constant integer BUILD_MAGIC   = 2    // 法师流
    constant integer BUILD_TANK    = 3    // 肉盾流
    constant integer BUILD_CTRL    = 4    // 控制辅助流
    constant integer BUILD_MIXED   = 5    // 混合（均衡/强爆发）

    // 团战定位（对应 6A.2）
    constant integer ROLE_VANGUARD = 1    // 前排肉
    constant integer ROLE_DPS      = 2    // 输出核心
    constant integer ROLE_NUKER    = 3    // 中后排法师
    constant integer ROLE_SUPPORT  = 4    // 辅助控制

    // 蹲守状态（对应 6A.4）
    constant integer AMBUSH_IDLE      = 0  // 敌不可见，保持隐匿
    constant integer AMBUSH_WAIT      = 1  // 蹲守视野盲区
    constant integer AMBUSH_ENGAGE    = 2  // 目标现身，逼近
    constant integer AMBUSH_PRESS     = 3  // 低血压制/秒杀

    // 阈值
    constant real  BURST_MULT        = 1.10   // 爆发（预估）>= 血量*1.1 可秒
    constant real  SECURE_DESIRE_BONUS = 0.50  // 秒杀/蹲守 desire 注入
    constant real  VANGUARD_RANGE    = 400.0  // 前排团战距离
    constant real  DPS_RANGE         = 600.0  // 输出团战距离
    constant real  NUKER_RANGE       = 800.0  // 法师施法距离
    constant real  SUPPORT_RANGE     = 900.0  // 辅助靠后
    constant real  KEY_HERO_HP_PRESS = 0.30   // 关键英雄血量压制阈值
    endglobals

//---------------------------------------------------------------------------
// 2. 流派识别（对应 6A.1）——双通道：基图物理/魔法分类 + SkillDef 控制/生存/功能标签
//---------------------------------------------------------------------------

    // 判断 value 的 bit 位是否置位（bit = 1/2/4/8/16...）
    private function BitIsSet takes integer value, integer bit returns boolean
        return ModuloInteger(value, bit * 2) >= bit
    endfunction

    // 单个技能 -> 流派位掩码（可多标签叠加；基于 OMGAI SkillDef 标签）
    public function OMGAI_GetSkillArchetype takes integer abilityId returns integer
        local integer idx = OMGAISkillDef_FindByRawCode(abilityId)
        local integer tags = 0
        local integer arch = 0
        if idx == 0 then
            return 0
        endif
        set tags = SkillDef_Tags[idx]
        // 伤害维度
        if OMGAISkillTag_HasTag(tags, STAG_DMG_PHYSICAL) then
            set arch = arch + ARCH_PHYSICAL
        endif
        if OMGAISkillTag_HasTag(tags, STAG_DMG_MAGICAL) or OMGAISkillTag_HasTag(tags, STAG_DMG_PURE) then
            set arch = arch + ARCH_MAGIC
        endif
        // 控制维度
        if OMGAISkillTag_HasTag(tags, STAG_CTRL_STUN) or OMGAISkillTag_HasTag(tags, STAG_CTRL_SLOW) or OMGAISkillTag_HasTag(tags, STAG_CTRL_SILENCE) or OMGAISkillTag_HasTag(tags, STAG_CTRL_ROOT) or OMGAISkillTag_HasTag(tags, STAG_CTRL_DISARM) or OMGAISkillTag_HasTag(tags, STAG_CTRL_FEAR) then
            set arch = arch + ARCH_CONTROL
        endif
        // 生存维度
        if OMGAISkillTag_HasTag(tags, STAG_HEAL) or OMGAISkillTag_HasTag(tags, STAG_SHIELD) or OMGAISkillTag_HasTag(tags, STAG_LIFESTEAL) or OMGAISkillTag_HasTag(tags, STAG_DURABILITY) then
            set arch = arch + ARCH_SURVIVE
        endif
        // 功能维度
        if OMGAISkillTag_HasTag(tags, STAG_SUMMON) or OMGAISkillTag_HasTag(tags, STAG_AURA) then
            set arch = arch + ARCH_UTILITY
        endif
        return arch
    endfunction

    // 枚举英雄实际技能（基图已授予的 OMG 技能池技能）-> 写入 PSS 4+2 槽
    // 基图技能池 = HM4/HN4/HO4（小技能）+ HP4/HQ4（大招），英雄基础技能也在池内
    // 返回收集到的技能数
    public function OMGAI_EnumerateHeroSkills takes unit u returns integer
        local integer pid = GetPlayerId(GetOwningPlayer(u)) + 1
        local integer i = 1
        local integer count = 0
        local integer slot = 1
        local integer raw = 0
        loop
            exitwhen i > BASE_SKILL_COUNT or slot > 6
            set raw = BASE_SKILL_TABLE[i]
            if GetUnitAbilityLevel(u, raw) > 0 then
                if slot <= 4 then
                    call OMGAIPlayerSkillState_SetFixedSkillRawCode(pid, slot, raw)
                elseif slot == 5 then
                    set PSS_ExtraSmall[pid] = raw
                else
                    set PSS_ExtraBig[pid] = raw
                endif
                set slot = slot + 1
                set count = count + 1
            endif
            set i = i + 1
        endloop
        if count > 0 then
            call OMGAILog_LOG_INFO("STRAT", "技能枚举 pid=" + I2S(pid) + " count=" + I2S(count))
        endif
        return count
    endfunction

    // 4+2 综合：从 PSS 技能槽读实际技能，双通道分类 -> 判流派
    public function OMGAI_ComputeBuild takes unit u returns integer
        local integer pid = GetPlayerId(GetOwningPlayer(u)) + 1
        local integer i = 0
        local integer abilityId = 0
        local integer arch = 0
        local integer cls = 0
        local integer phys = 0
        local integer magic = 0
        local integer ctrl = 0
        local integer surv = 0
        local integer util = 0
        // 4 固定槽
        loop
            exitwhen i >= 4
            set abilityId = OMGAIPlayerSkillState_GetFixedSkillRawCode(pid, i + 1)
            if abilityId != 0 then
                set cls = SuijiMode_SkillClass(abilityId)
                if cls == 1 then
                    set phys = phys + 1
                elseif cls == 2 then
                    set magic = magic + 1
                endif
                set arch = OMGAI_GetSkillArchetype(abilityId)
                if BitIsSet(arch, ARCH_CONTROL) then
                    set ctrl = ctrl + 1
                endif
                if BitIsSet(arch, ARCH_SURVIVE) then
                    set surv = surv + 1
                endif
                if BitIsSet(arch, ARCH_UTILITY) then
                    set util = util + 1
                endif
            endif
            set i = i + 1
        endloop
        // 额外小技能
        set abilityId = PSS_ExtraSmall[pid]
        if abilityId != 0 then
            set cls = SuijiMode_SkillClass(abilityId)
            if cls == 1 then
                set phys = phys + 1
            elseif cls == 2 then
                set magic = magic + 1
            endif
            set arch = OMGAI_GetSkillArchetype(abilityId)
            if BitIsSet(arch, ARCH_CONTROL) then
                set ctrl = ctrl + 1
            endif
            if BitIsSet(arch, ARCH_SURVIVE) then
                set surv = surv + 1
            endif
            if BitIsSet(arch, ARCH_UTILITY) then
                set util = util + 1
            endif
        endif
        // 额外大技能
        set abilityId = PSS_ExtraBig[pid]
        if abilityId != 0 then
            set cls = SuijiMode_SkillClass(abilityId)
            if cls == 1 then
                set phys = phys + 1
            elseif cls == 2 then
                set magic = magic + 1
            endif
            set arch = OMGAI_GetSkillArchetype(abilityId)
            if BitIsSet(arch, ARCH_CONTROL) then
                set ctrl = ctrl + 1
            endif
            if BitIsSet(arch, ARCH_SURVIVE) then
                set surv = surv + 1
            endif
            if BitIsSet(arch, ARCH_UTILITY) then
                set util = util + 1
            endif
        endif
        // 综合评分（缓存）
        call OMGAICore_OMGAI_SaveInt(GetHandleId(u), 81, phys)
        call OMGAICore_OMGAI_SaveInt(GetHandleId(u), 82, magic)
        call OMGAICore_OMGAI_SaveInt(GetHandleId(u), 83, ctrl)
        call OMGAICore_OMGAI_SaveInt(GetHandleId(u), 84, surv)
        call OMGAICore_OMGAI_SaveInt(GetHandleId(u), 85, util)
        // 流派判定（肉/控制优先，其次物理/魔法）
        if surv >= 2 then
            call OMGAICore_OMGAI_SaveInt(GetHandleId(u), 80, BUILD_TANK)
            return BUILD_TANK
        elseif ctrl >= 2 then
            call OMGAICore_OMGAI_SaveInt(GetHandleId(u), 80, BUILD_CTRL)
            return BUILD_CTRL
        elseif phys >= 2 and magic <= 1 then
            call OMGAICore_OMGAI_SaveInt(GetHandleId(u), 80, BUILD_PHYS)
            return BUILD_PHYS
        elseif magic >= 2 and phys <= 1 then
            call OMGAICore_OMGAI_SaveInt(GetHandleId(u), 80, BUILD_MAGIC)
            return BUILD_MAGIC
        endif
        call OMGAICore_OMGAI_SaveInt(GetHandleId(u), 80, BUILD_MIXED)
        return BUILD_MIXED
    endfunction

    public function OMGAI_GetBuild takes unit u returns integer
        return OMGAICore_OMGAI_LoadInt(GetHandleId(u), 80)
    endfunction

    // 流派 -> 装备栏位选择（对应 4.6 多维装备"流派"维度）
    public function OMGAI_BuildItemColumn takes unit u returns integer
        local integer b = OMGAI_GetBuild(u)
        if b == BUILD_PHYS then
            return 1
        endif
        if b == BUILD_MAGIC then
            return 2
        endif
        if b == BUILD_TANK then
            return 3
        endif
        if b == BUILD_CTRL then
            return 4
        endif
        return 0
    endfunction

//---------------------------------------------------------------------------
// 3. 团战定位（对应 6A.2）
//---------------------------------------------------------------------------

    public function OMGAI_AssignRole takes unit u returns integer
        local integer b = OMGAI_GetBuild(u)
        local integer role = ROLE_DPS
        if b == BUILD_TANK then
            set role = ROLE_VANGUARD
        elseif b == BUILD_MAGIC then
            set role = ROLE_NUKER
        elseif b == BUILD_CTRL then
            set role = ROLE_SUPPORT
        elseif b == BUILD_PHYS then
            set role = ROLE_DPS
        else
            set role = ROLE_DPS
        endif
        call OMGAICore_OMGAI_SaveInt(GetHandleId(u), 86, role)
        return role
    endfunction

    public function OMGAI_GetRole takes unit u returns integer
        return OMGAICore_OMGAI_LoadInt(GetHandleId(u), 86)
    endfunction

    // 站位距离计算：按定位返回理想团战距离
    public function OMGAI_ComputeStandPos takes unit u, unit enemyCore returns real
        local integer role = OMGAI_GetRole(u)
        if role == ROLE_VANGUARD then
            return VANGUARD_RANGE
        elseif role == ROLE_NUKER then
            return NUKER_RANGE
        elseif role == ROLE_SUPPORT then
            return SUPPORT_RANGE
        endif
        return DPS_RANGE
    endfunction

    // 团战 desire 加减权（肉不逃跑/前排顶着，辅助保命优先）
    public function OMGAI_RoleDesireBias takes unit u, integer behaviorId returns real
        local integer role = OMGAI_GetRole(u)
        if behaviorId == BEH_RETREAT and role == ROLE_VANGUARD then
            return -0.4
        endif
        if behaviorId == BEH_RETREAT and role == ROLE_SUPPORT then
            return 0.2
        endif
        return 0.0
    endfunction

//---------------------------------------------------------------------------
// 4. 秒人判断（对应 6A.3）——爆发估算
//    规则：爆发预估 >= 血量*1.1 且 有控制链配合 -> gank/团战 desire +0.5 + focusTarget 写入
//    数据：缓存 = 英雄 hid，槽 87 = 当前秒杀目标（handle id）
//---------------------------------------------------------------------------

    // 估算当前 4+2 技能爆发：
    //   SkillDef 已注册技能：DmgScale*60*1.3（技能等级加成）
    //   未注册技能：物理按 (力量+敏捷*1.5)，魔法按 智力*3（近似，后续用 w3a 精修）
    public function OMGAI_EstimateBurst takes unit u returns real
        local integer pid = GetPlayerId(GetOwningPlayer(u)) + 1
        local integer i = 0
        local integer abilityId = 0
        local integer idx = 0
        local real total = 0.0
        local real scale = 0.0
        local integer cls = 0
        loop
            exitwhen i >= 4
            set abilityId = OMGAIPlayerSkillState_GetFixedSkillRawCode(pid, i + 1)
            if abilityId != 0 then
                set idx = OMGAISkillDef_FindByRawCode(abilityId)
                if idx != 0 then
                    set scale = SkillDef_DmgScale[idx]
                    if scale > 0.0 then
                        set total = total + scale * 60.0 * 1.3
                    endif
                else
                    set cls = SuijiMode_SkillClass(abilityId)
                    if cls == 1 then
                        set total = total + (GetHeroStr(u, true) + GetHeroAgi(u, true) * 1.5) * 1.2
                    elseif cls == 2 then
                        set total = total + GetHeroInt(u, true) * 3.0
                    endif
                endif
            endif
            set i = i + 1
        endloop
        set abilityId = PSS_ExtraSmall[pid]
        if abilityId != 0 then
            set idx = OMGAISkillDef_FindByRawCode(abilityId)
            if idx != 0 then
                set scale = SkillDef_DmgScale[idx]
                if scale > 0.0 then
                    set total = total + scale * 60.0 * 1.3
                endif
            else
                set cls = SuijiMode_SkillClass(abilityId)
                if cls == 1 then
                    set total = total + (GetHeroStr(u, true) + GetHeroAgi(u, true) * 1.5) * 1.2
                elseif cls == 2 then
                    set total = total + GetHeroInt(u, true) * 3.0
                endif
            endif
        endif
        set abilityId = PSS_ExtraBig[pid]
        if abilityId != 0 then
            set idx = OMGAISkillDef_FindByRawCode(abilityId)
            if idx != 0 then
                set scale = SkillDef_DmgScale[idx]
                if scale > 0.0 then
                    set total = total + scale * 60.0 * 1.3
                endif
            else
                set cls = SuijiMode_SkillClass(abilityId)
                if cls == 1 then
                    set total = total + (GetHeroStr(u, true) + GetHeroAgi(u, true) * 1.5) * 1.2
                elseif cls == 2 then
                    set total = total + GetHeroInt(u, true) * 3.0
                endif
            endif
        endif
        return total
    endfunction

    // 秒杀判断：爆发 >= 最近敌人血量*1.1 -> 锁定为目标（否则 0）
    public function OMGAI_FindKillTarget takes unit u returns integer
        local integer hid = GetHandleId(u)
        local unit target = OMGAITargetSel_OMGAI_GetClosestEnemy(u)
        local real burst = 0.0
        local real hp = 0.0
        if target == null then
            call OMGAICore_OMGAI_SaveInt(hid, 87, 0)
            call OMGAICore_OMGAI_SaveUnitHandle(hid, 94, null)
            return 0
        endif
        set burst = OMGAI_EstimateBurst(u)
        set hp = GetUnitState(target, UNIT_STATE_LIFE)
        if burst >= hp * BURST_MULT then
            call OMGAICore_OMGAI_SaveInt(hid, 87, GetHandleId(target))
            call OMGAICore_OMGAI_SaveUnitHandle(hid, 94, target)
            return GetHandleId(target)
        endif
        call OMGAICore_OMGAI_SaveInt(hid, 87, 0)
        call OMGAICore_OMGAI_SaveUnitHandle(hid, 94, null)
        return 0
    endfunction

    // 秒杀通道：desire 注入（有锁定目标 -> gank/团战 desire 加成）
    public function OMGAI_KillDesireBonus takes unit u returns real
        if OMGAICore_OMGAI_LoadInt(GetHandleId(u), 87) != 0 then
            return SECURE_DESIRE_BONUS
        endif
        return 0.0
    endfunction

//---------------------------------------------------------------------------
// 5. 蹲守针对（对应 6A.4）
//---------------------------------------------------------------------------

    public function OMGAI_AmbushThink takes unit u returns integer
        local integer hid = GetHandleId(u)
        local unit keyHero = OMGAIEnemyState_OMGAI_GetTopThreat()
        local integer st = 0
        if keyHero == null then
            return AMBUSH_IDLE
        endif
        if (not IsUnitType(keyHero, UNIT_TYPE_DEAD) and GetWidgetLife(keyHero) > 0.405) then
            set st = AMBUSH_PRESS
        elseif IsUnitVisible(keyHero, GetOwningPlayer(u)) then
            if GetUnitState(keyHero, UNIT_STATE_LIFE) < GetUnitState(keyHero, UNIT_STATE_MAX_LIFE) * KEY_HERO_HP_PRESS then
                set st = AMBUSH_PRESS
            else
                set st = AMBUSH_ENGAGE
            endif
        else
            set st = AMBUSH_IDLE
        endif
        call OMGAICore_OMGAI_SaveInt(hid, 88, st)
        return st
    endfunction

    // 蹲守 desire 加成：ENGAGE/PRESS 时注入集火欲望
    public function OMGAI_AmbushDesireBonus takes unit u returns real
        local integer st = OMGAICore_OMGAI_LoadInt(GetHandleId(u), 88)
        if st == AMBUSH_ENGAGE or st == AMBUSH_PRESS then
            return SECURE_DESIRE_BONUS
        endif
        return 0.0
    endfunction

    // 蹲守克制：敌不可见时降低 gank/推塔欲望（不贸然暴露）
    public function OMGAI_AmbushRestraint takes unit u, integer behaviorId returns real
        local integer st = OMGAICore_OMGAI_LoadInt(GetHandleId(u), 88)
        if st == AMBUSH_IDLE then
            if behaviorId == BEH_GANK then
                return -0.3
            endif
            if behaviorId == BEH_PUSH then
                return -0.2
            endif
        endif
        return 0.0
    endfunction

    // 针对出装：按 EnemyState 对位 Build 返回反制装备栏位（出装系统对接后启用）
    public function OMGAI_CounterBuild takes unit u returns integer
        local player p = GetOwningPlayer(u)
        local group g = CreateGroup()
        local unit e = null
        local integer phys = 0
        local integer mag = 0
        local integer b = 0
        // 统计周围 2000 码敌方英雄流派
        call GroupEnumUnitsInRange(g, GetUnitX(u), GetUnitY(u), 2000.0, null)
        set e = FirstOfGroup(g)
        loop
            exitwhen e == null
            if IsUnitType(e, UNIT_TYPE_HERO) and UnitAlive(e) and IsUnitEnemy(e, p) then
                set b = OMGAI_GetBuild(e)
                if b == BUILD_PHYS then
                    set phys = phys + 1
                elseif b == BUILD_MAGIC then
                    set mag = mag + 1
                endif
            endif
            call GroupRemoveUnit(g, e)
            set e = FirstOfGroup(g)
        endloop
        call DestroyGroup(g)
        set g = null
        set e = null
        // 克制决策：敌方物理流多 -> 1(物理抗性)；法师流多 -> 2(法抗)；均衡 -> 0(默认)
        if phys >= mag and phys > 0 then
            return 1
        elseif mag > phys then
            return 2
        endif
        return 0
    endfunction

//---------------------------------------------------------------------------
// 6. 视野博弈（对应 6A.5）
//---------------------------------------------------------------------------

    // 标记可疑守卫：敌方英雄在我方附近停留过 -> 记录
    public function OMGAI_MarkSuspiciousWard takes unit wardLoc, unit enemyNear returns nothing
        call OMGAICore_OMGAI_SaveReal(GetHandleId(wardLoc), 92, 1.0)
        call OMGAICore_OMGAI_SaveInt(GetHandleId(wardLoc), 93, GetHandleId(enemyNear))
    endfunction

    // 反眼目标：返回视野内最近的敌方守卫（守卫类型库对接后启用；V2.4 保守返回 null）
    public function OMGAI_GetWardToDeWard takes unit u returns unit
        local player p = GetOwningPlayer(u)
        local group g = CreateGroup()
        local unit ward = null
        local unit tmp = null
        // 扫描 1400 码：敌方、存活、非英雄非建筑、带守卫特征技能 A04R
        call GroupEnumUnitsInRange(g, GetUnitX(u), GetUnitY(u), 1400.0, null)
        set tmp = FirstOfGroup(g)
        loop
            exitwhen tmp == null
            if not IsUnitType(tmp, UNIT_TYPE_HERO) and not IsUnitType(tmp, UNIT_TYPE_STRUCTURE) and UnitAlive(tmp) and IsUnitEnemy(tmp, p) and GetUnitAbilityLevel(tmp, 'A04R') > 0 then
                set ward = tmp
                exitwhen true
            endif
            call GroupRemoveUnit(g, tmp)
            set tmp = FirstOfGroup(g)
        endloop
        call DestroyGroup(g)
        set g = null
        set tmp = null
        return ward
    endfunction

    // 反眼链路：扫描附近敌守卫 -> 存槽 92（AI 英雄），ThinkWard 消费
    public function OMGAI_DetectWards takes unit u returns nothing
        local integer hid = GetHandleId(u)
        local player p = GetOwningPlayer(u)
        local group g = CreateGroup()
        local unit tmp = null
        local unit ward = null
        call GroupEnumUnitsInRange(g, GetUnitX(u), GetUnitY(u), 1400.0, null)
        set tmp = FirstOfGroup(g)
        loop
            exitwhen tmp == null
            if not IsUnitType(tmp, UNIT_TYPE_HERO) and not IsUnitType(tmp, UNIT_TYPE_STRUCTURE) and UnitAlive(tmp) and IsUnitEnemy(tmp, p) and GetUnitAbilityLevel(tmp, 'A04R') > 0 then
                set ward = tmp
                exitwhen true
            endif
            call GroupRemoveUnit(g, tmp)
            set tmp = FirstOfGroup(g)
        endloop
        call DestroyGroup(g)
        if ward != null then
            call OMGAICore_OMGAI_SaveUnitHandle(hid, 92, ward)
            call OMGAILog_LOG_WARN("WARD", "发现敌方守卫 type=" + I2S(GetUnitTypeId(ward)))
        else
            call OMGAICore_OMGAI_SaveUnitHandle(hid, 92, null)
        endif
        set g = null
        set tmp = null
        set ward = null
    endfunction

    // 开雾判断：有秒杀目标且目标不可见 -> 建议开雾
    public function OMGAI_ShouldUseSmoke takes unit u returns boolean
        local integer kill = OMGAICore_OMGAI_LoadInt(GetHandleId(u), 87)
        if kill != 0 then
            return true
        endif
        return false
    endfunction

//---------------------------------------------------------------------------
// 7. 初始化与自检
//---------------------------------------------------------------------------

    // 注册：AI 英雄出生后调用 -> 枚举技能 + 流派识别 + 定位分配
    public function OMGAI_StrategyInitHero takes unit u returns nothing
        local integer pid = GetPlayerId(GetOwningPlayer(u)) + 1
        // 初始化 PSS 状态（电脑侧无 UI 流程，直接进入完成态）
        call OMGAIPlayerSkillState_Init(pid, GetUnitTypeId(u), u)
        // 枚举英雄实际技能 -> 写 PSS 4+2 槽
        call OMGAI_EnumerateHeroSkills(u)
        call OMGAI_ComputeBuild(u)
        call OMGAI_AssignRole(u)
        call OMGAILog_LOG_INFO("STRAT", "英雄战术初始化: build=" + I2S(OMGAI_GetBuild(u)) + " role=" + I2S(OMGAI_GetRole(u)))
    endfunction

    // 每 tick：刷新秒杀目标 + 蹲守状态（行为层 Desire/Think 前调用）
    public function OMGAI_StrategyTick takes unit u returns nothing
        local integer hid = GetHandleId(u)
        local real now = OMGAICore_OMGAI_GetGameTime()
        local real last = OMGAICore_OMGAI_LoadReal(hid, 99)
        // V2.6: 2s 节流（FindKillTarget/AmbushThink 内部有枚举，避免每 tick 重算）
        if now - last < 2.0 then
            return
        endif
        call OMGAICore_OMGAI_SaveReal(hid, 99, now)
        call OMGAI_FindKillTarget(u)
        call OMGAI_AmbushThink(u)
        call OMGAI_DetectWards(u)
        // 团战标记（槽 93 = 1 团战中）：供 Behaviors DesireTeam 读取，避免高频枚举
        if OMGAITargetSel_OMGAI_IsTeamFight(u) then
            call OMGAICore_OMGAI_SaveInt(hid, 93, 1)
        else
            call OMGAICore_OMGAI_SaveInt(hid, 93, 0)
        endif
    endfunction

    public function OMGAIStrategy_Init takes nothing returns nothing
        call OMGAILog_LOG_INFO("STRAT", "OMGAIStrategy 战术意识层初始化完成（V2.4 基图运行时对接）")
    endfunction


endlibrary
