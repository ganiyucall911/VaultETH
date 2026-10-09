package com.vaulteth.app

import com.vaulteth.app.core.WalletEngine
import org.junit.Assert.*
import org.junit.Test
import java.math.BigInteger

class WalletEngineTest {

    @Test
    fun testMnemonicGenerationAndValidation() {
        val mnemonic = WalletEngine.generateMnemonic()
        assertEquals(12, mnemonic.size)
        assertTrue(WalletEngine.isValidMnemonic(mnemonic))
    }

    @Test
    fun testAddressDerivation() {
        val testWords = listOf(
            "abandon", "abandon", "abandon", "abandon",
            "abandon", "abandon", "abandon", "abandon",
            "abandon", "abandon", "abandon", "about"
        )
        val seed = WalletEngine.mnemonicToSeed(testWords)
        assertNotNull(seed)
        assertEquals(64, seed.size)

        val evm = WalletEngine.deriveEVMAddress(seed)
        assertTrue(evm.second.startsWith("0x"))
        assertEquals(42, evm.second.length)
        assertTrue(WalletEngine.isValidAddress(evm.second))

        val solana = WalletEngine.deriveSolanaAddress(seed)
        assertTrue(solana.isNotBlank())

        val btc = WalletEngine.deriveBitcoinAddress(seed)
        assertTrue(btc.startsWith("bc1q"))
    }

    @Test
    fun testPaymentURIParsing() {
        val uriStr = "ethereum:0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae?value=1000000000000000000"
        val parsed = WalletEngine.parsePaymentURI(uriStr)
        assertNotNull(parsed)
        assertEquals("0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae", parsed?.recipient)
        assertEquals("1", parsed?.amountEth)
        assertEquals(BigInteger("1000000000000000000"), parsed?.valueWei)
    }

    @Test
    fun testWeiConversion() {
        val oneEthInWei = WalletEngine.ethToWei("1.5")
        assertEquals(BigInteger("1500000000000000000"), oneEthInWei)
        val backToEth = WalletEngine.weiToEth(BigInteger("1500000000000000000"))
        assertEquals("1.5", backToEth)
    }

    @Test
    fun testENSUtilsAndWalletAccountWithENS() {
        // Normalization
        assertEquals("vitalik.eth", com.vaulteth.app.core.ENSUtils.normalizeENSName("vitalik"))
        assertEquals("vitalik.eth", com.vaulteth.app.core.ENSUtils.normalizeENSName("@vitalik.eth"))
        assertEquals("vitalik.eth", com.vaulteth.app.core.ENSUtils.normalizeENSName("VITALIK.ETH"))
        assertEquals("sat.eth", com.vaulteth.app.core.ENSUtils.normalizeENSName("  sat  "))

        // Annual Cost
        assertEquals(0.18, com.vaulteth.app.core.ENSUtils.estimateAnnualCost("abc.eth"), 0.0001)
        assertEquals(0.045, com.vaulteth.app.core.ENSUtils.estimateAnnualCost("abcd.eth"), 0.0001)
        assertEquals(0.0016, com.vaulteth.app.core.ENSUtils.estimateAnnualCost("vitalik.eth"), 0.0001)
        assertEquals(0.0, com.vaulteth.app.core.ENSUtils.estimateAnnualCost("ab.eth"), 0.0001)

        // Registration URL
        assertEquals("https://app.ens.domains/vitalik.eth", com.vaulteth.app.core.ENSUtils.registrationUrl("vitalik"))

        // VaultWallet model with ENS
        val wallet = com.vaulteth.app.core.VaultWallet(
            name = "Test Vault",
            address = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
            importedEnsName = "vitalik.eth"
        )
        assertEquals("vitalik.eth", wallet.importedEnsName)
    }
}

