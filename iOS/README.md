# ShopLive 통합 SDK v3 — iOS 온보딩 데모앱

고객사가 **미션을 따라가며 `Integration/` 의 코드를 자기 앱에 그대로 붙여넣는** 방식으로 연동을 끝낼 수 있게 만든 UIKit 데모앱입니다.

- 연동 가이드: <https://sdk.shoplive.cloud> (미션 1~8 번호가 이 앱의 카드 번호와 같습니다)
- 화면 설계 근거: `shoplive-onboarding-demo-prototype.html` (화면 3개 · 오버레이 2개 · 기능 8개)

---

## 1. 바로 실행하기

```bash
open ShopliveOnboardingDemo.xcworkspace
```

`.xcodeproj` 는 저장소에 포함돼 있어 **Tuist 없이** 열어서 바로 빌드됩니다.
시뮬레이터/실기기 모두 동작하며, 내장 데모 캠페인 키가 들어 있어 **입력 없이** "둘러보기 · 바로 시작" 으로 미션 1~7 을 확인할 수 있습니다.
미션 8(송출)은 송출 토큰이 필요하고 **토큰은 소스에 두지 않으므로**, S1 에서 직접 입력해야 잠금이 풀립니다(입력값은 Keychain 에만 저장).

프로젝트 구성을 바꿔야 하면(파일 추가·설정 변경) Tuist 로 재생성합니다.

```bash
tuist generate --no-open
```

---

## 2. 코드 구조 — 두 층, 컴파일로 강제됨

| 디렉터리 | 성격 |
|---|---|
| **`Integration/`** | ★ **복사 대상.** SDK 호출만 있다. 하네스 의존 **0건** — 폴더째 복사하면 그대로 컴파일된다. |
| `Screens/` · `Support/` · `App/` | 데모 하네스(목록·로그 시트·옵션·테마·지역화). 복사 대상이 **아니다**. |

경계는 문서가 아니라 **두 가지 장치로 강제**한다.

**① 경계 스캐너** — `Integration/` 에 하네스 심볼(`EventLog`·`DemoTheme`·`L("…")` 등)이 등장하면 실패.
```bash
python3 scripts/integration_boundary_scanner.py
```

**② 복사 증명 타깃 `IntegrationCopyPasteProof`** — 소스가 `Integration/**` **하나뿐인** 프레임워크 타깃.
고객사가 빈 프로젝트에 `Integration/` 만 넣은 상황과 동일한 조건이라, 하네스 의존이 하나라도 생기면 빌드가 깨진다.
```bash
xcodebuild -workspace ShopliveOnboardingDemo.xcworkspace -scheme IntegrationCopyPasteProof \
  -destination 'generic/platform=iOS' build
```
> 스캐너가 못 잡는 것도 이 타깃이 잡는다. 실제로 리팩터 중 `demoLabel`(하네스 확장)·`PlayerConfigurationFactory.make()`(옵션탭 전용) 의존을 이 타깃이 검출했다.

### Integration/ 의 외부 연결 지점은 3개뿐

복사한 뒤 손댈 곳이 이것뿐이라는 뜻이다.

| 지점 | 기본값 | 용도 |
|---|---|---|
| `shopliveLog(_:_:)` | no-op | 로그. 자기 로거를 꽂거나 호출부를 지워도 된다 |
| `DeepLinkRouter.configurationProvider` | `.init()` | 딥링크 재생에 쓸 설정 |
| `DeepLinkRouter.delegateProvider` | `nil` | 딥링크 재생의 이벤트 수신자 |

데모앱은 `App/DemoBootstrap.swift` 에서 이 3개를 한 번에 꽂는다 — 고객사 앱에서 무엇을 연결해야 하는지 그대로 보여주는 예시다.

### 미션 ↔ 파일 맵

앱의 각 카드에 적힌 📄 경로가 그대로 이 표다.

