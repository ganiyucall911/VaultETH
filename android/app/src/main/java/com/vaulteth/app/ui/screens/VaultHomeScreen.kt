package com.vaulteth.app.ui.screens

import android.widget.Toast
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.*
import androidx.compose.foundation.Image
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
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vaulteth.app.R
import com.vaulteth.app.core.AlertCondition
import com.vaulteth.app.core.AlertStatus
import com.vaulteth.app.core.BlockchainNetwork
import com.vaulteth.app.core.DefaultPriceAlerts
import com.vaulteth.app.core.DefaultTokenAssets
import com.vaulteth.app.core.PriceAlertItem
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
    var showAlertsDialog by remember { mutableStateOf(false) }
    var alertsList by remember { mutableStateOf(DefaultPriceAlerts) }
    var activeBannerAlert by remember { mutableStateOf<PriceAlertItem?>(DefaultPriceAlerts.firstOrNull { it.isEnabled }) }

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
                    ) {
                        Image(
                            painter = painterResource(R.mipmap.ic_launcher),
                            contentDescription = "VaultETH logo",
                            contentScale = ContentScale.Fit,
                            modifier = Modifier.size(30.dp).clip(RoundedCornerShape(8.dp))
                        )
                        Spacer(modifier = Modifier.width(9.dp))
                        Text(
                            text = "VaultETH",
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                            color = VaultTextPrimary
                        )
                    }
                },
                actions = {
                    PulsingAlertBell(
                        alertCount = alertsList.count { it.isEnabled },
                        onClick = { showAlertsDialog = true }
                    )
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
                            tint = VaultMint
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
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(VaultSurfaceVariant)
                        .border(1.dp, VaultBorder, RoundedCornerShape(20.dp))
                        .clickable { showNetworkDialog = true }
                        .padding(horizontal = 12.dp, vertical = 8.dp)
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
            }

            // Price Alert Notification Banner (Obsidian Mint Design)
            if (activeBannerAlert != null) {
                item {
                    PriceAlertBanner(
                        alert = activeBannerAlert!!,
                        onDismiss = { activeBannerAlert = null },
                        onViewAlerts = { showAlertsDialog = true }
                    )
                }
            }

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
                                                    color = VaultMint,
                                                    modifier = Modifier
                                                        .background(VaultMint.copy(alpha = 0.15f), RoundedCornerShape(4.dp))
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
                                    color = VaultMint,
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
                                    .background(if (wallet.importedEnsName != null) VaultMint.copy(alpha = 0.12f) else VaultSurfaceVariant)
                                    .border(
                                        1.dp,
                                        if (wallet.importedEnsName != null) VaultMint.copy(alpha = 0.35f) else VaultBorder,
                                        RoundedCornerShape(20.dp)
                                    )
                                    .clickable { onNavigateToWallets() }
                                    .padding(horizontal = 12.dp, vertical = 5.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.AlternateEmail,
                                    contentDescription = "ENS",
                                    tint = if (wallet.importedEnsName != null) VaultMint else VaultTextMuted,
                                    modifier = Modifier.size(13.dp)
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = if (wallet.importedEnsName != null) "@${wallet.importedEnsName}" else "Buy / Link ENS",
                                    style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
                                    color = if (wallet.importedEnsName != null) VaultMint else VaultTextSecondary
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
                                    color = VaultMint,
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
                                colors = ButtonDefaults.buttonColors(containerColor = VaultMint)
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
                        text = "Demo Assets & Tokens",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = VaultTextPrimary
                    )
                    Text(
                        text = "Sample data only",
                        style = MaterialTheme.typography.bodySmall,
                        color = VaultTextSecondary
                    )
                }
            }
            item {
                Text(
                    text = "Demo only — sample prices and holdings, not live market data or your wallet balance.",
                    style = MaterialTheme.typography.bodySmall,
                    color = VaultTextMuted
                )
            }

            items(DefaultTokenAssets) { token ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .border(1.dp, VaultBorder, RoundedCornerShape(16.dp)),
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
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                                ) {
                                    Text(
                                        text = token.priceFormatted,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = VaultTextSecondary
                                    )
                                    Box(
                                        modifier = Modifier
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(
                                                if (token.isPositive) VaultMint.copy(alpha = 0.12f)
                                                else VaultDanger.copy(alpha = 0.12f)
                                            )
                                            .border(
                                                1.dp,
                                                if (token.isPositive) VaultMint.copy(alpha = 0.35f)
                                                else VaultDanger.copy(alpha = 0.35f),
                                                RoundedCornerShape(8.dp)
                                            )
                                            .padding(horizontal = 6.dp, vertical = 2.dp)
                                    ) {
                                        Text(
                                            text = token.changeFormatted,
                                            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                                            color = if (token.isPositive) VaultMint else VaultDanger
                                        )
                                    }
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
                                style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium),
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
                                .border(1.dp, if (isSelected) VaultMint else VaultBorder, RoundedCornerShape(12.dp))
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
                                    tint = VaultMint
                                )
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showNetworkDialog = false }) {
                    Text("Close", color = VaultMint)
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
                    text = "Buy Crypto — Coming Soon",
                    style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                    color = VaultTextPrimary
                )
            },
            text = {
                Text(
                    text = "Purchases are not supported in VaultETH yet. No payment provider or purchase submission is connected.",
                    style = MaterialTheme.typography.bodySmall,
                    color = VaultTextSecondary
                )
            },
            confirmButton = {
                TextButton(onClick = { showBuyDialog = false }) {
                    Text("Close", color = VaultMint)
                }
            },
            containerColor = VaultBackground
        )
    }

    if (showAlertsDialog) {
        AlertDialog(
            onDismissRequest = { showAlertsDialog = false },
            title = {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = "Price Alerts",
                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                        color = VaultTextPrimary
                    )
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .background(VaultMint.copy(alpha = 0.15f))
                            .padding(horizontal = 8.dp, vertical = 3.dp)
                    ) {
                        Text(
                            text = "${alertsList.count { it.isEnabled }} Active",
                            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                            color = VaultMint
                        )
                    }
                }
            },
            text = {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    alertsList.forEachIndexed { index, alert ->
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .border(1.dp, VaultBorder, RoundedCornerShape(12.dp)),
                            colors = CardDefaults.cardColors(containerColor = VaultSurface)
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text(
                                            text = alert.symbol,
                                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                                            color = VaultTextPrimary
                                        )
                                        Spacer(modifier = Modifier.width(6.dp))
                                        Text(
                                            text = "${alert.condition.label} ${alert.targetPriceFormatted}",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = VaultMint
                                        )
                                    }
                                    Text(
                                        text = "Current: ${alert.currentPriceFormatted}${alert.note?.let { " • $it" } ?: ""}",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = VaultTextSecondary
                                    )
                                }
                                Switch(
                                    checked = alert.isEnabled,
                                    onCheckedChange = { isChecked ->
                                        alertsList = alertsList.toMutableList().also { list ->
                                            list[index] = alert.copy(
                                                isEnabled = isChecked,
                                                status = if (isChecked) AlertStatus.ACTIVE else AlertStatus.MUTED
                                            )
                                        }
                                        if (!isChecked && activeBannerAlert?.id == alert.id) {
                                            activeBannerAlert = null
                                        }
                                    },
                                    colors = SwitchDefaults.colors(
                                        checkedThumbColor = Color.Black,
                                        checkedTrackColor = VaultMint,
                                        uncheckedThumbColor = VaultTextMuted,
                                        uncheckedTrackColor = VaultSurfaceVariant
                                    )
                                )
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showAlertsDialog = false }) {
                    Text("Done", color = VaultMint, fontWeight = FontWeight.Bold)
                }
            },
            containerColor = VaultBackground
        )
    }
}

