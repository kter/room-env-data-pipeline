# Dataform GitHub連携セットアップガイド

## 🎯 概要

DataformリポジトリをGitHubと連携させることで、`dataform/`ディレクトリの内容を自動同期し、完全にコード管理できます。

## 📋 前提条件

- GitHubアカウント
- リポジトリへの管理者権限
- GCPプロジェクトへのアクセス権限

## 🚀 セットアップ手順

### Step 1: GitHub Personal Access Token (PAT) の作成

1. GitHubにログイン
2. **Settings → Developer settings → Personal access tokens → Tokens (classic)** に移動
   👉 https://github.com/settings/tokens

3. **Generate new token (classic)** をクリック

4. 以下の設定で作成：
   - **Note**: `Dataform room-env-data-pipeline`
   - **Expiration**: 90 days または No expiration（推奨：90 days）
   - **Scopes**: 
     - ✅ `repo` (Full control of private repositories)

5. **Generate token** をクリックし、トークンをコピー
   ⚠️ このトークンは1度しか表示されないので、必ず保存してください

### Step 2: GCP Secret Managerにトークンを保存

```bash
# 環境変数にトークンを設定（実際のトークンに置き換えてください）
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Secret Managerにトークンを保存
echo -n "${GITHUB_TOKEN}" | gcloud secrets create dataform-github-token \
  --data-file=- \
  --replication-policy="automatic" \
  --project=room-env-data-pipeline-dev

# 確認
gcloud secrets describe dataform-github-token \
  --project=room-env-data-pipeline-dev
```

### Step 3: Dataformサービスアカウントに権限付与

```bash
# プロジェクト番号を取得
PROJECT_NUMBER=$(gcloud projects describe room-env-data-pipeline-dev \
  --format='value(projectNumber)')

# DataformサービスアカウントにSecret Managerアクセス権限を付与
gcloud secrets add-iam-policy-binding dataform-github-token \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-dataform.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=room-env-data-pipeline-dev

# 確認
gcloud secrets get-iam-policy dataform-github-token \
  --project=room-env-data-pipeline-dev
```

### Step 4: Terraform変数を設定

`env/dev/terraform.tfvars` を編集（または作成）：

```hcl
# 既存の設定...

# Dataform GitHub連携
dataform_git_repository_url       = "https://github.com/kter/room-env-data-pipeline.git"
dataform_git_token_secret_version = "projects/room-env-data-pipeline-dev/secrets/dataform-github-token/versions/latest"
```

### Step 5: Terraformでデプロイ

```bash
cd env/dev

# プランを確認
terraform plan

# デプロイ実行
terraform apply
```

### Step 6: 動作確認

1. **GCPコンソールでDataformリポジトリを確認**
   👉 https://console.cloud.google.com/bigquery/dataform/locations/asia-northeast1/repositories/dev-sensor-data-transformation?project=room-env-data-pipeline-dev

2. **GitHubとの同期を確認**
   - リポジトリページで **"Remote repository"** セクションを確認
   - Branch: `main` と表示されることを確認

3. **ワークスペースを作成**
   - **"Create workspace"** をクリック
   - Workspace name: `main` (デフォルト)
   - **"Create"** をクリック

4. **ファイルが自動同期されていることを確認**
   - `dataform.json`
   - `package.json`
   - `definitions/sensor_hourly_stats.sqlx`
   - `definitions/sensor_daily_stats.sqlx`
   - `definitions/sensor_latest.sqlx`

5. **ワークフローを実行**
   - **"Start execution"** をクリック
   - **"Include all actions"** を選択
   - **"Start execution"** をクリック

6. **実行結果を確認**
   - すべてのアクションが成功することを確認
   - BigQueryで集計テーブルにデータが入っていることを確認

## 🔄 GitHub連携後の運用

### コード変更フロー

1. **ローカルで`dataform/`ディレクトリを編集**
```bash
# 例: sensor_hourly_stats.sqlxを編集
vi dataform/definitions/sensor_hourly_stats.sqlx
```

2. **GitHubにプッシュ**
```bash
git add dataform/
git commit -m "feat: Update sensor_hourly_stats aggregation logic"
git push origin main
```

3. **Dataformで自動同期**
   - GitHubにプッシュすると、Dataformが自動的に変更を検知
   - 次回のスケジュール実行（毎時0分）で新しいコードが実行される

### 手動実行

変更をすぐに反映したい場合：

1. GCPコンソールでDataformリポジトリを開く
2. ワークスペースで最新のコードをプル
3. **"Start execution"** で手動実行

## 🔧 トラブルシューティング

### エラー: "Failed to clone repository"

**原因**: GitHub Personal Access Tokenが無効、または権限不足

**解決策**:
1. トークンの有効期限を確認
2. トークンの `repo` スコープが有効か確認
3. 新しいトークンを作成して Secret Manager を更新
```bash
echo -n "NEW_TOKEN" | gcloud secrets versions add dataform-github-token \
  --data-file=- \
  --project=room-env-data-pipeline-dev
```

### エラー: "Permission denied for secret"

**原因**: Dataformサービスアカウントに Secret Manager アクセス権限がない

**解決策**:
```bash
PROJECT_NUMBER=$(gcloud projects describe room-env-data-pipeline-dev \
  --format='value(projectNumber)')

gcloud secrets add-iam-policy-binding dataform-github-token \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-dataform.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=room-env-data-pipeline-dev
```

### GitHub連携を無効化したい場合

`env/dev/terraform.tfvars` で以下のように設定：

```hcl
dataform_git_repository_url       = ""
dataform_git_token_secret_version = ""
```

その後、`terraform apply` を実行すると、GitHub連携が削除され、手動アップロード方式に戻ります。

## 📊 GitHub連携のメリット

✅ **完全なコード管理**: すべての定義ファイルがGitで管理される
✅ **バージョン管理**: 変更履歴が明確
✅ **コードレビュー**: プルリクエストでレビュー可能
✅ **CI/CD対応**: GitHub Actionsと連携可能
✅ **自動同期**: プッシュするだけで反映
✅ **チーム開発**: 複数人での開発が容易
✅ **災害復旧**: GitHubをバックアップとして利用

## 📚 参考資料

- [Dataform Documentation](https://cloud.google.com/dataform/docs)
- [Connect to a Git repository](https://cloud.google.com/dataform/docs/connect-repository)
- [Secret Manager Documentation](https://cloud.google.com/secret-manager/docs)
- [GitHub Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)

## 🎯 次のステップ

1. ✅ GitHub Personal Access Token作成
2. ✅ Secret Managerに保存
3. ✅ Terraform apply
4. → Dataformワークフロー実行テスト
5. → スケジュール実行の確認
6. → Lookerセットアップ

