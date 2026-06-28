# Takapay Webhook Integration Guide

This document describes how to integrate your server backend with the Takapay forwarding daemon to verify transactions automatically. 

The Takapay app monitors incoming notifications (bKash, Nagad, Rocket) and delivers HTTP POST JSON payloads to your configured endpoint(s).

---

## 1. Request Details

### HTTP Method
* `POST`

### Content-Type
* `application/json`

### Authentication Headers
To prevent unauthorized parties from spoofing transaction notifications, every request contains a verification signature:
* `X-Webhook-Secret`: The secret token configured for the endpoint.

---

## 2. Payload Types

Your server endpoint must handle two types of JSON payloads: **Connection Test** and **Transaction Notification**.

### A. Connection Test Payload
Sent when the user clicks the "Test Connection" button in settings.

#### Payload Schema
```json
{
  "test": "connection",
  "secret": "string"
}
```

#### Example
```json
{
  "test": "connection",
  "secret": "uvxVXt6TsU0He4..."
}
```

---

### B. Transaction Payload
Sent in real-time when a cash-in message is captured and parsed successfully.

#### Payload Schema
```json
{
  "sender": "string (e.g. bKash / Nagad / Rocket)",
  "amount": "string (numerical format, e.g. 500.00)",
  "trx_id": "string",
  "raw_body": "string (original notification text)",
  "timestamp": "ISO 8601 String",
  "from": "string (Sender phone number or 'Unknown')",
  "secret": "string"
}
```

#### Example
```json
{
  "sender": "bKash",
  "amount": "1250.00",
  "trx_id": "8K5L9M2N",
  "raw_body": "bKash Cash In 1250.00 TK from 01712345678 received. TrxID 8K5L9M2N.",
  "timestamp": "2026-06-28T15:10:44.123Z",
  "from": "01712345678",
  "secret": "uvxVXt6TsU0He4..."
}
```

---

## 3. Server Responses (Good vs. Bad)

The Takapay client evaluates HTTP response status codes to determine delivery status.

| Response Code Range | Classification | Client Behavior |
| :--- | :--- | :--- |
| **`200 - 299`** (e.g. `200 OK`, `204 No Content`) | **Good (SUCCESS)** | The transaction is marked as `SUCCESS` in the local SQLite logs. |
| **`400 - 499`** (e.g. `401 Unauthorized`, `404 Not Found`) | **Bad (FAILED)** | Marked as `FAILED` (client-side configuration/permission issue). Details logged in debug console. |
| **`500 - 599`** (e.g. `500 Internal Error`, `502 Bad Gateway`) | **Bad (FAILED)** | Marked as `FAILED` (server-side system error). Retried manually via the app. |

---

## 4. Verification Check list
To secure your endpoint:
1. Compare the `X-Webhook-Secret` HTTP header (or the `secret` payload field) with the secret token generated in your Takapay app. Reject the request if they do not match.
2. Ensure your backend handles duplicate payloads gracefully. In case of network drops, the same payload may be resent. Ensure you verify the uniqueness of `trx_id` in your database.

---

## 5. Server Code Examples

### A. Node.js (Express)
```javascript
const express = require('express');
const app = express();

app.use(express.json());

const WEBHOOK_SECRET = 'your_configured_secret';

app.post('/webhook', (req, res) => {
  // 1. Verify Secret Token
  const secretHeader = req.headers['x-webhook-secret'];
  const secretBody = req.body.secret;

  if (secretHeader !== WEBHOOK_SECRET && secretBody !== WEBHOOK_SECRET) {
    return res.status(401).json({ error: 'Unauthorized payload signature' });
  }

  // 2. Handle Connection Test
  if (req.body.test === 'connection') {
    return res.status(200).json({ status: 'connected' });
  }

  // 3. Process Transaction Payload
  const { sender, amount, trx_id, from, raw_body } = req.body;
  console.log(`Received ${amount} TK via ${sender} from ${from}. TrxID: ${trx_id}`);

  // TODO: Update database, credit user balance, activate premium, etc.
  
  // 4. Respond with 200 OK to acknowledge receipt
  return res.status(200).json({ success: true, message: 'Transaction processed' });
});

app.listen(3000, () => console.log('Server running on port 3000'));
```

### B. PHP (Native)
```php
<?php
header('Content-Type: application/json');

$webhookSecret = 'your_configured_secret';

// Get request body
$json = file_get_contents('php://input');
$data = json_decode($json, true);

// Get headers
$headers = getallheaders();
$secretHeader = isset($headers['X-Webhook-Secret']) ? $headers['X-Webhook-Secret'] : '';
$secretBody = isset($data['secret']) ? $data['secret'] : '';

// 1. Verify Secret
if ($secretHeader !== $webhookSecret && $secretBody !== $webhookSecret) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized payload signature']);
    exit();
}

// 2. Handle Connection Test
if (isset($data['test']) && $data['test'] === 'connection') {
    http_response_code(200);
    echo json_encode(['status' => 'connected']);
    exit();
}

// 3. Process Transaction Payload
$sender = $data['sender'];
$amount = $data['amount'];
$trxId = $data['trx_id'];
$from = $data['from'];

// TODO: Update database, credit user balance, activate premium, etc.

// 4. Respond with 200 OK to acknowledge receipt
http_response_code(200);
echo json_encode(['success' => true, 'message' => 'Transaction processed']);
?>
```

### C. Python (FastAPI)
```python
from fastapi import FastAPI, Header, HTTPException, status
from pydantic import BaseModel
from typing import Optional

app = FastAPI()

WEBHOOK_SECRET = "your_configured_secret"

class WebhookPayload(BaseModel):
    test: Optional[str] = None
    sender: Optional[str] = None
    amount: Optional[str] = None
    trx_id: Optional[str] = None
    raw_body: Optional[str] = None
    timestamp: Optional[str] = None
    from_num: Optional[str] = None # 'from' is a Python keyword, Pydantic parses body keys mapping
    secret: Optional[str] = None

    class Config:
        fields = {
            'from_num': 'from'
        }

@app.post("/webhook")
async def handle_webhook(payload: WebhookPayload, x_webhook_secret: Optional[str] = Header(None)):
    # 1. Verify Secret
    if x_webhook_secret != WEBHOOK_SECRET and payload.secret != WEBHOOK_SECRET:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unauthorized payload signature"
        )
    
    # 2. Handle Connection Test
    if payload.test == "connection":
        return {"status": "connected"}
    
    # 3. Process Transaction
    print(f"Received {payload.amount} TK via {payload.sender}. TrxID: {payload.trx_id}")
    
    # TODO: Update database, credit user balance, activate premium, etc.
    
    # 4. Return success response
    return {"success": True, "message": "Transaction processed"}
```