| 미션 | 내용 | 파일 |
|---|---|---|
| — | 초기화 (앱 1회) | `Integration/ShopliveBootstrap.swift` |
| 1 | 플레이어 띄우기 | `Integration/PlayerLauncher.swift` |
| 2 | 딥링크로 띄우기 | `Integration/DeepLinkRouter.swift` + `App/SceneDelegate.swift` |
| 3 | 회원 정보 연결 | `Integration/UserSetup.swift` |
| 4 | 화면 안에 임베드 | `Integration/EmbeddedPlayerView.swift` |
| 5 | PIP 적용 | `Integration/PipOptions.swift` |
| 6 | 이벤트 · 상품 · 쿠폰 | `Integration/DemoPlayerDelegate.swift` |
| 7 | UI 커스터마이징 | `Integration/PlayerConfigurationFactory.swift` |
| 8 | 방송 송출 | `Integration/StudioLauncher.swift` |
| 공통 | 로그 훅 / enum 라벨 | `Integration/ShopliveLog.swift` · `ShopliveLabels.swift` |

---

## 3. 프레임워크

`Frameworks/` 에 xcframework 5종이 들어 있고 앱 타깃이 직접 링크·임베드합니다.

| xcframework | 내용 |
|---|---|
| `ShopliveCore` | 공통 — 인증 · 설정 · 사용자 · 에러 |
| `ShoplivePlayerSDK` | 시청 — HLS/WebRTC 엔진 내장 · 자동 절체 · PIP · 오버레이 |
| `ShopliveStreamerSDK` | 송출 — 스튜디오 UI 전체 (1차 WebRTC) |
| `ShopLiveWebRTCHelperSDK` | Player/Streamer 의 내부 의존 |
| `WebRTC` | rtc-ios 1.0.26 바이너리 |

각 슬라이스: `ios-arm64` (실기기) + `ios-arm64_x86_64-simulator`. `BUILD_LIBRARY_FOR_DISTRIBUTION=YES` 로 빌드해 `.swiftinterface` 를 포함합니다.

> **고객사 배포 시**: 로컬 xcframework 대신 SPM 으로 대체됩니다.
> ```
> https://github.com/shoplive/shoplive-ios-sdk
> ```
> 그때는 `Frameworks/` 참조를 지우고 `ShoplivePlayerSDK` / `ShopliveStreamerSDK` 만 타깃에 추가하면 됩니다(Core 는 자동으로 따라옵니다).

### 빌드 재현 (SDK 소스에서)

**`matrix-sdk-ios` 의 `chore/sdk-version-3.0.0` 브랜치 `36a7157a`** 기준으로 추출했습니다(2026-07-30 재빌드).
그 커밋은 `dev`(`5f0ee781`) + **버전 상수 5개만 `3.0.0` 으로** 올린 것이라, 동작 변경은 없습니다
— Android(`3.0.0`)와 버전 표기를 맞추기 위한 변경입니다.
`Shoplive.sdkVersion` 이 `3.0.0` 을 반환하는 것은 시뮬레이터에서 개발자 시트 로그로 실측 확인했습니다.
(그 이전 빌드는 `feature/SMV-1446-repack-player` `8d66bcd6` 기준이었습니다 — §7 에 API 차이를 적어 뒀습니다.)

재현 절차:

```bash
cd matrix-sdk-ios            # 라인 심링크가 이미 international 이면 use-international.sh 불필요
git switch chore/sdk-version-3.0.0

bash scripts/run-tuist.sh generate --no-open
# ① 스킴 4종(ShopliveCore · ShopLiveWebRTCHelperSDK · ShoplivePlayerSDK · ShopliveStreamerSDK) 을
#    iphoneos / iphonesimulator 로 archive (BUILD_LIBRARY_FOR_DISTRIBUTION=YES)
#    → xcodebuild -create-xcframework
# ② WebRTC 는 재빌드 대상이 아닙니다 — 기존 것을 그대로 씁니다
#    (필요하면 .build/checkouts/rtc-ios/Frameworks/WebRTC.xcframework 복사)
```

