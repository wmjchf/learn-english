# App Starter

从 [奏折 / collection-app](../collection-app) 工程框架剥离的起步模板：**Flutter App + Express/MySQL Backend + docs / `.cursor` 约定**。

已包含手机号验证码登录与空壳首页；不含收藏、AI、IAP、Chrome 扩展。

## 目录

```
app-starter/
├── app/          # Flutter
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
pnpm dev           # http://127.0.0.1:3001
```

健康检查：`GET /api/health`  
开发登录：任意 `1` 开头 11 位手机号，验证码默认 `123456`（`SMS_DEV_MODE=true`）。

## App

```bash
cd app
flutter pub get
flutter run
# 或指定后端：
# flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3001
```

## 改成你的产品

1. 替换文案：`app/lib/core/config/app_brand.dart`
2. 包名：`app/pubspec.yaml` 的 `name`、Dart import 前缀 `app_starter`
3. iOS/Android applicationId / bundle：`com.example.appstarter`
4. 数据库名：`backend/.env` → `MYSQL_DATABASE`
5. 更新 `docs/PRD.md` 与 `docs/技术实现.md`

## 约定

改代码后在 `docs/技术实现.md` §8 变更记录顶部追加一行（见 `.cursor/rules/tech-doc-changelog.mdc`）。
