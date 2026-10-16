package com.vaulteth.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Obsidian Matte FinTech Palette matching web showcase
val VaultBackground = Color(0xFF0B0D10)
val VaultSurface = Color(0xFF12151A)
val VaultSurfaceElevated = Color(0xFF181C23)
val VaultSurfaceVariant = Color(0xFF14181D)
val VaultCardHover = Color(0xFF1C2129)
val VaultBorder = Color(0x1AFFFFFF) // rgba(255, 255, 255, 0.10)
val VaultBorderHighlight = Color(0x33FFFFFF) // rgba(255, 255, 255, 0.20)

// Cash App / Rainbow Signature Mint (#00D632)
val VaultMint = Color(0xFF00D632)
val VaultMintHover = Color(0xFF00EB37)
val VaultPrimary = VaultMint
val VaultCyan = VaultMint // Aliased for backward compatibility

// Accents and Semantic Status
val VaultViolet = Color(0xFF6B7380) // neutral slate (monochrome system)
val VaultEmerald = Color(0xFF00D632)
val VaultDanger = Color(0xFFE5484D)
val VaultRose = VaultDanger
val VaultAmber = Color(0xFFD99E42)
val VaultBlue = Color(0xFF6B7380) // neutral slate (monochrome system)

// Text Tones
val VaultTextPrimary = Color(0xFFE8EAED)
val VaultTextSecondary = Color(0xFF8A919C)
val VaultTextMuted = Color(0xFF6B7280)

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
