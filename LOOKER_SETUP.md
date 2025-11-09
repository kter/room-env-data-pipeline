# Looker Studio セットアップガイド

## 🎯 目的

BigQueryに保存されたセンサーデータを **Looker Studio（旧Google Data Studio）** で可視化し、リアルタイムダッシュボードを作成します。

**Looker Studio**: Googleが提供する無料のBIツール。BigQueryと簡単に連携できます。

## 📊 利用可能なテーブル

### 1. sensor_latest（推奨: ダッシュボード用）

**テーブルID**:
- **dev環境**: `room-env-data-pipeline-dev.dev_sensor_data.sensor_latest`
- **prd環境**: `room-env-data-pipeline.prd_sensor_data.sensor_latest`

**用途**: 現在の温度・湿度を表示するダッシュボード

**カラム**:
- `device_mac`: デバイスMACアドレス
- `device_type`: デバイスタイプ
- `last_updated`: 最終更新時刻
- `current_temperature`: 現在の温度 (°C)
- `current_humidity`: 現在の湿度 (%)
- `current_battery`: バッテリー残量 (%)
- `minutes_since_update`: 最終更新からの経過時間（分）

### 2. sensor_hourly_stats（推奨: 折れ線グラフ用）

**テーブルID**:
- **dev環境**: `room-env-data-pipeline-dev.dev_sensor_data.sensor_hourly_stats`
- **prd環境**: `room-env-data-pipeline.prd_sensor_data.sensor_hourly_stats`

**用途**: 時系列の温度・湿度推移グラフ

**カラム**:
- `hour_timestamp`: 時刻（1時間単位）
- `device_mac`: デバイスMACアドレス
- `device_type`: デバイスタイプ
- `avg_temperature`: 平均温度 (°C)
- `min_temperature`: 最低温度 (°C)
- `max_temperature`: 最高温度 (°C)
- `avg_humidity`: 平均湿度 (%)
- `min_humidity`: 最低湿度 (%)
- `max_humidity`: 最高湿度 (%)
- `avg_battery`: 平均バッテリー残量 (%)
- `event_count`: イベント数
- `last_updated`: 集計実行時刻

### 3. sensor_daily_stats（オプション: 日別レポート用）

**テーブルID**:
- **dev環境**: `room-env-data-pipeline-dev.dev_sensor_data.sensor_daily_stats`
- **prd環境**: `room-env-data-pipeline.prd_sensor_data.sensor_daily_stats`

**用途**: 日次レポート、長期トレンド分析

**カラム**:
- `date`: 日付
- `device_mac`: デバイスMACアドレス
- `device_type`: デバイスタイプ
- `avg_temperature`: 平均温度 (°C)
- `min_temperature`: 最低温度 (°C)
- `max_temperature`: 最高温度 (°C)
- `avg_humidity`: 平均湿度 (%)
- `min_humidity`: 最低湿度 (%)
- `max_humidity`: 最高湿度 (%)
- `avg_battery`: 平均バッテリー残量 (%)
- `event_count`: イベント数
- `last_updated`: 集計実行時刻

---

## 🚀 セットアップ手順

### 前提条件

- Googleアカウント（GmailまたはGoogle Workspace）
- BigQueryにデータが蓄積されていること
- BigQueryへのアクセス権限

---

### Step 1: Looker Studioにアクセス

1. ブラウザで以下のURLにアクセス：
   ```
   https://lookerstudio.google.com/
   ```

2. Googleアカウントでログイン

3. 初回の場合、利用規約に同意

---

### Step 2: 新しいレポートを作成

1. **作成** ボタンをクリック

2. **レポート** を選択

3. データソースの追加画面が表示される

---

### Step 3: BigQuery データソースを追加

#### 3-1. sensor_latest（現在の温度・湿度用）

1. **BigQuery** コネクタを選択

2. **カスタムクエリ** を選択

3. **プロジェクト**: `room-env-data-pipeline-dev` を選択

4. 以下のクエリを入力：

```sql
SELECT
  device_mac,
  device_type,
  last_updated,
  current_temperature,
  current_humidity,
  current_battery,
  minutes_since_update
FROM
  `room-env-data-pipeline-dev.dev_sensor_data.sensor_latest`
WHERE
  current_temperature IS NOT NULL
  AND current_humidity IS NOT NULL
ORDER BY
  last_updated DESC
```

5. **追加** をクリック

6. データソース名を「**現在のセンサー状態**」に変更

7. **レポートに追加** をクリック

#### 3-2. sensor_hourly_stats（時系列グラフ用）

1. **リソース → 追加したデータソースを管理** をクリック

2. **データソースを追加** をクリック

3. **BigQuery** → **カスタムクエリ** を選択

4. **プロジェクト**: `room-env-data-pipeline-dev` を選択