> **버전 상수는 `ShopliveCore` 안에서만 실체를 가집니다.** `package` 스코프라 의존 모듈이 인라인하지 않고
> 런타임에 읽어 가므로, 재빌드해도 실질적으로 바뀌는 바이너리는 `ShopliveCore` 하나입니다.
>
> ⚠️ **바이너리를 `strings` 로 버전 검증할 수 없습니다.** `"3.0.0"`·`"2.0.20.1"` 모두 15바이트 이하라
> Swift small-string 최적화로 코드에 immediate 로 인라인됩니다(문자열 리터럴이 남지 않음).
> 확인은 반드시 런타임(`Shoplive.sdkVersion`)으로 하세요.

> `ShopLiveTestApp/Project.swift` 의 죽은 모듈 참조(`Modules/CorePlayer`·`Modules/WebRTCPlayer`)는
> 수정돼 이제 `tuist generate` 가 그냥 통과합니다. 예전에 쓰던 `TUIST_GENTYPE=SDKONLY` 우회는 불필요합니다.

> ⚠️ **`scripts/use-international.sh` 는 실행 중인 Xcode 를 종료시킵니다.** 작업 중이면 쓰지 마세요.
> 이번 dev 빌드는 별도 워크트리(`git worktree add --detach … origin/dev`)에서 루트 심링크를
> 직접 만들어(`ln -sfn lines/international/<name> <name>`) 사용자의 체크아웃·Xcode 를 건드리지 않았습니다.

---

## 4. 자격증명

`Support/DemoCredentials.swift` 의 `DemoDefaults` 에 사내 데모 캠페인 값이 들어 있습니다.

```swift
enum DemoDefaults {
    static let accessKey = "uv9CGthPzlvsInZerCw0"
    static let campaignKey = "faea28dd96c3"
    static let streamToken = "1-5QALAn…"                 // 미션 8 전용
}
```

- 고객사에 전달할 때는 이 세 값을 **비우거나 고객사 키로 교체**하세요. 비우면 앱이 S1 에서 입력을 요구합니다.
- 사용자가 입력한 값은 기기에만 저장됩니다(accessKey/campaignKey → UserDefaults, 송출 토큰 → Keychain). 서버로 전송하지 않습니다.

> **위 세 값은 사내 데모 캠페인용**이라 미션 8까지 설정 없이 돌아가도록 그대로 커밋해 뒀습니다.
> **고객사 앱에서는 이 방식을 따라 하지 마세요** — 송출 토큰은 읽을 수 있는 사람이면 누구나
> **해당 캠페인으로 방송을 시작할 수 있는** 권한입니다. 자기 토큰은 소스에 두지 말고
> 빌드 시 주입하거나 런타임에 입력받으세요(S1 입력값은 Keychain 에만 저장됩니다).

> **캠페인 `faea28dd96c3` 은 현재 Apple 의 공개 샘플 HLS(BipBop)를 가리킵니다** (2026-07-30 22:09 실측).
> 재생은 1920x1080@60fps VOD 로 정상이지만 실제 라이브 커머스 콘텐츠가 아니므로,
> 채팅·상품·LIVE 배지 등 방송 중에만 나타나는 요소는 이 캠페인으로 확인할 수 없습니다.

---

## 5. 다국어 (en 기본 / ko / ja)

- 문자열: `ShopliveOnboardingDemo/Resources/{en,ko,ja}.lproj/Localizable.strings` (각 107개 키, 누락 없음)
- 조회: `Support/DemoStrings.swift` 의 `L("key")` / `L("key", args...)`
- **기본(개발) 언어는 `en`** 입니다 — 기기 언어가 ko/ja 면 해당 언어로, 그 외 언어면 en 으로 폴백합니다.
  (`CFBundleDevelopmentRegion = en`, `CFBundleLocalizations = [en, ko, ja]`)
- **EventLog 메시지는 지역화하지 않습니다** — 개발자가 읽는 SDK 호출·이벤트 기록이라 API 이름 원문이 그대로 보이는 것이 정확합니다.
- **소스 주석은 전부 영어입니다** (2026-07-30 전환). `ShopliveIntegration/` 은 고객사가 그대로 복사해
  읽는 교재이므로, 영어권 고객사도 주석만 읽고 이해할 수 있어야 합니다. 하네스(`Screens/`·`Support/`·`App/`)와
  `Project.swift`·경계 스캐너도 함께 영어로 맞췄습니다 — 한 프로젝트 안에서 언어가 섞이지 않도록.
  검증: `grep -rn '[가-힣]' ShopliveIntegration ShopliveOnboardingDemo Project.swift` → `Resources/*.lproj` 외 0건.

