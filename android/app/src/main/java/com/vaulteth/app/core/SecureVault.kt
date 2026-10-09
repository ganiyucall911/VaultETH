package com.vaulteth.app.core

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import org.json.JSONArray
import org.json.JSONObject

class SecureVault(context: Context) {

    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val securePrefs = EncryptedSharedPreferences.create(
        context,
        "vaulteth_secure_storage",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    private val publicPrefs = context.getSharedPreferences("vaulteth_prefs", Context.MODE_PRIVATE)

    fun saveMnemonic(walletId: String, mnemonic: List<String>) {
        val phrase = mnemonic.joinToString(" ")
        securePrefs.edit().putString("mnemonic_$walletId", phrase).apply()
    }

    fun getMnemonic(walletId: String): List<String>? {
        val phrase = securePrefs.getString("mnemonic_$walletId", null) ?: return null
        return phrase.split(" ").filter { it.isNotBlank() }
    }

    fun deleteMnemonic(walletId: String) {
        securePrefs.edit().remove("mnemonic_$walletId").apply()
    }

    fun saveWallets(wallets: List<VaultWallet>) {
        val array = JSONArray()
        for (w in wallets) {
            val obj = JSONObject().apply {
                put("id", w.id)
                put("name", w.name)
                put("address", w.address)
                put("solanaAddress", w.solanaAddress)
                put("bitcoinAddress", w.bitcoinAddress)
                put("isBackedUp", w.isBackedUp)
                put("importedEnsName", w.importedEnsName)
                put("createdAt", w.createdAt)
            }
            array.put(obj)
        }
        publicPrefs.edit().putString("wallets_list", array.toString()).apply()
    }

    fun loadWallets(): List<VaultWallet> {
        val str = publicPrefs.getString("wallets_list", null) ?: return emptyList()
        val list = mutableListOf<VaultWallet>()
        val array = JSONArray(str)
        for (i in 0 until array.length()) {
            val obj = array.getJSONObject(i)
            list.add(
                VaultWallet(
                    id = obj.getString("id"),
                    name = obj.getString("name"),
                    address = obj.getString("address"),
                    solanaAddress = obj.optString("solanaAddress", ""),
                    bitcoinAddress = obj.optString("bitcoinAddress", ""),
                    isBackedUp = obj.optBoolean("isBackedUp", false),
                    importedEnsName = if (obj.has("importedEnsName") && !obj.isNull("importedEnsName")) obj.optString("importedEnsName").ifBlank { null } else null,
                    createdAt = obj.optLong("createdAt", System.currentTimeMillis())
                )
            )
        }
        return list
    }

    fun saveTransactions(txs: List<SentTransaction>) {
        val array = JSONArray()
        for (t in txs) {
            val obj = JSONObject().apply {
                put("id", t.id)
                put("hash", t.hash)
                put("recipient", t.recipient)
                put("amount", t.amount)
                put("networkName", t.networkName)
                put("timestamp", t.timestamp)
                put("status", t.status.name)
            }
            array.put(obj)
        }
        publicPrefs.edit().putString("transactions_list", array.toString()).apply()
    }

    fun loadTransactions(): List<SentTransaction> {
        val str = publicPrefs.getString("transactions_list", null) ?: return emptyList()
        val list = mutableListOf<SentTransaction>()
        val array = JSONArray(str)
        for (i in 0 until array.length()) {
            val obj = array.getJSONObject(i)
            list.add(
                SentTransaction(
                    id = obj.getString("id"),
                    hash = obj.getString("hash"),
                    recipient = obj.getString("recipient"),
                    amount = obj.getString("amount"),
                    networkName = obj.optString("networkName", "Ethereum Mainnet"),
                    timestamp = obj.optLong("timestamp", System.currentTimeMillis()),
                    status = try {
                        TransactionStatus.valueOf(obj.optString("status", "PENDING"))
                    } catch (_: Exception) {
                        TransactionStatus.PENDING
                    }
                )
            )
        }
        return list
    }

    fun setSelectedWalletId(id: String?) {
        publicPrefs.edit().putString("selected_wallet_id", id).apply()
    }

    fun getSelectedWalletId(): String? = publicPrefs.getString("selected_wallet_id", null)

    fun setSelectedNetworkId(id: String) {
        publicPrefs.edit().putString("selected_network_id", id).apply()
    }

    fun getSelectedNetworkId(): String = publicPrefs.getString("selected_network_id", "ethereum") ?: "ethereum"
}
