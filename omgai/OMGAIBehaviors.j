//===========================================================================
// OMGAIBehaviors.j  --  Dota OMG ���� AI 8 ����Ϊģ��
//   ��Ӧ��������6��Desire ��ʽ + Think ״̬�� + ��ֵ����
//   ������OMGAICore, OMGAILog, OMGAISpellCast, OMGAITargetSel, OMGAIActionMask
//   ÿ��ģ�� = OMGAI_Desire<X>(unit)��real + OMGAI_Think<X>(unit)
//   ��ֵ�������ļ�ͷ��������������� OMGAIConfig��
//===========================================================================

library OMGAIBehaviors requires OMGAICore, OMGAILog, OMGAISpellCast, OMGAITargetSel, OMGAIActionMask, OMGAIStrategy

//---------------------------------------------------------------------------
// 0. ��ֵ���������пɵ���
//---------------------------------------------------------------------------

    // ���ߣ���6.1��
    globals
    constant real FARM_DESIRE_BASE   = 0.50
    constant real DENY_HP_THRESHOLD  = 0.49  // ������ֵ��D2 OpenHyperAI:160��
    constant real DANGER_HERO_RANGE  = 800.0
    // ��Ұ����6.2��
    constant real JUNGLE_WINDOW_MIN  = 6.0   // ����
    constant real JUNGLE_WINDOW_MAX  = 10.0
    // gank����6.3��
    constant real GANK_TARGET_HP     = 0.50
    // ��������6.4��
    constant real PUSH_BASE          = 0.20
    constant real PUSH_TIME_START    = 12.0
    // ��ս����6.5��
    constant real TEAM_FIGHT_COUNT   = 5
    // ���ˣ���6.6��
    constant real RETREAT_HP_PCT     = 0.25
    constant real RETREAT_ENEMY_RANGE = 600.0
    // �ؼҲ�������5.3 Ӳ״̬�ã�
    constant real HOME_HP_PCT        = 0.25
    constant real HOME_MANA_PCT      = 0.15

//---------------------------------------------------------------------------
// 1. ���� Farm����6.1��
//    ״̬�� LANE��PUSH��DEFEND��Desire = ���� + С��Ȩ�� - Σ������
//---------------------------------------------------------------------------

    endglobals
    public function OMGAI_DesireFarm takes unit u returns real
        local real d = FARM_DESIRE_BASE
        // �з�С���ɲ��� �� 0.05��TODO: ��������С��������
        // ����С���� �� 0.02
        // Σ����������Ӣ�� 800 �����ҷ����� �� �� desire
        // TODO: �� EnemyState ����
        return d
    endfunction

    public function OMGAI_ThinkFarm takes unit u returns nothing
        // TODO: FSM LANE/PUSH/DEFEND
        // ������Ԥ���˺� �� Ŀ�굱ǰѪ����ǰҡ+�������� t=2.0*attackPoint+dist/moveSpeed��
        // ����������С�� < 49% �� ��������С��
        // ���������� 30s �����������
        // ��λ������Ŀ���仯 < 120 �벻������
        // ���ģ��������ѡ���ܣ���/��/Զ������
        call OMGAILog_LOG_DEBUG("BEH", "Farm Think")
    endfunction

//---------------------------------------------------------------------------
// 2. ��Ǯ/��Ұ����6.2��
//    TRAVELLING��NEAR��FARMING��STACKING��ÿ���� :55 ��Ұ�¼�
//---------------------------------------------------------------------------

    public function OMGAI_DesireJungle takes unit u returns real
        local real d = 0.0
        local real t = OMGAICore_OMGAI_GetGameTime() / 60.0
        // 6~10 ����Ұ���ƽ��� �� ����
        if t >= JUNGLE_WINDOW_MIN and t <= JUNGLE_WINDOW_MAX then
            set d = 0.4
        endif
        // ������᣺ˢ�µ���ʱ <30s �Ҿ��� <5000 �� +0.3
        // TODO: Rune ʱ�䴰
        return d
    endfunction

    public function OMGAI_ThinkJungle takes unit u returns nothing
        // TODO: TRAVELLING��NEAR��FARMING��STACKING ״̬����D2 adam3q��
        call OMGAILog_LOG_DEBUG("BEH", "Jungle Think")
    endfunction

//---------------------------------------------------------------------------
// 3. Gank����6.3��
//    Desire ��������ս�����ż� / �䵥(1200 ����ѡ�1) / �ɼ� / 70% �������
//    Think��ASSEMBLE��ROAMING��Ŀ�궪ʧ5s����
//---------------------------------------------------------------------------

        public function OMGAI_DesireGank takes unit u returns real
        local unit target = OMGAICore_OMGAI_LoadUnitHandle(GetHandleId(u), 94)
        local real d = 0.0
        if target == null then
            return 0.0
        endif
        // ����ɱĿ�꣨FindKillTarget ���в�Ѫ+���������� ���� 0.7
        set d = 0.7
        // �䵥 + 0.2
        if OMGAITargetSel_OMGAI_IsLoneEnemy(target) then
            set d = d + 0.2
        endif
        // ������У�70%��
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
        // ���ڹ���Ŀ���򲻷�����������ϻ�ͼ AI��
        if GetUnitCurrentOrder(u) != OrderId("smart") then
            call IssueTargetOrder(u, "smart", target)
            call OMGAILog_LOG_WARN("GANK", "���� " + I2S(GetUnitTypeId(target)) + " hp%=" + R2S(GetUnitState(target, UNIT_STATE_LIFE) / GetUnitState(target, UNIT_STATE_MAX_LIFE)))
        endif
    endfunction

