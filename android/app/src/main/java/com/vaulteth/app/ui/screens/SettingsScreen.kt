package com.vaulteth.app.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.vaulteth.app.core.BlockchainNetwork
import com.vaulteth.app.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    selectedNetwork: BlockchainNetwork
) {
    val context = LocalContext.current

    var showPrivacyDialog by remember { mutableStateOf(false) }
    var showSupportDialog by remember { mutableStateOf(false) }

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
                        text = "Settings",
                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold)
                    )
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
            // Section: Network & Nodes
            item {
                Text(
                    text = "NETWORK & RPC",
                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                    color = VaultTextMuted
                )
            }
            item {
                Card(
                    modifier = Modifier.fillMaxWidth().border(1.dp, VaultBorder, RoundedCornerShape(16.dp)),
                    colors = CardDefaults.cardColors(containerColor = VaultSurface)
                ) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text("Active Network", color = VaultTextSecondary)
                            Text(selectedNetwork.name, fontWeight = FontWeight.SemiBold, color = VaultTextPrimary)
                        }
                        HorizontalDivider(color = VaultBorder)
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text("Chain ID", color = VaultTextSecondary)
                            Text("${selectedNetwork.chainId}", fontWeight = FontWeight.SemiBold, color = VaultTextPrimary)
                        }
                        HorizontalDivider(color = VaultBorder)
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text("Primary RPC", color = VaultTextSecondary)
                            Text(
                                text = selectedNetwork.rpcUrls.firstOrNull()?.replace("https://", "")?.take(24) ?: "Default",
                                color = VaultCyan,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }
                }
            }

            // Section: Security
            item {
                Text(
                    text = "SECURITY & STORAGE",
                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                    color = VaultTextMuted
                )
            }
            item {
                Card(
                    modifier = Modifier.fillMaxWidth().border(1.dp, VaultBorder, RoundedCornerShape(16.dp)),
                    colors = CardDefaults.cardColors(containerColor = VaultSurface)
                ) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text("Storage Architecture", color = VaultTextSecondary)
                            Text("Android Keystore AES-256", fontWeight = FontWeight.SemiBold, color = VaultEmerald)
                        }
                        HorizontalDivider(color = VaultBorder)
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text("Cloud Backup", color = VaultTextSecondary)
                            Text("Disabled (Zero Cloud Leak)", fontWeight = FontWeight.SemiBold, color = VaultCyan)
                        }
                    }
                }
            }

            // Section: Web3 Domain Identity
            item {
                Text(
                    text = "WEB3 DOMAIN IDENTITY",
                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                    color = VaultTextMuted
                )
            }
            item {
                Card(
                    modifier = Modifier.fillMaxWidth().border(1.dp, VaultBorder, RoundedCornerShape(16.dp)),
                    colors = CardDefaults.cardColors(containerColor = VaultSurface)
                ) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text("ENS Domain (.eth)", fontWeight = FontWeight.SemiBold, color = VaultTextPrimary)
                                Text("Decentralized human-readable name", style = MaterialTheme.typography.bodySmall, color = VaultTextSecondary)
                            }
                            OutlinedButton(
                                onClick = {
                                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://app.ens.domains"))
                                    context.startActivity(intent)
                                },
                                border = androidx.compose.foundation.BorderStroke(1.dp, VaultCyan.copy(alpha = 0.5f)),
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Text("ENS App", color = VaultCyan, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.labelMedium)
                            }
                        }
                        HorizontalDivider(color = VaultBorder)
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text("Resolution Protocol", color = VaultTextSecondary)
                            Text("Direct On-Chain (EIP-137)", fontWeight = FontWeight.SemiBold, color = VaultEmerald)
                        }
                        HorizontalDivider(color = VaultBorder)
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text("Vault Management", color = VaultTextSecondary)
                            Text("Manage in Wallets Tab", fontWeight = FontWeight.SemiBold, color = VaultTextPrimary)
                        }
                    }
                }
            }

            // Section: Legal & Support
            item {
                Text(
                    text = "LEGAL & ABOUT",
                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                    color = VaultTextMuted
                )
            }
            item {
                Card(
                    modifier = Modifier.fillMaxWidth().border(1.dp, VaultBorder, RoundedCornerShape(16.dp)),
                    colors = CardDefaults.cardColors(containerColor = VaultSurface)
                ) {
                    Column {
                        SettingsRow(
                            icon = Icons.Default.PrivacyTip,
                            title = "Privacy Policy",
                            onClick = { showPrivacyDialog = true }
                        )
                        HorizontalDivider(color = VaultBorder)
                        SettingsRow(
                            icon = Icons.Default.HelpOutline,
                            title = "Support & FAQ",
                            onClick = { showSupportDialog = true }
                        )
                        HorizontalDivider(color = VaultBorder)
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(16.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("Developer", color = VaultTextSecondary)
                            Text("vault.", fontWeight = FontWeight.SemiBold, color = VaultTextPrimary)
                        }
                    }
                }
            }

            item {
                Box(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "VaultETH v1.0.0 (Build 1) • Sovereign Edition",
                        style = MaterialTheme.typography.bodySmall,
                        color = VaultTextMuted
                    )
                }
            }
        }

        if (showPrivacyDialog) {
            AlertDialog(
                onDismissRequest = { showPrivacyDialog = false },
                title = { Text("Privacy Policy", color = VaultTextPrimary, fontWeight = FontWeight.Bold) },
                text = {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Developer: vault.", color = VaultCyan, style = MaterialTheme.typography.bodySmall)
                        Text(
                            "• Zero Personal Data: VaultETH collects no personal information, analytics, or identifiers.\n\n" +
                            "• Hardware Keystore: All keys and recovery phrases are stored exclusively in the Android Keystore with AES-256 GCM encryption.\n\n" +
                            "• Decentralized RPC: Network queries connect directly to public Ethereum JSON-RPC nodes with zero middlemen.\n\n" +
                            "• No Cloud Sync: Keys never leave this physical device.",
                            color = VaultTextSecondary,
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                },
                confirmButton = {
                    TextButton(onClick = { showPrivacyDialog = false }) {
                        Text("Done", color = VaultCyan, fontWeight = FontWeight.Bold)
                    }
                },
                containerColor = VaultSurface
            )
        }

        if (showSupportDialog) {
            AlertDialog(
                onDismissRequest = { showSupportDialog = false },
                title = { Text("Support & FAQ", color = VaultTextPrimary, fontWeight = FontWeight.Bold) },
                text = {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Developer: vault.", color = VaultCyan, style = MaterialTheme.typography.bodySmall)
                        Text(
                            "1. What is non-custodial?\nYou alone hold the keys to your funds. No central entity or developer can access your wallet.\n\n" +
                            "2. Can my wallet be recovered if I lose my phrase?\nNo. Because your keys are generated locally in the Android Keystore, no one can recover a lost phrase. Always keep offline backups.\n\n" +
                            "3. Are there platform fees?\nZero fees. Network gas fees go 100% to blockchain validators.",
                            color = VaultTextSecondary,
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                },
                confirmButton = {
                    TextButton(onClick = { showSupportDialog = false }) {
                        Text("Done", color = VaultCyan, fontWeight = FontWeight.Bold)
                    }
                },
                containerColor = VaultSurface
            )
        }
    }
}

@Composable
fun SettingsRow(
    icon: ImageVector,
    title: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(imageVector = icon, contentDescription = null, tint = VaultTextSecondary, modifier = Modifier.size(20.dp))
            Spacer(modifier = Modifier.width(12.dp))
            Text(text = title, style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold), color = VaultTextPrimary)
        }
        Icon(imageVector = Icons.Default.ChevronRight, contentDescription = null, tint = VaultTextMuted, modifier = Modifier.size(20.dp))
    }
}
