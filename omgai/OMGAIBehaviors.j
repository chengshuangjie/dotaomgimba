//===========================================================================
// OMGAIBehaviors.j  --  Dota OMG ï¿½ï¿½ï¿½ï¿½ AI 8 ï¿½ï¿½ï¿½ï¿½ÎªÄ£ï¿½ï¿½
//   ï¿½ï¿½Ó¦ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½6ï¿½ï¿½Desire ï¿½ï¿½Ê½ + Think ×´Ì¬ï¿½ï¿½ + ï¿½ï¿½Öµï¿½ï¿½ï¿½ï¿½
//   ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½OMGAICore, OMGAILog, OMGAISpellCast, OMGAITargetSel, OMGAIActionMask
//   Ã¿ï¿½ï¿½Ä£ï¿½ï¿½ = OMGAI_Desire<X>(unit)ï¿½ï¿½real + OMGAI_Think<X>(unit)
//   ï¿½ï¿½Öµï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½Ä¼ï¿½Í·ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ OMGAIConfigï¿½ï¿½
//===========================================================================

library OMGAIBehaviors requires OMGAICore, OMGAILog, OMGAISpellCast, OMGAITargetSel, OMGAIActionMask, OMGAIStrategy

//---------------------------------------------------------------------------
// 0. ï¿½ï¿½Öµï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½Ð¿Éµï¿½ï¿½ï¿½
//---------------------------------------------------------------------------

    // ï¿½ï¿½ï¿½ß£ï¿½ï¿½ï¿½6.1ï¿½ï¿½
    globals
    constant real FARM_DESIRE_BASE   = 0.50
    constant real DENY_HP_THRESHOLD  = 0.49  // ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½Öµï¿½ï¿½D2 OpenHyperAI:160ï¿½ï¿½
    constant real DANGER_HERO_RANGE  = 800.0
    // ï¿½ï¿½Ò°ï¿½ï¿½ï¿½ï¿½6.2ï¿½ï¿½
    constant real JUNGLE_WINDOW_MIN  = 6.0   // ï¿½ï¿½ï¿½ï¿½
    constant real JUNGLE_WINDOW_MAX  = 10.0
    // gankï¿½ï¿½ï¿½ï¿½6.3ï¿½ï¿½
    constant real GANK_TARGET_HP     = 0.50
    // ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½6.4ï¿½ï¿½
    constant real PUSH_BASE          = 0.20
    constant real PUSH_TIME_START    = 12.0
    // ï¿½ï¿½Õ½ï¿½ï¿½ï¿½ï¿½6.5ï¿½ï¿½
    constant real TEAM_FIGHT_COUNT   = 5
    // ï¿½ï¿½ï¿½Ë£ï¿½ï¿½ï¿½6.6ï¿½ï¿½
    constant real RETREAT_HP_PCT     = 0.25
    constant real RETREAT_ENEMY_RANGE = 600.0
    // ï¿½Ø¼Ò²ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½5.3 Ó²×´Ì¬ï¿½Ã£ï¿½
    constant real HOME_HP_PCT        = 0.25
    constant real HOME_MANA_PCT      = 0.15

