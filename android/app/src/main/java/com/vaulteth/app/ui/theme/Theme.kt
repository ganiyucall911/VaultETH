package com.vaulteth.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Obsidian Matte FinTech Palette matching web showcase
val VaultBackground = Color(0xFF080A0E)
val VaultSurface = Color(0xFF0E1219)
val VaultSurfaceElevated = Color(0xFF141A24)
val VaultSurfaceVariant = Color(0xFF121822)
val VaultCardHover = Color(0xFF18202D)
val VaultBorder = Color(0x14FFFFFF) // rgba(255, 255, 255, 0.08)
val VaultBorderHighlight = Color(0x29FFFFFF) // rgba(255, 255, 255, 0.16)

// Cash App / Rainbow Signature Mint (#00D632)
val VaultMint = Color(0xFF00D632)
val VaultMintHover = Color(0xFF00EB37)
val VaultPrimary = VaultMint
val VaultCyan = VaultMint // Aliased for backward compatibility

// Accents and Semantic Status
val VaultViolet = Color(0xFF8A2BE2)
val VaultEmerald = Color(0xFF00D632)
val VaultDanger = Color(0xFFFF4757)
val VaultRose = VaultDanger
val VaultAmber = Color(0xFFFFA502)
val VaultBlue = Color(0xFF3867D6)

// Text Tones
val VaultTextPrimary = Color(0xFFF8FAFC)
val VaultTextSecondary = Color(0xFF94A3B8)
val VaultTextMuted = Color(0xFF64748B)

private val DarkColorScheme = darkColorScheme(
    primary = VaultMint,
    onPrimary = Color.Black,
    secondary = VaultViolet,
    onSecondary = Color.White,
    tertiary = VaultMint,
    background = VaultBackground,
    onBackground = VaultTextPrimary,
    surface = VaultSurfaceVariant,
    onSurface = VaultTextPrimary,
    surfaceVariant = VaultSurfaceElevated,
    onSurfaceVariant = VaultTextSecondary,
    outline = VaultBorder
)

@Composable
fun VaultETHTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    // VaultETH is always rendered in Obsidian Matte FinTech luxury dark theme
    MaterialTheme(
        colorScheme = DarkColorScheme,
        content = content
    )
}
