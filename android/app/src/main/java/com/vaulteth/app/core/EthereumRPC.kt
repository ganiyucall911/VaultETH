package com.vaulteth.app.core

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigInteger
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong

class EthereumRPC(private val network: BlockchainNetwork) {

    private val client = OkHttpClient.Builder()
        .connectTimeout(12, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    private val idCounter = AtomicLong(1)
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    suspend fun getBalance(address: String): BigInteger = withContext(Dispatchers.IO) {
        val result = executeRpc("eth_getBalance", JSONArray().put(address).put("latest"))
        parseHexBigInteger(result)
    }

    suspend fun getTransactionCount(address: String): BigInteger = withContext(Dispatchers.IO) {
        val result = executeRpc("eth_getTransactionCount", JSONArray().put(address).put("pending"))
        parseHexBigInteger(result)
    }

    suspend fun getGasPrice(): BigInteger = withContext(Dispatchers.IO) {
        val result = executeRpc("eth_gasPrice", JSONArray())
        parseHexBigInteger(result)
    }

    suspend fun getMaxPriorityFeePerGas(): BigInteger = withContext(Dispatchers.IO) {
        try {
            val result = executeRpc("eth_maxPriorityFeePerGas", JSONArray())
            parseHexBigInteger(result)
        } catch (_: Exception) {
            // Fallback default tip: 1.5 Gwei
            BigInteger.valueOf(1_500_000_000L)
        }
    }

    suspend fun getLatestBaseFee(): BigInteger? = withContext(Dispatchers.IO) {
        try {
            val result = executeRpc("eth_getBlockByNumber", JSONArray().put("latest").put(false))
            val json = JSONObject(result)
            if (json.has("baseFeePerGas")) {
                parseHexBigInteger(json.getString("baseFeePerGas"))
            } else {
                null
            }
        } catch (_: Exception) {
            null
        }
    }

    suspend fun sendRawTransaction(signedHex: String): String = withContext(Dispatchers.IO) {
        executeRpc("eth_sendRawTransaction", JSONArray().put(signedHex))
    }

    suspend fun getTransactionReceipt(hash: String): JSONObject? = withContext(Dispatchers.IO) {
        val result = executeRpc("eth_getTransactionReceipt", JSONArray().put(hash))
        if (result == "null" || result.isBlank()) null else JSONObject(result)
    }

    suspend fun resolveENS(name: String): String? = withContext(Dispatchers.IO) {
        if (!name.endsWith(".eth", ignoreCase = true)) return@withContext null
        try {
            // Forward resolution via ENS Public Resolver
            // namehash of domain -> resolver.addr(node)
            val node = namehash(name)
            val callData = "0x3b3b57de" + node.removePrefix("0x") // addr(bytes32)

            val callObject = JSONObject().apply {
                put("to", "0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41") // ENS Public Resolver
                put("data", callData)
            }
            val result = executeRpc("eth_call", JSONArray().put(callObject).put("latest"))
            if (result.length >= 66) {
                val addrHex = "0x" + result.substring(result.length - 40)
                if (WalletEngine.isValidAddress(addrHex) && addrHex != "0x0000000000000000000000000000000000000000") {
                    return@withContext WalletEngine.toChecksumAddress(
                        WalletEngine.hexToBytes(addrHex.removePrefix("0x"))
                    )
                }
            }
            null
        } catch (_: Exception) {
            null
        }
    }

    private fun executeRpc(method: String, params: JSONArray): String {
        var lastException: Exception? = null
        for (url in network.rpcUrls) {
            try {
                val requestId = idCounter.getAndIncrement()
                val payload = JSONObject().apply {
                    put("jsonrpc", "2.0")
                    put("id", requestId)
                    put("method", method)
                    put("params", params)
                }
                val request = Request.Builder()
                    .url(url)
                    .post(payload.toString().toRequestBody(jsonMediaType))
                    .build()

                client.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) {
                        throw RuntimeException("HTTP ${response.code} from $url")
                    }
                    val body = response.body?.string() ?: throw RuntimeException("Empty response")
                    val json = JSONObject(body)
                    if (json.has("error")) {
                        val errObj = json.getJSONObject("error")
                        throw RuntimeException(errObj.optString("message", "RPC Error"))
                    }
                    return json.optString("result", json.opt("result")?.toString() ?: "")
                }
            } catch (e: Exception) {
                lastException = e
            }
        }
        throw lastException ?: RuntimeException("All RPC endpoints failed")
    }

    private fun parseHexBigInteger(hex: String): BigInteger {
        val clean = hex.trim().removePrefix("0x").removePrefix("0X")
        if (clean.isEmpty()) return BigInteger.ZERO
        return BigInteger(clean, 16)
    }

    private fun namehash(name: String): String {
        var node = ByteArray(32) // 32 zero bytes
        val labels = name.lowercase().split(".").reversed()
        for (label in labels) {
            val labelHash = WalletEngine.keccak256(label.toByteArray(Charsets.UTF_8))
            val combined = ByteArray(64)
            System.arraycopy(node, 0, combined, 0, 32)
            System.arraycopy(labelHash, 0, combined, 32, 32)
            node = WalletEngine.keccak256(combined)
        }
        return "0x" + node.joinToString("") { "%02x".format(it) }
    }
}
