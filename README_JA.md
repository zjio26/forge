[English](README.md) | [中文](README_CN.md) | [日本語](README_JA.md) | [Español](README_ES.md)

# Forge

> Forge — a solid harness-engineered workflow for Claude Code. 構造が品質を強制する。プロンプトの自制心に頼らない。

![License](https://img.shields.io/github/license/zjio26/forge) ![GitHub stars](https://img.shields.io/github/stars/zjio26/forge?style=social)

```
┌─────────────────────────────────────────────────────────┐
│  $ /forge:forge Build a rate-limited API gateway with    │
│            JWT auth, Redis token revocation, request     │
│            dedup, and Prometheus metrics                 │
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

## 通常のClaude Codeでは問題がある — Forgeは構造的に解決する

こういう経験、ありませんか：

- **テストのないコード** — あるいは名目上だけのテスト。人間がテストをスキップするなら、モデルも同じ
- **コンテキストの逸脱** — タスクの途中で、最初の目的を忘れてしまう
- **Aを直してBを壊す** — 閉ループ検証がないため、バグが連鎖する
- **毎回同じ過ち** — 過去の失敗から何も学習しない
- **クラッシュ＝最初からやり直し** — checkpointも復旧もなく、作業が全部消える

Forgeはモデルに「気をつけて」と頼むのではなく、工学的規律をワークフローに組み込む：

| 能力 | 仕組み |
|------|--------|
| **閉ループ Dev→Test→Fix** | DevはTestを通過しなければならない。失敗？修正。また失敗？再修正、最大3ラウンド。判定はPASS/FAIL — 「まあ大丈夫」は不可 |
| **Waveベースのスケーリング** | 大きな要件は自動的にWaveに分割。各Waveに独立したDev+Testペアを割り当て。Wave間のhandoffはhandoffファイル経由 |
| **経験の蓄積** | Learnerが教訓をknowledge.mdに抽出。Plannerが次回参照。実行するたびに賢くなる |
| **クラッシュ復旧** | 各ステップでcheckpointをstate.jsonに書き込み。同じコマンドを再実行すれば、中断地点から再開。一行も失われない |
| **コードの前に思考** | Plannerが曖昧さを発見し、まずあなたに確認。一時間も間違った方向にコーディングすることがなくなる |
| **コンテキストの隔離** | Coordinatorはパスとステータスのみ追跡 — 中間内容は一切読み込まない。コンテキストは常に軽量 |

## アーキテクチャ

```
User ──"/forge requirement"──▶ Coordinator
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

| エージェント | モデル | 役割 |
|-------------|--------|------|
| Coordinator | — | エージェントをディスパッチ、パスとステータスを追跡 — 中間内容は一切読み込まない |
| Planner | sonnet | 要件を分解、受け入れ基準を定義、曖昧さを表面化 |
| Dev | sonnet | 機能を実装、ユニットテストを記述、バグを修正 — プランにあることのみ |
| Test | haiku | ユニットテストは必須合格、インテグレーションテストはベストエフォート、バグレポートは的確に |
| Learner | haiku | 教訓を抽出、重複排除、1回あたり最大5件 |

---

## 設計哲学：Harness Engineering

モデルの自制心ではなく、構造的制約で品質を保証する：

- **構造 > 意志** — ルールはプロンプトではなくワークフローに組み込む。構造的に強制できないルールなら、ワークフローを再設計する
- **閉ループ > 開ループ** — Dev→Test→Fixは必須。判定はPASS/FAILのみ、「たぶん大丈夫」は不可
- **隔離 > 肥大化** — Coordinatorはパスとステータスのみ追跡、内容は読まない。各Waveは独立したコンテキストを持つ
- **復旧可能 > 再試行可能** — 各ステップでstate checkpointを記録。クラッシュ後は中断点から再開、最初からやり直さない
- **頼まれたことだけ** — 変更された各行はプランまたはバグ修正まで遡れる。余計な追加も、投機的な改善もしない

---

## 5分クイックスタート

**前提条件**: [Claude Code CLI](https://docs.anthropics.com/en/docs/claude-code) がインストールされていること。

**プラグインインストール（推奨）:**

```
/plugin marketplace add zjio26/forge
/plugin install forge@forge
```

**オフラインインストール:**

```bash
git clone https://github.com/zjio26/forge.git && cd forge && bash install.sh
```

**実行:**

```
/forge:forge Build a rate-limited API gateway with JWT auth, Redis token revocation, request dedup, and Prometheus metrics
```

> プラグインモードでは`/forge:forge`、手動インストールでは`/forge`を使います。これが唯一の違いです。

---

## 使用例

**本格的な機能を構築する:**

> **あなた**: `/forge:forge Implement a full user registration→login→order→payment flow with JWT auth, inventory locking, and timeout auto-release`
>
> **Forge**: Plannerが5つのサブタスクに分解、3つのWaveにグループ化 → Wave 1でデータモデルと認証を構築 → Wave 2で注文と在庫を処理 → Wave 3で決済とタイムアウトを処理 → フルインテグレーションテスト → Learnerが3つの教訓を抽出

**セーフティネット付きでリファクタリング:**

> **あなた**: `/forge:forge Refactor the database layer to use connection pooling, compatible with all existing callers`
>
> **Forge**: Plannerが影響を受けるモジュールを特定 → Devが的確に変更 → Testがユニット＋インテグレーションの全テストスイートを実行 → 自動Fixでリグレッションを検出 → 手動介入なし

**クラッシュした？再開:**

> **あなた**: `/forge:forge`（同じコマンドを再実行するだけ）
>
> **Forge**: state.jsonを読み込み → 最後のcheckpointから再開 → 一行も失われない

---

## プロジェクト構成

```
forge/
├── agents/                  # Specialized agent definitions
│   ├── planner.md           # Requirement decomposition — sonnet, defines acceptance criteria
│   ├── dev.md               # Implementation + unit tests + bug fixes — sonnet, only planned work
│   ├── test.md              # Test verification — haiku, unit test fail = FAIL
│   └── learner.md           # Experience extraction — haiku, dedup, max 5 per run
├── skills/forge/
│   ├── SKILL.md             # Coordinator orchestrator — tracks paths and status only
│   └── knowledge.md         # Experience knowledge base — auto-updated by Learner
├── install.sh               # Offline installer
└── CLAUDE.md                # Project instructions
```

ランタイム成果物（ターゲットプロジェクトの`.forge/`ディレクトリ、gitignore対象）:

```
.forge/
├── {slug}-plan.md              # Development plan
├── {slug}-waves.json           # Wave grouping
├── {slug}-dev-W{n}.md          # Wave dev record
├── {slug}-test-W{n}.md         # Wave test report
├── {slug}-handoff-W{n}.md      # Wave handoff file
├── {slug}-test-integration.md  # Full integration test report
├── {slug}-state.json           # State checkpoint (crash recovery)
└── {slug}-metrics.json         # Runtime metrics
```

---

## コントリビュート & ライセンス

PRは歓迎します。エージェント定義とオーケストレーションロジックがコア — 変更前にCLAUDE.mdの設計原則をお読みください。

- エージェント定義の変更: 各ファイルは自己完結している必要がある。パス参照には`.forge/`を使用
- SKILL.mdの変更: Coordinatorはパスとステータスのみ追跡、内容は読み込まない
- install.shの変更: ソースからターゲットへのパスマッピングを同期させること

[MIT License](LICENSE)