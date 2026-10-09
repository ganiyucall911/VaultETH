package com.vaulteth.app.ui.screens

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
import com.vaulteth.app.core.VaultWallet
import com.vaulteth.app.ui.components.VaultIdenticon
import com.vaulteth.app.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WalletsScreen(
    wallets: List<VaultWallet>,
    selectedWalletId: String?,
    onSelectWallet: (VaultWallet) -> Unit,
    onCreateWallet: () -> Unit,
    onImportWallet: (String, List<String>) -> Unit,
    onDeleteWallet: (VaultWallet) -> Unit,
    onViewMnemonic: (VaultWallet) -> List<String>?
) {
    val context = LocalContext.current
    val clipboardManager = LocalClipboardManager.current
    var showImportDialog by remember { mutableStateOf(false) }
    var mnemonicToView by remember { mutableStateOf<Pair<VaultWallet, List<String>>?>(null) }

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
                            }
                        }

                        Row {
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
}
