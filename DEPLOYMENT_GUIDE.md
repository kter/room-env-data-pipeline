# 本番環境デプロイガイド

## 🎯 概要

このガイドでは、開発環境（develop）から本番環境（main）へのデプロイ手順を説明します。

---

## 📊 環境とブランチの対応

| 環境 | Gitブランチ | Dataform同期ブランチ | プロジェクトID | BigQueryデータセット |
|------|-----------|---------------------|---------------|-------------------|
| **dev** | `develop` | `develop` | `room-env-data-pipeline-dev` | `dev_sensor_data` |
| **prd** | `main` | `main` | `room-env-data-pipeline` | `prd_sensor_data` |

---

## 🚀 デプロイフロー

```
1. develop ブランチで開発・テスト
    ↓
2. Pull Request (develop → main)
    ↓
3. レビュー & 承認
    ↓
4. main ブランチにマージ
    ↓
5. dataform.json を prd 用に更新
    ↓
6. 本番環境に Terraform apply
    ↓
7. Dataform 自動実行 (hourly)
```

---

## 📝 デプロイ手順

### Step 1: develop ブランチで動作確認

```bash
# dev環境でDataformが正常に動作していることを確認
cd env/dev
terraform output
```

**確認項目**:
- ✅ Cloud Functions が正常に動作
- ✅ Pub/Sub → BigQuery へのデータ取り込みが成功
- ✅ Dataform が定期実行されている
- ✅ 集計テーブルにデータが入っている

---

### Step 2: Pull Request 作成

```bash
# GitHub でPull Requestを作成
# https://github.com/kter/room-env-data-pipeline/compare/main...develop
```

**PRの確認事項**:
- [ ] すべてのテストが成功
- [ ] Dataform定義が正しく動作
- [ ] Terraform planが正常
- [ ] ドキュメントが更新されている

---

### Step 3: main ブランチにマージ

```bash
git checkout main
git pull origin main
git merge develop
```

---

### Step 4: dataform.json を prd 用に更新

**重要**: mainブランチにマージ後、`dataform.json`を本番環境用に更新します。

```bash
# mainブランチで編集
git checkout main
```

`dataform.json` を以下のように変更：

```json
{
  "warehouse": "bigquery",
  "defaultSchema": "prd_sensor_data",
  "assertionSchema": "prd_dataform_assertions",
  "defaultDatabase": "room-env-data-pipeline",
  "defaultLocation": "asia-northeast1"
}
```

**変更点**:
- `defaultSchema`: `dev_sensor_data` → `prd_sensor_data`
- `assertionSchema`: `dev_dataform_assertions` → `prd_dataform_assertions`
- `defaultDatabase`: `room-env-data-pipeline-dev` → `room-env-data-pipeline`

```bash
# 変更をコミット
git add dataform.json
git commit -m "chore: dataform.jsonを本番環境用に更新"
git push origin main
```

---

### Step 5: 本番環境の GCP プロジェクトを準備

#### 5-1. 請求先アカウントの設定

```bash
gcloud config set project room-env-data-pipeline
gcloud beta billing projects link room-env-data-pipeline \
  --billing-account=YOUR_BILLING_ACCOUNT_ID
```

#### 5-2. 必要な API を有効化

```bash
gcloud services enable \
  cloudfunctions.googleapis.com \
  cloudresourcemanager.googleapis.com \
  storage.googleapis.com \
  iam.googleapis.com \
  cloudbuild.googleapis.com \
  pubsub.googleapis.com \
  bigquery.googleapis.com \
  dataform.googleapis.com \
  secretmanager.googleapis.com \
  --project=room-env-data-pipeline
```

---

### Step 6: 本番環境に Terraform でインフラをデプロイ

```bash
cd env/prd

# terraform.tfvars が存在するか確認
ls -la terraform.tfvars

# 存在しない場合は作成
cp terraform.tfvars.example terraform.tfvars
# エディタで必要な値を設定

# 初期化
terraform init

# プラン確認
terraform plan

# デプロイ（GitHub PATを環境変数で設定）
export TF_VAR_github_token="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
terraform apply
```

**デプロイされるリソース**:
- Cloud Functions (Webhook受信)
- Pub/Sub トピック & サブスクリプション
- BigQuery データセット & テーブル
- Dataform リポジトリ & リリース設定
- IAM権限
- Secret Manager (GitHub PAT)

---

### Step 7: SwitchBot Webhook を本番環境に設定

```bash
cd ../../scripts

# .env ファイルを編集（本番環境のWebhook URLを設定）
cp .env.example .env
# SWITCHBOT_TOKENとSWITCHBOT_SECRETを設定

# Webhook URLを本番環境のものに更新
./setup_switchbot_webhook.sh
```

**設定するURL**:
```
https://asia-northeast1-room-env-data-pipeline.cloudfunctions.net/prd-webhook-function
```

