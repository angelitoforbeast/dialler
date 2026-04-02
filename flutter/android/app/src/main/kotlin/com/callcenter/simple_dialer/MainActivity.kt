package com.callcenter.simple_dialer

import android.app.role.RoleManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.telecom.TelecomManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.callcenter.simple_dialer/calls"
    private val EVENT_CHANNEL = "com.callcenter.simple_dialer/call_events"
    private val RECORDER_CHANNEL = "com.callcenter.simple_dialer/recorder"
    private val REQUEST_DEFAULT_DIALER = 1001

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

        // Recorder channel - now uses Foreground Service
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECORDER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startRecording" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        try {
                            val intent = Intent(this, RecordingService::class.java).apply {
                                action = RecordingService.ACTION_START
                                putExtra(RecordingService.EXTRA_PATH, path)
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            Log.d("MainActivity", "RecordingService start requested for: $path")
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "Failed to start RecordingService: ${e.message}")
                            result.error("SERVICE_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "Path is null", null)
                    }
                }
                "stopRecording" -> {
                    try {
                        val intent = Intent(this, RecordingService::class.java).apply {
                            action = RecordingService.ACTION_STOP
                        }
                        startService(intent)
                        Log.d("MainActivity", "RecordingService stop requested")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Failed to stop RecordingService: ${e.message}")
                        result.error("STOP_ERROR", e.message, null)
                    }
                }
                "getRecordingStatus" -> {
                    result.success(mapOf(
                        "isRecording" to RecordingService.isRecording,
                        "audioSource" to (RecordingService.audioSourceUsed ?: "none"),
                        "error" to (RecordingService.lastError ?: "")
                    ))
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
}
