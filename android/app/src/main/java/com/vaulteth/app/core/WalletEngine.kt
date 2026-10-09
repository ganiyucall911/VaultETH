package com.vaulteth.app.core

import org.bouncycastle.crypto.digests.KeccakDigest
import org.bouncycastle.crypto.digests.RIPEMD160Digest
import org.bouncycastle.crypto.digests.SHA256Digest
import org.bouncycastle.crypto.digests.SHA512Digest
import org.bouncycastle.crypto.macs.HMac
import org.bouncycastle.crypto.params.ECDomainParameters
import org.bouncycastle.crypto.params.ECPrivateKeyParameters
import org.bouncycastle.crypto.params.KeyParameter
import org.bouncycastle.crypto.signers.ECDSASigner
import org.bouncycastle.crypto.signers.HMacDSAKCalculator
import org.bouncycastle.jce.ECNamedCurveTable
import java.io.ByteArrayOutputStream
import java.math.BigDecimal
import java.math.BigInteger
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets
import java.security.SecureRandom
import java.util.Locale

object WalletEngine {

    // BIP-39 English Wordlist (essential subset + standard hashing)
    private val standardWords by lazy { Bip39EnglishWordList.words }

    fun generateMnemonic(): List<String> {
        val entropy = ByteArray(16) // 128 bits = 12 words
        SecureRandom().nextBytes(entropy)
        return entropyToMnemonic(entropy)
    }

    fun isValidMnemonic(words: List<String>): Boolean {
        if (words.size !in listOf(12, 15, 18, 21, 24)) return false
        val set = standardWords.toHashSet()
        return words.all { set.contains(it.lowercase().trim()) }
    }

    fun mnemonicToSeed(words: List<String>, passphrase: String = ""): ByteArray {
        val mnemonicStr = words.joinToString(" ") { it.lowercase().trim() }
        val salt = "mnemonic$passphrase".toByteArray(StandardCharsets.UTF_8)
        val password = mnemonicStr.toByteArray(StandardCharsets.UTF_8)

        val mac = HMac(SHA512Digest())
        mac.init(KeyParameter(password))

        // PBKDF2 with HMAC-SHA512, 2048 iterations, 64-byte key
        val result = ByteArray(64)
        var u = ByteArray(64)
        val uTemp = ByteArray(64)

        // Block 1
        val saltBlock = ByteArray(salt.size + 4)
        System.arraycopy(salt, 0, saltBlock, 0, salt.size)
        saltBlock[saltBlock.size - 1] = 1

        mac.update(saltBlock, 0, saltBlock.size)
        mac.doFinal(u, 0)
        System.arraycopy(u, 0, result, 0, 64)

        for (iter in 1 until 2048) {
            mac.update(u, 0, u.size)
            mac.doFinal(uTemp, 0)
            System.arraycopy(uTemp, 0, u, 0, 64)
            for (j in 0 until 64) {
                result[j] = (result[j].toInt() xor u[j].toInt()).toByte()
            }
        }
        return result
    }

    // Derive Master Key & EVM Key (m/44'/60'/0'/0/0)
    fun deriveEVMAddress(seed: ByteArray): Pair<ByteArray, String> {
        val master = deriveMasterKey(seed)
        // m/44'/60'/0'/0/0
        val p1 = deriveChildKey(master.first, master.second, 44 or 0x80000000.toInt())
        val p2 = deriveChildKey(p1.first, p1.second, 60 or 0x80000000.toInt())
        val p3 = deriveChildKey(p2.first, p2.second, 0 or 0x80000000.toInt())
        val p4 = deriveChildKey(p3.first, p3.second, 0)
        val p5 = deriveChildKey(p4.first, p4.second, 0)

        val privateKey = p5.first
        val address = privateKeyToAddress(privateKey)
        return Pair(privateKey, address)
    }

    fun deriveSolanaAddress(seed: ByteArray): String {
        // Deterministic Solana derivation from seed using SHA-256 digest + Base58
        val sha = SHA256Digest()
        val path = "solana:m/44'/501'/0'/0'".toByteArray(StandardCharsets.UTF_8)
        sha.update(seed, 0, seed.size)
        sha.update(path, 0, path.size)
        val hash = ByteArray(32)
        sha.doFinal(hash, 0)
        return Base58.encode(hash)
    }

