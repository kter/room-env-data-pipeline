import functions_framework
import json
import logging
import os
from flask import Request
from datetime import datetime
from google.cloud import pubsub_v1

# ロガーの設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Pub/Sub設定
PUBSUB_TOPIC = os.environ.get('PUBSUB_TOPIC')
publisher = pubsub_v1.PublisherClient() if PUBSUB_TOPIC else None


def convert_to_bigquery_format(data: dict) -> dict:
    """
    SwitchBot WebhookデータをBigQuery形式に変換
    
    Args:
        data: Webhookペイロード
        
    Returns:
        BigQuery形式のデータ
    """
    context = data.get('context', {})
    
    # タイムスタンプをBigQuery TIMESTAMP形式に変換（RFC3339）
    time_of_sample = context.get('timeOfSample', 0)
    if time_of_sample:
        # ミリ秒のタイムスタンプを秒に変換してRFC3339形式に
        timestamp = datetime.fromtimestamp(time_of_sample / 1000).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z'
    else:
        timestamp = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z'
    
    current_time = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z'
    
    # BigQuery用のレコード作成
    # NULLではなく空文字列を使用（NULLABLE フィールドの場合）
    bq_record = {
        "timestamp": timestamp,
        "device_mac": context.get('deviceMac') or 'unknown',
        "device_type": context.get('deviceType') or 'unknown',
        "event_type": data.get('eventType') or 'unknown',
        "event_version": data.get('eventVersion') or '',
        "temperature": context.get('temperature'),
        "humidity": context.get('humidity'),
        "battery": context.get('battery'),
        "lock_state": context.get('lockState') or '',
        "detection_state": context.get('detectionState') or '',
        "open_state": context.get('openState') or '',
        "power_state": context.get('powerState') or '',
        "brightness": context.get('lightLevel') or context.get('brightness'),  # lightLevel → brightness (INTEGER)
        "raw_data": json.dumps(data, ensure_ascii=False),  # JSONを文字列化
        "inserted_at": current_time
    }
    
    return bq_record


def publish_to_pubsub(message_data: dict) -> bool:
    """
    Pub/Subにメッセージを送信
    
    Args:
        message_data: 送信するメッセージデータ
        
    Returns:
        成功したかどうか
    """
    if not publisher or not PUBSUB_TOPIC:
        logger.warning("Pub/Sub is not configured. Skipping message publication.")
        return False
    
    try:
        # メッセージをJSON文字列に変換してバイト列に
        message_json = json.dumps(message_data, ensure_ascii=False)
        message_bytes = message_json.encode('utf-8')
        
        # Pub/Subに送信
        future = publisher.publish(PUBSUB_TOPIC, message_bytes)
        message_id = future.result()  # 送信完了を待機
        
        logger.info(f"[Pub/Sub] Message published successfully. Message ID: {message_id}")
        return True
        
    except Exception as e:
        logger.error(f"[Pub/Sub] Failed to publish message: {str(e)}", exc_info=True)
        return False


def process_switchbot_webhook(data: dict) -> dict:
    """
    SwitchBot Webhookデータを処理する
    
    Args:
        data: Webhookペイロード
        
    Returns:
        処理結果の辞書
    """
    event_type = data.get('eventType', 'unknown')
    event_version = data.get('eventVersion', 'unknown')
    context = data.get('context', {})
    
    device_type = context.get('deviceType', 'unknown')
    device_mac = context.get('deviceMac', 'unknown')
    time_of_sample = context.get('timeOfSample', 0)
    
    logger.info(f"[SwitchBot] Event Type: {event_type}, Version: {event_version}")
    logger.info(f"[SwitchBot] Device: {device_type} (MAC: {device_mac})")
    logger.info(f"[SwitchBot] Time of Sample: {time_of_sample}")
    
    # デバイスタイプごとの処理
    result = {
        "eventType": event_type,
        "deviceType": device_type,
        "deviceMac": device_mac,
        "timestamp": time_of_sample
    }
    
    # Lock/Lock Pro/Lock Ultraの状態
    if 'lockState' in context:
        lock_state = context['lockState']
        battery = context.get('battery', 'unknown')
        logger.info(f"[SwitchBot Lock] State: {lock_state}, Battery: {battery}%")
        result['lockState'] = lock_state
        result['battery'] = battery
    
    # Motion Sensor
    elif 'detectionState' in context:
        detection_state = context['detectionState']
        brightness = context.get('lightLevel') or context.get('brightness', 'unknown')
        logger.info(f"[SwitchBot Motion] Detection: {detection_state}, Brightness: {brightness}")
        result['detectionState'] = detection_state
        result['brightness'] = brightness
    
    # Contact Sensor
    elif 'openState' in context:
        open_state = context['openState']
        brightness = context.get('lightLevel') or context.get('brightness', 'unknown')
        logger.info(f"[SwitchBot Contact] State: {open_state}, Brightness: {brightness}")
        result['openState'] = open_state
        result['brightness'] = brightness
    
    # Meter (温湿度計)
    elif 'temperature' in context or 'humidity' in context:
        temperature = context.get('temperature', 'N/A')
        humidity = context.get('humidity', 'N/A')
        battery = context.get('battery', 'unknown')
        logger.info(f"[SwitchBot Meter] Temp: {temperature}°C, Humidity: {humidity}%, Battery: {battery}%")
        result['temperature'] = temperature
        result['humidity'] = humidity
        result['battery'] = battery
    
    # Bot (スイッチボット)
    elif 'powerState' in context:
        power_state = context['powerState']
        battery = context.get('battery', 'unknown')
        logger.info(f"[SwitchBot Bot] Power: {power_state}, Battery: {battery}%")
        result['powerState'] = power_state
        result['battery'] = battery
    
    # その他のコンテキストをログ出力
    logger.info(f"[SwitchBot] Full context: {json.dumps(context, ensure_ascii=False)}")
    
    return result


