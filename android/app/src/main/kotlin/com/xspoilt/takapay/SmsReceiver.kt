package com.xspoilt.takapay

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import io.flutter.plugin.common.MethodChannel

class SmsReceiver : BroadcastReceiver() {
    companion object {
        fun setMethodChannel(methodChannel: MethodChannel) {
            BackgroundProcessor.setMethodChannel(methodChannel)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (sms in messages) {
                val body = sms.displayMessageBody ?: ""
                val sender = sms.displayOriginatingAddress ?: ""

                BackgroundProcessor.saveDebugLogToDb(
                    context,
                    "SMS_NATIVE",
                    "Received SMS from: $sender",
                    false
                )

                BackgroundProcessor.processIncomingSms(context, sender, body)
            }
        }
    }
}
