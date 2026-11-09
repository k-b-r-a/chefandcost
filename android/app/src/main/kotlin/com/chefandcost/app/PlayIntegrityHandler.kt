package com.chefandcost.app

import android.content.Context
import android.util.Base64
import android.util.Log
import com.google.android.play.core.integrity.IntegrityManager
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import com.google.android.play.core.integrity.StandardIntegrityManager
import com.google.android.play.core.integrity.StandardIntegrityManager.PrepareIntegrityTokenRequest
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenProvider
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenRequest
import com.google.android.play.core.integrity.IntegrityServiceException
import com.google.android.play.core.integrity.StandardIntegrityException
import com.google.android.play.core.integrity.model.IntegrityErrorCode
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.security.MessageDigest
import java.security.SecureRandom

/**
 * Handles client-side Google Play Integrity API operations (both Standard and Classic APIs).
 * 
 * StandardIntegrityManager is used for low-latency, high-frequency integrity checks
 * on sensitive actions (warmup on app start, token generation on login / checkout / sync).
 * Classic IntegrityManager serves as a robust fallback.
 */
class PlayIntegrityHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.chefandcost.app/play_integrity"
        const val TAG = "PlayIntegrityHandler"
        const val DEFAULT_CLOUD_PROJECT_NUMBER = 194514517992L
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val mutex = Mutex()

    private val standardIntegrityManager: StandardIntegrityManager by lazy {
        IntegrityManagerFactory.createStandard(context.applicationContext)
    }

    private val classicIntegrityManager: IntegrityManager by lazy {
        IntegrityManagerFactory.create(context.applicationContext)
    }

    private var cachedTokenProvider: StandardIntegrityTokenProvider? = null
    private var lastPreparedProjectNumber: Long? = null
    private var methodChannel: MethodChannel? = null

    fun setup(messenger: BinaryMessenger) {
        methodChannel = MethodChannel(messenger, CHANNEL_NAME).apply {
            setMethodCallHandler(this@PlayIntegrityHandler)
        }
    }

    fun dispose() {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        scope.cancel()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "prepareIntegrityTokenProvider" -> {
                val projectNumber = getCloudProjectNumber(call)
                scope.launch {
                    try {
                        prepareStandardProvider(projectNumber)
                        result.success(
                            mapOf(
                                "status" to "prepared",
                                "cloudProjectNumber" to projectNumber
                            )
                        )
                    } catch (e: Exception) {
                        val (errorCode, message) = parseIntegrityException(e)
                        result.error(errorCode, message, e.stackTraceToString())
                    }
                }
            }

            "requestStandardIntegrityToken" -> {
                val projectNumber = getCloudProjectNumber(call)
                val requestHash = call.argument<String>("requestHash")
                    ?: generateDefaultRequestHash()

                scope.launch {
                    try {
                        val token = requestStandardToken(requestHash, projectNumber)
                        result.success(
                            mapOf(
                                "token" to token,
                                "type" to "standard",
                                "requestHash" to requestHash
                            )
                        )
                    } catch (e: Exception) {
                        val (errorCode, message) = parseIntegrityException(e)
                        result.error(errorCode, message, e.stackTraceToString())
                    }
                }
            }

            "requestClassicIntegrityToken" -> {
                val projectNumber = getCloudProjectNumber(call)
                val nonce = call.argument<String>("nonce")
                    ?: generateDefaultNonce()

                scope.launch {
                    try {
                        val token = requestClassicToken(nonce, projectNumber)
                        result.success(
                            mapOf(
                                "token" to token,
                                "type" to "classic",
                                "nonce" to nonce
                            )
                        )
                    } catch (e: Exception) {
                        val (errorCode, message) = parseIntegrityException(e)
                        result.error(errorCode, message, e.stackTraceToString())
                    }
                }
            }

            "requestIntegrityToken" -> {
                // Unified: attempts Standard Integrity first, seamlessly falls back to Classic
                val projectNumber = getCloudProjectNumber(call)
                val rawHashOrNonce = call.argument<String>("requestHash")
                    ?: call.argument<String>("nonce")

                scope.launch {
                    try {
                        val safeHash = rawHashOrNonce ?: generateDefaultRequestHash()
                        val standardToken = try {
                            requestStandardToken(safeHash, projectNumber)
                        } catch (standardEx: Exception) {
                            Log.w(TAG, "Standard integrity token request failed, attempting classic fallback: ${standardEx.message}")
                            null
                        }

                        if (standardToken != null) {
                            result.success(
                                mapOf(
                                    "token" to standardToken,
                                    "type" to "standard",
                                    "requestHash" to safeHash
                                )
                            )
                            return@launch
                        }

                        val safeNonce = rawHashOrNonce ?: generateDefaultNonce()
                        val classicToken = requestClassicToken(safeNonce, projectNumber)
                        result.success(
                            mapOf(
                                "token" to classicToken,
                                "type" to "classic",
                                "nonce" to safeNonce
                            )
                        )
                    } catch (e: Exception) {
                        val (errorCode, message) = parseIntegrityException(e)
                        result.error(errorCode, message, e.stackTraceToString())
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Prepares and warms up the StandardIntegrityTokenProvider.
     */
    suspend fun prepareStandardProvider(cloudProjectNumber: Long): StandardIntegrityTokenProvider =
        withContext(Dispatchers.IO) {
            mutex.withLock {
                if (cachedTokenProvider != null && lastPreparedProjectNumber == cloudProjectNumber) {
                    return@withContext cachedTokenProvider!!
                }

                Log.d(TAG, "Preparing StandardIntegrityTokenProvider for project $cloudProjectNumber...")
                val request = PrepareIntegrityTokenRequest.builder()
                    .setCloudProjectNumber(cloudProjectNumber)
                    .build()

                val provider = standardIntegrityManager.prepareIntegrityToken(request).await()
                cachedTokenProvider = provider
                lastPreparedProjectNumber = cloudProjectNumber
                Log.d(TAG, "StandardIntegrityTokenProvider warmed up successfully.")
                provider
            }
        }

    /**
     * Requests a Standard Integrity Token with the specified request hash.
     * Automatically warms up the provider if missing or invalid.
     */
    suspend fun requestStandardToken(
        requestHash: String,
        cloudProjectNumber: Long
    ): String = withContext(Dispatchers.IO) {
        val provider = cachedTokenProvider ?: prepareStandardProvider(cloudProjectNumber)

        val tokenRequest = StandardIntegrityTokenRequest.builder()
            .setRequestHash(requestHash)
            .build()

        try {
            val response = provider.request(tokenRequest).await()
            response.token()
        } catch (e: StandardIntegrityException) {
            if (e.errorCode == IntegrityErrorCode.INTEGRITY_TOKEN_PROVIDER_INVALID) {
                Log.w(TAG, "Token provider invalid/expired. Refreshing provider and retrying...")
                mutex.withLock {
                    cachedTokenProvider = null
                }
                val refreshedProvider = prepareStandardProvider(cloudProjectNumber)
                val retryResponse = refreshedProvider.request(tokenRequest).await()
                retryResponse.token()
            } else {
                throw e
            }
        }
    }

    /**
     * Requests a Classic Integrity Token as fallback.
     */
    suspend fun requestClassicToken(
        nonce: String,
        cloudProjectNumber: Long
    ): String = withContext(Dispatchers.IO) {
        Log.d(TAG, "Requesting Classic Integrity token for project $cloudProjectNumber...")
        val request = IntegrityTokenRequest.builder()
            .setCloudProjectNumber(cloudProjectNumber)
            .setNonce(nonce)
            .build()

        val response = classicIntegrityManager.requestIntegrityToken(request).await()
        response.token()
    }

    private fun getCloudProjectNumber(call: MethodCall): Long {
        return when (val arg = call.argument<Any>("cloudProjectNumber")) {
            is Number -> arg.toLong()
            is String -> arg.toLongOrNull() ?: DEFAULT_CLOUD_PROJECT_NUMBER
            else -> DEFAULT_CLOUD_PROJECT_NUMBER
        }
    }

    private fun generateDefaultRequestHash(): String {
        val randomBytes = ByteArray(32)
        SecureRandom().nextBytes(randomBytes)
        val digest = MessageDigest.getInstance("SHA-256").digest(randomBytes)
        return Base64.encodeToString(digest, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    }

    private fun generateDefaultNonce(): String {
        val randomBytes = ByteArray(32)
        SecureRandom().nextBytes(randomBytes)
        return Base64.encodeToString(randomBytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    }

    private fun parseIntegrityException(e: Exception): Pair<String, String> {
        val errorCode = when (e) {
            is StandardIntegrityException -> e.errorCode
            is IntegrityServiceException -> e.errorCode
            else -> null
        }

        val codeName = when (errorCode) {
            IntegrityErrorCode.API_NOT_AVAILABLE -> "API_NOT_AVAILABLE (-1)"
            IntegrityErrorCode.PLAY_STORE_NOT_FOUND -> "PLAY_STORE_NOT_FOUND (-2)"
            IntegrityErrorCode.NETWORK_ERROR -> "NETWORK_ERROR (-3)"
            IntegrityErrorCode.PLAY_STORE_ACCOUNT_NOT_FOUND -> "PLAY_STORE_ACCOUNT_NOT_FOUND (-4)"
            IntegrityErrorCode.APP_NOT_INSTALLED -> "APP_NOT_INSTALLED (-5)"
            IntegrityErrorCode.PLAY_SERVICES_NOT_FOUND -> "PLAY_SERVICES_NOT_FOUND (-6)"
            IntegrityErrorCode.APP_UID_MISMATCH -> "APP_UID_MISMATCH (-7)"
            IntegrityErrorCode.TOO_MANY_REQUESTS -> "TOO_MANY_REQUESTS (-8)"
            IntegrityErrorCode.CANNOT_BIND_TO_SERVICE -> "CANNOT_BIND_TO_SERVICE (-9)"
            IntegrityErrorCode.NONCE_TOO_SHORT -> "NONCE_TOO_SHORT (-10)"
            IntegrityErrorCode.NONCE_TOO_LONG -> "NONCE_TOO_LONG (-11)"
            IntegrityErrorCode.GOOGLE_SERVER_UNAVAILABLE -> "GOOGLE_SERVER_UNAVAILABLE (-12)"
            IntegrityErrorCode.NONCE_IS_NOT_BASE64 -> "NONCE_IS_NOT_BASE64 (-13)"
            IntegrityErrorCode.PLAY_STORE_VERSION_OUTDATED -> "PLAY_STORE_VERSION_OUTDATED (-14)"
            IntegrityErrorCode.PLAY_SERVICES_VERSION_OUTDATED -> "PLAY_SERVICES_VERSION_OUTDATED (-15)"
            IntegrityErrorCode.CLOUD_PROJECT_NUMBER_IS_INVALID -> "CLOUD_PROJECT_NUMBER_IS_INVALID (-16)"
            IntegrityErrorCode.CLIENT_TRANSIENT_ERROR -> "CLIENT_TRANSIENT_ERROR (-17)"
            IntegrityErrorCode.INTEGRITY_TOKEN_PROVIDER_INVALID -> "INTEGRITY_TOKEN_PROVIDER_INVALID (-19)"
            else -> "UNKNOWN_INTEGRITY_ERROR (${errorCode ?: -999})"
        }

        return Pair(codeName, e.localizedMessage ?: "Play Integrity error occurred")
    }
}
