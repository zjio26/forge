[English](README.md) | [中文](README_CN.md) | [日本語](README_JA.md) | [Español](README_ES.md)

# Forge

> Forge — a solid harness-engineered workflow for Claude Code. 用结构而非意志力逼出高质量代码。

![License](https://img.shields.io/github/license/zjio26/forge) ![GitHub stars](https://img.shields.io/github/stars/zjio26/forge?style=social)

```
┌─────────────────────────────────────────────────────────┐
│  $ /forge:forge 实现带限流的 API 网关，JWT 校验，Redis    │
│            令牌撤销，请求去重，Prometheus 指标             │
│                                                         │
│  🟦 Planning...      ✅ Plan complete                   │
│  🟩 Wave 1/3 Dev...  ✅ 12 unit tests passed            │
│  🟨 Wave 1/3 Test... ✅ PASS (unit: 12/12, int: 3/4)   │
│  🟩 Wave 2/3 Dev...  ✅ 8 unit tests passed             │
│  🟨 Wave 2/3 Test... ❌ 2 bugs → 🟩 Fix → ✅ PASS      │
│  🟩 Wave 3/3 Dev...  ✅ 6 unit tests passed             │
│  🟨 Wave 3/3 Test... ✅ PASS                            │
│  🟨 Integration...   ✅ Full integration PASS            │
│  🟪 Learning...      4 new lessons → knowledge.md       │
│                                                         │
│  Forge completed! 26/26 unit tests passed.              │
└─────────────────────────────────────────────────────────┘
```

---

## 原生 Claude Code 的痛，Forge 用结构来治

你肯定经历过这些：

- **写完代码不写测试** — 或者测试形同虚设。人类都偷懒，何况模型
- **上下文一长就漂移** — 干着干着忘了最初要做什么
- **Bug 改了又改** — 没有闭环验证，改了 A 坏了 B
- **同样的坑踩两次** — 上次踩过的雷下次照样踩
- **中途崩了全白干** — 没有断点恢复，从头再来

Forge 不靠"请仔细一点"这种废话。它把工程纪律焊进工作流：

| 机制 | 如何实现 |
|--------|----------|
| **闭环 Dev→Test→Fix** | Dev 写完必须过 Test，不过就 Fix，再不过再 Fix，最多三轮。结果只有 PASS/FAIL，没有"看起来还行" |
| **分波作战** | 大需求自动拆成 Wave，每波一对新 Dev+Test，上下文干净不溢出，波间交接靠 handoff 文件 |
| **经验积累** | Learner 每轮提取教训写入 knowledge.md，Planner 下次直接参考。越用越聪明，不踩重复的坑 |
| **崩溃恢复** | 每步 checkpoint 写入 state.json，断了重跑直接续上，一行代码不丢 |
| **先想后写** | Planner 遇到歧义先问你，确认了再动手。拒绝闷头写完发现方向全错 |
| **上下文隔离** | Coordinator 只管调度和路径，绝不读中间产物。上下文永远精简 |

## 架构

```
用户 ──"/forge 需求"──▶ Coordinator
                            │
                 ┌──────────┤
                 ▼          │
            🟦 Planner     │
            plan + waves   │
                 │          │
                 ▼          │
         ┌─── Wave Loop ──────────────────┐
         │                                │
         │  🟩 Dev W1 ──▶ 🟨 Test W1     │
         │       ▲              │         │
         │       │           FAIL?        │
         │       └── Fix ──────┘          │
         │       (same agent,             │
         │        context preserved)      │
         │              │                 │
         │            PASS ──▶ next wave  │
         │                                │
         └────────────────────────────────┘
                            │
                            ▼
                 🟨 Full Integration Test
                            │
                            ▼
                 🟪 Learner ──▶ 📚 knowledge.md
```

| Agent | Model | Role |
|-------|-------|------|
| Coordinator | — | 调度 Agent、追踪路径和状态 — 绝不读中间产物 |
| Planner | sonnet | 拆解需求、定义验收标准、发现歧义先问你 |
| Dev | sonnet | 实现功能、写单测、修 Bug — 只干计划内的事 |
| Test | haiku | 单测不过即 FAIL，集成尽力，Bug 报告精确 |
| Learner | haiku | 提取经验、去重去噪，最多 3 条/轮 |

---

## 设计宗旨：Harness Engineering

靠流程结构逼出质量，不靠模型自觉：

- **结构 > 意志** — 规则写进工作流，不写进提示词。如果一条规则无法被结构化执行，就重新设计流程
- **闭环 > 开环** — Dev→Test→Fix 是强制循环，结果只有 PASS/FAIL，没有"应该没问题"
- **隔离 > 膨胀** — Coordinator 只追踪路径和状态，不读内容；每波独立上下文
- **可恢复 > 可重试** — 每步存档，崩溃后从断点续跑，不是从头再来
- **只做被要求的** — 每一行改动必须追溯到计划或 Bug 修复，禁止夹带私货

---

## 五分钟上手

**前置条件**：[Claude Code CLI](https://docs.anthropics.com/en/docs/claude-code) 已安装。

**插件安装（推荐）：**

```
/plugin marketplace add zjio26/forge
/plugin install forge
```

**离线安装：**

```bash
git clone https://github.com/zjio26/forge.git && cd forge && bash install.sh
```

**开火：**

```
/forge:forge 实现带限流的 API 网关，JWT 校验，Redis 令牌撤销，请求去重，Prometheus 指标
```

> 插件模式用 `/forge:forge`，手动安装用 `/forge`。就这点区别。

---

## 使用示例

**造一个非平凡功能：**

> **你**：`/forge:forge 实现用户注册→登录→下单→支付的完整业务流，JWT 鉴权，库存锁定，超时自动释放`
>
> **Forge**：Planner 拆出 5 个子任务、3 个 Wave → Wave 1 建数据模型和鉴权 → Wave 2 搞下单和库存 → Wave 3 搞支付和超时 → 全链路集成测试 → Learner 提取 3 条教训

**带安全网的重构：**

> **你**：`/forge:forge 把数据库层重构为连接池，兼容现有所有调用方`
>
> **Forge**：Planner 识别受影响模块 → Dev 精准修改 → Test 跑全量单元 + 集成测试 → 有回归自动 Fix → 零人工介入

**崩了？续上：**

> **你**：`/forge:forge`（直接重跑同一条命令）
>
> **Forge**：读 state.json → 从上次断点续跑 → 不丢一行代码

---

## 目录结构

```
forge/
├── agents/                  # 专业 Agent 定义
│   ├── planner.md           # 需求分解 — sonnet，拆任务、定验收标准
│   ├── dev.md               # 实现 + 单测 + 修 Bug — sonnet，只干计划内的事
│   ├── test.md              # 测试验证 — haiku，单测不过即 FAIL
│   └── learner.md           # 经验提取 — haiku，去重去噪，最多 5 条/轮
├── skills/forge/
│   ├── SKILL.md             # Coordinator 调度器 — 只管路径和状态
│   └── knowledge.md         # 经验知识库 — Learner 自动更新
├── install.sh               # 离线安装脚本
└── CLAUDE.md                # 项目指引
```

运行时产物（目标项目 `.forge/` 目录，已 gitignore）：

```
.forge/
├── {slug}-plan.md              # 开发计划
├── {slug}-waves.json           # 波次分组
├── {slug}-dev-W{n}.md          # 波次开发记录
├── {slug}-test-W{n}.md         # 波次测试报告
├── {slug}-handoff-W{n}.md      # 波次交接文件
├── {slug}-test-integration.md  # 全链路集成测试报告
├── {slug}-state.json           # 状态断点（崩溃恢复用）
└── {slug}-metrics.json         # 运行指标
```

---

## 贡献与协议

PR 欢迎。Agent 定义和调度逻辑是核心，改之前先读 CLAUDE.md 的设计原则。

- 改 Agent 定义：每个文件要自包含，路径引用用 `.forge/`
- 改 SKILL.md：Coordinator 只跟踪路径和状态，不读内容
- 改 install.sh：同步更新源文件和目标路径的映射

[MIT License](LICENSE)