5. 以下のクエリを入力：

```sql
SELECT
  hour_timestamp,
  device_mac,
  device_type,
  avg_temperature,
  min_temperature,
  max_temperature,
  avg_humidity,
  min_humidity,
  max_humidity,
  avg_battery,
  event_count
FROM
  `room-env-data-pipeline-dev.dev_sensor_data.sensor_hourly_stats`
WHERE
  hour_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
ORDER BY
  hour_timestamp ASC
```

6. **追加** をクリック

7. データソース名を「**時間別センサー統計**」に変更

8. **完了** をクリック

---

### Step 4: ダッシュボードを作成

#### 4-1. 現在の温度・湿度を表示（スコアカード）

1. **グラフを追加** → **スコアカード** を選択

2. データソース: **現在のセンサー状態** を選択

3. **指標**: `current_temperature` を選択

4. グラフの設定：
   - **スタイル** タブで、フォントサイズを大きく（例: 48pt）
   - **単位**: 「°C」を追加
   - **タイトル**: 「現在の温度」

5. グラフをコピー（Ctrl+C, Ctrl+V）して湿度用を作成

6. 湿度スコアカード：
   - **指標**: `current_humidity` に変更
   - **単位**: 「%」を追加
   - **タイトル**: 「現在の湿度」

7. バッテリー残量のスコアカードも同様に作成（オプション）
   - **指標**: `current_battery`
   - **単位**: 「%」
   - **タイトル**: 「バッテリー残量」

#### 4-2. 温度推移の折れ線グラフ

1. **グラフを追加** → **時系列グラフ** を選択

2. **データソースを切り替え** → **時間別センサー統計** を選択

3. グラフの設定：
   - **期間のディメンション**: `hour_timestamp`
   - **指標**: `avg_temperature` を選択
   - **並べ替え**: `hour_timestamp` 昇順

4. スタイル設定：
   - **タイトル**: 「温度推移（時間別平均）」
   - **系列の色**: 赤系（例: #FF5252）
   - **折れ線の太さ**: 3px

5. 詳細設定（オプション）：
   - **指標を追加**: `min_temperature`, `max_temperature` を追加して範囲を表示
   - **参照線を追加**: 快適温度の範囲（例: 20-26°C）を表示

#### 4-3. 湿度推移の折れ線グラフ

1. 温度グラフをコピー（Ctrl+C, Ctrl+V）

2. グラフの設定を変更：
   - **指標**: `avg_humidity` に変更
   - **タイトル**: 「湿度推移（時間別平均）」
   - **系列の色**: 青系（例: #2196F3）

3. 詳細設定（オプション）：
   - **指標を追加**: `min_humidity`, `max_humidity` を追加
   - **参照線を追加**: 快適湿度の範囲（例: 40-60%）を表示

#### 4-4. レイアウトの調整

1. スコアカードを上部に横並びで配置

2. 温度グラフを中段に配置

3. 湿度グラフを下段に配置

4. グラフサイズを調整して、見やすいレイアウトに

---

### Step 5: ダッシュボードをカスタマイズ

#### 5-1. ページ設定

1. **ファイル → ページ設定** をクリック

2. ページ名を「**センサーダッシュボード**」に変更

3. **背景色**: 白またはライトグレー（#F5F5F5）

4. **テーマとレイアウト**: お好みで選択

#### 5-2. タイトルとテキストを追加

1. **テキストを追加** をクリック

2. ダッシュボードのタイトルを追加：
   - テキスト: 「**室内環境モニタリング**」
   - フォントサイズ: 32pt
   - 配置: 中央または左上

3. 最終更新時刻を表示（オプション）：
   - データソース: **現在のセンサー状態**
   - フィールド: `last_updated`
   - テキスト: 「最終更新: [フィールド]」

#### 5-3. フィルタを追加（複数デバイスがある場合）

1. **フィルタを追加** をクリック

2. **device_type** または **device_mac** でフィルタを作成

3. フィルタをダッシュボード上部に配置

4. これにより、特定のデバイスのみを表示可能

---

### Step 6: ダッシュボードを共有

#### 6-1. レポートを表示

1. **表示** ボタンをクリックして、完成したダッシュボードを確認

2. データが正しく表示されているか確認

#### 6-2. 共有設定

1. **共有** ボタンをクリック

2. 共有方法を選択：
   - **特定のユーザーと共有**: メールアドレスを入力
   - **リンクを知っている全員が閲覧可**: URLを共有
   - **埋め込み**: Webサイトにiframeで埋め込み

3. 権限を設定：
   - **閲覧者**: ダッシュボードの閲覧のみ
   - **編集者**: ダッシュボードの編集可能

#### 6-3. スケジュール配信（オプション）