    fun deriveBitcoinAddress(seed: ByteArray): String {
        // Native SegWit BIP-84 address derivation stub (bc1q...)
        val sha = SHA256Digest()
        val path = "bitcoin:m/84'/0'/0'/0/0".toByteArray(StandardCharsets.UTF_8)
        sha.update(seed, 0, seed.size)
        sha.update(path, 0, path.size)
        val pubKeyHash = ByteArray(32)
        sha.doFinal(pubKeyHash, 0)

        val ripemd = RIPEMD160Digest()
        ripemd.update(pubKeyHash, 0, pubKeyHash.size)
        val hash160 = ByteArray(20)
        ripemd.doFinal(hash160, 0)

        return Bech32.encode("bc", 0, hash160)
    }

    fun privateKeyToAddress(privateKey: ByteArray): String {
        val ecSpec = ECNamedCurveTable.getParameterSpec("secp256k1")
        val q = ecSpec.g.multiply(BigInteger(1, privateKey)).normalize()
        val x = q.affineXCoord.encoded
        val y = q.affineYCoord.encoded

        val pubKey = ByteArray(64)
        System.arraycopy(x, 0, pubKey, 0, 32)
        System.arraycopy(y, 0, pubKey, 32, 32)

        val hash = keccak256(pubKey)
        val rawAddress = ByteArray(20)
        System.arraycopy(hash, 12, rawAddress, 0, 20)

        return toChecksumAddress(rawAddress)
    }

    fun toChecksumAddress(rawAddress: ByteArray): String {
        val hex = rawAddress.joinToString("") { "%02x".format(it) }
        val hash = keccak256(hex.toByteArray(StandardCharsets.US_ASCII))
        val hashHex = hash.joinToString("") { "%02x".format(it) }

        val sb = StringBuilder("0x")
        for (i in hex.indices) {
            val c = hex[i]
            if (c in '0'..'9') {
                sb.append(c)
            } else {
                val nibble = Character.digit(hashHex[i], 16)
                if (nibble >= 8) sb.append(c.uppercaseChar()) else sb.append(c)
            }
        }
        return sb.toString()
    }

    fun keccak256(input: ByteArray): ByteArray {
        val digest = KeccakDigest(256)
        digest.update(input, 0, input.size)
        val out = ByteArray(32)
        digest.doFinal(out, 0)
        return out
    }

    // EIP-1559 Transaction Signing
    fun signEIP1559(
        chainId: Long,
        nonce: BigInteger,
        maxPriorityFeePerGas: BigInteger,
        maxFeePerGas: BigInteger,
        gasLimit: BigInteger,
        to: String,
        value: BigInteger,
        data: ByteArray,
        privateKey: ByteArray
    ): String {
        val cleanTo = to.removePrefix("0x").removePrefix("0X")
        val toBytes = hexToBytes(cleanTo)

        // RLP: [chainId, nonce, maxPriorityFee, maxFee, gasLimit, to, value, data, accessList=[]]
        val payloadFields = listOf(
            RLP.encode(BigInteger.valueOf(chainId)),
            RLP.encode(nonce),
            RLP.encode(maxPriorityFeePerGas),
            RLP.encode(maxFeePerGas),
            RLP.encode(gasLimit),
            RLP.encode(toBytes),
            RLP.encode(value),
            RLP.encode(data),
            RLP.encodeList(emptyList()) // empty accessList
        )
        val rlpPayload = RLP.encodeList(payloadFields)

        // Prepend type 0x02 for EIP-1559
        val signData = ByteArray(1 + rlpPayload.size)
        signData[0] = 0x02
        System.arraycopy(rlpPayload, 0, signData, 1, rlpPayload.size)

        val txHash = keccak256(signData)
        val sig = signSecp256k1(txHash, privateKey)

        // Final payload: 0x02 || RLP([chainId, nonce, maxPriority, maxFee, gasLimit, to, value, data, accessList, yParity, r, s])
        val signedFields = payloadFields + listOf(
            RLP.encode(BigInteger.valueOf(sig.recId.toLong())),
            RLP.encode(sig.r),
            RLP.encode(sig.s)
        )
        val signedRlp = RLP.encodeList(signedFields)
        val result = ByteArray(1 + signedRlp.size)
        result[0] = 0x02
        System.arraycopy(signedRlp, 0, result, 1, signedRlp.size)

        return "0x" + result.joinToString("") { "%02x".format(it) }
    }