언어별 확인:

```bash
xcrun simctl launch <UDID> cloud.shoplive.onboarding.demo -AppleLanguages "(ja)"
```

한국어 파일(`ko.lproj`)이 기준 원문이고, 나머지는 그 번역입니다 — 새 문자열을 추가할 때는 3개 파일 모두에 넣으세요.

---

## 6. 실측으로 확인된 SDK 동작 (2026-07-30, SDK 3.0.0 — `dev` `5f0ee781` 코드)

데모앱을 시뮬레이터에서 실제로 돌려 확인한 사실입니다. 앱 코드 곳곳의 `⚠️`/`Warning` 주석과 대응합니다.

### 정상 동작 확인
`initialize` → 캠페인 해소 → 오버레이 웹뷰 로드 → `playback` / `error` 델리게이트 전달까지 이어집니다. 개발자 시트 로그에서 실시간으로 보입니다.

### 설정 필드 소비처 — dev 에서 6종 전부 배선됨 ✅ (이전 기록 정정)

`8d66bcd6` 빌드 시점에는 아래 6개가 "값만 저장되고 동작 미반영" 이었습니다.
**dev(`5f0ee781`) 에서는 전부 소비처가 생겼습니다** — 코드 근거:

| 필드 | 배선 지점 |
|---|---|
| `overlay.ui` | `PublicSurface/ShoplivePlayerView.swift:160` → `_overlayUI` |
| `pip.isOSPipEnabled` | `Core/Adapter/ConfigurationBridge.swift:43` (2026-07-30 구현) |
| `navigation.shareScheme` | `ShoplivePlayerView.swift:157` `engine.action(.setShareScheme)` |
| `appearance.allowScreenCapture` | `ConfigurationBridge.swift:38` → `ScreenCaptureGuard` (2026-07-30 구현) |
| `ShoplivePlayOptions.referrer` | `ShoplivePlayerView.swift:156` `engine.action(.setReferrer)` |
| `ShoplivePlayOptions.keepWindowStateOnPlayExecuted` | `ShoplivePlayerView.swift:92` |

> 근거는 **정적(코드 읽기)** 입니다. 각 필드가 실제로 의도한 동작을 내는지는 아직 **실측하지 않았습니다** — `요확인`.
> 특히 `allowScreenCapture`(캡처 감지 가림)·`isOSPipEnabled`(OS PIP 미등록)는 시뮬레이터로 확인이 어려워 실기기 검증 대상입니다.

데모는 `EmbeddedPlayerView` 에서 런타임 프로퍼티 `player.overlayUI = .hidden` 을 **여전히 함께** 설정합니다
(설계서 §3.4 를 호출부에 명시적으로 남기는 목적). 그래서 임베드에서 오버레이가 숨은 것이
config 경로 때문인지 런타임 경로 때문인지는 이번 실측으로 **분리 확인되지 않았습니다**.

(`autoEnterOnLeaveScreen` · `isStatusBarVisible` 는 공개 표면에서 **삭제**됐습니다 — §7.)

### 정상 재생 경로 (캠페인 `8f595bd943cc`, 2026-07-30 15:45 실측)
`initialize` → embed → `playback(REQUEST → AUDIO_LOADED → STARTED → RENDERING…)` +
`connectionStateChanged(.connecting → .connected)` 로 **에러 0건**, 실제 영상이 재생됩니다.
이 캠페인은 WebRTC egress 가 404 인데 LL-HLS 는 살아 있고, SDK 는 **에러 이벤트 없이 조용히 HLS 로 재생**했습니다
— 설계서 §5 "절체는 공개 이벤트로 알리지 않는다" 와 일치합니다.

### 사용처별 프리셋 — 풀스크린 = `.live`, 임베드 = `.preview`

