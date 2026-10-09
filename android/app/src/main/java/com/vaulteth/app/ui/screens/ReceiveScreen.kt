package com.vaulteth.app.ui.screens

import android.content.Intent
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Share
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.vaulteth.app.core.VaultWallet
import com.vaulteth.app.ui.components.QRCodeImage
import com.vaulteth.app.ui.components.VaultIdenticon
import com.vaulteth.app.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReceiveScreen(
    wallet: VaultWallet?,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val clipboardManager = LocalClipboardManager.current
    var selectedChainIndex by remember { mutableStateOf(0) } // 0: EVM, 1: Solana, 2: Bitcoin

    val chains = listOf("EVM Chains", "Solana", "Bitcoin")
    val activeAddress = when (selectedChainIndex) {
        0 -> wallet?.address ?: ""
        1 -> wallet?.solanaAddress?.ifBlank { wallet.address } ?: ""
        else -> wallet?.bitcoinAddress?.ifBlank { wallet.address } ?: ""
    }

    val chainNotice = when (selectedChainIndex) {
        0 -> "Compatible with Ethereum, Arbitrum, Base, Optimism, Polygon, BNB Chain, Avalanche, and all EVM networks."
        1 -> "Direct deposits to your derived Solana address."
        else -> "Native SegWit Bitcoin address (bc1q)."
    }

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
                        text = "Receive Assets",
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
                .padding(horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // Segmented 3-Way Tabs
            TabRow(
                selectedTabIndex = selectedChainIndex,
                containerColor = VaultSurface,
                contentColor = VaultCyan,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .border(1.dp, VaultBorder, RoundedCornerShape(12.dp))
            ) {
                chains.forEachIndexed { index, title ->
                    Tab(
                        selected = selectedChainIndex == index,
                        onClick = { selectedChainIndex = index },
                        text = {
                            Text(
                                text = title,
                                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                                color = if (selectedChainIndex == index) VaultCyan else VaultTextMuted
                            )
                        }
                    )
                }
            }

            // QR Card Pass
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(24.dp))
                    .border(1.dp, VaultBorder, RoundedCornerShape(24.dp)),
                colors = CardDefaults.cardColors(containerColor = VaultSurface)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    if (selectedChainIndex == 0 && activeAddress.isNotBlank()) {
                        VaultIdenticon(address = activeAddress, size = 52.dp)
                        Spacer(modifier = Modifier.height(16.dp))
                    }

                    Box(
                        modifier = Modifier
                            .background(Color.White, RoundedCornerShape(16.dp))
                            .padding(12.dp)
                    ) {
                        if (activeAddress.isNotBlank()) {
                            QRCodeImage(content = activeAddress, size = 200.dp)
                        }
                    }

                    Spacer(modifier = Modifier.height(20.dp))

                    Text(
                        text = activeAddress,
                        style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium),
                        color = VaultTextPrimary,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .clip(RoundedCornerShape(10.dp))
                            .background(VaultSurfaceVariant)
                            .border(1.dp, VaultBorder, RoundedCornerShape(10.dp))
                            .clickable {
                                clipboardManager.setText(AnnotatedString(activeAddress))
                                Toast.makeText(context, "Address copied to clipboard", Toast.LENGTH_SHORT).show()
                            }
                            .padding(horizontal = 14.dp, vertical = 10.dp)
                    )

                    Spacer(modifier = Modifier.height(14.dp))

                    Text(
                        text = chainNotice,
                        style = MaterialTheme.typography.bodySmall,
                        color = VaultTextSecondary,
                        textAlign = TextAlign.Center
                    )
                }
            }

            // Action Buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Button(
                    onClick = {
                        clipboardManager.setText(AnnotatedString(activeAddress))
                        Toast.makeText(context, "Address copied to clipboard", Toast.LENGTH_SHORT).show()
                    },
                    modifier = Modifier.weight(1f).height(50.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = VaultCyan),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(imageVector = Icons.Default.ContentCopy, contentDescription = null, tint = Color.Black)
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Copy", color = Color.Black, fontWeight = FontWeight.Bold)
                }

                OutlinedButton(
                    onClick = {
                        val sendIntent = Intent().apply {
                            action = Intent.ACTION_SEND
                            putExtra(Intent.EXTRA_TEXT, activeAddress)
                            type = "text/plain"
                        }
                        context.startActivity(Intent.createChooser(sendIntent, "Share Deposit Address"))
                    },
                    modifier = Modifier.weight(1f).height(50.dp),
                    border = androidx.compose.foundation.BorderStroke(1.dp, VaultBorder),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(imageVector = Icons.Default.Share, contentDescription = null, tint = VaultTextPrimary)
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Share", color = VaultTextPrimary, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}
