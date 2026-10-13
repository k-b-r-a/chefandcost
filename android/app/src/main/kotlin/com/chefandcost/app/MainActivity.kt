package com.chefandcost.app

import android.content.ContentResolver
import android.content.Intent
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val ALARM_CHANNEL = "com.chefandcost.app/alarm"
    private val FILE_INTENT_CHANNEL = "com.chefandcost.app/file_intent"
    private var ringtone: Ringtone? = null

    private var fileChannel: MethodChannel? = null
    private var pendingFilePayload: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.let { handleFileIntent(it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleFileIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playSystemAlarm" -> {
                    try {
                        if (ringtone == null) {
                            var alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                            if (alarmUri == null) {
                                alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                            }
                            ringtone = RingtoneManager.getRingtone(applicationContext, alarmUri)
                        }
                        if (ringtone != null && !ringtone!!.isPlaying) {
                            ringtone!!.play()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ALARM_ERROR", e.localizedMessage, null)
                    }
                }
                "stopSystemAlarm" -> {
                    try {
                        if (ringtone != null && ringtone!!.isPlaying) {
                            ringtone!!.stop()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ALARM_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        fileChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_INTENT_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialFile" -> {
                        val payload = pendingFilePayload
                        pendingFilePayload = null
                        result.success(payload)
                    }
                    "clearPendingFile" -> {
                        pendingFilePayload = null
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        pendingFilePayload?.let { payload ->
            fileChannel?.invokeMethod("onFileReceived", payload)
        }
    }

    private fun handleFileIntent(intent: Intent) {
        val action = intent.action
        val uri: Uri? = when (action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            }
            else -> null
        } ?: return

        try {
            val fileName = getFileName(uri)
            val content = readFileContent(uri)

            if (!content.isNullOrBlank()) {
                val trimmed = content.trim()
                if (trimmed.startsWith("{") && trimmed.endsWith("}")) {
                    val payload = mapOf(
                        "fileName" to fileName,
                        "content" to content
                    )
                    pendingFilePayload = payload
                    fileChannel?.invokeMethod("onFileReceived", payload)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun getFileName(uri: Uri): String {
        var name = "recipe.chefy"
        if (uri.scheme == ContentResolver.SCHEME_CONTENT) {
            try {
                val cursor = contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                cursor?.use {
                    if (it.moveToFirst()) {
                        val index = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (index != -1) {
                            val resolved = it.getString(index)
                            if (!resolved.isNullOrBlank()) {
                                name = resolved
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                // Fallback to lastPathSegment
            }
        }
        if (name == "recipe.chefy") {
            uri.lastPathSegment?.let { segment ->
                val clean = segment.substringAfterLast('/')
                if (clean.isNotBlank()) {
                    name = clean
                }
            }
        }
        return name
    }

    private fun readFileContent(uri: Uri): String? {
        return try {
            contentResolver.openInputStream(uri)?.use { inputStream ->
                inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            }
        } catch (e: Exception) {
            null
        }
    }
}