//---------------------------------------------------------------------------
// 1. ï¿½ï¿½ï¿½ï¿½ Farmï¿½ï¿½ï¿½ï¿½6.1ï¿½ï¿½
//    ×´Ì¬ï¿½ï¿½ LANEï¿½ï¿½PUSHï¿½ï¿½DEFENDï¿½ï¿½Desire = ï¿½ï¿½ï¿½ï¿½ + Ð¡ï¿½ï¿½È¨ï¿½ï¿½ - Î£ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½
//---------------------------------------------------------------------------

    endglobals
    public function OMGAI_DesireFarm takes unit u returns real
        local real d = FARM_DESIRE_BASE
        // ï¿½Ð·ï¿½Ð¡ï¿½ï¿½ï¿½É²ï¿½ï¿½ï¿½ ï¿½ï¿½ 0.05ï¿½ï¿½TODO: ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½Ð¡ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½
        // ï¿½ï¿½ï¿½ï¿½Ð¡ï¿½ï¿½ï¿½ï¿½ ï¿½ï¿½ 0.02
        // Î£ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½Ó¢ï¿½ï¿½ 800 ï¿½ï¿½ï¿½ï¿½ï¿½Ò·ï¿½ï¿½ï¿½ï¿½ï¿½ ï¿½ï¿½ ï¿½ï¿½ desire
        // TODO: ï¿½ï¿½ EnemyState ï¿½ï¿½ï¿½ï¿½
        return d
    endfunction

    public function OMGAI_ThinkFarm takes unit u returns nothing
        // TODO: FSM LANE/PUSH/DEFEND
        // ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½Ô¤ï¿½ï¿½ï¿½Ëºï¿½ ï¿½ï¿½ Ä¿ï¿½êµ±Ç°Ñªï¿½ï¿½ï¿½ï¿½Ç°Ò¡+ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ t=2.0*attackPoint+dist/moveSpeedï¿½ï¿½
        // ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½Ð¡ï¿½ï¿½ < 49% ï¿½ï¿½ ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½Ð¡ï¿½ï¿½
        // ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ 30s ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½
        // ï¿½ï¿½Î»ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½Ä¿ï¿½ï¿½ï¿½ä»¯ < 120 ï¿½ë²»ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½
        // ï¿½ï¿½ï¿½Ä£ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½Ñ¡ï¿½ï¿½ï¿½Ü£ï¿½ï¿½ï¿½/ï¿½ï¿½/Ô¶ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½
        call OMGAILog_LOG_DEBUG("BEH", "Farm Think")
    endfunction

//---------------------------------------------------------------------------
// 2. ï¿½ï¿½Ç®/ï¿½ï¿½Ò°ï¿½ï¿½ï¿½ï¿½6.2ï¿½ï¿½
//    TRAVELLINGï¿½ï¿½NEARï¿½ï¿½FARMINGï¿½ï¿½STACKINGï¿½ï¿½Ã¿ï¿½ï¿½ï¿½ï¿½ :55 ï¿½ï¿½Ò°ï¿½Â¼ï¿½
//---------------------------------------------------------------------------

    public function OMGAI_DesireJungle takes unit u returns real
        local real d = 0.0
        local real t = OMGAICore_OMGAI_GetGameTime() / 60.0
        // 6~10 ï¿½ï¿½ï¿½ï¿½Ò°ï¿½ï¿½ï¿½Æ½ï¿½ï¿½ï¿½ ï¿½ï¿½ ï¿½ï¿½ï¿½ï¿½
        if t >= JUNGLE_WINDOW_MIN and t <= JUNGLE_WINDOW_MAX then
            set d = 0.4
        endif
        // ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½á£ºË¢ï¿½Âµï¿½ï¿½ï¿½Ê± <30s ï¿½Ò¾ï¿½ï¿½ï¿½ <5000 ï¿½ï¿½ +0.3
        // TODO: Rune Ê±ï¿½ä´°
        return d
    endfunction

    public function OMGAI_ThinkJungle takes unit u returns nothing
        // TODO: TRAVELLINGï¿½ï¿½NEARï¿½ï¿½FARMINGï¿½ï¿½STACKING ×´Ì¬ï¿½ï¿½ï¿½ï¿½D2 adam3qï¿½ï¿½
        call OMGAILog_LOG_DEBUG("BEH", "Jungle Think")
    endfunction

