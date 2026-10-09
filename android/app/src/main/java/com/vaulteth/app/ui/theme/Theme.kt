package com.vaulteth.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val VaultBackground = Color(0xFF0A0D14)
val VaultSurface = Color(0xFF121824)
val VaultSurfaceVariant = Color(0xFF172030)
val VaultBorder = Color(0xFF1F293D)
val VaultCyan = Color(0xFF00F5FF)
val VaultViolet = Color(0xFF8A2BE2)
val VaultEmerald = Color(0xFF00E676)
val VaultAmber = Color(0xFFFFB300)
val VaultTextPrimary = Color(0xFFF1F5F9)
val VaultTextSecondary = Color(0xFF94A3B8)
val VaultTextMuted = Color(0xFF64748B)
val VaultRose = Color(0xFFFF4D4F)

private val DarkColorScheme = darkColorScheme(
    primary = VaultCyan,
    onPrimary = Color.Black,
    secondary = VaultViolet,
    onSecondary = Color.White,
    tertiary = VaultEmerald,
    background = VaultBackground,
    onBackground = VaultTextPrimary,
    surface = VaultSurface,
    onSurface = VaultTextPrimary,
    surfaceVariant = VaultSurfaceVariant,
    onSurfaceVariant = VaultTextSecondary,
    outline = VaultBorder
)

@Composable
fun VaultETHTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    // VaultETH is always rendered in Sovereign Obsidian luxury dark theme
    MaterialTheme(
        colorScheme = DarkColorScheme,
        content = content
    )
}