1. **ファイル → スケジュールされた配信** をクリック

2. **新しいスケジュールされた配信** をクリック

3. 配信設定：
   - **頻度**: 毎日、毎週、毎月
   - **時刻**: 配信時刻
   - **宛先**: メールアドレス
   - **形式**: PDFまたはリンク

4. **保存** をクリック

---

## 🎨 ダッシュボードデザイン例

### レイアウト案

```
┌─────────────────────────────────────────────────────────┐
│  室内環境モニタリング                最終更新: 2025-11-09 │
├─────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │  24.5°C  │  │   52%    │  │   85%    │              │
│  │  現在の   │  │  現在の   │  │ バッテリー │              │
│  │   温度   │  │   湿度   │  │   残量   │              │
│  └──────────┘  └──────────┘  └──────────┘              │
├─────────────────────────────────────────────────────────┤
│  温度推移（時間別平均）                                   │
│  ┌───────────────────────────────────────────────────┐  │
│  │                        📈                        │  │
│  │  26°C ┼─╮                                       │  │
│  │  24°C ┼──╰───╮                                  │  │
│  │  22°C ┼──────╰───────╮                          │  │
│  │  20°C ┼──────────────╰───────                   │  │
│  │       └──┬───┬───┬───┬───┬───┬──→             │  │
│  │         00  04  08  12  16  20                 │  │
│  └───────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────┤
│  湿度推移（時間別平均）                                   │
│  ┌───────────────────────────────────────────────────┐  │
│  │                        📊                        │  │
│  │  60% ┼─────╮                                     │  │
│  │  50% ┼─────╰──╮                                  │  │
│  │  40% ┼────────╰───╮                              │  │
│  │  30% ┼────────────╰────────                      │  │
│  │      └──┬───┬───┬───┬───┬───┬──→              │  │
│  │        00  04  08  12  16  20                  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### カラースキーム推奨

- **温度グラフ**: 赤系グラデーション
  - 低温: `#2196F3` (青)
  - 適温: `#4CAF50` (緑)
  - 高温: `#FF5252` (赤)

- **湿度グラフ**: 青系グラデーション
  - 低湿: `#FFB74D` (オレンジ)
  - 適湿: `#2196F3` (青)
  - 高湿: `#1565C0` (濃青)

- **背景色**: `#F5F5F5` (ライトグレー)
- **テキスト色**: `#212121` (ダークグレー)

---

## 📱 モバイル対応

Looker Studioのダッシュボードはレスポンシブデザインに対応していますが、モバイル表示を最適化したい場合：

1. **ファイル → レイアウトオプション** をクリック

2. **モバイルレイアウト** を有効化

3. モバイル表示用のレイアウトを個別に調整

4. スコアカードを縦に並べる
5. グラフの高さを調整

---

## 🔄 データの自動更新

Looker Studioは **自動的にBigQueryからデータを取得** します。

### 更新頻度

- **デフォルト**: ダッシュボードを開くたびに最新データを取得
- **キャッシュ**: 12時間（BigQueryのキャッシュ設定）

### 手動更新

1. ダッシュボード右上の **更新** ボタンをクリック

2. または、ブラウザをリロード（F5）

### データ更新の確認

1. BigQueryのDataformが正常に動作しているか確認：
   ```bash
   # GCPコンソール → Dataform → リリース実行履歴
   ```

2. Cloud Functionsが正常にWebhookを受信しているか確認：
   ```bash
   # GCPコンソール → Cloud Functions → ログ
   ```

3. Pub/SubからBigQueryへの書き込みが成功しているか確認：
   ```bash
   # GCPコンソール → Pub/Sub → サブスクリプション → メトリクス
   ```

---

## 🐛 トラブルシューティング

### 問題1: データが表示されない

**原因**: BigQueryにデータが存在しない、または権限がない

**対処**:
1. BigQueryコンソールで直接クエリを実行してデータを確認：
   ```sql
   SELECT * FROM `room-env-data-pipeline-dev.dev_sensor_data.sensor_latest` LIMIT 10;
   ```

2. データがない場合：
   - SwitchBot Webhookが正常に動作しているか確認
   - Cloud Functionsのログを確認
   - Pub/Subサブスクリプションのステータスを確認

3. 権限がない場合：
   - GCPプロジェクトへのアクセス権を確認
   - BigQueryの `roles/bigquery.dataViewer` 権限を付与

### 問題2: グラフが正しく表示されない

**原因**: フィールドの型が正しくない、またはNULL値が多い

**対処**:
1. データソースの設定を確認：
   - **リソース → 追加したデータソースを管理**
   - フィールドの型を確認（数値、日時など）

2. クエリを修正してNULL値を除外：
   ```sql
   WHERE current_temperature IS NOT NULL
   ```