//---------------------------------------------------------------------------
// 3. Gankï¿½ï¿½ï¿½ï¿½6.3ï¿½ï¿½
//    Desire ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½Õ½ï¿½ï¿½ï¿½ï¿½ï¿½Å¼ï¿½ / ï¿½äµ¥(1200 ï¿½ï¿½ï¿½ï¿½Ñ¡ï¿½1) / ï¿½É¼ï¿½ / 70% ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½
//    Thinkï¿½ï¿½ASSEMBLEï¿½ï¿½ROAMINGï¿½ï¿½Ä¿ï¿½ê¶ªÊ§5sï¿½ï¿½ï¿½ï¿½
//---------------------------------------------------------------------------

        public function OMGAI_DesireGank takes unit u returns real
        local unit target = OMGAICore_OMGAI_LoadUnitHandle(GetHandleId(u), 94)
        local real d = 0.0
        if target == null then
            return 0.0
        endif
        // ï¿½ï¿½ï¿½ï¿½É±Ä¿ï¿½ê£¨FindKillTarget ï¿½ï¿½ï¿½Ð²ï¿½Ñª+ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ ï¿½ï¿½ï¿½ï¿½ 0.7
        set d = 0.7
        // ï¿½äµ¥ + 0.2
        if OMGAITargetSel_OMGAI_IsLoneEnemy(target) then
            set d = d + 0.2
        endif
        // ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½Ð£ï¿½70%ï¿½ï¿½
        if GetRandomInt(1, 100) > 70 then
            set d = 0.0
        endif
        return d
    endfunction

        public function OMGAI_ThinkGank takes unit u returns nothing
        local unit target = OMGAITargetSel_OMGAI_GetFocusTarget(u)
        local integer hid = GetHandleId(u)
        local real now = OMGAICore_OMGAI_GetGameTime()
        local real last = OMGAICore_OMGAI_LoadReal(hid, 95)
        if target == null then
            return
        endif
        if now - last < 0.6 then
            return
        endif
        call OMGAICore_OMGAI_SaveReal(hid, 95, now)
        // ï¿½ï¿½ï¿½Ú¹ï¿½ï¿½ï¿½Ä¿ï¿½ï¿½ï¿½ò²»·ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½î£¨ï¿½ï¿½ï¿½ï¿½ï¿½Ï»ï¿½Í¼ AIï¿½ï¿½
        if GetUnitCurrentOrder(u) != OrderId("smart") then
            call IssueTargetOrder(u, "smart", target)
            call OMGAILog_LOG_WARN("GANK", "ï¿½ï¿½ï¿½ï¿½ " + I2S(GetUnitTypeId(target)) + " hp%=" + R2S(GetUnitState(target, UNIT_STATE_LIFE) / GetUnitState(target, UNIT_STATE_MAX_LIFE)))
        endif
    endfunction

//---------------------------------------------------------------------------
// 4. ï¿½ï¿½ï¿½ï¿½/ï¿½ï¿½ï¿½Ø£ï¿½ï¿½ï¿½6.4ï¿½ï¿½
//---------------------------------------------------------------------------

    public function OMGAI_DesirePush takes unit u returns real
        local real d = PUSH_BASE
        local real t = OMGAICore_OMGAI_GetGameTime() / 60.0
        // 12 ï¿½ï¿½ï¿½Óºï¿½ï¿½ï¿½Ê±ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½
        if t > PUSH_TIME_START then
            set d = d + (t - PUSH_TIME_START) * 0.01
        endif
        // ï¿½ï¿½/ï¿½ï¿½Óª/ï¿½ï¿½ï¿½Ã²ï¿½ï¿½ï¿½ï¿½ï¿½Ó¼ï¿½ï¿½ï¿½TODOï¿½ï¿½
        if d > 0.8 then
            set d = 0.8
        endif
        return d
    endfunction

    public function OMGAI_ThinkPush takes unit u returns nothing
        // TODO: ï¿½ï¿½ï¿½ß¼ï¿½È¨ï¿½ï¿½ï¿½È¡ï¿½ï¿½ï¿½Â·ï¿½ï¿½D2 GetCommonPushLaneDesiresï¿½ï¿½
        call OMGAILog_LOG_DEBUG("BEH", "Push Think")
    endfunction

    public function OMGAI_DesireDefend takes unit u returns real
        // TODO: ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ ï¿½ï¿½ ï¿½ï¿½Ô®ï¿½Â¼ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ desire
        return 0.0
    endfunction

    public function OMGAI_ThinkDefend takes unit u returns nothing
        // TODO: DEFEND_Towerï¿½ï¿½ClearWaveï¿½ï¿½Return ×´Ì¬ï¿½ï¿½ï¿½ï¿½D1 aiDefTowerAttackï¿½ï¿½
        call OMGAILog_LOG_DEBUG("BEH", "Defend Think")
    endfunction