    // Legacy Transaction Signing (EIP-155)
    fun signLegacy(
        chainId: Long,
        nonce: BigInteger,
        gasPrice: BigInteger,
        gasLimit: BigInteger,
        to: String,
        value: BigInteger,
        data: ByteArray,
        privateKey: ByteArray
    ): String {
        val cleanTo = to.removePrefix("0x").removePrefix("0X")
        val toBytes = hexToBytes(cleanTo)

        val fieldsToHash = listOf(
            RLP.encode(nonce),
            RLP.encode(gasPrice),
            RLP.encode(gasLimit),
            RLP.encode(toBytes),
            RLP.encode(value),
            RLP.encode(data),
            RLP.encode(BigInteger.valueOf(chainId)),
            RLP.encode(BigInteger.ZERO),
            RLP.encode(BigInteger.ZERO)
        )
        val txHash = keccak256(RLP.encodeList(fieldsToHash))
        val sig = signSecp256k1(txHash, privateKey)

        val v = BigInteger.valueOf(chainId * 2 + 35 + sig.recId)
        val signedFields = listOf(
            RLP.encode(nonce),
            RLP.encode(gasPrice),
            RLP.encode(gasLimit),
            RLP.encode(toBytes),
            RLP.encode(value),
            RLP.encode(data),
            RLP.encode(v),
            RLP.encode(sig.r),
            RLP.encode(sig.s)
        )
        val signedRlp = RLP.encodeList(signedFields)
        return "0x" + signedRlp.joinToString("") { "%02x".format(it) }
    }

    data class ECDSASignature(val r: BigInteger, val s: BigInteger, val recId: Int)

    private fun signSecp256k1(hash: ByteArray, privateKey: ByteArray): ECDSASignature {
        val ecSpec = ECNamedCurveTable.getParameterSpec("secp256k1")
        val domain = ECDomainParameters(ecSpec.curve, ecSpec.g, ecSpec.n, ecSpec.h)
        val keyParams = ECPrivateKeyParameters(BigInteger(1, privateKey), domain)

        val signer = ECDSASigner(HMacDSAKCalculator(SHA256Digest()))
        signer.init(true, keyParams)
        val components = signer.generateSignature(hash)
        var r = components[0]
        var s = components[1]

        val halfCurveOrder = ecSpec.n.shiftRight(1)
        var recId = 0
        if (s > halfCurveOrder) {
            s = ecSpec.n.subtract(s)
            recId = 1
        }
        return ECDSASignature(r, s, recId)
    }

    private fun deriveMasterKey(seed: ByteArray): Pair<ByteArray, ByteArray> {
        val hmac = HMac(SHA512Digest())
        hmac.init(KeyParameter("Bitcoin seed".toByteArray(StandardCharsets.US_ASCII)))
        hmac.update(seed, 0, seed.size)
        val out = ByteArray(64)
        hmac.doFinal(out, 0)
        val key = out.copyOfRange(0, 32)
        val chainCode = out.copyOfRange(32, 64)
        return Pair(key, chainCode)
    }

    private fun deriveChildKey(parentKey: ByteArray, parentChainCode: ByteArray, index: Int): Pair<ByteArray, ByteArray> {
        val hmac = HMac(SHA512Digest())
        hmac.init(KeyParameter(parentChainCode))

        val isHardened = (index and 0x80000000.toInt()) != 0
        val data = ByteArray(37)
        if (isHardened) {
            data[0] = 0
            System.arraycopy(parentKey, 0, data, 1, 32)
        } else {
            val ecSpec = ECNamedCurveTable.getParameterSpec("secp256k1")
            val q = ecSpec.g.multiply(BigInteger(1, parentKey)).normalize()
            val pub = q.getEncoded(true)
            System.arraycopy(pub, 0, data, 0, 33)
        }
        val idxBytes = ByteBuffer.allocate(4).putInt(index).array()
        System.arraycopy(idxBytes, 0, data, data.size - 4, 4)

        hmac.update(data, 0, data.size)
        val out = ByteArray(64)
        hmac.doFinal(out, 0)

        val ecSpec = ECNamedCurveTable.getParameterSpec("secp256k1")
        val il = BigInteger(1, out.copyOfRange(0, 32))
        val pk = BigInteger(1, parentKey)
        val childKey = il.add(pk).mod(ecSpec.n).toByteArray()

        val normalizedChildKey = ByteArray(32)
        val srcPos = if (childKey.size > 32) childKey.size - 32 else 0
        val destPos = if (childKey.size < 32) 32 - childKey.size else 0
        val length = minOf(32, childKey.size)
        System.arraycopy(childKey, srcPos, normalizedChildKey, destPos, length)

        return Pair(normalizedChildKey, out.copyOfRange(32, 64))
    }

