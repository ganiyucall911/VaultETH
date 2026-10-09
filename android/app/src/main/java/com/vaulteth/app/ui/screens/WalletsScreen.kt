package com.vaulteth.app.ui.screens

import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.vaulteth.app.core.BlockchainNetwork
import com.vaulteth.app.core.ENSUtils
import com.vaulteth.app.core.EthereumRPC
import com.vaulteth.app.core.VaultWallet
import com.vaulteth.app.ui.components.VaultIdenticon
import com.vaulteth.app.ui.theme.*
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WalletsScreen(
    wallets: List<VaultWallet>,
    selectedWalletId: String?,
    onSelectWallet: (VaultWallet) -> Unit,
    onCreateWallet: () -> Unit,
    onImportWallet: (String, List<String>) -> Unit,
    onDeleteWallet: (VaultWallet) -> Unit,
    onViewMnemonic: (VaultWallet) -> List<String>?,
    onSetImportedEns: (String, String?) -> Unit = { _, _ -> }
) {
    val context = LocalContext.current
    val clipboardManager = LocalClipboardManager.current
    var showImportDialog by remember { mutableStateOf(false) }
    var mnemonicToView by remember { mutableStateOf<Pair<VaultWallet, List<String>>?>(null) }
    var ensWalletToManage by remember { mutableStateOf<VaultWallet?>(null) }

    Scaffold(
        containerColor = VaultBackground,
        topBar = {
            TopAppBar(
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = VaultBackground,
                    titleContentColor = VaultTextPrimary
                ),
                title = {
                    Text(
                        text = "Vaults & Keys",
                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold)
                    )
                },
                actions = {
                    IconButton(onClick = onCreateWallet) {
                        Icon(
                            imageVector = Icons.Default.Add,
                            contentDescription = "Create Vault",
                            tint = VaultCyan
                        )
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Button(
                        onClick = onCreateWallet,
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = VaultCyan),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Icon(imageVector = Icons.Default.Add, contentDescription = null, tint = Color.Black)
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("Create Vault", color = Color.Black, fontWeight = FontWeight.Bold)
                    }
                    OutlinedButton(
                        onClick = { showImportDialog = true },
                        modifier = Modifier.weight(1f),
                        border = androidx.compose.foundation.BorderStroke(1.dp, VaultBorder),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Icon(imageVector = Icons.Default.Download, contentDescription = null, tint = VaultTextPrimary)
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("Import Vault", color = VaultTextPrimary, fontWeight = FontWeight.Bold)
                    }
                }
            }

            items(wallets) { w ->
                val isSelected = w.id == selectedWalletId
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .border(1.dp, if (isSelected) VaultCyan else VaultBorder, RoundedCornerShape(16.dp))
                        .clickable { onSelectWallet(w) },
                    colors = CardDefaults.cardColors(containerColor = if (isSelected) VaultSurfaceVariant else VaultSurface)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            VaultIdenticon(address = w.address, size = 44.dp)
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        text = w.name,
                                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                                        color = VaultTextPrimary
                                    )
                                    if (isSelected) {
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Text(
                                            text = "ACTIVE",
                                            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                                            color = VaultCyan,
                                            modifier = Modifier
                                                .background(VaultCyan.copy(alpha = 0.15f), RoundedCornerShape(4.dp))
                                                .padding(horizontal = 6.dp, vertical = 2.dp)
                                        )
                                    }
                                }
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(
                                    text = "${w.address.take(8)}...${w.address.takeLast(6)}",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = VaultTextSecondary
                                )
                                w.importedEnsName?.let { ens ->
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        modifier = Modifier
                                            .clip(RoundedCornerShape(6.dp))
                                            .background(VaultCyan.copy(alpha = 0.15f))
                                            .border(0.5.dp, VaultCyan.copy(alpha = 0.4f), RoundedCornerShape(6.dp))
                                            .clickable { ensWalletToManage = w }
                                            .padding(horizontal = 6.dp, vertical = 2.dp)
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.AlternateEmail,
                                            contentDescription = "ENS Identity",
                                            tint = VaultCyan,
                                            modifier = Modifier.size(12.dp)
                                        )
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text(
                                            text = ens,
                                            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                                            color = VaultCyan
                                        )
                                    }
                                }
                            }
                        }

                        Row {
                            IconButton(
                                onClick = { ensWalletToManage = w }
                            ) {
                                Icon(
                                    imageVector = Icons.Default.AlternateEmail,
                                    contentDescription = "ENS Domain",
                                    tint = if (w.importedEnsName != null) VaultCyan else VaultTextSecondary,
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                            IconButton(
                                onClick = {
                                    clipboardManager.setText(AnnotatedString(w.address))
                                    Toast.makeText(context, "Address copied", Toast.LENGTH_SHORT).show()
                                }
                            ) {
                                Icon(
                                    imageVector = Icons.Default.ContentCopy,
                                    contentDescription = "Copy",
                                    tint = VaultTextSecondary,
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                            IconButton(
                                onClick = {
                                    val words = onViewMnemonic(w)
                                    if (words != null) {
                                        mnemonicToView = Pair(w, words)
                                    } else {
                                        Toast.makeText(context, "Recovery phrase not found", Toast.LENGTH_SHORT).show()
                                    }
                                }
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Key,
                                    contentDescription = "View Phrase",
                                    tint = VaultAmber,
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // Import Dialog
    if (showImportDialog) {
        var walletName by remember { mutableStateOf("") }
        var mnemonicInput by remember { mutableStateOf("") }

        AlertDialog(
            onDismissRequest = { showImportDialog = false },
            title = {
                Text(
                    text = "Import Existing Vault",
                    style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                    color = VaultTextPrimary
                )
            },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        text = "Enter your 12 or 24-word recovery phrase separated by spaces.",
                        style = MaterialTheme.typography.bodySmall,
                        color = VaultTextSecondary
                    )
                    OutlinedTextField(
                        value = walletName,
                        onValueChange = { walletName = it },
                        label = { Text("Vault Name (optional)") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                    OutlinedTextField(
                        value = mnemonicInput,
                        onValueChange = { mnemonicInput = it },
                        label = { Text("Recovery Phrase (12 or 24 words)") },
                        modifier = Modifier.fillMaxWidth().height(120.dp),
                        maxLines = 4
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val words = mnemonicInput.trim().split("\\s+".toRegex()).filter { it.isNotBlank() }
                        if (words.size in listOf(12, 15, 18, 21, 24)) {
                            val name = walletName.ifBlank { "Vault #${wallets.size + 1}" }
                            onImportWallet(name, words)
                            showImportDialog = false
                        } else {
                            Toast.makeText(context, "Please enter 12 or 24 words", Toast.LENGTH_SHORT).show()
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = VaultCyan)
                ) {
                    Text("Import", color = Color.Black, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showImportDialog = false }) {
                    Text("Cancel", color = VaultTextSecondary)
                }
            },
            containerColor = VaultBackground
        )
    }

    // View Recovery Phrase Sheet Dialog
    mnemonicToView?.let { (wallet, words) ->
        AlertDialog(
            onDismissRequest = { mnemonicToView = null },
            title = {
                Text(
                    text = "Recovery Phrase: ${wallet.name}",
                    style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                    color = VaultTextPrimary
                )
            },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Text(
                        text = "Never share these 12 words with anyone. Anyone with this phrase has full access to your funds.",
                        style = MaterialTheme.typography.bodySmall,
                        color = VaultAmber
                    )

                    // 2-column numbered word capsules
                    LazyVerticalGrid(
                        columns = GridCells.Fixed(2),
                        modifier = Modifier.fillMaxWidth().height(260.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        itemsIndexed(words) { index, word ->
                            Row(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(VaultSurfaceVariant)
                                    .border(1.dp, VaultBorder, RoundedCornerShape(8.dp))
                                    .padding(horizontal = 10.dp, vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "${index + 1}.",
                                    style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Bold),
                                    color = VaultTextMuted,
                                    modifier = Modifier.width(24.dp)
                                )
                                Text(
                                    text = word,
                                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                                    color = VaultTextPrimary
                                )
                            }
                        }
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = { mnemonicToView = null },
                    colors = ButtonDefaults.buttonColors(containerColor = VaultCyan)
                ) {
                    Text("I've Saved It", color = Color.Black, fontWeight = FontWeight.Bold)
                }
            },
            containerColor = VaultBackground
        )
    }

    // ENS Management Dialog
    ensWalletToManage?.let { wallet ->
        ENSManagementDialog(
            wallet = wallet,
            onDismiss = { ensWalletToManage = null },
            onSetEns = { ensName ->
                onSetImportedEns(wallet.id, ensName)
            }
        )
    }
}

@Composable
fun ENSManagementDialog(
    wallet: VaultWallet,
    onDismiss: () -> Unit,
    onSetEns: (String?) -> Unit
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    var selectedTab by remember { mutableStateOf(0) } // 0: Buy .eth, 1: Import ENS

    // Buy Tab State
    var buySearchName by remember { mutableStateOf("") }

    // Import Tab State
    var importEnsName by remember { mutableStateOf("") }
    var isVerifying by remember { mutableStateOf(false) }
    var verificationStatus by remember { mutableStateOf<String?>(null) }
    var resolvedAddress by remember { mutableStateOf<String?>(null) }
    var statusIsError by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.AlternateEmail,
                        contentDescription = null,
                        tint = VaultCyan,
                        modifier = Modifier.size(24.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "ENS Identity (.eth)",
                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                        color = VaultTextPrimary
                    )
                }
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "Vault: ${wallet.name} (${wallet.address.take(6)}...${wallet.address.takeLast(4)})",
                    style = MaterialTheme.typography.bodySmall,
                    color = VaultTextSecondary
                )
            }
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                // Currently linked handle badge
                if (wallet.importedEnsName != null) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(10.dp))
                            .background(VaultCyan.copy(alpha = 0.12f))
                            .border(1.dp, VaultCyan.copy(alpha = 0.3f), RoundedCornerShape(10.dp))
                            .padding(10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column {
                            Text("Active ENS Handle", style = MaterialTheme.typography.labelSmall, color = VaultTextMuted)
                            Text(
                                text = "@${wallet.importedEnsName}",
                                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                                color = VaultCyan
                            )
                        }
                        TextButton(
                            onClick = {
                                onSetEns(null)
                                Toast.makeText(context, "ENS unlinked", Toast.LENGTH_SHORT).show()
                                onDismiss()
                            }
                        ) {
                            Text("Unlink", color = VaultRose, fontWeight = FontWeight.Bold)
                        }
                    }
                }

                // Tab Switcher
                TabRow(
                    selectedTabIndex = selectedTab,
                    containerColor = VaultSurfaceVariant,
                    contentColor = VaultCyan,
                    modifier = Modifier.clip(RoundedCornerShape(10.dp))
                ) {
                    Tab(
                        selected = selectedTab == 0,
                        onClick = { selectedTab = 0 },
                        text = { Text("Buy .eth", fontWeight = FontWeight.Bold) }
                    )
                    Tab(
                        selected = selectedTab == 1,
                        onClick = { selectedTab = 1 },
                        text = { Text("Import ENS", fontWeight = FontWeight.Bold) }
                    )
                }

                if (selectedTab == 0) {
                    // BUY .ETH TAB
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(
                            text = "Register an on-chain .eth identity via the official ENS Registrar.",
                            style = MaterialTheme.typography.bodySmall,
                            color = VaultTextSecondary
                        )
                        OutlinedTextField(
                            value = buySearchName,
                            onValueChange = { buySearchName = it },
                            label = { Text("Desired name (e.g. satoshi)") },
                            trailingIcon = {
                                Text(".eth", color = VaultCyan, modifier = Modifier.padding(end = 12.dp), fontWeight = FontWeight.Bold)
                            },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth()
                        )

                        val cleanBuyName = ENSUtils.normalizeENSName(buySearchName)
                        val charCount = cleanBuyName.removeSuffix(".eth").length
                        val estCost = ENSUtils.estimateAnnualCost(cleanBuyName)

                        Card(
                            colors = CardDefaults.cardColors(containerColor = VaultSurfaceVariant),
                            modifier = Modifier.fillMaxWidth().border(1.dp, VaultBorder, RoundedCornerShape(10.dp))
                        ) {
                            Column(modifier = Modifier.padding(10.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text("Estimated Fee", style = MaterialTheme.typography.bodySmall, color = VaultTextMuted)
                                    Text(
                                        text = if (charCount < 3) "Min 3 chars" else "~$estCost ETH / yr",
                                        style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Bold),
                                        color = if (charCount < 3) VaultAmber else VaultEmerald
                                    )
                                }
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text("Pricing Tier", style = MaterialTheme.typography.labelSmall, color = VaultTextMuted)
                                    Text(
                                        text = when {
                                            charCount == 0 -> "Enter a name"
                                            charCount < 3 -> "Unavailable (< 3 chars)"
                                            charCount == 3 -> "3-char tier (~$640/yr)"
                                            charCount == 4 -> "4-char tier (~$160/yr)"
                                            else -> "5+ char tier (~$5/yr)"
                                        },
                                        style = MaterialTheme.typography.labelSmall,
                                        color = VaultTextSecondary
                                    )
                                }
                            }
                        }

                        Button(
                            onClick = {
                                if (charCount < 3) {
                                    Toast.makeText(context, "Domain name must be at least 3 characters", Toast.LENGTH_SHORT).show()
                                } else {
                                    val url = ENSUtils.registrationUrl(cleanBuyName)
                                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                                    context.startActivity(intent)
                                }
                            },
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(containerColor = VaultCyan),
                            shape = RoundedCornerShape(10.dp)
                        ) {
                            Icon(imageVector = Icons.Default.Language, contentDescription = null, tint = Color.Black)
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Open ENS Registrar", color = Color.Black, fontWeight = FontWeight.Bold)
                        }

                        if (charCount >= 3) {
                            OutlinedButton(
                                onClick = {
                                    onSetEns(cleanBuyName)
                                    Toast.makeText(context, "Linked $cleanBuyName to vault", Toast.LENGTH_SHORT).show()
                                    onDismiss()
                                },
                                modifier = Modifier.fillMaxWidth(),
                                border = androidx.compose.foundation.BorderStroke(1.dp, VaultBorder),
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                Text("Link as Vault Alias", color = VaultTextPrimary, fontWeight = FontWeight.SemiBold)
                            }
                        }
                    }
                } else {
                    // IMPORT ENS TAB
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(
                            text = "Import and link any ENS domain you already own to your sovereign vault.",
                            style = MaterialTheme.typography.bodySmall,
                            color = VaultTextSecondary
                        )
                        OutlinedTextField(
                            value = importEnsName,
                            onValueChange = {
                                importEnsName = it
                                verificationStatus = null
                                resolvedAddress = null
                            },
                            label = { Text("ENS Domain (e.g. vitalik.eth)") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth()
                        )

                        if (verificationStatus != null) {
                            Text(
                                text = verificationStatus ?: "",
                                style = MaterialTheme.typography.bodySmall,
                                color = if (statusIsError) VaultRose else VaultEmerald
                            )
                        }

                        if (resolvedAddress != null) {
                            Text(
                                text = "Resolves to: ${resolvedAddress?.take(8)}...${resolvedAddress?.takeLast(6)}",
                                style = MaterialTheme.typography.labelSmall,
                                color = VaultTextMuted
                            )
                        }

                        Button(
                            onClick = {
                                val clean = ENSUtils.normalizeENSName(importEnsName)
                                if (clean.removeSuffix(".eth").length < 3) {
                                    Toast.makeText(context, "Enter a valid ENS name", Toast.LENGTH_SHORT).show()
                                    return@Button
                                }
                                isVerifying = true
                                verificationStatus = "Querying Ethereum JSON-RPC..."
                                statusIsError = false

                                coroutineScope.launch {
                                    try {
                                        val rpc = EthereumRPC(BlockchainNetwork.Ethereum)
                                        val resolved = rpc.resolveENS(clean)
                                        isVerifying = false
                                        if (resolved != null) {
                                            resolvedAddress = resolved
                                            val isMatch = resolved.equals(wallet.address, ignoreCase = true)
                                            if (isMatch) {
                                                verificationStatus = "Verified on-chain! Domain matches vault address."
                                                statusIsError = false
                                                onSetEns(clean)
                                                Toast.makeText(context, "Linked $clean to vault", Toast.LENGTH_SHORT).show()
                                                onDismiss()
                                            } else {
                                                verificationStatus = "Verified on-chain. Warning: Points to $resolved instead of current vault address."
                                                statusIsError = false
                                            }
                                        } else {
                                            verificationStatus = "Domain not found or forward record is empty."
                                            statusIsError = true
                                        }
                                    } catch (e: Exception) {
                                        isVerifying = false
                                        verificationStatus = "RPC check failed: ${e.message}"
                                        statusIsError = true
                                    }
                                }
                            },
                            enabled = !isVerifying,
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(containerColor = VaultCyan),
                            shape = RoundedCornerShape(10.dp)
                        ) {
                            if (isVerifying) {
                                CircularProgressIndicator(modifier = Modifier.size(18.dp), color = Color.Black, strokeWidth = 2.dp)
                                Spacer(modifier = Modifier.width(8.dp))
                                Text("Verifying...", color = Color.Black, fontWeight = FontWeight.Bold)
                            } else {
                                Icon(imageVector = Icons.Default.CheckCircle, contentDescription = null, tint = Color.Black)
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Verify & Link Domain", color = Color.Black, fontWeight = FontWeight.Bold)
                            }
                        }

                        if (resolvedAddress != null && !resolvedAddress.equals(wallet.address, ignoreCase = true)) {
                            OutlinedButton(
                                onClick = {
                                    val clean = ENSUtils.normalizeENSName(importEnsName)
                                    onSetEns(clean)
                                    Toast.makeText(context, "Linked $clean as custom identity", Toast.LENGTH_SHORT).show()
                                    onDismiss()
                                },
                                modifier = Modifier.fillMaxWidth(),
                                border = androidx.compose.foundation.BorderStroke(1.dp, VaultBorder),
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                Text("Link Anyway as Custom Handle", color = VaultAmber, fontWeight = FontWeight.SemiBold)
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {},
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Close", color = VaultTextSecondary)
            }
        },
        containerColor = VaultBackground
    )
}

