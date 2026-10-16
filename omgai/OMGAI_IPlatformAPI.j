// ===========================================================================
// OMGAIIPlatformAPI.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 平台抽象接口
// 技术方案 T03 / PRD 5.4 跨平台降级
// ---------------------------------------------------------------------------
// 设计：
//   * 业务代码只依赖 IPlatformAPI 全局函数（不直接调 DzAPI_*）
//   * KKPlatformAPI.j 注册 KK 完整版（存档+商城+付费）
//   * Platform11API.j 注册 11 降级版（免费无限转）
//   * 通过 Install 设置 IPlatformAPI_Active 切换实现
//   * 注意：YDWE jasshelper 不支持 code 变量点语法（.execute/.evaluate），
//     故不使用函数指针，改为平台状态变量 + 库内实现分支
// ===========================================================================
library OMGAIIPlatformAPI requires OMGAIConfig, OMGAIGlobals, OMGAILogger

    // ---- 平台状态（Install 时设置）------------------------------------
    globals
        integer IPlatformAPI_Active = 0   // 0=未激活 1=KK 2=11
    endglobals

    // ================= KK 实现（完整商业化） =================
    private function KKIsCommercialImpl takes nothing returns integer
        return 1
    endfunction

    private function KKGetVoucherImpl takes integer playerId returns integer
        local string val = DzAPI_Map_GetServerString(Player(playerId - 1), OMGAI_VOUCHER_ITEM_KEY)
        if val == null or val == "" then
            return 0
        endif
        return S2I(val)
    endfunction

    private function KKConsumeVoucherImpl takes integer playerId, integer count returns integer
        local integer current = KKGetVoucherImpl(playerId)
        if current < count then
            return 0
        endif
        set current = current - count
        call DzAPI_Map_SaveServerString(Player(playerId - 1), OMGAI_VOUCHER_ITEM_KEY, I2S(current))
        return 1
    endfunction

    private function KKQuickBuyImpl takes integer playerId, string itemKey, integer count returns integer
        call DzAPI_Map_QuickBuy(Player(playerId - 1), itemKey)
        return 1
    endfunction

    private function KKSaveDataImpl takes integer playerId, string key, string value returns nothing
        call DzAPI_Map_SaveServerString(Player(playerId - 1), key, value)
    endfunction

    private function KKLoadDataImpl takes integer playerId, string key returns string
        return DzAPI_Map_GetServerString(Player(playerId - 1), key)
    endfunction

    // ================= 11 平台实现（免费降级） =================
    private function P11IsCommercialImpl takes nothing returns integer
        return 0
    endfunction

    private function P11GetVoucherImpl takes integer playerId returns integer
        return 999999
    endfunction

    private function P11ConsumeVoucherImpl takes integer playerId, integer count returns integer
        return 1
    endfunction

    private function P11QuickBuyImpl takes integer playerId, string itemKey, integer count returns integer
        return 0
    endfunction

    private function P11SaveDataImpl takes integer playerId, string key, string value returns nothing
        // 11 平台无服务器存档，用 Preload 本地存档兜底（T03 后续）
    endfunction

    private function P11LoadDataImpl takes integer playerId, string key returns string
        return ""
    endfunction

    // ---- 对外接口（业务代码用）-------------------------------------
    public function IsCommercialEnabled takes nothing returns boolean
        if IPlatformAPI_Active == 1 then
            return KKIsCommercialImpl() == 1
        endif
        return false
    endfunction

    public function GetVoucherBalance takes integer playerId returns integer
        if IPlatformAPI_Active == 1 then
            return KKGetVoucherImpl(playerId)
        elseif IPlatformAPI_Active == 2 then
            return P11GetVoucherImpl(playerId)
        endif
        return 0
    endfunction

    public function ConsumeVoucher takes integer playerId, integer count returns boolean
        if IPlatformAPI_Active == 1 then
            return KKConsumeVoucherImpl(playerId, count) == 1
        elseif IPlatformAPI_Active == 2 then
            return P11ConsumeVoucherImpl(playerId, count) == 1
        endif
        return false
    endfunction

    public function QuickBuy takes integer playerId, string itemKey, integer count returns boolean
        if IPlatformAPI_Active == 1 then
            return KKQuickBuyImpl(playerId, itemKey, count) == 1
        elseif IPlatformAPI_Active == 2 then
            return P11QuickBuyImpl(playerId, itemKey, count) == 1
        endif
        return false
    endfunction

    public function SaveServerData takes integer playerId, string key, string value returns nothing
        if IPlatformAPI_Active == 1 then
            call KKSaveDataImpl(playerId, key, value)
        elseif IPlatformAPI_Active == 2 then
            call P11SaveDataImpl(playerId, key, value)
        endif
    endfunction

    public function LoadServerData takes integer playerId, string key returns string
        if IPlatformAPI_Active == 1 then
            return KKLoadDataImpl(playerId, key)
        elseif IPlatformAPI_Active == 2 then
            return P11LoadDataImpl(playerId, key)
        endif
        return ""
    endfunction

endlibrary