dev 는 `ShoplivePlayerConfiguration` 에 **이름 있는 프리셋 2종**을 제공합니다
(`Modules/PlayerSDK/Sources/PublicSurface/PlayerConfiguration.swift:79-105`).
데모는 이걸 `PlayerConfigurationFactory.fullScreenLive()` / `.embeddedPreview()` 로 감싸고,
`DemoConfigBuilder.Usage` 축으로 호출부에서 골라 씁니다.

| | `.live` (풀스크린) | `.preview` (임베드) |
|---|---|---|
| 값 | `.init()` 과 동일 — 전 기능 | 아래 5개만 다름 |
| `pip.isInAppPipEnabled` / `isOSPipEnabled` | 기본(on) | **false / false** |
| `overlay.ui` | `.builtIn` (기본) | **`.hidden`** |
| `appearance.resizeMode` | `.fill` | `.fill` |
| `sound.muteOnStart` | false | **true** |

- 쓰는 곳: `MissionListViewController`·`DemoBootstrap` 딥링크·승격 후 → `.fullScreenLive`,
  `FeedDemoViewController` 임베드 → `.embeddedPreview`.
- `.preview` 는 **표시 정책만** 바꿉니다. v2 `ShopLive.preview()` 가 함께 하던 프리뷰 전용 스트림
  (`previewLiveUrl`·`previewEgressProtocols`) 전환은 임베드 경로에 배선이 없어 포함되지 않습니다
  — 재생되는 스트림은 라이브와 같습니다(SDK 주석에 명시).
- `.preview` 를 쓰면 옵션 탭의 수동 오버라이드는 적용하지 않습니다(프리셋 의미를 유지). 색·customParameters 만 덧칠합니다.

**실측 결과 (2026-07-30 20:29~20:33)**: 임베드는 오버레이 없이 영상만, 풀스크린은 오버레이 전체
(로고·LIVE·공유·PIP·상품 배너·좋아요/채팅)가 뜨는 것을 화면으로 확인했습니다. 에러 0건.

**단, 임베드에서 `.fill` 이 화면상 `.fit` 처럼 보입니다** ⚠️
`resizeMode` 자체는 임베드 경로에 정상 전달됩니다(`ShoplivePlayerView.swift:161` → `:202` `.setResizeMode`).
문제는 그 다음 프레임 계산입니다 — `Core/ShopLivePlayerView/View/View + VideoGravity.swift:182` 가
호스트 뷰 bounds 가 아니라 **`UIScreen.main.bounds`** 로 비디오 프레임을 구합니다.
그래서 210pt 높이 컨테이너에 화면 크기 기준 프레임이 들어가 좌우 여백이 생깁니다.
앱 쪽에서 우회할 수 있는 값이 아니라 **SDK 수정이 필요한 항목**입니다(데모는 그대로 노출해 둡니다).

### 정상 재생 중 오지 않는 이벤트 ⚠️

| 이벤트 | 15:45(b8591bde) | 18:37(8d66bcd6) | 20:33(dev `5f0ee781`) |
|---|---|---|---|
| `stateChanged` | **0** | **0** | **0** (여전히 안 옴) |
| `campaignStatusChanged` | 0 | **1** ✅ 복구 | 2 ✅ |
| `campaignInfoReceived` | 0 | **1** ✅ 복구 (title "Kio V5 new") | 2 ✅ |
| `playback` · `connectionStateChanged` · `analytics` | 정상 | 정상 | 정상 (playback 218 · error **0**) |

`8d66bcd6` 의 "임베드 경로 미완 배선 복구" 로 오버레이 웹뷰가 뜨면서
`campaignStatusChanged` · `campaignInfoReceived` 는 **정상화됐습니다**(오버레이 웹이 이 두 이벤트의 출처였음).
`stateChanged` 는 아직 오지 않습니다.

설계서 §3.6 은 `stateChanged(ShoplivePlayerState)` 가 재생 수명주기를 통지한다고 정의하지만 실제로는 오지 않습니다.
그래서 `player.state` 는 계속 `.idle` 이고, `analytics` 도 `isPlaying: false` · `durationMs: 0` 으로 옵니다
(어댑터가 state 에서 파생하기 때문).

