package com.xspoilt.takapay

import notification.listener.service.NotificationListener
import android.service.notification.StatusBarNotification
import java.util.*

class MyNotificationListener : NotificationListener() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        super.onNotificationPosted(sbn) // Forward to Flutter plugin
        
        try {
            val packageName = sbn.packageName ?: ""
            val extras = sbn.notification?.extras
            val title = extras?.getString("android.title") ?: ""
            val text = extras?.getCharSequence("android.text")?.toString() ?: ""
            
            BackgroundProcessor.saveDebugLogToDb(
                applicationContext,
                "NOTIFICATION_NATIVE",
                "Notification Posted: pkg=$packageName, title=$title, text=$text",
                false
            )

            BackgroundProcessor.processIncomingNotification(applicationContext, packageName, title, text)
        } catch (e: Exception) {
            e.printStackTrace()
            try {
                BackgroundProcessor.saveDebugLogToDb(
                    applicationContext,
                    "NOTIFICATION_NATIVE",
                    "Exception: ${e.message}",
                    true
                )
            } catch (ex: Exception) {
                // Ignore
            }
        }
    }
}
