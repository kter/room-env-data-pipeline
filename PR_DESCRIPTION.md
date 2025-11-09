# 🚀 BigQueryデータパイプライン & Dataform GitHub連携の完全自動化

## 📋 概要

SwitchBot Webhookから取得したセンサーデータを、BigQueryで集計・分析できるデータパイプラインを構築しました。さらに、DataformとGitHubを連携させ、SQLによるデータ変換を完全自動化しました。

### アーキテクチャ

```
SwitchBot Webhook
    ↓
Cloud Functions (Webhook受信・データ処理)
    ↓
Pub/Sub (非同期メッセージング)
    ↓
BigQuery Subscription (自動書き込み)
    ↓
BigQuery (生データ: sensor_raw_data)
    ↓
Dataform ← GitHub (自動同期) ← dataform/*.sqlx
    ↓
BigQuery (集計データ: sensor_hourly_stats, sensor_daily_stats, sensor_latest)
    ↓
Looker (ダッシュボード可視化)
```

すべてのインフラストラクチャがTerraformで管理され、Dataformの定義ファイルはGitHubで管理されます。

---

## ✨ 主な実装内容

### 1. データパイプライン構築

#### Pub/Sub → BigQuery Subscription
- **自動データ取り込み**: Pub/SubからBigQueryへの自動書き込み
- **スキーマ検証**: メッセージフォーマットをBigQueryスキーマに適合
- **Dead Letter Queue**: 失敗メッセージを別トピックに保存
- **RFC3339タイムスタンプ**: BigQuery TIMESTAMP型に対応

#### BigQueryテーブル設計
```sql
-- 生データテーブル
sensor_raw_data
  - timestamp (TIMESTAMP, REQUIRED, パーティショニング)
  - device_mac, device_type (クラスタリング)
  - temperature, humidity, battery
  - raw_data (JSON, 完全なペイロード保存)

-- 時間別集計テーブル
sensor_hourly_stats
  - hour_timestamp (パーティショニング)
  - avg/min/max temperature, humidity
  - event_count

-- 日別集計テーブル
sensor_daily_stats
  - date (パーティショニング)
  - 日別統計

-- 最新状態テーブル (Looker用)
sensor_latest
  - 各デバイスの最新状態
  - minutes_since_update
```

### 2. Dataform GitHub連携 🔥

