package com.vaulteth.app.ui.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vaulteth.app.R

private fun tokenIconRes(symbol: String): Int? = when (symbol.lowercase()) {
    "eth" -> R.drawable.token_eth
    "btc" -> R.drawable.token_btc
    "sol" -> R.drawable.token_sol
    "bnb" -> R.drawable.token_bnb
    "op" -> R.drawable.token_op
    "arb" -> R.drawable.token_arb
    "pol" -> R.drawable.token_pol
    "usde" -> R.drawable.token_usde
    "usdt" -> R.drawable.token_usdt
    "usdc" -> R.drawable.token_usdc
    "dai" -> R.drawable.token_dai
    "pyusd" -> R.drawable.token_pyusd
    "eurc" -> R.drawable.token_eurc
    else -> null
}

/**
 * Renders the bundled real token logo when one exists for the symbol,
 * falling back to the accent monogram for anything else.
 */
@Composable
fun TokenIcon(
    symbol: String,
    accentHex: Long,
    size: Dp = 28.dp,
    modifier: Modifier = Modifier
) {
    val res = tokenIconRes(symbol)
    if (res != null) {
        Image(
            painter = painterResource(res),
            contentDescription = "$symbol logo",
            modifier = modifier
                .size(size)
                .clip(CircleShape)
        )
    } else {
        Box(
            modifier = modifier
                .size(size)
                .clip(CircleShape)
                .background(Color(accentHex)),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = symbol.take(2),
                style = MaterialTheme.typography.labelSmall.copy(
                    fontWeight = FontWeight.Black,
                    fontSize = (size.value * 0.36).sp
                ),
                color = Color.White
            )
        }
    }
}