@functions_framework.http
def webhook_handler(request: Request):
    """
    Webhookを受け取り、ログに出力する関数
    SwitchBot Webhookに対応
    
    Args:
        request (flask.Request): HTTP request object
        
    Returns:
        Response: HTTP response
    """
    try:
        # リクエストメソッドをログ出力
        logger.info(f"Received {request.method} request")
        
        # ヘッダー情報をログ出力（一部のみ）
        important_headers = {
            'Content-Type': request.headers.get('Content-Type'),
            'User-Agent': request.headers.get('User-Agent'),
        }
        logger.info(f"Headers: {important_headers}")
        
        # クエリパラメータをログ出力
        if request.args:
            logger.info(f"Query parameters: {dict(request.args)}")
        
        # リクエストボディをログ出力
        request_data = None
        processed_data = None
        
        if request.method in ['POST', 'PUT', 'PATCH']:
            # Content-Typeに応じてデータを取得
            content_type = request.headers.get('Content-Type', '')
            
            if 'application/json' in content_type:
                request_data = request.get_json(silent=True)
                logger.info(f"JSON body: {json.dumps(request_data, ensure_ascii=False)}")
                
                # SwitchBot Webhookかどうかを判定
                if request_data and 'eventType' in request_data and 'context' in request_data:
                    logger.info("=== SwitchBot Webhook detected ===")
                    
                    # SwitchBotデータを処理（ログ出力）
                    processed_data = process_switchbot_webhook(request_data)
                    
                    # BigQuery形式に変換
                    bq_data = convert_to_bigquery_format(request_data)
                    
                    # Pub/Subに送信
                    publish_success = publish_to_pubsub(bq_data)
                    if publish_success:
                        logger.info("[Pub/Sub] Data sent to pipeline successfully")
                    else:
                        logger.warning("[Pub/Sub] Failed to send data to pipeline")
                    
                    logger.info("=== SwitchBot Webhook processing completed ===")
                
            elif 'application/x-www-form-urlencoded' in content_type:
                request_data = request.form.to_dict()
                logger.info(f"Form data: {request_data}")
            else:
                request_data = request.get_data(as_text=True)
                logger.info(f"Raw body: {request_data}")
        
        # 成功レスポンスを返す
        response_data = {
            "status": "success",
            "message": "Webhook received successfully",
            "method": request.method,
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
        
        # SwitchBotデータを処理した場合は情報を追加
        if processed_data:
            response_data['switchbot'] = processed_data
        
        logger.info(f"Response: {json.dumps(response_data, ensure_ascii=False)}")
        
        return (
            json.dumps(response_data, ensure_ascii=False),
            200,
            {"Content-Type": "application/json; charset=utf-8"}
        )
        
    except Exception as e:
        logger.error(f"Error processing webhook: {str(e)}", exc_info=True)
        
        error_response = {
            "status": "error",
            "message": "Failed to process webhook",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
        
        return (
            json.dumps(error_response, ensure_ascii=False),
            500,
            {"Content-Type": "application/json; charset=utf-8"}
        )

