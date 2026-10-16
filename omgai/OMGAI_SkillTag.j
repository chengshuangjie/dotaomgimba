// ===========================================================================
// OMGAISkillTag.j
// ---------------------------------------------------------------------------
// DOTA1 OMG AI 地图 - 技能标签枚举与位掩码
// 技术方案 T02 技能系统 / PRD 4.3.2 SkillDef AI 标签字段
// ---------------------------------------------------------------------------
// 用途：
//   * 为每个技能打标签，AI 运行时读取标签生成 SkillProfile
//   * SkillDef.tags 用位掩码 OR 组合多个标签
//   * 例：标签 = STAG_BURST_HIGH or STAG_CONTROL_STUN or STAG_PASSIVE
// 设计：
//   * 用全局整数常量代替 enum（vJASS enum 走 array 不便 OR）
//   * 每个标签是 2 的整数次幂，最多 32 位
// ===========================================================================
library OMGAISkillTag requires OMGAIConfig

    globals
        // ---- 伤害维度标签（位掩码）-------------------------------------
        constant integer STAG_DMG_PHYSICAL = 0x00000001   // 1
        constant integer STAG_DMG_MAGICAL  = 0x00000002   // 2
        constant integer STAG_DMG_PURE      = 0x00000004   // 4
        constant integer STAG_BURST_HIGH   = 0x00000008   // 8  爆发高分
        constant integer STAG_SUSTAIN_HIGH = 0x00000010   // 16 持续输出高分

        // ---- 控制维度标签 -----------------------------------------------
        constant integer STAG_CTRL_STUN     = 0x00000020   // 32  眩晕
        constant integer STAG_CTRL_SLOW     = 0x00000040   // 64  减速
        constant integer STAG_CTRL_SILENCE  = 0x00000080   // 128 沉默
        constant integer STAG_CTRL_ROOT     = 0x00000100   // 256 缠绕
        constant integer STAG_CTRL_DISARM  = 0x00000200   // 512 缴械
        constant integer STAG_CTRL_FEAR     = 0x00000400   // 1024 恐惧

        // ---- 续航/生存标签 ----------------------------------------------
        constant integer STAG_HEAL         = 0x00000800   // 2048 治疗
        constant integer STAG_SHIELD      = 0x00001000   // 4096 护盾
        constant integer STAG_LIFESTEAL    = 0x00002000   // 8192 吸血
        constant integer STAG_DURABILITY    = 0x00004000   // 16384 坦克倾向

        // ---- 机动性标签 -------------------------------------------------
        constant integer STAG_DASH         = 0x00008000   // 32768 短距位移
        constant integer STAG_BLINK        = 0x00010000   // 65536 瞬移
        constant integer STAG_ESCAPE       = 0x00020000   // 131072 撤离技能

        // ---- 技能类型标签 -----------------------------------------------
        constant integer STAG_PASSIVE     = 0x00040000   // 被动
        constant integer STAG_TRANSFORM   = 0x00080000   // 变身（守卫触发）
        constant integer STAG_ORB_EFFECT  = 0x00100000   // 法球/攻击特效
        constant integer STAG_AOE          = 0x00200000   // 范围效果
        constant integer STAG_SUMMON  = 0x00400000   // 召唤
        constant integer STAG_AURA          = 0x00800000   // 光环
        constant integer STAG_ULTIMATE      = 0x01000000   // 大招
        constant integer STAG_TOGGLE       = 0x02000000   // 切换型技能（守卫触发）

        // ---- 射程分类（不是位掩码，单独用枚举值）------------------------
        constant integer SRANGE_MELEE  = 1
        constant integer SRANGE_SHORT  = 2   // 300-500
        constant integer SRANGE_LONG   = 3   // 500-800
        constant integer SRANGE_GLOBAL = 4   // 全图

        // ---- 冷却档位 ---------------------------------------------------
        constant integer SCOOLDOWN_NONE   = 0   // 被动/无 CD
        constant integer SCOOLDOWN_SHORT  = 1   // <8s
        constant integer SCOOLDOWN_MID    = 2   // 8-20s
        constant integer SCOOLDOWN_LONG   = 3   // 20-60s
        constant integer SCOOLDOWN_HUGE    = 4   // >60s 大招级
    endglobals

    // 工具函数：测试 SkillDef.tags 是否包含某标签
    public function HasTag takes integer tags, integer testTag returns boolean
        return not (tags - (tags / testTag) * testTag == 0) // 等价于 (tags & testTag) != 0，vJASS 位运算写法
    endfunction

endlibrary