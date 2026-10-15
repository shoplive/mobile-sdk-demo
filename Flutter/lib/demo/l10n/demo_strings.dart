import 'package:flutter/foundation.dart';

import 'generated_strings.dart';

/// The demo's UI text, in English (default), Korean and Japanese.
///
/// The base table is generated from the native Android demo's `strings.xml`, so
/// the three demos read the same. [flutterOverrides] replaces the handful of
/// sentences that describe native-only things (Activity, EncryptedSharedPreferences,
/// `local.properties`, the embeddable view) with what is true for Flutter.
///
/// Developer log lines are intentionally NOT localized: they mirror SDK API calls
/// and get pasted into bug reports.
///
/// The language is an app setting (English by default) and does not follow the
/// device — the same rule as the native demos.
enum DemoLanguage {
  en('English'),
  ko('한국어'),
  ja('日本語');

  const DemoLanguage(this.nativeName);

  final String nativeName;
}

abstract final class DemoStrings {
  static final ValueNotifier<DemoLanguage> language = ValueNotifier(DemoLanguage.en);

  /// Looks up [key] in the current language, falling back to English, then to the
  /// key itself. `{0}`, `{1}` … are replaced by [args].
  static String tr(String key, [List<Object?> args = const []]) {
    final lang = language.value.name;
    var text =
        flutterOverrides[lang]?[key] ??
        generatedStrings[lang]?[key] ??
        flutterOverrides['en']?[key] ??
        generatedStrings['en']?[key] ??
        key;
    for (var i = 0; i < args.length; i++) {
      text = text.replaceAll('{$i}', '${args[i]}');
    }
    return text;
  }
}

/// Shorthand used by every screen.
String tr(String key, [List<Object?> args = const []]) => DemoStrings.tr(key, args);

