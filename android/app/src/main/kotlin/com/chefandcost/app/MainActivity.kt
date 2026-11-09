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
    private val URL_CHANNEL = "com.chefandcost.app/url"
    private var ringtone: Ringtone? = null

    private var fileChannel: MethodChannel? = null
    private var pendingFilePayload: Map<String, String>? = null
    private var lastHandledUriString: String? = null
    private var playIntegrityHandler: PlayIntegrityHandler? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) {
            intent?.let { handleFileIntent(it, isNewIntent = false) }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleFileIntent(intent, isNewIntent = true)
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, URL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (!url.isNullOrBlank()) {
                        try {
                            val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(browserIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("URL_ERROR", e.localizedMessage, null)
                        }
                    } else {
                        result.error("BAD_ARGS", "URL cannot be null or empty", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Initialize and bind Play Integrity Handler (StandardIntegrityManager & fallback)
        playIntegrityHandler = PlayIntegrityHandler(this).apply {
            setup(flutterEngine.dartExecutor.binaryMessenger)
        }
    }

    override fun onDestroy() {
        playIntegrityHandler?.dispose()
        playIntegrityHandler = null
        super.onDestroy()
    }

    private fun handleFileIntent(intent: Intent, isNewIntent: Boolean) {
        val action = intent.action
        val rawUri: Uri? = when (action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            }
            else -> null
        }
        val uri: Uri = rawUri ?: return

        val uriString = uri.toString()
        if (uriString == lastHandledUriString && !isNewIntent) {
            return
        }
        lastHandledUriString = uriString

        try {
            val fileName = getFileName(uri)
            val mimeType = intent.type ?: try { contentResolver.getType(uri) } catch (e: Exception) { null }
            val isChefyMime = mimeType == "application/vnd.chefandcost.recipe" ||
                              mimeType == "application/x-chefy"
            val hasChefyExt = fileName.endsWith(".chefy", ignoreCase = true)

            val content = readFileContent(uri)

            if (!content.isNullOrBlank()) {
                val trimmed = content.trim()
                val isChefyJson = trimmed.startsWith("{") && trimmed.endsWith("}") &&
                    (trimmed.contains("\"chefy_recipe\"") || trimmed.contains("\"recipe\""))

                if (hasChefyExt || isChefyMime || isChefyJson) {
                    val safeFileName = if (hasChefyExt) fileName else "$fileName.chefy"
                    val payload = mapOf(
                        "fileName" to safeFileName,
                        "content" to content
                    )
                    if (isNewIntent) {
                        // Warm start: app is already open, stream the event to Flutter
                        pendingFilePayload = null
                        fileChannel?.invokeMethod("onFileReceived", payload)
                    } else {
                        // Cold start: cache for getInitialFile to fetch once on launch
                        pendingFilePayload = payload
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun getFileName(uri: Uri?): String {
        if (uri == null) return "recipe.chefy"
        var name: String? = null
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
        if (name.isNullOrBlank()) {
            uri.lastPathSegment?.let { segment ->
                val clean = segment.substringAfterLast('/')
                if (clean.isNotBlank()) {
                    name = clean
                }
            }
        }
        return name ?: "recipe.chefy"
    }

    private fun readFileContent(uri: Uri?): String? {
        if (uri == null) return null
        return try {
            contentResolver.openInputStream(uri)?.use { inputStream ->
                inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            }
        } catch (e: Exception) {
            null
        }
    }
}
