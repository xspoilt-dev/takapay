package com.xspoilt.takapay

import android.content.Context
import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*
import java.util.regex.Pattern
import kotlin.concurrent.thread
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

object BackgroundProcessor {
    private var channel: MethodChannel? = null

    fun setMethodChannel(methodChannel: MethodChannel) {
        channel = methodChannel
    }

    fun triggerFlutterRefresh() {
        Handler(Looper.getMainLooper()).post {
            try {
                channel?.invokeMethod("onTransactionProcessed", null)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    fun isTransactionDuplicate(context: Context, trxId: String): Boolean {
        var exists = false
        try {
            val db = context.openOrCreateDatabase("takapay.db", Context.MODE_PRIVATE, null)
            // Ensure table exists before querying
            db.execSQL("CREATE TABLE IF NOT EXISTS transactions (" +
                    "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                    "sender TEXT NOT NULL, " +
                    "amount TEXT NOT NULL, " +
                    "trx_id TEXT NOT NULL, " +
                    "raw_body TEXT NOT NULL, " +
                    "timestamp TEXT NOT NULL, " +
                    "status TEXT NOT NULL, " +
                    "error_message TEXT, " +
                    "sender_number TEXT)")
            
            val cursor = db.rawQuery("SELECT id FROM transactions WHERE trx_id = ?", arrayOf(trxId))
            exists = cursor.count > 0
            cursor.close()
            db.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return exists
    }

    fun saveTransactionToDb(context: Context, sender: String, amount: String, trxId: String, rawBody: String, senderNumber: String?, status: String, errorMessage: String?) {
        try {
            val db = context.openOrCreateDatabase("takapay.db", Context.MODE_PRIVATE, null)
            db.execSQL("CREATE TABLE IF NOT EXISTS transactions (" +
                    "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                    "sender TEXT NOT NULL, " +
                    "amount TEXT NOT NULL, " +
                    "trx_id TEXT NOT NULL, " +
                    "raw_body TEXT NOT NULL, " +
                    "timestamp TEXT NOT NULL, " +
                    "status TEXT NOT NULL, " +
                    "error_message TEXT, " +
                    "sender_number TEXT)")
            
            val values = ContentValues().apply {
                put("sender", sender)
                put("amount", amount)
                put("trx_id", trxId)
                put("raw_body", rawBody)
                put("timestamp", SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date()))
                put("status", status)
                put("error_message", errorMessage)
                put("sender_number", senderNumber)
            }
            db.insert("transactions", null, values)
            db.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun saveDebugLogToDb(context: Context, category: String, message: String, isError: Boolean) {
        try {
            val db = context.openOrCreateDatabase("takapay.db", Context.MODE_PRIVATE, null)
            db.execSQL("CREATE TABLE IF NOT EXISTS debug_logs (" +
                    "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                    "timestamp TEXT NOT NULL, " +
                    "category TEXT NOT NULL, " +
                    "message TEXT NOT NULL, " +
                    "is_error INTEGER NOT NULL DEFAULT 0)")
            
            val values = ContentValues().apply {
                put("timestamp", SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date()))
                put("category", category)
                put("message", message)
                put("is_error", if (isError) 1 else 0)
            }
            db.insert("debug_logs", null, values)
            db.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun getWebhooksFromPrefs(context: Context): List<JSONObject> {
        val list = mutableListOf<JSONObject>()
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val jsonString = prefs.getString("flutter.webhooks_list", null)
            if (!jsonString.isNullOrEmpty()) {
                val jsonArray = JSONArray(jsonString)
                for (i in 0 until jsonArray.length()) {
                    list.add(jsonArray.getJSONObject(i))
                }
            } else {
                // Fallback to legacy settings
                val legacyUrl = prefs.getString("flutter.webhook_url", null)
                val legacySecret = prefs.getString("flutter.webhook_secret", "") ?: ""
                if (!legacyUrl.isNullOrEmpty()) {
                    val legacyObj = JSONObject().apply {
                        put("id", "legacy")
                        put("url", legacyUrl)
                        put("secret", legacySecret)
                        put("name", "Primary Webhook (Legacy)")
                    }
                    list.add(legacyObj)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return list
    }

    fun processIncomingSms(context: Context, sender: String, body: String) {
        val lowerBody = body.lowercase(Locale.US)
        val lowerSender = sender.lowercase(Locale.US)
        var cleanSender = "Unknown"
        var isMfs = false

        if (lowerBody.contains("bkash") || lowerSender.contains("bkash")) {
            cleanSender = "bKash"
            isMfs = true
        } else if (lowerBody.contains("nagad") || lowerSender.contains("nagad")) {
            cleanSender = "Nagad"
            isMfs = true
        } else if (lowerBody.contains("rocket") || lowerSender.contains("rocket") || lowerSender.contains("dbbl") || lowerSender.contains("16216")) {
            cleanSender = "Rocket"
            isMfs = true
        }

        if (!isMfs) {
            saveDebugLogToDb(context, "PARSER_NATIVE", "Ignored non-MFS SMS from $sender", false)
            return
        }

        // Parse amount: Tk\.?\s*([\d,]+\.\d{2})
        var amount: String? = null
        val amountPattern = Pattern.compile("Tk\\.?\\s*([\\d,]+\\.\\d{2})", Pattern.CASE_INSENSITIVE)
        val amountMatcher = amountPattern.matcher(body)
        if (amountMatcher.find()) {
            amount = amountMatcher.group(1)
        }

        // Parse trxId: (?:TrxID|TxnID|Txn\s+ID|Trx\s+ID)\s*:?\s*([A-Za-z0-9]+)
        var trxId: String? = null
        val trxPattern = Pattern.compile("(?:TrxID|TxnID|Txn\\s+ID|Trx\\s+ID)\\s*:?\\s*([A-Za-z0-9]+)", Pattern.CASE_INSENSITIVE)
        val trxMatcher = trxPattern.matcher(body)
        if (trxMatcher.find()) {
            trxId = trxMatcher.group(1)
        }

        // Parse phone: (?:from|by)\s*(?:\+?88)?(01[3-9]\d{8}) and fallback \b(01[3-9]\d{8})\b
        var senderNumber: String? = null
        val fromPhonePattern = Pattern.compile("(?:from|by)\\s*(?:\\+?88)?(01[3-9]\\d{8})", Pattern.CASE_INSENSITIVE)
        val fromPhoneMatcher = fromPhonePattern.matcher(body)
        if (fromPhoneMatcher.find()) {
            senderNumber = fromPhoneMatcher.group(1)
        } else {
            val phonePattern = Pattern.compile("\\b(01[3-9]\\d{8})\\b")
            val phoneMatcher = phonePattern.matcher(body)
            if (phoneMatcher.find()) {
                senderNumber = phoneMatcher.group(1)
            }
        }

        if (amount == null || trxId == null) {
            saveDebugLogToDb(context, "PARSER_NATIVE", "Failed to parse amount or TrxID from $cleanSender SMS", true)
            return
        }

        saveDebugLogToDb(context, "PARSER_NATIVE", "Parsed: $cleanSender - $amount TK - TrxID: $trxId", false)

        // Dispatch webhook and save transaction
        dispatchWebhookAndSave(context, cleanSender, amount, trxId, body, senderNumber)
    }

    fun processIncomingNotification(context: Context, packageName: String, title: String, text: String) {
        val lowerTitle = title.lowercase(Locale.US)
        val lowerText = text.lowercase(Locale.US)
        
        var isMfs = false
        var cleanSender = "Unknown"
        
        if (lowerTitle.contains("bkash") || lowerText.contains("bkash")) {
            cleanSender = "bKash"
            isMfs = true
        } else if (lowerTitle.contains("nagad") || lowerText.contains("nagad")) {
            cleanSender = "Nagad"
            isMfs = true
        } else if (lowerTitle.contains("rocket") || lowerText.contains("rocket") || lowerTitle.contains("16216")) {
            cleanSender = "Rocket"
            isMfs = true
        }
        
        if (!isMfs) return
        
        // Parse amount: Tk\.?\s*([\d,]+\.\d{2})
        var amount: String? = null
        val amountPattern = Pattern.compile("Tk\\.?\\s*([\\d,]+\\.\\d{2})", Pattern.CASE_INSENSITIVE)
        val amountMatcher = amountPattern.matcher(text)
        if (amountMatcher.find()) {
            amount = amountMatcher.group(1)
        }

        // Parse trxId: (?:TrxID|TxnID|Txn\s+ID|Trx\s+ID)\s*:?\s*([A-Za-z0-9]+)
        var trxId: String? = null
        val trxPattern = Pattern.compile("(?:TrxID|TxnID|Txn\\s+ID|Trx\\s+ID)\\s*:?\\s*([A-Za-z0-9]+)", Pattern.CASE_INSENSITIVE)
        val trxMatcher = trxPattern.matcher(text)
        if (trxMatcher.find()) {
            trxId = trxMatcher.group(1)
        }

        // Parse phone: (?:from|by)\s*(?:\+?88)?(01[3-9]\d{8}) and fallback \b(01[3-9]\d{8})\b
        var senderNumber: String? = null
        val fromPhonePattern = Pattern.compile("(?:from|by)\\s*(?:\\+?88)?(01[3-9]\\d{8})", Pattern.CASE_INSENSITIVE)
        val fromPhoneMatcher = fromPhonePattern.matcher(text)
        if (fromPhoneMatcher.find()) {
            senderNumber = fromPhoneMatcher.group(1)
        } else {
            val phonePattern = Pattern.compile("\\b(01[3-9]\\d{8})\\b")
            val phoneMatcher = phonePattern.matcher(text)
            if (phoneMatcher.find()) {
                senderNumber = phoneMatcher.group(1)
            }
        }

        if (amount == null || trxId == null) {
            return
        }

        // Dispatch webhook and save transaction
        dispatchWebhookAndSave(context, cleanSender, amount, trxId, text, senderNumber)
    }

    fun dispatchWebhookAndSave(context: Context, sender: String, amount: String, trxId: String, rawBody: String, senderNumber: String?) {
        thread {
            if (isTransactionDuplicate(context, trxId)) {
                saveDebugLogToDb(context, "DUPLICATE", "Transaction $trxId already exists, skipping duplicate", false)
                return@thread
            }

            val webhooks = getWebhooksFromPrefs(context)
            val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }.format(Date())

            if (webhooks.isEmpty()) {
                saveDebugLogToDb(context, "WEBHOOK_NATIVE", "No webhooks configured. Saving as FAILED.", true)
                saveTransactionToDb(context, sender, amount, trxId, rawBody, senderNumber, "FAILED", "No webhook endpoints configured")
                triggerFlutterRefresh()
                return@thread
            }

            val reports = mutableListOf<String>()
            var allSuccess = true

            for (webhook in webhooks) {
                val name = webhook.getString("name")
                val urlString = webhook.getString("url")
                val secret = webhook.getString("secret")

                try {
                    val url = URL(urlString)
                    val conn = url.openConnection() as HttpURLConnection
                    conn.requestMethod = "POST"
                    conn.setRequestProperty("Content-Type", "application/json")
                    conn.setRequestProperty("X-Webhook-Secret", secret)
                    conn.doOutput = true
                    conn.connectTimeout = 10000
                    conn.readTimeout = 10000

                    val payload = JSONObject().apply {
                        put("sender", sender)
                        put("amount", amount)
                        put("trx_id", trxId)
                        put("raw_body", rawBody)
                        put("timestamp", timestamp)
                        put("from", senderNumber ?: "Unknown")
                        put("secret", secret)
                    }

                    OutputStreamWriter(conn.outputStream, "UTF-8").use { writer ->
                        writer.write(payload.toString())
                        writer.flush()
                    }

                    val responseCode = conn.responseCode
                    if (responseCode in 200..299) {
                        reports.add("● $name: SUCCESS")
                    } else {
                        allSuccess = false
                        reports.add("● $name: FAILED (HTTP $responseCode)")
                    }
                    conn.disconnect()
                } catch (e: Exception) {
                    allSuccess = false
                    reports.add("● $name: FAILED (Error: ${e.message})")
                }
            }

            val reportString = reports.joinToString("\n")
            val status = if (allSuccess) "SUCCESS" else "FAILED"

            saveTransactionToDb(context, sender, amount, trxId, rawBody, senderNumber, status, reportString)
            saveDebugLogToDb(context, "WEBHOOK_NATIVE", "Webhook dispatch status: $status\n$reportString", !allSuccess)
            triggerFlutterRefresh()
        }
    }
}