const Map<String, Map<String, String>> flutterOverrides = {
  'en': {
    'qr_button': 'Scan a QR code',
    'qr_title': 'Scan credentials QR',
    'qr_hint':
        'Point the camera at a test-app QR code. It reads ak (accessKey), ck (campaignKey), st (stream token) and userjwt.',
    'qr_rejected': 'This QR has no usable values. It needs ak and ck together, or st, or userjwt in its URL query.',
    'qr_camera_error': 'The camera is not available ({0}). Allow camera access in Settings, or type the keys instead.',
    'qr_applied': 'QR “{0}” — filled {1}. Check the values, then tap “Validate and start”.',
    'app_name': 'ShopLive Flutter Demo',
    'start_title': 'ShopLive Flutter SDK\nIntegration Demo',
    'start_storage': 'Your input is stored only on this device (shared_preferences) and is never sent to a server.',
    'start_tour_hint_missing': 'No built-in demo keys — pass --dart-define values or enter your own keys below.',
    'msg_demo_keys_missing':
        'The built-in demo keys are empty. Pass --dart-define=SHOPLIVE_DEMO_ACCESS_KEY and SHOPLIVE_DEMO_CAMPAIGN_KEY, or continue with “Use my own account”.',
    'mission4_title': 'Show it in your screen',
    'mission4_desc': 'Float a muted preview over the home feed, then promote it to full screen.',
    'mission4_check': 'Preview floats over the feed · promotes to full screen',
    'warn_os_pip_activity_only':
        'Android: OS PIP needs android:supportsPictureInPicture="true" on the host Activity (set in this demo). Without it the player reports PIP_ACTIVITY_NOT_DECLARED and stays in in-app PIP.',
    'warn_overlay_hidden':
        'HIDDEN only hides the UI. The command channel stays alive, so product and coupon requests keep arriving — watch the log tab.',
    'warn_allow_screen_capture':
        'Android only (configuration.android). false makes the SDK apply FLAG_SECURE, so video shows up black in screenshots, mirroring, and recordings. Not exposed for iOS in Flutter 3.0.2.',
    'warn_mute_on_start':
        'Measured in the native Android demo (SDK 3.0.0): enabling this made playback bounce into PIP. Not re-measured on Flutter — turn it on for inspection only.',
    'warn_config_merge':
        'Flutter merges configuration onto the current settings — fields you do not pass keep their last value. This tab always sends every field, so what you see is what plays.',
    'feed_tip_embed':
        'Flutter SDK 3.0.2 has no embeddable player widget. The closest equivalent is starting the player directly in in-app PIP: a muted preview floating over this screen. Events, requests and controls are the same as full screen.',
    'feed_warn_activity_context':
        'The floating window is not part of this widget tree — it does not scroll with the feed and is not removed with the screen. This screen closes it when you leave.',
    'feed_card2_desc': 'Scroll freely — the preview floats and keeps playing',
    'feed_card3_desc': 'Position and size come from pip.defaultPosition / scale',
    'feed_btn_start': '▶ Start preview',
    'feed_btn_close': '✕ Close preview',
    'feed_warn_expand_restream':
        'Full screen calls exitPictureInPicture() on the running session instead of a new start(). On iOS the player reports stateChanged(loading) right after — whether the stream is re-fetched is not verified.',
    'start_code_tip':
        'The code is not in the app. Read it in the Flutter project — every feature card names the file to open under lib/.',
    'mission_list_sdk_screen_tip':
        'Flutter UI cannot be drawn on top of the SDK player or studio (they are native screens). Events keep accumulating in the log — check the ⌗ developer sheet once you are back.',
    'group_runtime_state': 'Session state',
    'action_read': 'Read',
  },
  'ko': {
    'qr_button': 'QR 코드로 입력',
    'qr_title': '인증 정보 QR 스캔',
    'qr_hint': '테스트앱 QR 코드에 카메라를 맞추세요. ak(accessKey)·ck(campaignKey)·st(스트림 토큰)·userjwt 를 읽습니다.',
    'qr_rejected': '이 QR 에는 쓸 수 있는 값이 없습니다. URL 쿼리에 ak 와 ck 를 함께, 또는 st, 또는 userjwt 가 있어야 합니다.',
    'qr_camera_error': '카메라를 쓸 수 없습니다({0}). 설정에서 카메라 접근을 허용하거나 키를 직접 입력하세요.',
    'qr_applied': 'QR “{0}” — {1} 입력 완료. 값을 확인한 뒤 “검증하고 시작하기” 를 누르세요.',
    'app_name': 'ShopLive Flutter 데모',
    'start_title': 'ShopLive Flutter SDK\n연동 데모',
    'start_storage': '입력값은 이 기기(shared_preferences)에만 저장되며 서버로 전송되지 않습니다.',
    'start_tour_hint_missing': '내장 데모 키가 비어 있습니다 — --dart-define 값을 넘기거나 아래에서 직접 입력하세요.',
    'msg_demo_keys_missing':
        '내장 데모 키가 비어 있습니다. --dart-define=SHOPLIVE_DEMO_ACCESS_KEY · SHOPLIVE_DEMO_CAMPAIGN_KEY 를 넘기거나 “내 계정으로 체험하기” 로 진행하세요.',
    'mission4_title': '화면 안에 띄우기',
    'mission4_desc': '홈 피드 위에 음소거 미리보기를 띄우고, 전체화면으로 승격합니다.',
    'mission4_check': '피드 위에 미리보기 표시 · 전체화면 승격',
    'warn_os_pip_activity_only':
        'Android: OS PIP 는 host Activity 에 android:supportsPictureInPicture="true" 가 필요합니다(이 데모는 설정됨). 없으면 PIP_ACTIVITY_NOT_DECLARED 를 보고하고 in-App PIP 에 머뭅니다.',
    'warn_overlay_hidden': 'HIDDEN 은 표시만 끕니다. 커맨드 채널은 살아 있어 상품·쿠폰 요청은 계속 들어옵니다 — 로그 탭에서 확인하세요.',
    'warn_allow_screen_capture':
        'Android 전용(configuration.android). false 로 두면 SDK 가 FLAG_SECURE 를 걸어 스크린샷·미러링·녹화에서 영상이 검게 나옵니다. Flutter 3.0.2 는 iOS 용 옵션을 노출하지 않습니다.',
    'warn_mute_on_start':
        '네이티브 Android 데모(SDK 3.0.0)에서 켜면 재생이 PIP 로 튕기는 문제가 측정됐습니다. Flutter 에서는 재측정하지 않았습니다 — 확인용으로만 켜세요.',
    'warn_config_merge':
        'Flutter 는 configuration 을 현재 설정 위에 병합합니다 — 넘기지 않은 필드는 직전 값을 유지합니다. 이 탭은 항상 모든 필드를 보내므로 보이는 값 그대로 재생됩니다.',
    'feed_tip_embed':
        'Flutter SDK 3.0.2 에는 임베드용 플레이어 위젯이 없습니다. 가장 가까운 방법은 플레이어를 처음부터 in-App PIP 로 시작하는 것입니다 — 이 화면 위에 뜨는 음소거 미리보기. 이벤트·요청·컨트롤은 전체화면과 같습니다.',
    'feed_warn_activity_context': '떠 있는 창은 이 위젯 트리에 속하지 않습니다 — 피드와 함께 스크롤되지 않고, 화면이 사라져도 남습니다. 이 화면은 나갈 때 창을 닫습니다.',
    'feed_card2_desc': '스크롤해도 미리보기는 떠 있는 채로 재생됩니다',
    'feed_card3_desc': '위치·크기는 pip.defaultPosition / scale 로 정합니다',
    'feed_btn_start': '▶ 미리보기 시작',
    'feed_btn_close': '✕ 미리보기 닫기',
    'feed_warn_expand_restream':
        '전체화면은 새 start() 가 아니라 실행 중인 세션에 exitPictureInPicture() 를 호출합니다. iOS 에서는 직후 stateChanged(loading) 이 옵니다 — 스트림 재조회 여부는 확인하지 않았습니다.',
    'start_code_tip': '코드는 앱에 없습니다. Flutter 프로젝트에서 보세요. 각 기능 카드에 lib/ 아래 열어볼 파일 경로가 적혀 있습니다.',
    'mission_list_sdk_screen_tip':
        'SDK 플레이어·스튜디오 화면 위에는 Flutter UI 를 얹을 수 없습니다(네이티브 화면). 그 동안의 이벤트는 로그에 쌓이니, 돌아온 뒤 ⌗ 개발자 시트에서 확인하세요.',
    'group_runtime_state': '세션 상태',
    'action_read': '읽기',
  },
  'ja': {
    'qr_button': 'QR コードで入力',
    'qr_title': '認証情報 QR をスキャン',
    'qr_hint': 'テストアプリの QR コードにカメラを向けてください。ak(accessKey)・ck(campaignKey)・st(ストリームトークン)・userjwt を読み取ります。',
    'qr_rejected': 'この QR には使える値がありません。URL クエリに ak と ck の両方、または st、または userjwt が必要です。',
    'qr_camera_error': 'カメラを使用できません({0})。設定でカメラへのアクセスを許可するか、キーを直接入力してください。',
    'qr_applied': 'QR「{0}」— {1} を入力しました。値を確認してから「検証して開始」を押してください。',
    'app_name': 'ShopLive Flutter デモ',
    'start_title': 'ShopLive Flutter SDK\n連携デモ',
    'start_storage': '入力値はこの端末(shared_preferences)にのみ保存され、サーバーへは送信されません。',
    'start_tour_hint_missing': '内蔵デモキーが空です — --dart-define で渡すか、下で直接入力してください。',
    'msg_demo_keys_missing':
        '内蔵デモキーが空です。--dart-define=SHOPLIVE_DEMO_ACCESS_KEY と SHOPLIVE_DEMO_CAMPAIGN_KEY を渡すか、「自分のアカウントで試す」から進めてください。',
    'mission4_title': '画面の上に表示する',
    'mission4_desc': 'ホームフィードの上にミュートのプレビューを浮かべ、全画面へ昇格します。',
    'mission4_check': 'フィードの上にプレビュー表示 · 全画面へ昇格',
    'warn_os_pip_activity_only':
        'Android: OS PIP にはホスト Activity の android:supportsPictureInPicture="true" が必要です(このデモは設定済み)。ない場合は PIP_ACTIVITY_NOT_DECLARED を報告し in-App PIP のままになります。',
    'warn_overlay_hidden': 'HIDDEN は表示だけを止めます。コマンドチャネルは生きているため商品・クーポンのリクエストは届き続けます — ログタブで確認してください。',
    'warn_allow_screen_capture':
        'Android 専用(configuration.android)。false にすると SDK が FLAG_SECURE を設定し、スクリーンショット・ミラーリング・録画で映像が黒くなります。Flutter 3.0.2 は iOS 向けのオプションを公開していません。',
    'warn_mute_on_start':
        'ネイティブ Android デモ(SDK 3.0.0)で有効にすると再生が PIP に切り替わる問題が測定されました。Flutter では再測定していません — 確認目的でのみ有効にしてください。',
    'warn_config_merge': 'Flutter は configuration を現在の設定にマージします — 渡さないフィールドは直前の値を保ちます。このタブは常に全フィールドを送るので、表示どおりに再生されます。',
    'feed_tip_embed':
        'Flutter SDK 3.0.2 には埋め込み用のプレイヤーウィジェットがありません。最も近い方法は、プレイヤーを最初から in-App PIP で開始することです — この画面の上に浮かぶミュートのプレビュー。イベント・リクエスト・操作は全画面と同じです。',
    'feed_warn_activity_context': '浮かぶウィンドウはこのウィジェットツリーに属しません — フィードと一緒にスクロールせず、画面が消えても残ります。この画面は離れるときにウィンドウを閉じます。',
    'feed_card2_desc': 'スクロールしてもプレビューは浮かんだまま再生されます',
    'feed_card3_desc': '位置とサイズは pip.defaultPosition / scale で決まります',
    'feed_btn_start': '▶ プレビュー開始',
    'feed_btn_close': '✕ プレビューを閉じる',
    'feed_warn_expand_restream':
        '全画面は新しい start() ではなく、実行中のセッションに exitPictureInPicture() を呼びます。iOS では直後に stateChanged(loading) が届きます — ストリームの再取得有無は未確認です。',
    'start_code_tip': 'コードはアプリ内にはありません。Flutter プロジェクトで確認してください。各機能カードに lib/ 以下の開くファイルのパスが記載されています。',
    'mission_list_sdk_screen_tip':
        'SDK のプレイヤー・スタジオ画面の上には Flutter UI を重ねられません(ネイティブ画面)。その間のイベントはログに蓄積されるので、戻ってから ⌗ 開発者シートで確認してください。',
    'group_runtime_state': 'セッション状態',
    'action_read': '読む',
  },
};
