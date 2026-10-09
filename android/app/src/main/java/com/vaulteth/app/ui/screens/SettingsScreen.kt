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
import androidx.compose.runtime.Composable
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
                            onClick = {
                                val url = "https://github.com/ganiyucall911/VaultETH/blob/main/PRIVACY_POLICY.md"
                                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                            }
                        )
                        HorizontalDivider(color = VaultBorder)
                        SettingsRow(
                            icon = Icons.Default.HelpOutline,
                            title = "Support & FAQ",
                            onClick = {
                                val url = "https://github.com/ganiyucall911/VaultETH/blob/main/SUPPORT.md"
                                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                            }
                        )
                        HorizontalDivider(color = VaultBorder)
                        SettingsRow(
                            icon = Icons.Default.Code,
                            title = "GitHub Repository",
                            onClick = {
                                val url = "https://github.com/ganiyucall911/VaultETH"
                                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                            }
                        )
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
