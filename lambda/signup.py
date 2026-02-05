"""FitForce email signup Lambda handler."""

import json
import os
import re
import time

import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

EMAIL_RE = re.compile(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')

CORS_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'POST,OPTIONS',
    'Content-Type': 'application/json',
}


def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': CORS_HEADERS,
        'body': json.dumps(body),
    }


def handler(event, context):
    # Handle CORS preflight
    if event.get('httpMethod') == 'OPTIONS':
        return response(200, {'message': 'ok'})

    # Parse body
    try:
        body = json.loads(event.get('body') or '{}')
    except (json.JSONDecodeError, TypeError):
        return response(400, {'message': 'Invalid request body.'})

    email = (body.get('email') or '').strip().lower()

    # Validate email
    if not email or not EMAIL_RE.match(email):
        return response(400, {'message': 'Please provide a valid email address.'})

    if len(email) > 320:
        return response(400, {'message': 'Email address is too long.'})

    # Check for duplicate, then store
    try:
        existing = table.get_item(Key={'email': email})
        if 'Item' in existing:
            return response(409, {'message': "You're already on the waitlist!"})

        table.put_item(
            Item={
                'email': email,
                'signed_up_at': int(time.time()),
                'source': 'landing_page',
            },
            ConditionExpression='attribute_not_exists(email)',
        )
    except dynamodb.meta.client.exceptions.ConditionalCheckFailedException:
        return response(409, {'message': "You're already on the waitlist!"})
    except Exception:
        return response(500, {'message': 'Something went wrong. Please try again.'})

    return response(200, {
        'message': "You're on the list! We'll be in touch soon.",
    })