**앱 쪽 대응**: 재생 도달 판정을 `stateChanged` 가 아니라 **`playback(STARTED/RENDERING)`** 으로 합니다
(`DemoPlayerDelegate`). 이걸 안 하면 "확인됨" 배지가 영원히 안 붙습니다.
고객사 앱도 재생 상태를 `stateChanged` 에만 의존하면 안 됩니다.

### 스트림이 없는 캠페인일 때
`campaignStatus: "ONAIR"` 인데 egress 가 전부 404 인 캠페인(예: 이전 데모 `faea28dd96c3`)에서는:

- `error(code: .unexpectedError, isRecoverable: false)` 가 **초당 2회 무한 반복**되고 HLS 폴백도 없습니다.
- 원본 연결 코드(`connection Issue [34]`)가 `message` 문자열에만 남고 `ErrorCode` 로 보존되지 않습니다.
- 재시도 중인데 `isRecoverable: false` 로 옵니다 — §5 와 어긋납니다.

**앱 쪽 대응**: 플레이어를 닫지 않고 세션당 1회만 사유를 안내합니다. 나가기는 `‹ 목록`.

### 갇힘(black screen) 방지
스트림이 없어 오버레이가 못 뜨면 SDK 자체 닫기 버튼도 함께 사라져 탈출구가 없어진다.
그래서 데모는 SDK 플레이어를 **자식 VC 로 품는 호스트**(`Screens/PlayerHostOverlay.swift` 의
`PlayerHostViewController`)를 쓰고, 그 위에 `‹ 목록` / `⌗ 개발자` 를 형제 뷰로 올린다.
호스트 view 의 subviews 가 `[player.view, controls]` 순이라 controls 가 항상 먼저 히트테스트되고,
SDK 가 내부에 무엇을 올리든 그것은 `player.view` 안쪽이라 이 순서를 이기지 못한다.

### in-App PIP — 호스트가 비켜나야 한다 ⚠️
PIP 로 승격되면 렌더 표면이 **앱 window 위 플로팅 컨테이너**로 옮겨가고, 원래 풀스크린 뷰에는
아무것도 남지 않는다. 그대로 두면 화면 전체가 검게 덮이고 그 위에 작은 PIP 창만 뜬다(사용자 보고 증상).

데모 대응:
- 호스트를 `.overFullScreen` 으로 present 한다(`.fullScreen` 은 presenter 뷰를 계층에서 떼어내
  호스트를 숨겨도 뒤에 아무것도 없다).
- `stateChanged(.inAppPIP)` 를 받으면 `PlayerHostViewController.setPipPresentation(true)` 로 호스트를 숨긴다
  → 뒤의 목록 화면이 보이고 PIP 만 떠 있는 정상 UX.
- 복귀는 `stateChanged` 로 오지 않을 수 있어 `isInPictureInPicture` 를 0.5초 간격으로 폴링하는 안전망을 둔다.

`stateChanged` 는 **`.inAppPIP` 진입 때만** 오고 playing/loading 전이는 오지 않는다(실측).

PIP 창은 `pip.padding = 0`(스펙 기본값)이면 화면 우/하단에 딱 붙어 홈 인디케이터까지 물려 잘려 보인다.
데모는 기본값만 `12` 로 띄웠다(옵션 탭에서 0 으로 되돌릴 수 있음).

### 임베드 뷰는 영상 전용으로 강제해야 한다 ⚠️
설계서 §3.4 는 View 방식을 "영상 전용, `overlayUI` 는 `.hidden` 고정" 으로 규정하지만 SDK 가 이를
강제하지 않는다(setter 가 `.builtIn` 대입을 받아준다). 그 결과 210pt 짜리 임베드 박스 안에
풀스크린용 오버레이가 축소된 채 그려진다(실측). 데모는 `play()` 직후 `overlayUI = .hidden` 을 명시 대입한다.

