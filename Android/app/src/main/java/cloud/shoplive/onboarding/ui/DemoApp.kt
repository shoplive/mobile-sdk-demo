package cloud.shoplive.onboarding.ui

import android.app.Activity
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Snackbar
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import cloud.shoplive.onboarding.BuildConfig
import cloud.shoplive.onboarding.R
import cloud.shoplive.onboarding.data.DemoMode
import cloud.shoplive.onboarding.data.MISSIONS
import cloud.shoplive.onboarding.demo.DemoLabels
import cloud.shoplive.onboarding.integration.ShopliveDeepLinkRouter
import cloud.shoplive.onboarding.integration.ShopliveUserSetup
import cloud.shoplive.onboarding.ui.devtools.DevSheet
import cloud.shoplive.onboarding.ui.feed.FeedScreen
import cloud.shoplive.onboarding.ui.feed.findActivity
import cloud.shoplive.onboarding.ui.hybrid.HybridListScreen
import cloud.shoplive.onboarding.ui.missions.MissionListScreen
import cloud.shoplive.onboarding.ui.missions.ModeBar
import cloud.shoplive.onboarding.ui.nudge.NudgeProductScreen
import cloud.shoplive.onboarding.ui.start.QrScanScreen
import cloud.shoplive.onboarding.ui.start.StartScreen

private object Routes {
    const val START = "start"
    const val MISSIONS = "missions"
    const val NUDGE = "nudge"
    const val FEED = "feed"
    const val HYBRID = "hybrid"
    const val QR = "qr"

    /** Demo-owned screens reached from a card; they show a back arrow. */
    val CARD_SCREENS = setOf(NUDGE, FEED, HYBRID)
}

