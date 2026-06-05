# RallyHub

社会人サークル向けイベント管理 iOS アプリ（SwiftUI + Firebase）。

## セットアップ

1. Firebase Console（プロジェクト: `rallyos`）で iOS アプリ `com.take.RallyHub` を追加
2. `GoogleService-Info.plist` をダウンロードし `RallyHub/RallyHub/` に配置（既存ファイルを上書き）
3. Xcode で `RallyHub.xcodeproj` を開きビルド

## Firestore ルール

RallyHub / RallyMate / RallyMatch は Firebase プロジェクト **rallyos** を共有しています。  
ルール未デプロイだとログイン後に `Missing or insufficient permissions` が出ます。

```bash
cd ../RallyMatch
firebase deploy --only firestore:rules
```

`RallyMatch/firestore.rules` に全アプリ分のルールを統合済みです。

## コレクション

| コレクション | 説明 |
|---|---|
| `users` | ユーザー情報（`fcmTokens` 含む） |
| `circles` | サークル |
| `circleMembers` | サークルメンバー（ドキュメント ID: `{circleId}_{userId}`） |
| `events` | イベント |
| `eventParticipants` | 出欠（ドキュメント ID: `{eventId}_{userId}`） |
| `eventVisitors` | Visitor |
| `announcements` | お知らせ |

## MVP 機能

- ユーザー登録 / ログイン / ログアウト
- サークル作成・一覧・招待コード参加
- イベント作成・定期一括作成・一覧・詳細
- 出欠登録・人数集計・満員判定
- Visitor 追加
- お知らせ投稿・一覧
- イベント詳細から「試合生成へ」（RallyMatch 連携準備）

## アーキテクチャ

```
Views → ViewModels → Repositories → Firestore
                ↘ AuthService → Firebase Auth
```

## Push 通知（後続）

Cloud Functions で以下を監視する想定:

- `events.isFull`: `false → true` で満員通知、`true → false` で空き通知
- `announcements` 新規作成でお知らせ通知

アプリ側は `users.fcmTokens` の保存 API（`AuthService.saveFCMToken`）を用意済みです。
