package com.trezor.trezorlivraison

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    /**
     * Canaux requis pour Android 8+ : le backend FCM utilise [CHANNEL_FCM],
     * les notifs locales Flutter utilisent [CHANNEL_LOCAL].
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val fcm = NotificationChannel(
            CHANNEL_FCM,
            "Trezor — alertes",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply { description = "Notifications push (essai, livraisons)" }
        val local = NotificationChannel(
            CHANNEL_LOCAL,
            "Livraisons",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply { description = "Notifications locales Trezor Livraison" }
        val cadeau = NotificationChannel(
            CHANNEL_CADEAU,
            "Cadeaux Trezor",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply { description = "Bonus et essais offerts par Trezor" }

        nm.createNotificationChannel(fcm)
        nm.createNotificationChannel(local)
        nm.createNotificationChannel(cadeau)
    }

    companion object {
        private const val CHANNEL_FCM = "trezo_notifications"
        private const val CHANNEL_LOCAL = "trezor_livraison"
        private const val CHANNEL_CADEAU = "trezor_cadeau"
    }
}
