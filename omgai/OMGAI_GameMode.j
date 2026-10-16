// ===========================================================================
// OMGAIGameMode.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 模式与命令入口
// 技术方案 T03' / PRD 4.5 外观定制借鉴竞品命令
// ---------------------------------------------------------------------------
// 借鉴竞品机制（PRD 4.4.5）：
//   * -omgai 启动 OMG AI 模式（替代 -nengap）
//   * -cg X 设置 AI 难度（X=1-1000，借鉴竞品 -cg X 机制，T05 阶段实现）
//   * -neng 切回正常 AI（无加成）
//   * -tx X 设置武器/身体特效（外观定制，P1 级）
//   * -cb X 设置翅膀外观（P1 级）
//   * -fixskill/-fixstun 等修复命令：本项目架构预防不提供（PRD 4.4.1）
// ---------------------------------------------------------------------------
// 简化实现：先做基础模式开关，命令解析复用 vcccv 已有 ChatCommands 系统
// ===========================================================================
library OMGAIGameMode initializer OnInit requires OMGAIConfig, OMGAIEventDispatcher, OMGAILogger

    globals
        // 模式开关（玩家输入 -omgai 后启用）
        boolean OMGAI_ModeEnabled = false
        // AI 难度（默认 100）
        integer OMGAI_AIDifficulty = 100
        // AI 难度调节（0=无加成，1-1000=动态经验金钱加成）
        boolean OMGAI_AIDifficultyEnabled = true
    endglobals

    // ---- 模式启动 ------------------------------------------------------
    public function EnableMode takes nothing returns nothing
        set OMGAI_ModeEnabled = true
        call OMGAILogger_I("GameMode", "OMGAI mode enabled")
    endfunction

    public function DisableMode takes nothing returns nothing
        set OMGAI_ModeEnabled = false
        call OMGAILogger_I("GameMode", "OMGAI mode disabled")
    endfunction

    // ---- AI 难度调节（P1，借鉴竞品 -cg X）---------------------------
    public function SetAIDifficulty takes integer difficulty returns nothing
        if difficulty < 1 then
            set difficulty = 1
        elseif difficulty > 1000 then
            set difficulty = 1000
        endif
        set OMGAI_AIDifficulty = difficulty
        call OMGAILogger_I("GameMode", "AI difficulty set to " + I2S(difficulty))
    endfunction

    // ---- 模块初始化 ---------------------------------------------------
    private function OnInit takes nothing returns nothing
        // 默认启用 OMGAI 模式（实际工程中可由玩家输入 -omgai 切换）
        set OMGAI_ModeEnabled = true
        call OMGAILogger_I("GameMode", "Init done (mode=enabled, AI difficulty=100)")
    endfunction

endlibrary