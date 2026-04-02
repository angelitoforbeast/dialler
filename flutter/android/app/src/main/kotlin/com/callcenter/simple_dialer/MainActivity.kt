package com.callcenter.simple_dialer

import android.app.role.RoleManager
import android.content.Intent
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.telecom.TelecomManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.callcenter.simple_dialer/calls"
    private val EVENT_CHANNEL = "com.callcenter.simple_dialer/call_events"
    private val RECORDER_CHANNEL = "com.callcenter.simple_dialer/recorder"
    private val REQUEST_DEFAULT_DIALER = 1001

    private var mediaRecorder: MediaRecorder? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Event channel for call state updates
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    CallService.callStateCallback = { state, stateStr ->
                        runOnUiThread {
                            eventSink?.success(mapOf(
                                "state" to state,
                                "stateStr" to stateStr,
                                "number" to CallService.getCallNumber()
                            ))
                        }
                    }
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    CallService.callStateCallback = null
                }
            }
        )

        // Method channel for call actions
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestDefaultDialer" -> {
                    requestDefaultDialer()
                    result.success(true)
                }
                "isDefaultDialer" -> {
                    val tm = getSystemService(TELECOM_SERVICE) as TelecomManager
                    result.success(tm.defaultDialerPackage == packageName)
                }
                "placeCall" -> {
                    val number = call.argument<String>("number")
                    if (number != null) {
                        placeCall(number)
                        result.success(true)
                    } else {
                        result.error("NO_NUMBER", "Number is null", null)
                    }
                }
                "endCall" -> {
                    CallService.endCall()
                    result.success(true)
                }
                "holdCall" -> {
                    CallService.holdCall()
                    result.success(true)
                }
                "unholdCall" -> {
                    CallService.unholdCall()
                    result.success(true)
                }
                "muteCall" -> {
                    val mute = call.argument<Boolean>("mute") ?: false
                    CallService.muteCall(mute)
                    result.success(true)
                }
                "speakerOn" -> {
                    val on = call.argument<Boolean>("on") ?: false
                    CallService.speakerOn(on)
                    result.success(true)
                }
                "getCallState" -> {
                    val hasCall = CallService.currentCall != null
                    result.success(mapOf(
                        "hasCall" to hasCall,
                        "number" to (if (hasCall) CallService.getCallNumber() else "")
                    ))
                }
                else -> result.notImplemented()
            }
        }

        // Recorder channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECORDER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startRecording" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        try {
                            startRecording(path)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("RECORDING_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "Path is null", null)
                    }
                }
                "stopRecording" -> {
                    try {
                        stopRecording()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Handle incoming DIAL intent
        handleDialIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleDialIntent(intent)
    }

    private fun handleDialIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_DIAL || intent?.action == Intent.ACTION_VIEW) {
            val number = intent.data?.schemeSpecificPart
            if (number != null) {
                // Send the number to Flutter via method channel
                flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    MethodChannel(messenger, METHOD_CHANNEL).invokeMethod("incomingDial", number)
                }
            }
        }
    }

    private fun requestDefaultDialer() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(ROLE_SERVICE) as RoleManager
            if (!roleManager.isRoleHeld(RoleManager.ROLE_DIALER)) {
                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_DIALER)
                startActivityForResult(intent, REQUEST_DEFAULT_DIALER)
            }
        } else {
            val intent = Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER)
            intent.putExtra(TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME, packageName)
            startActivityForResult(intent, REQUEST_DEFAULT_DIALER)
        }
    }

    private fun placeCall(number: String) {
        val uri = Uri.fromParts("tel", number, null)
        val telecomManager = getSystemService(TELECOM_SERVICE) as TelecomManager
        val extras = Bundle()
        telecomManager.placeCall(uri, extras)
    }

    private fun startRecording(path: String) {
        mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        mediaRecorder?.apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioEncodingBitRate(128000)
            setAudioSamplingRate(44100)
            setAudioChannels(1)
            setOutputFile(path)
            prepare()
            start()
        }
    }

    private fun stopRecording() {
        mediaRecorder?.apply {
            try { stop() } catch (_: Exception) {}
            release()
        }
        mediaRecorder = null
    }
}
