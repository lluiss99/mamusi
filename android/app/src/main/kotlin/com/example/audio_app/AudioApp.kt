package com.example.audio_app

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

// audio_service crea su propio canal de notificación con IMPORTANCE_LOW, lo
// que hace que MIUI/HyperOS lo agrupe bajo "Silenciadas" (sin la portada ni
// los colores extraídos del álbum). Los canales de Android no se pueden
// reconfigurar una vez creados, así que lo creamos nosotros primero, con
// mayor importancia, antes de que audio_service llegue a hacerlo.
class AudioApp : Application() {
    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Mamusi",
                    NotificationManager.IMPORTANCE_DEFAULT
                )
                channel.setSound(null, null)
                channel.enableVibration(false)
                channel.setShowBadge(false)
                manager.createNotificationChannel(channel)
            }
        }
    }

    companion object {
        private const val CHANNEL_ID = "com.example.audio_app.channel.audio"
    }
}
