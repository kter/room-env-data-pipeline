#!/bin/bash
set -e

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# プロジェクトルートに移動
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "============================================================"
echo "🤖 SwitchBot Webhook 設定ツール"
echo "============================================================"
echo ""

# .envファイルを読み込む
if [ ! -f ".env" ]; then
    echo -e "${RED}❌ .envファイルが見つかりません${NC}"
    echo "   .env.exampleを参考に.envファイルを作成してください。"
    exit 1
fi

# .envファイルから環境変数を読み込む
export $(cat .env | grep -v '^#' | xargs)

if [ -z "$SWITCHBOT_TOKEN" ] || [ -z "$SWITCHBOT_SECRET" ]; then
    echo -e "${RED}❌ SWITCHBOT_TOKEN と SWITCHBOT_SECRET が設定されていません${NC}"
    exit 1
fi

# 署名を生成する関数
generate_sign() {
    local token="$1"
    local secret="$2"
    local nonce="$3"
    local t="$4"
    
    # string_to_sign = token + t + nonce
    local string_to_sign="${token}${t}${nonce}"
    
    # HMAC-SHA256で署名を生成してBase64エンコード
    echo -n "$string_to_sign" | openssl dgst -sha256 -hmac "$secret" -binary | base64
}

# 現在の設定を取得
get_webhook_config() {
    echo -e "${BLUE}1️⃣  現在の設定を確認${NC}"
    echo "------------------------------------------------------------"
    
    local nonce=$(uuidgen)
    local t=$(date +%s)000
    local sign=$(generate_sign "$SWITCHBOT_TOKEN" "$SWITCHBOT_SECRET" "$nonce" "$t")
    
    local response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
        -X POST "https://api.switch-bot.com/v1.1/webhook/queryWebhook" \
        -H "Authorization: $SWITCHBOT_TOKEN" \
        -H "sign: $sign" \
        -H "t: $t" \
        -H "nonce: $nonce" \
        -H "Content-Type: application/json" \
        -d '{"action":"queryUrl"}')
    
    local body=$(echo "$response" | sed -e 's/HTTP_STATUS\:.*//g')
    local status=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTP_STATUS://')
    
    if [ "$status" == "200" ]; then
        echo -e "${GREEN}✅ ステータスコード: $status${NC}"
        echo "📄 レスポンス:"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    else
        echo -e "${YELLOW}⚠️  ステータスコード: $status${NC}"
        echo "📄 レスポンス: $body"
    fi
    
    echo ""
}

# Webhook URLを設定
setup_webhook() {
    local webhook_url="$1"
    local device_list="${2:-ALL}"
    
    echo -e "${BLUE}2️⃣  Webhook URLを設定${NC}"
    echo "------------------------------------------------------------"
    echo "🔧 SwitchBot Webhook URLを設定中..."
    echo "   URL: $webhook_url"
    echo "   Device List: $device_list"
    echo ""
    
    local nonce=$(uuidgen)
    local t=$(date +%s)000
    local sign=$(generate_sign "$SWITCHBOT_TOKEN" "$SWITCHBOT_SECRET" "$nonce" "$t")
    
    local payload=$(cat <<EOF
{
  "action": "setupWebhook",
  "url": "$webhook_url",
  "deviceList": "$device_list"
}
EOF
)
    
    local response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
        -X POST "https://api.switch-bot.com/v1.1/webhook/setupWebhook" \
        -H "Authorization: $SWITCHBOT_TOKEN" \
        -H "sign: $sign" \
        -H "t: $t" \
        -H "nonce: $nonce" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    local body=$(echo "$response" | sed -e 's/HTTP_STATUS\:.*//g')
    local status=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTP_STATUS://')
    
    if [ "$status" == "200" ]; then
        echo -e "${GREEN}✅ ステータスコード: $status${NC}"
        echo "📄 レスポンス:"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
        echo ""
        echo -e "${GREEN}🎉 Webhook URLの設定が完了しました！${NC}"
        echo "   $webhook_url"
    else
        echo -e "${RED}❌ ステータスコード: $status${NC}"
        echo "📄 レスポンス: $body"
        exit 1
    fi
    
    echo ""
}

# メイン処理
main() {
    # 現在の設定を確認
    get_webhook_config
    
    # 開発環境のWebhook URLを設定
    local dev_webhook_url="https://asia-northeast1-room-env-data-pipeline-dev.cloudfunctions.net/dev-webhook-function"
    setup_webhook "$dev_webhook_url" "ALL"
    
    echo "============================================================"
    echo -e "${GREEN}✅ 完了${NC}"
    echo "============================================================"
}

# スクリプト実行
main

