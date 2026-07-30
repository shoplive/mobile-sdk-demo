package cloud.shoplive.onboarding.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

val Brand = Color(0xFFFF2D55)
val BrandLight = Color(0xFFFF5C7A)
val Ok = Color(0xFF2EA043)
val Warn = Color(0xFFD29922)
val Info = Color(0xFF4C9AFF)

private val LightColors = lightColorScheme(
    primary = Brand,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFFFE4EA),
    onPrimaryContainer = Color(0xFF6B0A1E),
    secondary = Color(0xFF4A5260),
    background = Color(0xFFFAFAFC),
    onBackground = Color(0xFF111111),
    surface = Color.White,
    onSurface = Color(0xFF111111),
    surfaceVariant = Color(0xFFF2F3F6),
    onSurfaceVariant = Color(0xFF6B7280),
    outline = Color(0xFFDCDFE5),
    outlineVariant = Color(0xFFECECF0),
    error = Brand,
)

private val DarkColors = darkColorScheme(
    primary = BrandLight,
    onPrimary = Color(0xFF3D0010),
    primaryContainer = Color(0xFF5C1626),
    onPrimaryContainer = Color(0xFFFFD9E1),
    secondary = Color(0xFF9AA7B6),
    background = Color(0xFF0E1117),
    onBackground = Color(0xFFE6EDF3),
    surface = Color(0xFF161B22),
    onSurface = Color(0xFFE6EDF3),
    surfaceVariant = Color(0xFF1C2230),
    onSurfaceVariant = Color(0xFF9AA7B6),
    outline = Color(0xFF2A3140),
    outlineVariant = Color(0xFF242B38),
    error = BrandLight,
)

/** 로그·키 값처럼 자리수를 맞춰 읽어야 하는 텍스트에 쓴다. */
val MonoStyle = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 11.sp)

private val DemoTypography = Typography(
    headlineSmall = TextStyle(
        fontWeight = FontWeight.ExtraBold,
        fontSize = 24.sp,
        lineHeight = 30.sp,
        letterSpacing = (-0.5).sp,
    ),
    titleMedium = TextStyle(fontWeight = FontWeight.Bold, fontSize = 15.sp, lineHeight = 20.sp),
    titleSmall = TextStyle(fontWeight = FontWeight.Bold, fontSize = 13.5.sp, lineHeight = 18.sp),
    bodyMedium = TextStyle(fontSize = 13.5.sp, lineHeight = 20.sp),
    bodySmall = TextStyle(fontSize = 12.sp, lineHeight = 18.sp),
    labelSmall = TextStyle(fontWeight = FontWeight.Bold, fontSize = 10.5.sp),
)

@Composable
fun ShopliveOnboardingTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        // 브랜드 색을 그대로 보여야 하는 데모라 Dynamic Color 는 쓰지 않는다.
        colorScheme = if (darkTheme) DarkColors else LightColors,
        typography = DemoTypography,
        content = content,
    )
}