### resilient enum — `@unknown default` 필수
SDK 는 `BUILD_LIBRARY_FOR_DISTRIBUTION=YES` 로 배포돼 공개 enum 이 **resilient** 합니다. 따라서 `PlayerEvent` · `PlayerRequest` · `StreamerEvent` · `PlayerState` 등을 `switch` 할 때 모든 case 를 적어도 **`@unknown default` 가 없으면 경고**가 나고 Swift 6 언어 모드에서는 **에러**입니다.
`Integration/` 의 스위치에는 전부 넣어 뒀습니다 — 특히 `PlayerRequest` 는 응답(`respond`)을 요구하므로, 모르는 case 를 조용히 무시하면 오버레이가 응답을 기다리며 멈출 수 있습니다.

### iOS 에 없는 API
Android 의 `expandToFullScreen()`(임베드 → 풀스크린 세션 인계)에 해당하는 API 가 없습니다. 미션 4 는 임베드 세션을 정리하고 풀스크린 VC 를 새로 present 하므로 짧은 재로딩이 한 번 더 생깁니다.

---

## 7. 공개 타입 이름 — 전면 `Shoplive` 접두 (breaking)

이 브랜치에서 v3 공개 타입이 **전부 `Shoplive` 접두로 개명**됐습니다. 이전 이름으로 작성한 코드는 컴파일되지 않습니다.

| 이전 | 현재 |
|---|---|
| `PlayerState` | `ShoplivePlayerState` |
| `CampaignStatus` | `ShopliveCampaignStatus` |
| `ConnectionState` | `ShopliveConnectionState` |
| `ResizeMode` | `ShopliveResizeMode` |
| `PipPosition` | `ShoplivePipPosition` |
| `OverlayUIMode` | `ShopliveOverlayUIMode` |
| `NavigationAction` | `ShopliveNavigationAction` |
| `CampaignInfo` | `ShopliveCampaignInfo` |
| `PlayerConfiguration` | `ShoplivePlayerConfiguration` |
| `PlayOptions` | `ShoplivePlayOptions` |
| `PlayerEvent` / `PlayerRequest` | `ShoplivePlayerEvent` / `ShoplivePlayerRequest` |
| `Attribution` (Core) | `ShopliveAttribution` |
| `Gender` (Core) | `ShopliveGender` |
| `ErrorCode` (Core) | `ShopliveErrorCode` |
| `AppearanceOptions` (Streamer) | `ShopliveAppearanceOptions` |
| `BroadcastState` / `StreamerEvent` | `ShopliveBroadcastState` / `ShopliveStreamerEvent` |

중첩 옵션 타입(`PipOptions` · `SoundOptions` · `AppearanceOptions` · `NavigationOptions` · `OverlayOptions`)은
`ShoplivePlayerConfiguration` 안에 그대로 남아 이름이 바뀌지 않았습니다.

**삭제된 필드 3개** — 참조하면 컴파일 에러입니다.

- `PipOptions.keepWindowStyleOnReturnFromOSPip`
- `PipOptions.autoEnterOnLeaveScreen` (화면 이탈 자동 승격 — 수동 `enterPictureInPicture()` 만 남음)
- `AppearanceOptions.isStatusBarVisible`

### dev(`5f0ee781`) 기준 추가 차이 — `8d66bcd6` 에서 바뀐 것

| 항목 | `8d66bcd6` | dev `5f0ee781` |
|---|---|---|
| `ShoplivePlayerConfiguration.live` / `.preview` | 없음 | **추가** (이름 있는 프리셋 2종 — §6) |
| `AppearanceOptions.resizeMode` | 없음 | **추가** (`.fill` / `.fit`, 기본 `.fill`) |
| `AppearanceOptions.allowScreenCapture` | 소비처 없음 | `ScreenCaptureGuard` 로 **동작 구현** (기본 `true`) |
| Streamer `ShopliveAppearanceOptions` | 있음 | **삭제** — 위 표의 마지막 두 줄 중 `AppearanceOptions (Streamer)` 항목은 dev 에 존재하지 않습니다 |
| `ShopliveStreamerViewController` 생성자 | `init(campaignKey:appearance:)` | **`init(campaignKey:)` 만** |
| `Shoplive.present(campaignKey:streamToken:from:delegate:)` | `appearance:` 파라미터 있음 | **없음** |