@Composable
fun PulsingAlertBell(
    alertCount: Int,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.45f,
        animationSpec = infiniteRepeatable(
            animation = tween(1200, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseScale"
    )
    val pulseAlpha by infiniteTransition.animateFloat(
        initialValue = 0.8f,
        targetValue = 0.1f,
        animationSpec = infiniteRepeatable(
            animation = tween(1200, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseAlpha"
    )

    IconButton(onClick = onClick, modifier = modifier) {
        Box(contentAlignment = Alignment.Center) {
            Icon(
                imageVector = Icons.Default.Notifications,
                contentDescription = "Price Alerts",
                tint = if (alertCount > 0) VaultMint else VaultTextSecondary,
                modifier = Modifier.size(22.dp)
            )
            if (alertCount > 0) {
                // Pulsing outer halo
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .align(Alignment.TopEnd)
                        .scale(pulseScale)
                        .clip(CircleShape)
                        .background(VaultMint.copy(alpha = pulseAlpha))
                )
                // Solid center indicator dot
                Box(
                    modifier = Modifier
                        .size(6.dp)
                        .align(Alignment.TopEnd)
                        .clip(CircleShape)
                        .background(VaultMint)
                )
            }
        }
    }
}

@Composable
fun PriceAlertBanner(
    alert: PriceAlertItem,
    onDismiss: () -> Unit,
    onViewAlerts: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .border(1.dp, VaultMint.copy(alpha = 0.35f), RoundedCornerShape(16.dp))
            .clickable { onViewAlerts() },
        colors = CardDefaults.cardColors(containerColor = VaultSurfaceElevated)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.weight(1f)
            ) {
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(VaultMint.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.NotificationsActive,
                        contentDescription = "Alert",
                        tint = VaultMint,
                        modifier = Modifier.size(18.dp)
                    )
                }
                Spacer(modifier = Modifier.width(10.dp))
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = "PRICE ALERT",
                            style = MaterialTheme.typography.labelSmall.copy(
                                fontWeight = FontWeight.Black,
                                letterSpacing = 0.5.sp
                            ),
                            color = VaultMint
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = "${alert.symbol} ${alert.condition.label} ${alert.targetPriceFormatted}",
                            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Bold),
                            color = VaultTextPrimary
                        )
                    }
                    Text(
                        text = "Current: ${alert.currentPriceFormatted}${alert.note?.let { " • $it" } ?: ""}",
                        style = MaterialTheme.typography.bodySmall,
                        color = VaultTextSecondary
                    )
                }
            }

            IconButton(
                onClick = onDismiss,
                modifier = Modifier.size(28.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Close,
                    contentDescription = "Dismiss",
                    tint = VaultTextMuted,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
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
