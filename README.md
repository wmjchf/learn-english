# 词成文

把我的词，变成我的故事。Flutter App + Express / MySQL 后端。用户选词库、做水平测评、确认学习计划后，由 LLM 按画像生成每日短文（目标词高亮、复习词下划线），读完做闭眼回填，生词进入间隔复习。

产品规则见 `docs/PRD.md`，接口与数据模型见 `docs/技术实现.md`。

## 目录

```
english-learn/
├── app/          # Flutter（iOS / Android）
├── backend/      # Express + MySQL
├── docs/         # PRD / 技术实现
└── .cursor/rules/
```

## 后端

```bash
cd backend
nvm use            # Node 23.6.0
pnpm install
cp .env.example .env
pnpm db:init
pnpm db:migrate
pnpm db:seed-words # 把词条灌进 bank_words（抽词/释义查库）
pnpm dev           # http://127.0.0.1:3001
```

`.env` 里填 MySQL，以及 `DASHSCOPE_API_KEY`（日课正文生成走百炼）。  
真词库在表 **`bank_words`**（lemma / gloss / bank_code）；`bankWordPools.js` 只是灌库种子。

健康检查：`GET /api/health`  
开发登录：任意 `1` 开头 11 位手机号，验证码默认 `123456`（`SMS_DEV_MODE=true`）。

主要接口：`/api/auth`、`/api/catalog`、`/api/assess`、`/api/plans`、`/api/lessons`、`/api/words`、`/api/today`、`/api/streak`、`/api/me`。

## App

```bash
cd app
flutter pub get
flutter run
# 连本地后端（默认）：
# flutter run --dart-define=API_ENV=local
# 连测试服 http://47.97.67.47:3003 ：
# flutter run --dart-define=API_ENV=test
# 或任意地址：
# flutter run --dart-define=API_BASE_URL=http://47.97.67.47:3003
```

底部四个 Tab：今日、文章库、生词本、我的。阅读与闭眼回填从今日或文章库进入，不占 Tab。

## 学习闭环

```
登录 → 兴趣 / 场景 / 职业 → CEFR 测评 → 选词库 → 确认计划
  → 今日日课（AI 生成：短文 + 对话 + 8 道闭眼回填）
  → 点词查义 / 标记生词 → 完课推进词库指针
  → 错词与到期词进入 SRS，下次生成时作为复习词写进文章
  → 今日打卡连胜
```

日课只走模型生成，不从公共池或种子文出题。已落库的旧日课不会因改生成参数而重写；要新题数或新文案，换一篇或等到下一天。

## 约定

改代码后在 `docs/技术实现.md` 变更记录顶部追加一行（见 `.cursor/rules/tech-doc-changelog.mdc`）。  
iOS/Android 包名：`com.bufang.learnenglish`；Dart 包名暂仍 `app_starter`；产品文案在 `app/lib/core/config/app_brand.dart`。
