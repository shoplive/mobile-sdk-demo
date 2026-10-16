package cloud.shoplive.onboarding.flutter

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * The Flutter host Activity.
 *
 * `FlutterFragmentActivity` (an androidx `ComponentActivity`) instead of the template's
 * `FlutterActivity`: the Shoplive SDK registers its system-PIP mode listener only on a
 * `ComponentActivity` host. In-app PIP works with either; OS PIP callbacks need this one.
 * See the shoplive_player README, "Android: picture-in-picture".
 */
class MainActivity : FlutterFragmentActivity()
