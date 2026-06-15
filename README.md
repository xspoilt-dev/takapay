# Takapay - SMS & Notification Webhook Forwarder

Takapay is a highly optimized, premium Flutter-based Android application designed to listen for system notifications (such as SMS or app-specific transaction push notifications from payment gateways like bKash, Nagad, etc.) and securely forward the parsed transaction payload to a configured webhook URL.

## 🚀 Features

- **Notification Interceptor**: Intercepts active status bar notifications from payment apps and extracts payment confirmations.
- **Transaction Parser**: Automatically parses the transaction details:
  - Payment Channel/Sender (`bKash`, `Nagad`, etc.)
  - Transaction ID (`TrxID`)
  - Amount (`TK`)
  - Sender's Phone Number (`from` number extracted from the message body)
  - Full original message text (`raw_body`)
- **JSON Webhook Payload**: Delivers transaction payloads in real-time.
- **Detailed Webhook Logs**: Captures exact HTTP status codes and responses (e.g. `HTTP 500: Server Error`) or timeout/connection failures and logs them.
- **Resend/Retry System**: Stateful "Resend to Server" retry option from inside the transaction details dialog for failed transactions.
- **Premium Light Theme**: Designed with a clean, high-contrast White-and-Blue Material Light Theme.
- **Release Build Optimization**: Fully optimized with Proguard/R8 minification, icon tree-shaking, and resource shrinking for rapid startup and small installation size.

---

## 📲 Webhook JSON Payload Format

When a payment notification is intercepted or manually resent, Takapay POSTs a JSON payload to the configured webhook URL with the following structure:

```json
{
  "sender": "bKash",
  "amount": "11.00",
  "trx_id": "DFF9CF1S4T",
  "raw_body": "You have received Tk 11.00 from 01776812230. Fee Tk 0.00. Balance Tk 2,507.76. TrxID DFF9CF1S4T at 15/06/2026 14:25",
  "timestamp": "2026-06-15T14:25:40.495351",
  "from": "01776812230"
}
```

---

## 🛠️ Getting Started

### 1. Requirements
- Flutter SDK (latest version)
- Android Studio / Android SDK (Min SDK: 21)

### 2. Installation & Permissions
1. Run the app in debug mode or install the release APK.
2. On startup, the app will request:
   - SMS reading permissions
   - Battery Optimization exclusions (ensures the background service is not killed by the Android system)
   - Notification reading permission
3. The app will redirect you to the Android **Notification Access** settings screen. Look for **Takapay** in the list and enable the toggle.

### 3. Setting Webhook URL
1. Navigate to the **Settings** tab.
2. Enter your Webhook endpoint (e.g., `https://yourdomain.com/api/payment-webhook`).
3. Tap **Save Settings**.
4. Use **Test Connection** to send a test payload and verify that your server is reachable.

---

## 📦 How to Build the Optimized Release APK

To compile the production release APK with full code-shrinking and optimizations enabled:

```bash
flutter clean
flutter build apk --release
```

The compiled APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`
