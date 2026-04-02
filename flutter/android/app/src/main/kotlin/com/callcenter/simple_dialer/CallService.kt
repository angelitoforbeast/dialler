package com.callcenter.simple_dialer

import android.os.Build
import android.telecom.Call
import android.telecom.InCallService

class CallService : InCallService() {

    companion object {
        var instance: CallService? = null
        var currentCall: Call? = null
        var callStateCallback: ((Int, String) -> Unit)? = null

        fun endCall() {
            currentCall?.disconnect()
        }

        fun holdCall() {
            currentCall?.hold()
        }

        fun unholdCall() {
            currentCall?.unhold()
        }

        fun muteCall(mute: Boolean) {
            instance?.setMuted(mute)
        }

        fun speakerOn(on: Boolean) {
            if (on) {
                instance?.setAudioRoute(android.telecom.CallAudioState.ROUTE_SPEAKER)
            } else {
                instance?.setAudioRoute(android.telecom.CallAudioState.ROUTE_EARPIECE)
            }
        }

        fun getCallNumber(): String {
            val handle = currentCall?.details?.handle
            return handle?.schemeSpecificPart ?: "Unknown"
        }
    }

    private val callCallback = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) {
            super.onStateChanged(call, state)
            val stateStr = when (state) {
                Call.STATE_DIALING -> "DIALING"
                Call.STATE_RINGING -> "RINGING"
                Call.STATE_ACTIVE -> "ACTIVE"
                Call.STATE_HOLDING -> "HOLDING"
                Call.STATE_DISCONNECTED -> "DISCONNECTED"
                Call.STATE_CONNECTING -> "CONNECTING"
                else -> "UNKNOWN"
            }
            callStateCallback?.invoke(state, stateStr)
            if (state == Call.STATE_DISCONNECTED) {
                currentCall?.unregisterCallback(this)
                currentCall = null
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }

    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        currentCall = call
        call.registerCallback(callCallback)

        val state = call.state
        val stateStr = when (state) {
            Call.STATE_DIALING -> "DIALING"
            Call.STATE_RINGING -> "RINGING"
            Call.STATE_ACTIVE -> "ACTIVE"
            else -> "CONNECTING"
        }
        callStateCallback?.invoke(state, stateStr)
    }

    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        call.unregisterCallback(callCallback)
        currentCall = null
        callStateCallback?.invoke(Call.STATE_DISCONNECTED, "DISCONNECTED")
    }
}
