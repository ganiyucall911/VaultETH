package com.vaulteth.app.ui.screens

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.vaulteth.app.core.BlockchainNetwork
import com.vaulteth.app.core.VaultWallet
import com.vaulteth.app.core.WalletEngine
import com.vaulteth.app.ui.components.VaultIdenticon
import com.vaulteth.app.ui.theme.*
import java.math.BigDecimal

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SendScreen(
    wallet: VaultWallet?,
    network: BlockchainNetwork,
    balance: String,
    onBack: () -> Unit,
    onOpenScanner: () -> Unit,
    onSendTransaction: (recipient: String, amount: String, onComplete: (Boolean, String) -> Unit) -> Unit
) {
    val context = LocalContext.current
    val clipboardManager = LocalClipboardManager.current

    var recipient by remember { mutableStateOf("") }
    var amount by remember { mutableStateOf("") }
    var isSubmitting by remember { mutableStateOf(false) }
    var showReviewDialog by remember { mutableStateOf(false) }

    val isValidRecipient = WalletEngine.isValidAddress(recipient) || recipient.endsWith(".eth", ignoreCase = true)
    val parsedAmount = amount.toDoubleOrNull()
    val balanceDouble = balance.toDoubleOrNull() ?: 0.0
    val isValidAmount = parsedAmount != null && parsedAmount > 0 && parsedAmount <= balanceDouble

    Scaffold(
        containerColor = VaultBackground,
        topBar = {
            TopAppBar(
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = VaultBackground,
                    titleContentColor = VaultTextPrimary
                ),
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(imageVector = Icons.Default.ArrowBack, contentDescription = "Back", tint = VaultTextPrimary)
                    }
                },
                title = {
                    Text(
                        text = "Send ${network.symbol}",
                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold)
                    )
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
            // Network & Balance Banner
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, VaultBorder, RoundedCornerShape(12.dp)),
                colors = CardDefaults.cardColors(containerColor = VaultSurface)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(Color(network.accentHex))
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = network.name,
                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                            color = VaultTextPrimary
                        )
                    }
                    Text(
                        text = "Available: $balance ${network.symbol}",
                        style = MaterialTheme.typography.bodySmall,
                        color = VaultTextSecondary
                    )
                }
            }

            // Recipient Field
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = "Recipient Address or ENS",
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                    color = VaultTextSecondary
                )
                OutlinedTextField(
                    value = recipient,
                    onValueChange = { recipient = it.trim() },
                    placeholder = { Text("0x... or name.eth", color = VaultTextMuted) },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = VaultCyan,
                        unfocusedBorderColor = VaultBorder,
                        focusedContainerColor = VaultSurface,
                        unfocusedContainerColor = VaultSurface
                    ),
                    leadingIcon = {
                        if (recipient.isNotBlank()) {
                            VaultIdenticon(address = recipient, size = 28.dp)
                        } else {
                            Icon(imageVector = Icons.Default.Person, contentDescription = null, tint = VaultTextMuted)
                        }
                    },
                    trailingIcon = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            IconButton(onClick = {
                                val text = clipboardManager.getText()?.text
                                if (!text.isNullOrBlank()) {
                                    val uri = WalletEngine.parsePaymentURI(text)
                                    if (uri != null) {
                                        recipient = uri.recipient
                                        uri.amountEth?.let { amount = it }
                                    } else {
                                        recipient = text.trim()
                                    }
                                }
                            }) {
                                Icon(imageVector = Icons.Default.ContentPaste, contentDescription = "Paste", tint = VaultCyan)
                            }
                            IconButton(onClick = onOpenScanner) {
                                Icon(imageVector = Icons.Default.QrCodeScanner, contentDescription = "Scan", tint = VaultCyan)
                            }
                        }
                    }
                )
            }

            // Amount Field
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = "Amount",
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                    color = VaultTextSecondary
                )
                OutlinedTextField(
                    value = amount,
                    onValueChange = { amount = it.trim() },
                    placeholder = { Text("0.0", color = VaultTextMuted) },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = VaultCyan,
                        unfocusedBorderColor = VaultBorder,
                        focusedContainerColor = VaultSurface,
                        unfocusedContainerColor = VaultSurface
                    ),
                    trailingIcon = {
                        Text(
                            text = network.symbol,
                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                            color = VaultTextSecondary,
                            modifier = Modifier.padding(end = 12.dp)
                        )
                    }
                )

                // Percentage Chips
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    val presets = listOf(25, 50, 75, 100)
                    for (pct in presets) {
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(8.dp))
                                .background(VaultSurfaceVariant)
                                .border(1.dp, VaultBorder, RoundedCornerShape(8.dp))
                                .clickable {
                                    if (balanceDouble > 0) {
                                        val calculated = if (pct == 100) {
                                            // Keep headroom for gas fee (approx 0.002)
                                            maxOf(0.0, balanceDouble - 0.002)
                                        } else {
                                            balanceDouble * (pct / 100.0)
                                        }
                                        amount = BigDecimal(calculated).setScale(4, java.math.RoundingMode.DOWN).toPlainString()
                                    }
                                }
                                .padding(vertical = 8.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = if (pct == 100) "Max" else "$pct%",
                                style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
                                color = VaultCyan
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            // Review & Send Button
            Button(
                onClick = { showReviewDialog = true },
                enabled = isValidRecipient && isValidAmount && !isSubmitting,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(54.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = VaultCyan,
                    disabledContainerColor = VaultBorder
                )
            ) {
                if (isSubmitting) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp), color = Color.Black)
                } else {
                    Text(
                        text = "Review Transfer",
                        color = Color.Black,
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold)
                    )
                }
            }
        }
    }

    // Biometric / Authorization Review Dialog
    if (showReviewDialog) {
        AlertDialog(
            onDismissRequest = { if (!isSubmitting) showReviewDialog = false },
            title = {
                Text(
                    text = "Authorize Transfer",
                    style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                    color = VaultTextPrimary
                )
            },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        text = "Please verify the details before signing on-chain:",
                        style = MaterialTheme.typography.bodySmall,
                        color = VaultTextSecondary
                    )

                    Card(
                        colors = CardDefaults.cardColors(containerColor = VaultSurfaceVariant),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text("Amount", color = VaultTextMuted)
                                Text("$amount ${network.symbol}", fontWeight = FontWeight.Bold, color = VaultTextPrimary)
                            }
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text("Network", color = VaultTextMuted)
                                Text(network.name, color = VaultTextPrimary)
                            }
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text("Recipient", color = VaultTextMuted)
                                Text("${recipient.take(6)}...${recipient.takeLast(4)}", color = VaultCyan)
                            }
                        }
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        isSubmitting = true
                        onSendTransaction(recipient, amount) { success, message ->
                            isSubmitting = false
                            showReviewDialog = false
                            if (success) {
                                Toast.makeText(context, "Transaction Broadcast: $message", Toast.LENGTH_LONG).show()
                                onBack()
                            } else {
                                Toast.makeText(context, "Failed: $message", Toast.LENGTH_LONG).show()
                            }
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = VaultCyan)
                ) {
                    Text("Sign & Broadcast", color = Color.Black, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showReviewDialog = false }, enabled = !isSubmitting) {
                    Text("Cancel", color = VaultTextSecondary)
                }
            },
            containerColor = VaultBackground
        )
    }
}
