package com.callcenter.simple_dialer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log

class RecordingService : Service() {

    companion object {
        const val TAG = "RecordingService"
        const val CHANNEL_ID = "recording_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START = "START_RECORDING"
        const val ACTION_STOP = "STOP_RECORDING"
        const val EXTRA_PATH = "recording_path"

        var isRecording = false
            private set
        var lastError: String? = null
            private set
        var audioSourceUsed: String? = null
            private set
    }

    private var mediaRecorder: MediaRecorder? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val path = intent.getStringExtra(EXTRA_PATH)
                if (path != null) {
                    startForegroundWithNotification()
                    acquireWakeLock()
                    startRecording(path)
                }
            }
            ACTION_STOP -> {
                stopRecording()
                releaseWakeLock()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Call Recording",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Recording calls in background"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun startForegroundWithNotification() {
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("Recording Call")
                .setContentText("Mic recording is active")
                .setSmallIcon(android.R.drawable.ic_btn_speak_now)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("Recording Call")
                .setContentText("Mic recording is active")
                .setSmallIcon(android.R.drawable.ic_btn_speak_now)
                .setOngoing(true)
                .build()
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "SimpleDialer::RecordingWakeLock"
        ).apply {
            acquire(60 * 60 * 1000L) // 1 hour max
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }

    private fun startRecording(path: String) {
        lastError = null
        audioSourceUsed = null

        // Try multiple audio sources in order of preference
        val audioSources = listOf(
            Pair(MediaRecorder.AudioSource.MIC, "MIC"),
            Pair(MediaRecorder.AudioSource.VOICE_RECOGNITION, "VOICE_RECOGNITION"),
            Pair(MediaRecorder.AudioSource.CAMCORDER, "CAMCORDER"),
            Pair(MediaRecorder.AudioSource.UNPROCESSED, "UNPROCESSED"),
            Pair(MediaRecorder.AudioSource.DEFAULT, "DEFAULT")
        )

        for ((source, sourceName) in audioSources) {
            try {
                Log.d(TAG, "Trying AudioSource: $sourceName ($source)")

                mediaRecorder?.release()
                mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    MediaRecorder(this)
                } else {
                    @Suppress("DEPRECATION")
                    MediaRecorder()
                }

                mediaRecorder?.apply {
                    setAudioSource(source)
                    setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                    setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                    setAudioEncodingBitRate(128000)
                    setAudioSamplingRate(44100)
                    setAudioChannels(1)
                    setOutputFile(path)
                    prepare()
                    start()
                }

                isRecording = true
                audioSourceUsed = sourceName
                Log.d(TAG, "Recording started successfully with AudioSource: $sourceName")
                return

            } catch (e: Exception) {
                Log.e(TAG, "Failed with AudioSource $sourceName: ${e.message}")
                mediaRecorder?.release()
                mediaRecorder = null
            }
        }

        // All sources failed
        isRecording = false
        lastError = "All audio sources failed. Mic may be blocked during calls on this device."
        Log.e(TAG, lastError!!)
    }

    private fun stopRecording() {
        try {
            mediaRecorder?.apply {
                stop()
                release()
            }
            Log.d(TAG, "Recording stopped successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping recording: ${e.message}")
        }
        mediaRecorder = null
        isRecording = false
    }

    override fun onDestroy() {
        stopRecording()
        releaseWakeLock()
        super.onDestroy()
    }
}
