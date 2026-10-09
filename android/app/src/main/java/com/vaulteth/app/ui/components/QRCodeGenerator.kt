package com.vaulteth.app.ui.components

import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel

object QRCodeGenerator {
    fun generate(content: String, sizePixels: Int = 512): Bitmap? {
        return try {
            val hints = mapOf(
                EncodeHintType.MARGIN to 1,
                EncodeHintType.ERROR_CORRECTION to ErrorCorrectionLevel.H
            )
            val bitMatrix = QRCodeWriter().encode(content, BarcodeFormat.QR_CODE, sizePixels, sizePixels, hints)
            val width = bitMatrix.width
            val height = bitMatrix.height
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            for (x in 0 until width) {
                for (y in 0 until height) {
                    bitmap.setPixel(x, y, if (bitMatrix.get(x, y)) -0x1000000 else -0x1)
                }
            }
            bitmap
        } catch (_: Exception) {
            null
        }
    }
}

@Composable
fun QRCodeImage(
    content: String,
    size: Dp = 200.dp,
    modifier: Modifier = Modifier
) {
    val bitmap = remember(content) {
        QRCodeGenerator.generate(content)
    }

    Box(
        modifier = modifier
            .size(size)
            .clip(RoundedCornerShape(16.dp))
    ) {
        if (bitmap != null) {
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = "QR Code",
                modifier = Modifier.matchParentSize()
            )
        }
    }
}