    fun parsePaymentURI(uri: String): PaymentURI? {
        val trimmed = uri.trim()
        val raw = if (trimmed.startsWith("ethereum:", ignoreCase = true)) {
            trimmed.substring(9)
        } else if (trimmed.startsWith("pay-", ignoreCase = true)) {
            trimmed.substring(4)
        } else {
            trimmed
        }

        val parts = raw.split("?", limit = 2)
        var addressPart = parts[0]
        var chainId: Long? = null

        if (addressPart.contains("@")) {
            val atParts = addressPart.split("@", limit = 2)
            addressPart = atParts[0]
            chainId = atParts[1].toLongOrNull()
        }

        if (!isValidAddress(addressPart)) return null

        var amountEth: String? = null
        var valueWei: BigInteger? = null

        if (parts.size > 1) {
            val queryParams = parts[1].split("&")
            for (param in queryParams) {
                val kv = param.split("=", limit = 2)
                if (kv.size == 2) {
                    val key = kv[0].lowercase(Locale.ROOT)
                    val value = kv[1]
                    if (key == "value") {
                        valueWei = parseWeiValue(value)
                        if (valueWei != null) {
                            amountEth = weiToEth(valueWei)
                        }
                    } else if (key == "amount") {
                        amountEth = value
                        valueWei = ethToWei(value)
                    }
                }
            }
        }
        return PaymentURI(addressPart, amountEth, valueWei, chainId)
    }

    fun isValidAddress(address: String): Boolean {
        if (!address.startsWith("0x", ignoreCase = true)) return false
        if (address.length != 42) return false
        return address.substring(2).all { it in '0'..'9' || it in 'a'..'f' || it in 'A'..'F' }
    }

    fun ethToWei(eth: String): BigInteger? {
        return try {
            val bd = BigDecimal(eth.trim())
            bd.multiply(BigDecimal.TEN.pow(18)).toBigInteger()
        } catch (_: Exception) {
            null
        }
    }

    fun weiToEth(wei: BigInteger): String {
        val bd = BigDecimal(wei).divide(BigDecimal.TEN.pow(18), 6, java.math.RoundingMode.HALF_UP)
        return bd.stripTrailingZeros().toPlainString()
    }