//---------------------------------------------------------------------------
// 5. ï¿½ï¿½Õ½ï¿½ï¿½ï¿½ï¿½6.5ï¿½ï¿½
//---------------------------------------------------------------------------

        public function OMGAI_DesireTeam takes unit u returns real
        if OMGAICore_OMGAI_LoadInt(GetHandleId(u), 93) == 1 then
            return 1.0
        endif
        return 0.0
    endfunction

        public function OMGAI_ThinkTeam takes unit u returns nothing
        local unit target = OMGAITargetSel_OMGAI_GetFocusTarget(u)
        local integer hid = GetHandleId(u)
        local integer role = OMGAICore_OMGAI_LoadInt(hid, 86)
        local real now = OMGAICore_OMGAI_GetGameTime()
        local real last = OMGAICore_OMGAI_LoadReal(hid, 96)
        local real want = 600.0
        local real dx = 0.0
        local real dy = 0.0
        local real dist = 0.0
        if now - last < 1.0 then
            return
        endif
        call OMGAICore_OMGAI_SaveReal(hid, 96, now)
        // ï¿½ï¿½ï¿½ï¿½É«Õ¾Î»ï¿½ï¿½Ì¹ï¿½ï¿½(2)ï¿½ï¿½Ç° / ï¿½ï¿½Õ½(1)ï¿½ï¿½ / ï¿½ï¿½Ê¦ï¿½ï¿½ï¿½ï¿½(3/4)ï¿½ï¿½ï¿½ï¿½ / ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½
        if role == 2 then
            set want = 350.0
        elseif role == 1 then
            set want = 450.0
        elseif role == 3 or role == 4 then
            set want = 800.0
        endif
        if target != null then
            set dx = GetUnitX(u) - GetUnitX(target)
            set dy = GetUnitY(u) - GetUnitY(target)
            set dist = SquareRoot(dx * dx + dy * dy)
            if dist > want + 200.0 and dist > 1.0 then
                // Ì«Ô¶ï¿½ï¿½ï¿½ï¿½Ä¿ï¿½ê¿¿ï¿½ï¿½ï¿½ï¿½ want ï¿½ï¿½ï¿½ï¿½
                call IssuePointOrder(u, "move", GetUnitX(target) + dx / dist * want, GetUnitY(target) + dy / dist * want)
            elseif dist < want - 200.0 and dist > 1.0 then
                // Ì«ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½
                call IssuePointOrder(u, "move", GetUnitX(u) + dx / dist * 250.0, GetUnitY(u) + dy / dist * 250.0)
            endif
            // ï¿½ï¿½ï¿½ï¿½
            if GetUnitCurrentOrder(u) != OrderId("smart") then
                call IssueTargetOrder(u, "smart", target)
            endif
        endif
        call OMGAILog_LOG_WARN("TEAM", "ï¿½ï¿½Õ½Õ¾Î» role=" + I2S(role) + " want=" + R2S(want))
    endfunction

