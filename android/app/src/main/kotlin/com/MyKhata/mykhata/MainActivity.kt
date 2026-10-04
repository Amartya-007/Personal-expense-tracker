package com.MyKhata.mykhata

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.database.Cursor
import android.net.Uri
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import org.json.JSONArray

class MainActivity: FlutterFragmentActivity() {
    private val SMS_CHANNEL = "com.MyKhata.mykhata/sms"
    private val INTENT_CHANNEL = "com.MyKhata.mykhata/intent"
    private val SMS_PERMISSION_REQ_CODE = 8801
    private var initialIntentAction: String? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialIntentAction = intent?.action
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = intent.action
        if (action != null) {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, INTENT_CHANNEL).invokeMethod("handleIntentAction", action)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasSmsPermission" -> {
                    val hasPerm = checkSmsPermission()
                    Log.d("SMS_CHANNEL", "hasSmsPermission check: $hasPerm")
                    result.success(hasPerm)
                }
                "requestSmsPermission" -> {
                    if (checkSmsPermission()) {
                        result.success(true)
                    } else {
                        pendingPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(
                                android.Manifest.permission.RECEIVE_SMS,
                                android.Manifest.permission.READ_SMS
                            ),
                            SMS_PERMISSION_REQ_CODE
                        )
                    }
                }
                "readPendingSms" -> {
                    val messages = readPendingSmsList()
                    Log.d("SMS_CHANNEL", "readPendingSms returned ${messages.size} messages")
                    result.success(messages)
                }
                "acknowledgePendingSms" -> {
                    val ids = call.arguments as? List<String> ?: emptyList()
                    acknowledgePendingSmsList(ids)
                    Log.d("SMS_CHANNEL", "acknowledgePendingSms acknowledged ${ids.size} IDs")
                    result.success(null)
                }
                "getInboxSms" -> {
                    val limit = call.argument<Int>("limit") ?: 100
                    val smsList = readInboxSms(limit)
                    result.success(smsList)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INTENT_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInitialIntentAction") {
                result.success(initialIntentAction)
                initialIntentAction = null
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_REQ_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            Log.d("SMS_CHANNEL", "onRequestPermissionsResult granted: $granted")
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun checkSmsPermission(): Boolean {
        val receivePerm = ContextCompat.checkSelfPermission(this, android.Manifest.permission.RECEIVE_SMS)
        val readPerm = ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_SMS)
        return receivePerm == PackageManager.PERMISSION_GRANTED && readPerm == PackageManager.PERMISSION_GRANTED
    }

    private fun readPendingSmsList(): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        try {
            val prefs = getSharedPreferences(IncomingSmsReceiver.STORAGE_NAME, Context.MODE_PRIVATE)
            val jsonStr = prefs.getString(IncomingSmsReceiver.PENDING_KEY, "[]") ?: "[]"
            val array = JSONArray(jsonStr)

            val len = array.length()
            var i = 0
            while (i < len) {
                val obj = array.optJSONObject(i)
                if (obj != null) {
                    val map = mutableMapOf<String, Any>()
                    map["id"] = obj.optString("id", "")
                    map["sender"] = obj.optString("sender", "")
                    map["body"] = obj.optString("body", "")
                    map["receivedAt"] = obj.optLong("receivedAt", System.currentTimeMillis())
                    list.add(map)
                }
                i++
            }
        } catch (e: Exception) {
            Log.e("SMS_CHANNEL", "Error reading pending SMS list", e)
        }
        return list
    }

    private fun acknowledgePendingSmsList(idsToAcknowledge: List<String>) {
        if (idsToAcknowledge.isEmpty()) return
        try {
            val ackSet = idsToAcknowledge.toSet()
            val prefs = getSharedPreferences(IncomingSmsReceiver.STORAGE_NAME, Context.MODE_PRIVATE)
            val jsonStr = prefs.getString(IncomingSmsReceiver.PENDING_KEY, "[]") ?: "[]"
            val array = JSONArray(jsonStr)
            val newArray = JSONArray()

            val len = array.length()
            var i = 0
            while (i < len) {
                val obj = array.optJSONObject(i)
                if (obj != null) {
                    val id = obj.optString("id", "")
                    if (!ackSet.contains(id)) {
                        newArray.put(obj)
                    }
                }
                i++
            }

            prefs.edit().putString(IncomingSmsReceiver.PENDING_KEY, newArray.toString()).apply()
        } catch (e: Exception) {
            Log.e("SMS_CHANNEL", "Error acknowledging pending SMS list", e)
        }
    }

    private fun readInboxSms(limit: Int): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        try {
            val uri = Uri.parse("content://sms/inbox")
            val cursor: Cursor? = contentResolver.query(
                uri,
                arrayOf("_id", "address", "body", "date"),
                null,
                null,
                "date DESC LIMIT $limit"
            )
            cursor?.use { c ->
                val idIdx = c.getColumnIndex("_id")
                val addrIdx = c.getColumnIndex("address")
                val bodyIdx = c.getColumnIndex("body")
                val dateIdx = c.getColumnIndex("date")

                while (c.moveToNext()) {
                    val map = mutableMapOf<String, Any>()
                    if (idIdx >= 0) map["id"] = c.getString(idIdx) ?: ""
                    if (addrIdx >= 0) map["sender"] = c.getString(addrIdx) ?: ""
                    if (bodyIdx >= 0) map["body"] = c.getString(bodyIdx) ?: ""
                    if (dateIdx >= 0) map["date"] = c.getLong(dateIdx)
                    list.add(map)
                }
            }
        } catch (e: Exception) {
            Log.e("SMS_CHANNEL", "Error reading inbox SMS", e)
        }
        return list
    }
}
