// ===========================================================================
// OMGAIStateCleaner.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 状态清理器（架构预防竞品踩坑）
// 技术方案 T03 / PRD 4.4 借鉴竞品 -fixskill/-fixstun/-fixstate 等坑
// ---------------------------------------------------------------------------
// 设计原则：
//   * 竞品用修复命令兜底，说明运行时难根治
//   * 本模块在架构层通过"主动清理 + 周期巡检 + buff 来源校验"
//     让问题不发生而非发生后修复
// 功能：
//   * CleanForSkillRemoval(u, rawCode): 移除技能前清理关联 buff
//   * PeriodicSweep(): 主心跳周期调用，扫描异常状态
//   * 注册到 OMGAI_EVT_UNIT_TRANSFORM/Illusion 守卫
// ===========================================================================
library OMGAIStateCleaner initializer Init requires OMGAIConfig, OMGAIEventDispatcher, OMGAILogger

    // ---- buff 来源映射表（技能 rawcode -> buff rawcode 数组）---------
    // 简化版：先用空表，T03 后续填实际数据
    globals
        // 每个技能最多关联 4 个 buff，平铺数组
        // (rawCode, slot) -> buff rawCode
        integer array SC_SkillToBuff_Mapping
    endglobals

    // 移除技能前调用：清理该技能相关的所有 buff
    public function CleanForSkillRemoval takes unit u, integer skillRawCode returns nothing
        // 占位实现：扫描单位 buff 移除常见负面状态（眩晕/缠绕/恐惧等）
        // 使用 UnitRemoveAbility 直接移除 buff rawcode
        // 真实实现需基于 vcccv 物编实际 buff ID
        call OMGAILogger_D("StateClr", "CleanForSkillRemoval: rawCode=" + I2S(skillRawCode))
    endfunction

    // 周期巡检（TimerService 调用）
    public function PeriodicSweep takes nothing returns nothing
        // TODO: 扫描所有玩家+AI 单位，检测异常 buff，预防 -fixstun/-fixstate 坑
    endfunction

    // 注册变身/分身守卫
    public function Init takes nothing returns nothing
        // 监听变身事件→记录模型快照
        // 监听分身事件→同步属性/头像
        call OMGAILogger_I("StateClr", "Init done")
    endfunction

endlibrary