//---------------------------------------------------------------------------
// 6. ï¿½ï¿½ï¿½Ë£ï¿½ï¿½ï¿½6.6ï¿½ï¿½
//---------------------------------------------------------------------------

    public function OMGAI_DesireRetreat takes unit u returns real
        local real hpPct = 0.0
        set hpPct = GetUnitState(u, UNIT_STATE_LIFE) / GetUnitState(u, UNIT_STATE_MAX_LIFE)
        if hpPct < RETREAT_HP_PCT then
            return 1.0
        endif
        // TODO: ï¿½Ð·ï¿½ï¿½ï¿½Ð² top1 ï¿½ï¿½ < 300 ï¿½ï¿½ï¿½Ò·ï¿½Ñª < 40%
        return 0.0
    endfunction

        public function OMGAI_ThinkRetreat takes unit u returns nothing
        local integer hid = GetHandleId(u)
        local real now = OMGAICore_OMGAI_GetGameTime()
        local real last = OMGAICore_OMGAI_LoadReal(hid, 97)
        local player p = GetOwningPlayer(u)
        local real fx = 0.0
        local real fy = 0.0
        if now - last < 2.0 then
            return
        endif
        call OMGAICore_OMGAI_SaveReal(hid, 97, now)
        set fx = GetStartLocationX(GetPlayerStartLocation(p))
        set fy = GetStartLocationY(GetPlayerStartLocation(p))
        // ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½Ñ»Ø¼ï¿½ï¿½ï¿½ï¿½Ø¸ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½
        if not UnitAlive(u) then
            return
        endif
        if GetUnitCurrentOrder(u) != OrderId("move") or OMGAICore_OMGAI_LoadInt(hid, 97) == 0 then
            call IssuePointOrder(u, "move", fx, fy)
            call OMGAILog_LOG_WARN("RETR", "ï¿½ï¿½Ñªï¿½ï¿½ï¿½ï¿½ hp%=" + R2S(GetUnitState(u, UNIT_STATE_LIFE) / GetUnitState(u, UNIT_STATE_MAX_LIFE)))
        endif
    endfunction

//---------------------------------------------------------------------------
// 7. ï¿½ï¿½Ò°/ï¿½ï¿½ï¿½Û£ï¿½ï¿½ï¿½6.7ï¿½ï¿½
//---------------------------------------------------------------------------

        public function OMGAI_DesireWard takes unit u returns real
        local real now = OMGAICore_OMGAI_GetGameTime()
        local real last = OMGAICore_OMGAI_LoadReal(GetHandleId(u), 98)
        if now - last < 60.0 then
            return 0.0
        endif
        return 0.1
    endfunction

        public function OMGAI_ThinkWard takes unit u returns nothing
        local integer hid = GetHandleId(u)
        local real now = OMGAICore_OMGAI_GetGameTime()
        local real last = OMGAICore_OMGAI_LoadReal(hid, 98)
        local unit ward = null
        if now - last < 60.0 then
            return
        endif
        call OMGAICore_OMGAI_SaveReal(hid, 98, now)
        // ï¿½æ·´ï¿½Û£ï¿½ï¿½ï¿½ï¿½È¶ï¿½ï¿½ï¿½ 92 ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½Ê§Ð§ï¿½ò¶µµï¿½É¨ï¿½ï¿½
        set ward = OMGAICore_OMGAI_LoadUnitHandle(hid, 92)
        if ward == null or not UnitAlive(ward) or not IsUnitEnemy(ward, GetOwningPlayer(u)) then
            set ward = OMGAIStrategy_OMGAI_GetWardToDeWard(u)
        endif
        if ward != null then
            call IssueTargetOrder(u, "smart", ward)
            call OMGAILog_LOG_WARN("WARD", "ï¿½ï¿½ï¿½Û£ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½Ð·ï¿½ï¿½ï¿½ï¿½ï¿½ type=" + I2S(GetUnitTypeId(ward)))
        endif
        call OMGAILog_LOG_WARN("WARD", "ï¿½ï¿½Ò°ï¿½ï¿½ï¿½Ú£ï¿½ï¿½ï¿½ï¿½ï¿½/ï¿½ï¿½ï¿½ï¿½Ñ²ï¿½ï¿½")
    endfunction

