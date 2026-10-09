package com.vaulteth.app.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DeleteSweep
import androidx.compose.material.icons.filled.OpenInNew
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.vaulteth.app.core.BlockchainNetwork
import com.vaulteth.app.core.SentTransaction
import com.vaulteth.app.core.TransactionStatus
import com.vaulteth.app.ui.components.VaultIdenticon
import com.vaulteth.app.ui.theme.*
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ActivityScreen(
    transactions: List<SentTransaction>,
    selectedNetwork: BlockchainNetwork,
    onClearHistory: () -> Unit
) {
    val context = LocalContext.current
    var filterIndex by remember { mutableStateOf(0) } // 0: All, 1: Confirmed, 2: Pending
    var showClearDialog by remember { mutableStateOf(false) }

    val filteredList = remember(transactions, filterIndex) {
        when (filterIndex) {
            1 -> transactions.filter { it.status == TransactionStatus.CONFIRMED }
            2 -> transactions.filter { it.status == TransactionStatus.PENDING }
            else -> transactions
        }
    }

    val dateFormat = remember { SimpleDateFormat("MMM d, yyyy • HH:mm", Locale.getDefault()) }

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
                        text = "Activity",
                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold)
                    )
                },
                actions = {
                    if (transactions.isNotEmpty()) {
                        IconButton(onClick = { showClearDialog = true }) {
                            Icon(
                                imageVector = Icons.Default.DeleteSweep,
                                contentDescription = "Clear History",
                                tint = VaultTextSecondary
                            )
                        }
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Filter Pills
            TabRow(
                selectedTabIndex = filterIndex,
                containerColor = VaultSurface,
                contentColor = VaultCyan,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .border(1.dp, VaultBorder, RoundedCornerShape(12.dp))
            ) {
                listOf("All", "Confirmed", "Pending").forEachIndexed { index, title ->
                    Tab(
                        selected = filterIndex == index,
                        onClick = { filterIndex = index },
                        text = {
                            Text(
                                text = title,
                                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                                color = if (filterIndex == index) VaultCyan else VaultTextMuted
                            )
                        }
                    )
                }
            }

            if (filteredList.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "No transactions in this category.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = VaultTextMuted
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(filteredList) { tx ->
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .border(1.dp, VaultBorder, RoundedCornerShape(16.dp))
                                .clickable {
                                    if (tx.hash.isNotBlank()) {
                                        val explorerUrl = "${selectedNetwork.explorerTxUrl}${tx.hash}"
                                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(explorerUrl))
                                        context.startActivity(intent)
                                    }
                                },
                            colors = CardDefaults.cardColors(containerColor = VaultSurface)
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(16.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    VaultIdenticon(address = tx.recipient, size = 40.dp)
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Column {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Text(
                                                text = "To: ${tx.recipient.take(6)}...${tx.recipient.takeLast(4)}",
                                                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                                                color = VaultTextPrimary
                                            )
                                            Spacer(modifier = Modifier.width(6.dp))
                                            Icon(
                                                imageVector = Icons.Default.OpenInNew,
                                                contentDescription = "View on Explorer",
                                                tint = VaultTextMuted,
                                                modifier = Modifier.size(14.dp)
                                            )
                                        }
                                        Spacer(modifier = Modifier.height(2.dp))
                                        Text(
                                            text = dateFormat.format(Date(tx.timestamp)),
                                            style = MaterialTheme.typography.bodySmall,
                                            color = VaultTextMuted
                                        )
                                    }
                                }

                                Column(horizontalAlignment = Alignment.End) {
                                    Text(
                                        text = "-${tx.amount} ETH",
                                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                                        color = VaultTextPrimary
                                    )
                                    Spacer(modifier = Modifier.height(2.dp))
                                    Text(
                                        text = tx.status.name,
                                        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                                        color = when (tx.status) {
                                            TransactionStatus.CONFIRMED -> VaultEmerald
                                            TransactionStatus.PENDING -> VaultAmber
                                            TransactionStatus.FAILED -> MaterialTheme.colorScheme.error
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (showClearDialog) {
        AlertDialog(
            onDismissRequest = { showClearDialog = false },
            title = { Text("Clear Local History?", color = VaultTextPrimary) },
            text = { Text("This will only clear the local transaction logs on this device. On-chain history is permanent.", color = VaultTextSecondary) },
            confirmButton = {
                TextButton(onClick = {
                    onClearHistory()
                    showClearDialog = false
                }) {
                    Text("Clear", color = MaterialTheme.colorScheme.error, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showClearDialog = false }) {
                    Text("Cancel", color = VaultTextSecondary)
                }
            },
            containerColor = VaultBackground
        )
    }
}
