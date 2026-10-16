package cloud.shoplive.onboarding.ui.start

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import cloud.shoplive.onboarding.R
import cloud.shoplive.onboarding.data.QrCredentials
import cloud.shoplive.onboarding.ui.components.Tip
import cloud.shoplive.onboarding.ui.components.TipTone
import com.google.zxing.BarcodeFormat
import com.journeyapps.barcodescanner.BarcodeView
import com.journeyapps.barcodescanner.DefaultDecoderFactory

/**
 * Scans a credentials QR code (the format the native test apps use) and hands back a
 * [QrCredentials]. A QR it cannot use keeps the camera open and says why.
 *
 * Same screen and behavior as the Flutter demo's `QrScanScreen`: a viewfinder, a hint
 * card at the bottom that turns into the rejection message, and an inline message
 * when the camera is unavailable.
 *
 * Demo harness only — QR input is a tester convenience, not part of the SDK
 * integration, so it does not live in `:integration`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QrScanScreen(
    onResult: (QrCredentials) -> Unit,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    var hasPermission by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
                PackageManager.PERMISSION_GRANTED
        )
    }
    var permissionDenied by remember { mutableStateOf(false) }
    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        hasPermission = it
        permissionDenied = !it
    }
    LaunchedEffect(Unit) {
        if (!hasPermission) permissionLauncher.launch(Manifest.permission.CAMERA)
    }

    var rejected by remember { mutableStateOf(false) }
    // Plain holders, not state: they gate the decoder callback and never drive UI.
    val lastRaw = remember { arrayOfNulls<String>(1) }
    val done = remember { booleanArrayOf(false) }

    Scaffold(
        contentWindowInsets = WindowInsets(0),
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.qr_title), style = MaterialTheme.typography.titleMedium) },
                // DemoApp's Scaffold already pads for the status bar.
                windowInsets = WindowInsets(0),
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.cd_close))
                    }
                },
            )
        },
    ) { padding ->
        Box(
            Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            when {
                hasPermission -> CameraPreview { raw ->
                    // The decoder reports the same code on every frame.
                    if (done[0] || raw == lastRaw[0]) return@CameraPreview
                    lastRaw[0] = raw
                    val parsed = QrCredentials.parse(raw)
                    if (parsed == null) {
                        rejected = true
                    } else {
                        done[0] = true
                        onResult(parsed)
                    }
                }

                permissionDenied -> Column(Modifier.align(Alignment.Center).padding(24.dp)) {
                    Tip(stringResource(R.string.qr_camera_error, "permissionDenied"), TipTone.WARN)
                }
            }

            // Viewfinder — a visual target only; the whole preview is scanned.
            Box(
                Modifier
                    .align(Alignment.Center)
                    .size(240.dp)
                    .border(3.dp, Color.White, RoundedCornerShape(16.dp)),
            )

            Surface(
                color = MaterialTheme.colorScheme.surface,
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .padding(start = 16.dp, end = 16.dp, bottom = 32.dp),
            ) {
                Text(
                    stringResource(if (rejected) R.string.qr_rejected else R.string.qr_hint),
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(12.dp),
                )
            }
        }
    }
}

/** zxing's camera view, resumed and paused with the screen's lifecycle. */
@Composable
private fun CameraPreview(onScanned: (String) -> Unit) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val view = remember {
        BarcodeView(context).apply {
            decoderFactory = DefaultDecoderFactory(listOf(BarcodeFormat.QR_CODE))
            decodeContinuous { result -> result.text?.let(onScanned) }
        }
    }
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME -> view.resume()
                Lifecycle.Event.ON_PAUSE -> view.pause()
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        if (lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) view.resume()
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            view.pause()
        }
    }
    AndroidView(factory = { view }, modifier = Modifier.fillMaxSize())
}