//---------------------------------------------------------------------------
// 9. v0.9 ¸¨ÖúÕ½Êõ¶¯×÷£¨¿ªÎí±Æ½ü / Õ½ÂÔÑÛÎ» / ³ö×°Òýµ¼£©
//    ÓÉ Dispatcher TickUnit µÄ OMGAI_BehaviorsAuxTick µ÷ÓÃ£¬²»ÇÀÕ¼Ö÷ÐÐÎª
//---------------------------------------------------------------------------

    // ¿ªÎí±Æ½ü£ºÓÐÃëÉ±Ä¿±êÇÒÄ¿±ê²»¿É¼û -> Ö÷¶¯±Æ½ü£¨¾ºÈü¼¶×¥ÈËÒâÊ¶£©
    public function OMGAI_ThinkSmoke takes unit u returns nothing
        local unit target = OMGAICore_OMGAI_LoadUnitHandle(GetHandleId(u), 94)
        local integer hid = GetHandleId(u)
        local real now = OMGAICore_OMGAI_GetGameTime()
        local real last = OMGAICore_OMGAI_LoadReal(hid, 100)
        if target == null then
            return
        endif
        if now - last < 4.0 then
            return
        endif
        call OMGAICore_OMGAI_SaveReal(hid, 100, now)
        if not IsUnitVisible(target, GetOwningPlayer(u)) then
            call IssuePointOrder(u, "move", GetUnitX(target), GetUnitY(target))
            call OMGAILog_LOG_WARN("SMOKE", "SMOKE approach target=" + I2S(GetUnitTypeId(target)))
        endif
        set target = null
    endfunction

    // Õ½ÂÔÑÛÎ»Õ¾¸Ú£º¸¨Öú½ÇÉ«¶¨ÆÚÈ¥ºÓµÀ¹Ø¼üµãÕ¾¸Ú£¨ÊÓÒ°²¹Î»£¬²åÑÛÎïÆ·¶Ô½ÓÇ°ÖÃ£©
    public function OMGAI_ThinkWardPlace takes unit u returns nothing
        local integer hid = GetHandleId(u)
        local integer role = OMGAICore_OMGAI_LoadInt(hid, 86)
        local real now = OMGAICore_OMGAI_GetGameTime()
        local real last = OMGAICore_OMGAI_LoadReal(hid, 101)
        local real wx = 0.0
        local real wy = 0.0
        local rect world = GetWorldBounds()
        if role != 3 and role != 4 then
            return
        endif
        if now - last < 90.0 then
            return
        endif
        call OMGAICore_OMGAI_SaveReal(hid, 101, now)
        set wx = GetRectCenterX(world)
        set wy = GetRectCenterY(world)
        call IssuePointOrder(u, "move", wx, wy)
        call OMGAILog_LOG_WARN("WARD", "WARD post x=" + R2S(wx) + " y=" + R2S(wy))
        set world = null
    endfunction

    // ³ö×°Òýµ¼£º°´ CounterBuild Á÷ÅÉ½á¹ûÊä³öÕë¶Ô³ö×°½¨Òé£¨¹ºÂòÏµÍ³¶Ô½ÓÇ°ÖÃ£©
    public function OMGAI_BuyGuide takes unit u returns nothing
        local integer hid = GetHandleId(u)
        local integer cb = OMGAIStrategy_OMGAI_CounterBuild(u)
        local real now = OMGAICore_OMGAI_GetGameTime()
        local real last = OMGAICore_OMGAI_LoadReal(hid, 102)
        if now - last < 60.0 then
            return
        endif
        call OMGAICore_OMGAI_SaveReal(hid, 102, now)
        if cb == 1 then
            call OMGAILog_LOG_WARN("BUY", "BUY counter physical armor")
        elseif cb == 2 then
            call OMGAILog_LOG_WARN("BUY", "BUY counter magic resist")
        else
            call OMGAILog_LOG_WARN("BUY", "BUY balanced core build")
        endif
    endfunction

    // ¸¨Öú¶¯×÷¾ÛºÏ£¨ÓÉ Dispatcher TickUnit µ÷ÓÃ£©
    public function OMGAI_BehaviorsAuxTick takes unit u returns nothing
        call OMGAI_ThinkSmoke(u)
        call OMGAI_ThinkWardPlace(u)
        call OMGAI_BuyGuide(u)
    endfunction

//---------------------------------------------------------------------------
// 8. ï¿½ï¿½ï¿½ï¿½
//---------------------------------------------------------------------------


    public function OMGAI_BehaviorsInit takes nothing returns nothing
        call OMGAILog_LOG_INFO("BEH", "OMGAIBehaviors ï¿½ï¿½Ê¼ï¿½ï¿½ï¿½ï¿½ï¿½")
    endfunction

endlibrary
