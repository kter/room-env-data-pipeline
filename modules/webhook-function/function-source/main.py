import functions_framework
import json
import logging
from flask import Request

# ロガーの設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@functions_framework.http
def webhook_handler(request: Request):
    """
    Webhookを受け取り、ログに出力する関数
    
    Args:
        request (flask.Request): HTTP request object
        
    Returns:
        Response: HTTP response
    """
    try:
        # リクエストメソッドをログ出力
        logger.info(f"Received {request.method} request")
        
        # ヘッダー情報をログ出力
        logger.info(f"Headers: {dict(request.headers)}")
        
        # クエリパラメータをログ出力
        if request.args:
            logger.info(f"Query parameters: {dict(request.args)}")
        
        # リクエストボディをログ出力
        request_data = None
        if request.method in ['POST', 'PUT', 'PATCH']:
            # Content-Typeに応じてデータを取得
            content_type = request.headers.get('Content-Type', '')
            
            if 'application/json' in content_type:
                request_data = request.get_json(silent=True)
                logger.info(f"JSON body: {json.dumps(request_data, ensure_ascii=False)}")
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
            "timestamp": None  # Cloud Loggingが自動的にタイムスタンプを付与
        }
        
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
            "error": str(e)
        }
        
        return (
            json.dumps(error_response, ensure_ascii=False),
            500,
            {"Content-Type": "application/json; charset=utf-8"}
        )