//---------------------------------------------------------------------------
// 4. ����/���أ���6.4��
//---------------------------------------------------------------------------

    public function OMGAI_DesirePush takes unit u returns real
        local real d = PUSH_BASE
        local real t = OMGAICore_OMGAI_GetGameTime() / 60.0
        // 12 ���Ӻ���ʱ����������
        if t > PUSH_TIME_START then
            set d = d + (t - PUSH_TIME_START) * 0.01
        endif
        // ��/��Ӫ/���ò�����Ӽ���TODO��
        if d > 0.8 then
            set d = 0.8
        endif
        return d
    endfunction

    public function OMGAI_ThinkPush takes unit u returns nothing
        // TODO: ���߼�Ȩ���ȡ���·��D2 GetCommonPushLaneDesires��
        call OMGAILog_LOG_DEBUG("BEH", "Push Think")
    endfunction

    public function OMGAI_DesireDefend takes unit u returns real
        // TODO: ������������ �� ��Ԯ�¼������� desire
        return 0.0
    endfunction

    public function OMGAI_ThinkDefend takes unit u returns nothing
        // TODO: DEFEND_Tower��ClearWave��Return ״̬����D1 aiDefTowerAttack��
        call OMGAILog_LOG_DEBUG("BEH", "Defend Think")
    endfunction

//---------------------------------------------------------------------------
// 5. ��ս����6.5��
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
        // ����ɫվλ��̹��(2)��ǰ / ��ս(1)�� / ��ʦ����(3/4)���� / ������
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
                // ̫Զ����Ŀ�꿿���� want ����
                call IssuePointOrder(u, "move", GetUnitX(target) + dx / dist * want, GetUnitY(target) + dy / dist * want)
            elseif dist < want - 200.0 and dist > 1.0 then
                // ̫����������
                call IssuePointOrder(u, "move", GetUnitX(u) + dx / dist * 250.0, GetUnitY(u) + dy / dist * 250.0)
            endif
            // ����
            if GetUnitCurrentOrder(u) != OrderId("smart") then
                call IssueTargetOrder(u, "smart", target)
            endif
        endif
        call OMGAILog_LOG_WARN("TEAM", "��սվλ role=" + I2S(role) + " want=" + R2S(want))
    endfunction

//---------------------------------------------------------------------------
// 6. ���ˣ���6.6��
//---------------------------------------------------------------------------

    public function OMGAI_DesireRetreat takes unit u returns real
        local real hpPct = 0.0
        set hpPct = GetUnitState(u, UNIT_STATE_LIFE) / GetUnitState(u, UNIT_STATE_MAX_LIFE)
        if hpPct < RETREAT_HP_PCT then
            return 1.0
        endif
        // TODO: �з���в top1 �� < 300 ���ҷ�Ѫ < 40%
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
        // �������ѻؼ����ظ�������
        if not UnitAlive(u) then
            return
        endif
        if GetUnitCurrentOrder(u) != OrderId("move") or OMGAICore_OMGAI_LoadInt(hid, 97) == 0 then
            call IssuePointOrder(u, "move", fx, fy)
            call OMGAILog_LOG_WARN("RETR", "��Ѫ���� hp%=" + R2S(GetUnitState(u, UNIT_STATE_LIFE) / GetUnitState(u, UNIT_STATE_MAX_LIFE)))
        endif
    endfunction

//---------------------------------------------------------------------------
// 7. ��Ұ/���ۣ���6.7��
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
        // �淴�ۣ����ȶ��� 92 ���������ʧЧ�򶵵�ɨ��
        set ward = OMGAICore_OMGAI_LoadUnitHandle(hid, 92)
        if ward == null or not UnitAlive(ward) or not IsUnitEnemy(ward, GetOwningPlayer(u)) then
            set ward = OMGAIStrategy_OMGAI_GetWardToDeWard(u)
        endif
        if ward != null then
            call IssueTargetOrder(u, "smart", ward)
            call OMGAILog_LOG_WARN("WARD", "���ۣ������з����� type=" + I2S(GetUnitTypeId(ward)))
        endif
        call OMGAILog_LOG_WARN("WARD", "��Ұ���ڣ�����/����Ѳ��")
    endfunction

//---------------------------------------------------------------------------
// 8. ����
//---------------------------------------------------------------------------


    public function OMGAI_BehaviorsInit takes nothing returns nothing
        call OMGAILog_LOG_INFO("BEH", "OMGAIBehaviors ��ʼ�����")
    endfunction

endlibrary
