package com.vaulteth.app.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.vaulteth.app.core.WalletEngine
import java.security.MessageDigest

@Composable
fun VaultIdenticon(
    address: String,
    size: Dp = 48.dp,
    modifier: Modifier = Modifier
) {
    val clean = address.lowercase().removePrefix("0x")
    val bytes = if (clean.length >= 40) {
        WalletEngine.hexToBytesSafe(clean.substring(0, 40))
    } else {
        MessageDigest.getInstance("SHA-256").digest(address.toByteArray())
    }

    // Deterministic palette generation from address bytes
    val hue1 = ((bytes.getOrNull(0)?.toInt() ?: 0) and 0xFF) / 255f * 360f
    val hue2 = (hue1 + 60f + (((bytes.getOrNull(1)?.toInt() ?: 0) and 0x3F))) % 360f

    val primaryColor = Color.hsv(hue1, 0.85f, 0.95f)
    val secondaryColor = Color.hsv(hue2, 0.75f, 0.85f)
    val titanium = Color(0xFF1E2638)

    Box(modifier = modifier.size(size)) {
        Canvas(modifier = Modifier.matchParentSize()) {
            val center = Offset(this.size.width / 2f, this.size.height / 2f)
            val radius = this.size.minDimension / 2f

            // Outer subtle glow
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(primaryColor.copy(alpha = 0.25f), Color.Transparent),
                    center = center,
                    radius = radius
                ),
                radius = radius
            )

            // Outer titanium rim
            drawCircle(
                color = titanium,
                radius = radius * 0.92f,
                style = Stroke(width = radius * 0.08f)
            )

            // Inner calibration orbit
            drawCircle(
                color = primaryColor.copy(alpha = 0.4f),
                radius = radius * 0.76f,
                style = Stroke(width = radius * 0.04f)
            )

            // Keystone "V" Chevron
            val w = this.size.width
            val h = this.size.height
            val scale = 0.52f

            val chevronPath = Path().apply {
                moveTo(center.x, center.y + radius * scale)
                lineTo(center.x - radius * scale * 0.9f, center.y - radius * scale * 0.8f)
                lineTo(center.x - radius * scale * 0.4f, center.y - radius * scale * 0.8f)
                lineTo(center.x, center.y + radius * scale * 0.2f)
                lineTo(center.x + radius * scale * 0.4f, center.y - radius * scale * 0.8f)
                lineTo(center.x + radius * scale * 0.9f, center.y - radius * scale * 0.8f)
                close()
            }

            drawPath(
                path = chevronPath,
                brush = Brush.verticalGradient(
                    colors = listOf(primaryColor, secondaryColor)
                )
            )

            // Keystone Apex Jewel
            drawCircle(
                color = Color.White,
                radius = radius * 0.09f,
                center = Offset(center.x, center.y - radius * scale * 0.25f)
            )
        }
    }
}
