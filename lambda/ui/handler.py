import json
import os
from pathlib import Path


page = Path(__file__).with_name("index.html").read_text()


def handler(event, context):
    config = {
        "apiBaseUrl": os.environ["API_BASE_URL"],
        "callbackUrl": os.environ["CALLBACK_URL"],
        "clientId": os.environ["COGNITO_CLIENT_ID"],
        "cognitoDomain": os.environ["COGNITO_DOMAIN"],
    }

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "text/html; charset=utf-8",
            "Cache-Control": "no-store",
        },
        "body": page.replace("__APP_CONFIG__", json.dumps(config)),
    }