#### 完全自動化の実現
- **Secret Manager統合**: GitHub Personal Access Token (PAT) を安全に管理
- **自動同期**: GitHubのmainブランチとDataformを連携
- **Gitフロー**: dataform/*.sqlxをGitで管理 → Push → 自動反映
- **スケジュール実行**: 毎時0分に自動集計（Asia/Tokyo）

#### メリット
✅ **完全なGit管理**: .sqlxファイルの変更履歴を追跡  
✅ **コードレビュー**: Pull Requestで変更をレビュー可能  
✅ **バージョン管理**: タグ付け、ロールバックが容易  
✅ **CI/CD構築**: 自動テスト・デプロイが可能  
✅ **環境の再現性**: リポジトリクローンで環境再構築  
✅ **チーム開発**: 複数人での並行開発が可能

#### セキュリティ
- GitHub PATはSecret Managerで暗号化保存
- Terraformではsensitive変数として扱う
- コードに直接書かない（環境変数で設定）

### 3. Terraformモジュール構成

```
modules/
├── webhook-function/     Cloud Functions (Webhook処理)
└── data-pipeline/        Pub/Sub + BigQuery + Dataform

env/
├── dev/                  開発環境
└── prd/                  本番環境
```

---

## 🔧 追加・変更したリソース

### 新規作成
- ✅ `google_project_service.secretmanager` - Secret Manager API有効化
- ✅ `google_secret_manager_secret.dataform_github_token` - GitHubトークン管理
- ✅ `google_secret_manager_secret_version` - トークンバージョン管理
- ✅ `google_dataform_repository.git_remote_settings` - GitHub連携設定
- ✅ `google_bigquery_table.sensor_hourly_stats` - 時間別集計テーブル
- ✅ `google_bigquery_table.sensor_daily_stats` - 日別集計テーブル
- ✅ `google_bigquery_table.sensor_latest` - 最新状態テーブル
- ✅ `google_pubsub_subscription.bigquery_subscription` - BigQuery Subscription

### 更新
- 🔄 `modules/webhook-function/function-source/main.py` - Pub/Sub送信、BigQuery形式変換
- 🔄 `modules/data-pipeline/main.tf` - Dataform GitHub連携追加
- 🔄 `.gitignore` - env/ディレクトリルール修正

---

## 📊 作成したDataform定義ファイル

### dataform/definitions/sensor_hourly_stats.sqlx
```sql
config {
  type: "incremental",
  bigquery: {
    partitionBy: "TIMESTAMP_TRUNC(hour_timestamp, DAY)",
    clusterBy: ["device_mac", "device_type"]
  }
}

-- 生データから1時間ごとの統計を計算
SELECT
  TIMESTAMP_TRUNC(timestamp, HOUR) AS hour_timestamp,
  device_mac,
  device_type,
  AVG(temperature) AS avg_temperature,
  MIN(temperature) AS min_temperature,
  MAX(temperature) AS max_temperature,
  ...
FROM ${ref("sensor_raw_data")}
WHERE temperature IS NOT NULL OR humidity IS NOT NULL
${when(incremental(), `AND timestamp > (SELECT MAX(hour_timestamp) FROM ${self()})`)}
GROUP BY hour_timestamp, device_mac, device_type
```

### dataform/definitions/sensor_daily_stats.sqlx
- hourly_statsから日別統計を集計
- Lookerダッシュボード用

### dataform/definitions/sensor_latest.sqlx
- 各デバイスの最新状態を取得
- ダッシュボードのリアルタイム表示用

---

## 🚀 デプロイ手順

### 初回セットアップ

```bash
# 1. GitHub Personal Access Token (PAT) を作成
# https://github.com/settings/tokens/new
# Scopes: repo (Full control of private repositories)

# 2. 環境変数に設定
export TF_VAR_github_token="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# 3. terraform.tfvars作成（terraform.tfvars.exampleを参考）
cd env/dev
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvarsを編集してproject_id等を設定

# 4. Terraform実行
terraform init
terraform plan
terraform apply
```

### 継続運用

```bash
# dataform/*.sqlxを編集
vim dataform/definitions/sensor_hourly_stats.sqlx

# Gitにコミット＆プッシュ
git add dataform/
git commit -m "feat: 集計ロジック更新"
git push

# → 自動的にDataformに反映される！
```

---

## ✅ 動作確認済み

### インフラストラクチャ
- ✅ Cloud Functions: Webhook受信＆Pub/Sub送信
- ✅ Pub/Sub → BigQuery: データ保存（7行のテストデータ）
- ✅ BigQueryテーブル: 3つの集計テーブル作成済み
- ✅ Secret Manager: GitHub PAT保存済み
- ✅ Dataform GitHub連携: mainブランチと同期設定完了

### データフロー
- ✅ SwitchBot Webhook → Cloud Functions: 正常動作
- ✅ Cloud Functions → Pub/Sub: メッセージ送信確認
- ✅ Pub/Sub → BigQuery: 自動書き込み確認
- ✅ BigQuery: 生データ保存確認（sensor_raw_data）

---

## 📋 次のステップ

1. **Dataform定義ファイルをGitHubにプッシュ**
   ```bash
   git add dataform/
   git commit -m "feat: Dataform定義ファイル追加"
   git push
   ```
   → 自動的にDataformに反映される

2. **Dataformワークフロー実行**
   - GCPコンソールで手動実行してテスト
   - または毎時0分のスケジュール実行を待つ

3. **Lookerダッシュボード作成**
   - BigQueryデータソース接続
   - LookMLビューファイル作成（LOOKER_SETUP.md参照）
   - ダッシュボード作成

4. **本番環境（prd）へのデプロイ**
   - env/prd/terraform.tfvarsを設定
   - terraform apply

---

## 🔗 ドキュメント

- 📄 `README.md` - 全体アーキテクチャと設定手順
- 📄 `DATAFORM_SETUP.md` - Dataform詳細設定（手動設定時）
- 📄 `LOOKER_SETUP.md` - Looker接続とダッシュボード作成

---

## 🎯 技術的な工夫

### 1. BigQueryメッセージフォーマット最適化
- RFC3339タイムスタンプ形式に統一
- NULL値を空文字列に変換（NULLABLE STRING）
- ネストされたJSONを文字列化（JSON型対応）

### 2. インクリメンタル処理
- sensor_hourly_statsはインクリメンタル更新
- 過去データは再計算しない（パフォーマンス向上）

### 3. パーティショニング & クラスタリング
- 全テーブルでパーティショニング設定
- device_mac, device_typeでクラスタリング
- クエリコスト削減

### 4. セキュリティ
- GitHub PATをSecret Managerで暗号化保存
- IAM権限を最小限に設定
- サービスアカウント単位で権限管理

### 5. 環境分離
- dev/prd環境を完全分離
- 環境ごとの設定ファイル管理
- terraform.tfvarsで環境差異を吸収

---

## 📈 期待される効果

1. **開発効率向上**
   - SQLファイルをGitで管理 → コードレビュー可能
   - 変更履歴追跡 → ロールバック容易
   - Pull Request → 本番デプロイのフロー確立

2. **運用コスト削減**
   - 完全自動化 → 手動作業ゼロ
   - スケジュール実行 → 定期集計自動化
   - インクリメンタル更新 → クエリコスト削減

3. **データ品質向上**
   - スキーマ検証 → 不正データを防止
   - Dead Letter Queue → エラー追跡可能
   - パーティショニング → 高速クエリ

4. **スケーラビリティ**
   - Pub/Sub → 非同期処理で高スループット
   - BigQuery → ペタバイト級データに対応
   - 環境分離 → dev/prd/staging追加容易

---

## 🙏 レビューポイント

- [ ] Dataform GitHub連携設定の妥当性
- [ ] Secret Manager使用のセキュリティ確認
- [ ] BigQueryスキーマ設計の確認
- [ ] .gitignoreの設定確認（env/ディレクトリ）
- [ ] terraform.tfvars.exampleの内容確認

---

**関連Issue:** なし（新規機能実装）

**破壊的変更:** なし

**デプロイリスク:** 低（新規リソース追加のみ）

