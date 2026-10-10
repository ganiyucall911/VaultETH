package com.vaulteth.app.ui.screens

import android.widget.Toast
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
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
import androidx.compose.ui.unit.sp
import com.vaulteth.app.core.BlockchainNetwork
import com.vaulteth.app.core.DefaultTokenAssets
import com.vaulteth.app.core.SentTransaction
import com.vaulteth.app.core.TokenItem
import com.vaulteth.app.core.VaultWallet
import com.vaulteth.app.ui.components.VaultIdenticon
import com.vaulteth.app.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VaultHomeScreen(
    wallet: VaultWallet?,
    selectedNetwork: BlockchainNetwork,
    balance: String,
    isLoadingBalance: Boolean,
    recentTransactions: List<SentTransaction>,
    onSelectNetwork: (BlockchainNetwork) -> Unit,
    onRefresh: () -> Unit,
    onNavigateToSend: () -> Unit,
    onNavigateToReceive: () -> Unit,
    onNavigateToScan: () -> Unit,
    onNavigateToWallets: () -> Unit
) {
    val context = LocalContext.current
    val clipboardManager = LocalClipboardManager.current
    var isDiscreetMode by remember { mutableStateOf(false) }
    var showNetworkDialog by remember { mutableStateOf(false) }
    var showBuyDialog by remember { mutableStateOf(false) }

    Scaffold(
        containerColor = VaultBackground,
        topBar = {
            TopAppBar(
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = VaultBackground,
                    titleContentColor = VaultTextPrimary
                ),
                title = {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .clip(RoundedCornerShape(20.dp))
                            .background(VaultSurfaceVariant)
                            .border(1.dp, VaultBorder, RoundedCornerShape(20.dp))
                            .clickable { showNetworkDialog = true }
                            .padding(horizontal = 12.dp, vertical = 6.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(Color(selectedNetwork.accentHex))
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = selectedNetwork.name,
                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                            color = VaultTextPrimary
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Icon(
                            imageVector = Icons.Default.ArrowDropDown,
                            contentDescription = "Select Network",
                            tint = VaultTextSecondary,
                            modifier = Modifier.size(18.dp)
                        )
                    }
                },
                actions = {
                    IconButton(onClick = { isDiscreetMode = !isDiscreetMode }) {
                        Icon(
                            imageVector = if (isDiscreetMode) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                            contentDescription = "Toggle Balance Privacy",
                            tint = VaultTextSecondary
                        )
                    }
                    IconButton(onClick = onRefresh) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Refresh",
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
            // Main Hero Vault Card
            item {
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
                            .padding(20.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        if (wallet != null) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.clickable { onNavigateToWallets() }
                                ) {
                                    VaultIdenticon(address = wallet.address, size = 38.dp)
                                    Spacer(modifier = Modifier.width(10.dp))
                                    Column {
                                        Text(
                                            text = wallet.name,
                                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                                            color = VaultTextPrimary
                                        )
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Text(
                                                text = "${wallet.address.take(6)}...${wallet.address.takeLast(4)}",
                                                style = MaterialTheme.typography.bodySmall,
                                                color = VaultTextSecondary
                                            )
                                            if (wallet.importedEnsName != null) {
                                                Spacer(modifier = Modifier.width(6.dp))
                                                Text(
                                                    text = "@${wallet.importedEnsName}",
                                                    style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                                                    color = VaultCyan,
                                                    modifier = Modifier
                                                        .background(VaultCyan.copy(alpha = 0.15f), RoundedCornerShape(4.dp))
                                                        .padding(horizontal = 6.dp, vertical = 2.dp)
                                                )
                                            }
                                        }
                                    }
                                }

                                IconButton(
                                    onClick = {
                                        clipboardManager.setText(AnnotatedString(wallet.address))
                                        Toast.makeText(context, "Address copied to clipboard", Toast.LENGTH_SHORT).show()
                                    }
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.ContentCopy,
                                        contentDescription = "Copy Address",
                                        tint = VaultTextSecondary,
                                        modifier = Modifier.size(20.dp)
                                    )
                                }
                            }

                            Spacer(modifier = Modifier.height(24.dp))

                            // Balance Display
                            Text(
                                text = "Vault Balance",
                                style = MaterialTheme.typography.bodyMedium,
                                color = VaultTextMuted
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            if (isLoadingBalance) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(28.dp),
                                    color = VaultCyan,
                                    strokeWidth = 2.dp
                                )
                            } else {
                                Text(
                                    text = if (isDiscreetMode) "•••••••• ${selectedNetwork.symbol}" else "$balance ${selectedNetwork.symbol}",
                                    style = MaterialTheme.typography.headlineLarge.copy(
                                        fontWeight = FontWeight.ExtraBold,
                                        letterSpacing = (-0.5).sp
                                    ),
                                    color = VaultTextPrimary
                                )
                            }

                            Spacer(modifier = Modifier.height(8.dp))

                            // Interactive ENS Identity Pill
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier
                                    .clip(RoundedCornerShape(20.dp))
                                    .background(if (wallet.importedEnsName != null) VaultCyan.copy(alpha = 0.12f) else VaultSurfaceVariant)
                                    .border(
                                        1.dp,
                                        if (wallet.importedEnsName != null) VaultCyan.copy(alpha = 0.35f) else VaultBorder,
                                        RoundedCornerShape(20.dp)
                                    )
                                    .clickable { onNavigateToWallets() }
                                    .padding(horizontal = 12.dp, vertical = 5.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.AlternateEmail,
                                    contentDescription = "ENS",
                                    tint = if (wallet.importedEnsName != null) VaultCyan else VaultTextMuted,
                                    modifier = Modifier.size(13.dp)
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = if (wallet.importedEnsName != null) "@${wallet.importedEnsName}" else "Buy / Link ENS",
                                    style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
                                    color = if (wallet.importedEnsName != null) VaultCyan else VaultTextSecondary
                                )
                            }

                            Spacer(modifier = Modifier.height(18.dp))

                            // Action Buttons
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceEvenly
                            ) {
                                QuickActionButton(
                                    icon = Icons.Default.Add,
                                    label = "Buy",
                                    color = VaultCyan,
                                    onClick = { showBuyDialog = true }
                                )
                                QuickActionButton(
                                    icon = Icons.Default.ArrowUpward,
                                    label = "Send",
                                    color = Color.White,
                                    onClick = onNavigateToSend
                                )
                                QuickActionButton(
                                    icon = Icons.Default.ArrowDownward,
                                    label = "Receive",
                                    color = Color.White,
                                    onClick = onNavigateToReceive
                                )
                                QuickActionButton(
                                    icon = Icons.Default.QrCodeScanner,
                                    label = "Scan",
                                    color = Color.White,
                                    onClick = onNavigateToScan
                                )
                            }
                        } else {
                            // Empty State: Create / Import Wallet
                            Text(
                                text = "No Active Vault",
                                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                                color = VaultTextPrimary
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = "Create or import a self-custodial vault to get started.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = VaultTextSecondary
                            )
                            Spacer(modifier = Modifier.height(16.dp))
                            Button(
                                onClick = onNavigateToWallets,
                                colors = ButtonDefaults.buttonColors(containerColor = VaultCyan)
                            ) {
                                Text("Open Vault Manager", color = Color.Black, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }

            // Assets & Tokens Section
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Assets & Tokens",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = VaultTextPrimary
                    )
                    Text(
                        text = "${DefaultTokenAssets.size} Assets",
                        style = MaterialTheme.typography.bodySmall,
                        color = VaultTextSecondary
                    )
                }
            }

            items(DefaultTokenAssets) { token ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .border(1.dp, VaultBorder, RoundedCornerShape(16.dp))
                        .clickable { showBuyDialog = true },
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
                                    .size(38.dp)
                                    .clip(CircleShape)
                                    .background(Color(token.accentHex)),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = token.symbol.take(3),
                                    style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Black),
                                    color = Color.White
                                )
                            }
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text(
                                    text = token.name,
                                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                                    color = VaultTextPrimary
                                )
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        text = token.priceFormatted,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = VaultTextSecondary
                                    )
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text(
                                        text = token.changeFormatted,
                                        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                                        color = if (token.isPositive) VaultEmerald else Color(0xFFFF5252)
                                    )
                                }
                            }
                        }

                        Column(horizontalAlignment = Alignment.End) {
                            Text(
                                text = if (isDiscreetMode) "••••" else token.holdingFormatted,
                                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                                color = VaultTextPrimary
                            )
                            Text(
                                text = if (isDiscreetMode) "••••" else token.fiatFormatted,
                                style = MaterialTheme.typography.bodySmall,
                                color = VaultTextMuted
                            )
                        }
                    }
                }
            }

            // Recent Activity Section
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Recent Activity",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = VaultTextPrimary
                    )
                }
            }

            if (recentTransactions.isEmpty()) {
                item {
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .border(1.dp, VaultBorder, RoundedCornerShape(16.dp)),
                        colors = CardDefaults.cardColors(containerColor = VaultSurface)
                    ) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(24.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "No recent transactions found on this device.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = VaultTextMuted
                            )
                        }
                    }
                }
            } else {
                items(recentTransactions.take(5)) { tx ->
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .border(1.dp, VaultBorder, RoundedCornerShape(16.dp)),
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
                                VaultIdenticon(address = tx.recipient, size = 32.dp)
                                Spacer(modifier = Modifier.width(12.dp))
                                Column {
                                    Text(
                                        text = "Sent to ${tx.recipient.take(6)}...${tx.recipient.takeLast(4)}",
                                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                                        color = VaultTextPrimary
                                    )
                                    Text(
                                        text = tx.networkName,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = VaultTextSecondary
                                    )
                                }
                            }
                            Text(
                                text = "-${tx.amount} ${selectedNetwork.symbol}",
                                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                                color = VaultTextPrimary
                            )
                        }
                    }
                }
            }
        }
    }

    // Network Selection Dialog
    if (showNetworkDialog) {
        AlertDialog(
            onDismissRequest = { showNetworkDialog = false },
            title = {
                Text(
                    text = "Select Blockchain Network",
                    style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                    color = VaultTextPrimary
                )
            },
            text = {
                LazyColumn(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(BlockchainNetwork.AllBuiltIn) { net ->
                        val isSelected = net.id == selectedNetwork.id
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(12.dp))
                                .background(if (isSelected) VaultSurfaceVariant else VaultSurface)
                                .border(1.dp, if (isSelected) VaultCyan else VaultBorder, RoundedCornerShape(12.dp))
                                .clickable {
                                    onSelectNetwork(net)
                                    showNetworkDialog = false
                                }
                                .padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(
                                    modifier = Modifier
                                        .size(10.dp)
                                        .clip(CircleShape)
                                        .background(Color(net.accentHex))
                                )
                                Spacer(modifier = Modifier.width(10.dp))
                                Column {
                                    Text(
                                        text = net.name,
                                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                                        color = VaultTextPrimary
                                    )
                                    Text(
                                        text = "Chain ID: ${net.chainId} • ${net.symbol}",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = VaultTextSecondary
                                    )
                                }
                            }
                            if (isSelected) {
                                Icon(
                                    imageVector = Icons.Default.Check,
                                    contentDescription = "Selected",
                                    tint = VaultCyan
                                )
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showNetworkDialog = false }) {
                    Text("Close", color = VaultCyan)
                }
            },
            containerColor = VaultBackground
        )
    }

    if (showBuyDialog) {
        AlertDialog(
            onDismissRequest = { showBuyDialog = false },
            title = {
                Text(
                    text = "Add & Purchase Tokens",
                    style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                    color = VaultTextPrimary
                )
            },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(
                        text = "Choose your preferred payment method:",
                        style = MaterialTheme.typography.bodySmall,
                        color = VaultTextSecondary
                    )
                    listOf(
                        "Google Pay" to "Instant 1-tap checkout on Android",
                        "Debit / Credit Card" to "Visa, Mastercard via Stripe & MoonPay",
                        "Bank Transfer (Wire/SEPA)" to "Lowest fee (0.5%) • Direct account deposit",
                        "External Wallet Transfer" to "Deposit from Coinbase, Binance, or cold wallet"
                    ).forEach { (title, subtitle) ->
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .border(1.dp, VaultBorder, RoundedCornerShape(12.dp))
                                .clickable {
                                    Toast.makeText(context, "$title selected", Toast.LENGTH_SHORT).show()
                                    showBuyDialog = false
                                },
                            colors = CardDefaults.cardColors(containerColor = VaultSurfaceVariant)
                        ) {
                            Column(modifier = Modifier.padding(12.dp)) {
                                Text(text = title, style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold), color = VaultTextPrimary)
                                Text(text = subtitle, style = MaterialTheme.typography.bodySmall, color = VaultTextMuted)
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showBuyDialog = false }) {
                    Text("Close", color = VaultCyan)
                }
            },
            containerColor = VaultBackground
        )
    }
}

@Composable
fun QuickActionButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    color: Color,
    onClick: () -> Unit
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.clickable { onClick() }
    ) {
        Box(
            modifier = Modifier
                .size(54.dp)
                .clip(CircleShape)
                .background(VaultSurfaceVariant)
                .border(1.dp, VaultBorder, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = label,
                tint = color,
                modifier = Modifier.size(24.dp)
            )
        }
        Spacer(modifier = Modifier.height(6.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium),
            color = VaultTextSecondary
        )
    }
}