    private fun parseWeiValue(raw: String): BigInteger? {
        return try {
            if (raw.contains("e", ignoreCase = true)) {
                BigDecimal(raw).toBigInteger()
            } else {
                BigInteger(raw)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun entropyToMnemonic(entropy: ByteArray): List<String> {
        val sha = SHA256Digest()
        sha.update(entropy, 0, entropy.size)
        val hash = ByteArray(32)
        sha.doFinal(hash, 0)

        val totalBits = entropy.size * 8 + entropy.size * 8 / 32
        val bitBuffer = BooleanArray(totalBits)

        var idx = 0
        for (b in entropy) {
            for (i in 7 downTo 0) {
                bitBuffer[idx++] = ((b.toInt() ushr i) and 1) == 1
            }
        }
        val checksumBits = entropy.size * 8 / 32
        for (i in 7 downTo 8 - checksumBits) {
            bitBuffer[idx++] = ((hash[0].toInt() ushr i) and 1) == 1
        }

        val words = mutableListOf<String>()
        val numWords = totalBits / 11
        for (i in 0 until numWords) {
            var wordIdx = 0
            for (j in 0 until 11) {
                wordIdx = (wordIdx shl 1) or (if (bitBuffer[i * 11 + j]) 1 else 0)
            }
            words.add(standardWords[wordIdx])
        }
        return words
    }

    fun hexToBytesSafe(hex: String): ByteArray {
        val clean = if (hex.length % 2 != 0) "0$hex" else hex
        val len = clean.length
        val data = ByteArray(len / 2)
        var i = 0
        while (i < len) {
            data[i / 2] = ((Character.digit(clean[i], 16) shl 4) + Character.digit(clean[i + 1], 16)).toByte()
            i += 2
        }
        return data
    }

    fun hexToBytes(hex: String): ByteArray = hexToBytesSafe(hex)
}

// Minimal RLP Encoder
object RLP {
    fun encode(bigInt: BigInteger): ByteArray {
        if (bigInt == BigInteger.ZERO) {
            return byteArrayOf(0x80.toByte())
        }
        val bytes = bigInt.toByteArray().dropWhile { it == 0.toByte() }.toByteArray()
        return if (bytes.size == 1 && (bytes[0].toInt() and 0xFF) < 0x80) {
            bytes
        } else {
            encodeLength(bytes.size, 0x80) + bytes
        }
    }

    fun encode(bytes: ByteArray): ByteArray {
        return if (bytes.size == 1 && (bytes[0].toInt() and 0xFF) < 0x80) {
            bytes
        } else {
            encodeLength(bytes.size, 0x80) + bytes
        }
    }

    fun encodeList(items: List<ByteArray>): ByteArray {
        val total = ByteArrayOutputStream()
        items.forEach { total.write(it) }
        val payload = total.toByteArray()
        return encodeLength(payload.size, 0xC0) + payload
    }

    private fun encodeLength(len: Int, offset: Int): ByteArray {
        return if (len < 56) {
            byteArrayOf((len + offset).toByte())
        } else {
            val lenBytes = BigInteger.valueOf(len.toLong()).toByteArray().dropWhile { it == 0.toByte() }.toByteArray()
            byteArrayOf((lenBytes.size + offset + 55).toByte()) + lenBytes
        }
    }
}

// Base58 implementation
object Base58 {
    private const val ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    private val BASE = BigInteger.valueOf(58)

    fun encode(input: ByteArray): String {
        if (input.isEmpty()) return ""
        var zeros = 0
        while (zeros < input.size && input[zeros] == 0.toByte()) zeros++

        var bi = BigInteger(1, input)
        val sb = StringBuilder()
        while (bi > BigInteger.ZERO) {
            val divRem = bi.divideAndRemainder(BASE)
            bi = divRem[0]
            val rem = divRem[1].toInt()
            sb.append(ALPHABET[rem])
        }
        repeat(zeros) { sb.append('1') }
        return sb.reverse().toString()
    }
}

// Bech32 implementation for Bitcoin SegWit
object Bech32 {
    private const val CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

    fun encode(hrp: String, witnessVersion: Int, program: ByteArray): String {
        val values = mutableListOf<Byte>()
        values.add(witnessVersion.toByte())
        // convert 8-bit to 5-bit
        var acc = 0
        var bits = 0
        for (b in program) {
            acc = (acc shl 8) or (b.toInt() and 0xFF)
            bits += 8
            while (bits >= 5) {
                bits -= 5
                values.add(((acc ushr bits) and 31).toByte())
            }
        }
        if (bits > 0) {
            values.add(((acc shl (5 - bits)) and 31).toByte())
        }

        val checksum = createChecksum(hrp, values.toByteArray())
        val sb = StringBuilder(hrp).append('1')
        for (v in values) {
            sb.append(CHARSET[v.toInt()])
        }
        for (c in checksum) {
            sb.append(CHARSET[c.toInt()])
        }
        return sb.toString()
    }

    private fun createChecksum(hrp: String, values: ByteArray): ByteArray {
        val enc = hrpExpand(hrp) + values + ByteArray(6)
        val polymod = polymod(enc) xor 1
        val ret = ByteArray(6)
        for (i in 0 until 6) {
            ret[i] = ((polymod ushr (5 * (5 - i))) and 31).toByte()
        }
        return ret
    }

    private fun hrpExpand(hrp: String): ByteArray {
        val ret = ByteArray(hrp.length * 2 + 1)
        for (i in hrp.indices) {
            ret[i] = (hrp[i].code ushr 5).toByte()
            ret[i + hrp.length + 1] = (hrp[i].code and 31).toByte()
        }
        ret[hrp.length] = 0
        return ret
    }

    private fun polymod(values: ByteArray): Int {
        var chk = 1
        val gen = intArrayOf(0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3)
        for (v in values) {
            val b = chk ushr 25
            chk = ((chk and 0x1ffffff) shl 5) xor (v.toInt() and 0xFF)
            for (i in 0 until 5) {
                if (((b ushr i) and 1) == 1) {
                    chk = chk xor gen[i]
                }
            }
        }
        return chk
    }
}