3. デフォルト値を設定（オプション）：
   ```sql
   COALESCE(current_temperature, 0) AS current_temperature
   ```

### 問題3: ダッシュボードの読み込みが遅い

**原因**: クエリが複雑、またはデータ量が多い

**対処**:
1. データの期間を制限：
   ```sql
   WHERE hour_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
   ```

2. 集約を活用：
   - 時間別統計テーブル（`sensor_hourly_stats`）を使用
   - 日別統計テーブル（`sensor_daily_stats`）を使用

3. BigQueryのクエリキャッシュを活用：
   - 同じクエリは自動的にキャッシュされる（12時間有効）

### 問題4: リアルタイム性が低い

**原因**: Dataformのスケジュール実行が遅い

**対処**:
1. 生データテーブル（`sensor_raw_data`）を直接使用：
   ```sql
   SELECT
     timestamp,
     device_mac,
     temperature,
     humidity
   FROM
     `room-env-data-pipeline-dev.dev_sensor_data.sensor_raw_data`
   WHERE
     timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
   ORDER BY
     timestamp DESC
   ```

2. Dataformのスケジュール頻度を増やす（15分ごとなど）

---

## 📊 高度な機能

### 1. アラート設定（Looker Studioでは直接不可）

Looker Studioには直接のアラート機能がありませんが、代替案：

- **BigQueryスケジュールクエリ + Cloud Functions**: 閾値を超えたらメール通知
- **Google Apps Script**: Looker Studio APIと連携

### 2. 予測分析

BigQuery MLと組み合わせて、将来の温度・湿度を予測：

```sql
CREATE OR REPLACE MODEL `dev_sensor_data.temperature_forecast`
OPTIONS(
  model_type='ARIMA_PLUS',
  time_series_timestamp_col='hour_timestamp',
  time_series_data_col='avg_temperature'
) AS
SELECT
  hour_timestamp,
  avg_temperature
FROM
  `dev_sensor_data.sensor_hourly_stats`;
```

### 3. 比較分析

複数のデバイスや期間を比較：

1. **ブレンドデータ** を使用して、複数のデータソースを結合
2. **計算フィールド** で前日比、前週比を計算
3. **コントロール** でデバイスや期間を動的に切り替え

---

## 🔗 参考リンク

### 公式ドキュメント

- [Looker Studio 公式サイト](https://lookerstudio.google.com/)
- [Looker Studio ヘルプセンター](https://support.google.com/looker-studio)
- [BigQuery コネクタガイド](https://support.google.com/looker-studio/answer/6370296)

### BigQuery関連

- [BigQueryコンソール（dev環境）](https://console.cloud.google.com/bigquery?project=room-env-data-pipeline-dev)
- [Dataform コンソール（dev環境）](https://console.cloud.google.com/bigquery/dataform?project=room-env-data-pipeline-dev)

### サンプルクエリ

```sql
-- 過去24時間の温度推移
SELECT
  hour_timestamp,
  device_mac,
  avg_temperature,
  min_temperature,
  max_temperature
FROM
  `room-env-data-pipeline-dev.dev_sensor_data.sensor_hourly_stats`
WHERE
  hour_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
ORDER BY
  hour_timestamp ASC;

-- 過去7日間の日別平均
SELECT
  date,
  device_mac,
  avg_temperature,
  avg_humidity
FROM
  `room-env-data-pipeline-dev.dev_sensor_data.sensor_daily_stats`
WHERE
  date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
ORDER BY
  date ASC;

-- デバイス別の最新状態
SELECT
  device_mac,
  device_type,
  current_temperature,
  current_humidity,
  current_battery,
  last_updated,
  minutes_since_update
FROM
  `room-env-data-pipeline-dev.dev_sensor_data.sensor_latest`
ORDER BY
  last_updated DESC;
```

---

## ✅ チェックリスト

セットアップ完了前に以下を確認：

- [ ] Looker Studioにアクセスできる
- [ ] BigQueryデータソースを追加できた
- [ ] 現在の温度・湿度がスコアカードで表示される
- [ ] 温度推移グラフが表示される
- [ ] 湿度推移グラフが表示される
- [ ] ダッシュボードのレイアウトが整っている
- [ ] 共有設定が完了している
- [ ] データが正しく更新されることを確認した

---

## 🎉 完成！

これで、SwitchBotセンサーのデータをリアルタイムで可視化するダッシュボードが完成しました！

**次のステップ**:
- ダッシュボードを定期的に確認
- 快適な室内環境を維持
- 必要に応じてダッシュボードをカスタマイズ
- 本番環境（prd）にも同様のセットアップを実施

---

**Created by**: AI Assistant  
**Last Updated**: 2025-11-09  
**Status**: ✅ Ready to use