---

### Step 8: データ取り込みの動作確認

#### 8-1. Cloud Functions のログ確認

```bash
gcloud logging read \
  "resource.type=cloud_function AND resource.labels.function_name=prd-webhook-function" \
  --limit=20 \
  --project=room-env-data-pipeline
```

#### 8-2. BigQuery の生データ確認

```sql
SELECT COUNT(*) as row_count
FROM `room-env-data-pipeline.prd_sensor_data.sensor_raw_data`;

SELECT *
FROM `room-env-data-pipeline.prd_sensor_data.sensor_raw_data`
ORDER BY timestamp DESC
LIMIT 10;
```

---

### Step 9: Dataform の動作確認

#### 9-1. 自動実行を待つ（毎時00分）

Dataform は `hourly-aggregation` リリース設定により、毎時00分に自動実行されます。

#### 9-2. 手動で実行（オプション）

```bash
# GCPコンソールから実行
# https://console.cloud.google.com/bigquery/dataform?project=room-env-data-pipeline
```

1. Workspaceを作成
2. **PULL FROM GIT** → Branch: `main`
3. **Actions** → **Start execution** → **All actions**

#### 9-3. 集計テーブルの確認

```sql
-- 時間別統計
SELECT * FROM `room-env-data-pipeline.prd_sensor_data.sensor_hourly_stats`
ORDER BY hour_timestamp DESC LIMIT 10;

-- 日別統計
SELECT * FROM `room-env-data-pipeline.prd_sensor_data.sensor_daily_stats`
ORDER BY date DESC LIMIT 10;

-- 最新状態
SELECT * FROM `room-env-data-pipeline.prd_sensor_data.sensor_latest`;
```

---

### Step 10: Looker Studio ダッシュボードを作成

📄 参照: `LOOKER_SETUP.md`

**本番環境用の設定**:
- プロジェクト: `room-env-data-pipeline`
- データセット: `prd_sensor_data`
- テーブル: `sensor_latest`, `sensor_hourly_stats`, `sensor_daily_stats`

---

## 🔄 継続的デプロイ

### 機能追加の場合

```bash
# 1. feature ブランチで開発
git checkout -b feature/new-feature develop

# 2. 開発 & テスト
# ...

# 3. develop にマージ
git checkout develop
git merge feature/new-feature
git push origin develop

# 4. dev環境で動作確認
cd env/dev
terraform apply

# 5. PR作成（develop → main）
# 6. レビュー & 承認後、mainにマージ
# 7. dataform.jsonをprd用に更新（必要に応じて）
# 8. 本番環境にデプロイ
cd env/prd
terraform apply
```

---

## 🐛 トラブルシューティング

### 問題1: Dataform が「Can't find package.json」エラー

**原因**: GitHubブランチが正しく同期されていない

**対処**:
1. Dataform Workspaceで **PULL FROM GIT** を再実行
2. ブランチが `main` になっているか確認

---

### 問題2: BigQuery に データが入らない

**原因**: Pub/Sub サブスクリプションの権限不足

**対処**:
```bash
cd env/prd
terraform taint module.data_pipeline.google_pubsub_subscription.bigquery_subscription
terraform apply
```

---

### 問題3: Dataform 実行エラー

**原因**: `dataform.json` の設定が間違っている

**対処**:
1. `dataform.json` の `defaultSchema` を確認
2. BigQueryデータセット名と一致しているか確認
3. `defaultDatabase` がプロジェクトIDと一致しているか確認

---

## 📊 監視とアラート

### 推奨される監視項目

1. **Cloud Functions**
   - 実行回数
   - エラー率
   - レスポンスタイム

2. **Pub/Sub**
   - メッセージ数
   - Unacked messages
   - Dead letter queue のメッセージ数

3. **BigQuery**
   - テーブルの行数
   - データの更新頻度
   - クエリエラー

4. **Dataform**
   - 実行成功率
   - 実行時間
   - エラーログ

---

## 🔐 セキュリティ

### GitHub Personal Access Token の管理

```bash
# トークンをローテーションする場合
export TF_VAR_github_token="NEW_TOKEN_HERE"
cd env/prd
terraform apply
```

### Secret Manager の確認

```bash
gcloud secrets versions list dev-dataform-github-token \
  --project=room-env-data-pipeline
```

---

## 📚 参考ドキュメント

- [README.md](./README.md) - プロジェクト全体の概要
- [LOOKER_SETUP.md](./LOOKER_SETUP.md) - Looker Studio セットアップ
- [DATAFORM_SETUP.md](./DATAFORM_SETUP.md) - Dataform 詳細設定
- [PR_DESCRIPTION.md](./PR_DESCRIPTION.md) - Pull Request テンプレート

---

**Created by**: AI Assistant  
**Last Updated**: 2025-11-10  
**Status**: ✅ Ready for production deployment