→ 그래서 `StudioLauncher.swift` 의 `appearance(fontFamily:)` 헬퍼는 **삭제**했고, 자리에 NOTE 주석을 남겼습니다.
   송출 화면의 폰트·색 커스터마이즈는 dev 공개 표면에서 지정할 방법이 현재 없습니다.

---

## 8. 가이드 문서와 실제 API 가 다른 부분

<https://sdk.shoplive.cloud> 의 iOS 예제 중 **현재 바이너리에서 컴파일되지 않는** 것들입니다. 이 데모는 실제 API 기준으로 작성돼 있습니다.

| 가이드 | 실제 |
|---|---|
| `Shoplive.setUser(nil)` 로 로그아웃 | `setUser` 는 **비옵셔널**. 로그아웃은 `Shoplive.logout()` |
| `.profile(..., custom: ["grade": "vip"])` | `custom` 파라미터 **없음**. `rank: Int?` 가 있음 |
| `ShoplivePlayerView()` | `init(configuration:)` **필수**(무인자·스토리보드 경로 봉인) |
| `respond(.success)` | `ShopliveCouponResult(couponId:success:message:status:alertType:)` 전체 생성 |
| `playback(let pb)` 를 `pb != .rebuffering` 로 비교 | `PlaybackEvent` 는 **클래스**. 상태는 `pb.event`(`PlaybackEventType`) |
| `ShopLiveAnalyticsInfo` / `ShopLivePlayerCampaign` | `ShopliveAnalyticsInfo` / `ShopliveCampaign` (소문자 l) |
| `playerView.expandToFullScreen()` | iOS 에 없음(Android 전용) |

---

## 9. 앱 구성 (프로토타입 대응)

| 프로토타입 | 파일 |
|---|---|
| **S1** 시작 | `Screens/StartViewController.swift` |
| **S2** 기능 목록 | `Screens/MissionListViewController.swift` |
| **S3** 실행 화면 | SDK 가 그림 + `Screens/PlayerHostOverlay.swift`(데모 컨트롤) · `Screens/FeedDemoViewController.swift`(피드 variant) |
| **V1** 개발자 시트 | `Screens/DevSheetViewController.swift` (로그 / 옵션 2탭) |
| **V2** 상품 상세 | `Screens/ProductDetailViewController.swift` |

옵션 탭은 `PlayerConfiguration` 의 **모든 공개 필드**에 컨트롤을 하나씩 두고, 동작하지 않는 필드는 경고로 표시합니다.

---

## 10. 코드 서명

`Project.swift` 에 SDK 저장소와 **같은 팀**을 넣어 뒀습니다(`Tuist/ProjectDescriptionHelpers/Project+Templates.swift` 와 동일).

```swift
"CODE_SIGN_STYLE": "Automatic",
"DEVELOPMENT_TEAM": "D237UGRPX6",
"CODE_SIGN_IDENTITY": "Apple Development",
// 시뮬레이터는 서명 불필요 — 팀이 없는 머신에서도 시뮬레이터 빌드는 통과
"CODE_SIGNING_ALLOWED[sdk=iphonesimulator*]": "NO",
```

이게 없으면 Xcode 및 기기 타깃 빌드가 다음으로 실패합니다.

```
error: Signing for "ShopliveOnboardingDemo" requires a development team.
```

고객사에 전달할 때는 `DEVELOPMENT_TEAM` 을 **고객사 팀 ID 로 바꾸거나 지우고** 각자 Xcode 의
Signing & Capabilities 에서 팀을 고르게 하세요. 번들 ID(`cloud.shoplive.onboarding.demo`)도
고객사 프로비저닝에 맞게 교체가 필요합니다.

---

## 11. 요구사항

- Xcode 26 이상 (검증: 26.6)
- iOS 15.0 이상 — WebRTC OS PIP 가 iOS 15+ 전용 API 를 사용
- 미션 8(송출)은 `NSCameraUsageDescription` · `NSMicrophoneUsageDescription` 필요 (Info.plist 에 포함)
- 딥링크 스킴: `shopliveDemo://live?campaign=<KEY>&ref=<REFERRER>`