/**
 * The three-screen structure.
 *
 * - S1 [Routes.START] start
 * - S2 [Routes.MISSIONS] feature list
 * - S3 the running screen — the player and studio are **Activities owned by the SDK**,
 *   so they have no route. The app owns three: the product page the nudge preview
 *   floats over ([Routes.NUDGE]) and the two inline-preview lists, native
 *   ([Routes.FEED]) and hybrid ([Routes.HYBRID]).
 *
 * The two overlays are a ModalBottomSheet (developer sheet) and a separate Activity
 * (product detail).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DemoApp(
    isEncryptedStorage: Boolean,
    deepLinkCampaignKey: String?,
    deepLinkReferrer: String?,
    onDeepLinkConsumed: () -> Unit,
    viewModel: MainViewModel = viewModel(),
) {
    val navController = rememberNavController()
    val state by viewModel.state.collectAsStateWithLifecycle()
    val doneMissions by viewModel.doneMissions.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val activity = remember(context) { context.findActivity() }
    val snackbarHostState = remember { SnackbarHostState() }

    // Skip the start screen when a mode was stored.
    val startRoute = if (state.mode == null) Routes.START else Routes.MISSIONS

    // Subscribe to the current route once.
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route ?: startRoute
    val isStartRoute = currentRoute == Routes.START
    // The start screen and the QR scanner draw their own chrome.
    val hideChrome = isStartRoute || currentRoute == Routes.QR

    // ── Deep link handling ───────────────────────────────────────────────────
    LaunchedEffect(deepLinkCampaignKey) {
        val campaignKey = deepLinkCampaignKey ?: return@LaunchedEffect
        val host = activity ?: return@LaunchedEffect
        viewModel.playFromDeepLink(
            activity = host,
            link = ShopliveDeepLinkRouter.Link(campaignKey, deepLinkReferrer),
        )
        onDeepLinkConsumed()
    }

    LaunchedEffect(state.message) {
        val message = state.message ?: return@LaunchedEffect
        snackbarHostState.showSnackbar(message)
        viewModel.consumeMessage()
    }

    Scaffold(
        topBar = {
            if (!hideChrome) {
                TopAppBar(
                    title = {
                        Text(
                            stringResource(R.string.topbar_progress, doneMissions.size, MISSIONS.size),
                            style = MaterialTheme.typography.titleMedium,
                        )
                    },
                    navigationIcon = {
                        if (currentRoute in Routes.CARD_SCREENS) {
                            IconButton(onClick = { navController.popBackStack() }) {
                                Icon(
                                    Icons.AutoMirrored.Filled.ArrowBack,
                                    contentDescription = stringResource(R.string.cd_back_to_list),
                                )
                            }
                        }
                    },
                    actions = {
                        IconButton(onClick = {
                            viewModel.openSettings()
                            navController.navigate(Routes.START)
                        }) {
                            Icon(
                                Icons.Default.Settings,
                                contentDescription = stringResource(R.string.cd_settings),
                            )
                        }
                    },
                )
            }
        },
        snackbarHost = {
            SnackbarHost(snackbarHostState) { data -> Snackbar(snackbarData = data) }
        },
        floatingActionButton = {
            if (!hideChrome) {
                ExtendedFloatingActionButton(
                    onClick = { viewModel.openDevSheet() },
                    text = {
                        Text(
                            stringResource(R.string.fab_developer),
                            style = MaterialTheme.typography.titleSmall,
                        )
                    },
                    icon = { Text("⌗") },
                )
            }
        },
    ) { padding ->
        Box(
            Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            Column {
                if (state.mode != null && !hideChrome) {
                    val modeText = when (state.mode) {
                        DemoMode.OWN -> stringResource(
                            R.string.mode_own,
                            maskedKey(state.accessKeyInput, stringResource(R.string.key_not_entered)),
                        )

                        else -> stringResource(R.string.mode_tour)
                    }
                    ModeBar(
                        text = stringResource(
                            R.string.mode_auth_suffix,
                            modeText,
                            state.authMethod.label,
                        ),
                        isOwnMode = state.mode == DemoMode.OWN,
                    )
                }

                NavHost(
                    navController = navController,
                    startDestination = startRoute,
                    modifier = Modifier.fillMaxSize(),
                ) {
                    composable(Routes.START) {
                        StartScreen(
                            viewModel = viewModel,
                            isEncryptedStorage = isEncryptedStorage,
                            onProceed = {
                                navController.navigate(Routes.MISSIONS) {
                                    popUpTo(Routes.START) { inclusive = true }
                                }
                            },
                            onScanQr = { navController.navigate(Routes.QR) },
                        )
                    }

                    composable(Routes.QR) {
                        QrScanScreen(
                            onResult = { qr ->
                                viewModel.applyQrCredentials(qr)
                                navController.popBackStack()
                            },
                            onBack = { navController.popBackStack() },
                        )
                    }

                    composable(Routes.MISSIONS) {
                        MissionListScreen(
                            doneMissions = doneMissions,
                            lockReasonOf = viewModel::lockReason,
                            onMissionClick = { mission ->
                                val host = activity ?: return@MissionListScreen
                                when (viewModel.runMission(host, mission)) {
                                    MainViewModel.Destination.NUDGE -> navController.navigate(Routes.NUDGE)
                                    MainViewModel.Destination.FEED -> navController.navigate(Routes.FEED)
                                    MainViewModel.Destination.HYBRID -> navController.navigate(Routes.HYBRID)
                                    null -> Unit
                                }
                            },
                        )
                    }

                    composable(Routes.NUDGE) {
                        NudgeProductScreen(mainViewModel = viewModel)
                    }

                    composable(Routes.FEED) {
                        FeedScreen(
                            delegate = viewModel.delegateForEmbeddedView(),
                            campaignKey = viewModel.effectiveCampaignKey(),
                            startEmbedded = viewModel::startInlineEmbed,
                        )
                    }

                    composable(Routes.HYBRID) {
                        HybridListScreen(mainViewModel = viewModel)
                    }
                }
            }

            // Deep-link mission — the fake push banner, shown over the list rather
            // than on a screen of its own.
            if (state.showPushBanner) {
                PushBanner(
                    campaignKey = viewModel.effectiveCampaignKey(),
                    onTap = { activity?.let(viewModel::onPushBannerTap) },
                    onDismiss = viewModel::dismissPushBanner,
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .padding(12.dp),
                )
            }
        }
    }

    // User-info mission — choosing an auth method, asked in a dialog instead of a
    // screen.
    if (state.askAuthMethod) {
        AuthMethodDialog(
            onDismiss = viewModel::dismissAuthSheet,
            onSelect = { method -> activity?.let { viewModel.chooseAuthMethod(it, method) } },
        )
    }

    // Inline-preview mission — the guide shows two ways, so the card asks which.
    if (state.askInlineMode) {
        InlineModeDialog(
            onDismiss = viewModel::dismissInlineChoice,
            onSelect = { destination ->
                viewModel.dismissInlineChoice()
                navController.navigate(
                    when (destination) {
                        MainViewModel.Destination.HYBRID -> Routes.HYBRID
                        else -> Routes.FEED
                    }
                )
            },
        )
    }

    // The developer sheet.
    state.devSheetTab?.let { tab ->
        DevSheet(
            selectedTab = tab,
            onSelectTab = viewModel::selectDevTab,
            onDismiss = viewModel::closeDevSheet,
            onReplayWithOptions = {
                activity?.let(viewModel::replayWithCurrentOptions)
            },
        )
    }
}

@Composable
private fun PushBanner(
    campaignKey: String,
    onTap: () -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Card(
        onClick = onTap,
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
    ) {
        Column(
            Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Text(
                stringResource(R.string.push_banner_source),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                stringResource(R.string.push_banner_title),
                style = MaterialTheme.typography.titleSmall,
            )
            Text(
                ShopliveDeepLinkRouter.linkUri(
                    scheme = BuildConfig.DEEP_LINK_SCHEME,
                    campaignKey = campaignKey,
                    referrer = "push_demo",
                ).toString(),
                style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            TextButton(onClick = onDismiss) {
                Text(
                    stringResource(R.string.push_banner_dismiss),
                    style = MaterialTheme.typography.labelSmall,
                )
            }
        }
    }
}

@Composable
private fun AuthMethodDialog(
    onDismiss: () -> Unit,
    onSelect: (ShopliveUserSetup.Method) -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                stringResource(R.string.auth_dialog_title),
                style = MaterialTheme.typography.titleMedium,
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    stringResource(R.string.auth_dialog_note),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                ShopliveUserSetup.Method.entries.forEach { method ->
                    TextButton(
                        onClick = { onSelect(method) },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(
                            "${method.label} — " +
                                stringResource(DemoLabels.descriptionRes(method)),
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.auth_dialog_cancel)) }
        },
    )
}

@Composable
private fun InlineModeDialog(
    onDismiss: () -> Unit,
    onSelect: (MainViewModel.Destination) -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                stringResource(R.string.inline_choice_title),
                style = MaterialTheme.typography.titleMedium,
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                TextButton(
                    onClick = { onSelect(MainViewModel.Destination.FEED) },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        stringResource(R.string.inline_choice_native),
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                TextButton(
                    onClick = { onSelect(MainViewModel.Destination.HYBRID) },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        stringResource(R.string.inline_choice_hybrid),
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.auth_dialog_cancel)) }
        },
    )
}

private fun maskedKey(key: String, blankLabel: String): String =
    if (key.length <= 8) key.ifBlank { blankLabel } else "${key.take(8)}…"

