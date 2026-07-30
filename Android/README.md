# ShopLive 온보딩 데모앱 (Android)

통합 SDK v3(Player · Streamer)의 **8가지 기능을 탭 한 번으로 확인**하는 앱입니다.
고객사 개발자가 이 앱으로 동작을 눈으로 확인하고, **각 기능 카드에 적힌 파일을 열어
코드를 그대로 자기 앱에 붙여 넣는** 방식으로 쓰도록 만들었습니다.

- 연동 가이드: https://sdk.shoplive.cloud (한국어 / English / 日本語)
- 카드 번호 = 가이드의 **Mission 번호**와 동일

---

## 1. 자격증명 넣기

`local.properties.sample` 을 `local.properties` 로 복사한 뒤 값을 채웁니다.
`local.properties` 는 `.gitignore` 대상이라 **커밋되지 않습니다.**

```
sdk.dir=/Users/<you>/Library/Android/sdk

# 사설 Maven (필수) — 담당자 발급 값
shoplive.maven.username=
shoplive.maven.password=

# 둘러보기 모드용 데모 키 (선택)
shoplive.demo.accessKey=
shoplive.demo.campaignKey=
shoplive.demo.streamToken=
```

환경변수 `SHOPLIVE_MAVEN_USERNAME` / `SHOPLIVE_MAVEN_PASSWORD`,
`SHOPLIVE_DEMO_ACCESS_KEY` / `SHOPLIVE_DEMO_CAMPAIGN_KEY` / `SHOPLIVE_DEMO_STREAM_TOKEN`
로도 주입할 수 있습니다(CI용). 우선순위는 `local.properties` → `gradle.properties` → 환경변수입니다.

데모 키를 비워 두면 앱의 "둘러보기" 버튼이 잠기고, 사용자가 시작 화면에서 직접
accessKey · campaignKey 를 입력해 진행합니다.

기본 저장소는 개발용(`repo.us1`)입니다. 고객사 배포용을 쓰려면
`shoplive.maven.url=https://repo-mig.us1.shoplive.cloud/repository/shoplive/` 를 추가하세요.

## 2. 빌드

```bash
./gradlew :app:assembleDebug
```

---

## 그래들 의존성 (고객사가 복사할 부분)

### 저장소 — `settings.gradle.kts`

신규 프로젝트의 표준 위치입니다.

```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        maven {
            url = uri("https://repo.us1.shoplive.cloud/repository/shoplive/")
            credentials {
                username = "<발급받은 username>"
                password = "<발급받은 password>"
            }
        }
        mavenCentral()
    }
}
```

Groovy + 예전 방식(프로젝트 루트 `build.gradle`)도 그대로 동작합니다.

```groovy
allprojects {
    repositories {
        google()
        maven {
            url 'https://repo.us1.shoplive.cloud/repository/shoplive/'
            credentials {
                username = "<발급받은 username>"
                password = "<발급받은 password>"
            }
        }
        mavenCentral()
    }
}
```

### 의존성 — app 모듈

```groovy
def shoplive_sdk_version = "3.0.0"
implementation "cloud.shoplive:shoplive-player-sdk:$shoplive_sdk_version"
implementation "cloud.shoplive:shoplive-streamer-sdk:$shoplive_sdk_version"
```

- **시청만** 쓰면 `shoplive-player-sdk` 만
- **송출만** 쓰면 `shoplive-streamer-sdk` 만
- 둘 다 쓰면 둘 다 (core · exoplayer · webrtc · android-webrtc 는 내부 의존이라
  선언하지 않아도 되고, 겹치는 의존성도 SDK 쪽에서 정리됩니다)

이 프로젝트는 버전 카탈로그(`gradle/libs.versions.toml`)로 같은 선언을 관리합니다.

### 매니페스트

`INTERNET` · `ACCESS_NETWORK_STATE` · `CAMERA` 는 AAR 에 이미 선언돼 병합되지만,
**`RECORD_AUDIO` 는 AAR 에 없으므로 송출을 쓰는 앱이 직접 선언해야 합니다.**

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<!-- 광고 ID 기반 어트리뷰션을 쓸 때만 -->
<uses-permission android:name="com.google.android.gms.permission.AD_ID" />
```

런타임 권한 요청은 `ShopliveStreamer.start()` 가 대신 해 줍니다(`intent()` 는 하지 않습니다).

---

## 구성

- **Jetpack Compose + Material 3**, 단일 Activity + Navigation Compose, ViewModel + StateFlow
- compileSdk 35 / minSdk 24 / Java 17 / Kotlin 2.0.21 / AGP 8.7.3
- applicationId `cloud.shoplive.onboarding` — SDK 내부 데모앱(`cloud.shoplive.demo`)과
  한 기기에 함께 설치할 수 있습니다.

### 화면

| | 화면 | 소유 |
| --- | --- | --- |
| S1 | 시작 (둘러보기 / 내 계정) | 데모앱 |
| S2 | 기능 목록 8개 — **카드 탭 = 즉시 실행** | 데모앱 |
| S3 | 플레이어 · 스튜디오 | **SDK** (Activity) |
| S3 | 홈 피드 (Mission 4, 임베드 View) | 데모앱 |
| V1 | 개발자 시트 (로그 / 옵션) | 데모앱 · ModalBottomSheet |
| V2 | 상품 상세 | 데모앱 · Activity |

### 미션 ↔ 소스 파일

카드에 적힌 경로가 앱과 코드를 잇는 유일한 다리입니다.

| # | 기능 | 파일 |
| --- | --- | --- |
| 1 | 플레이어 띄우기 | `sdk/PlayerLauncher.kt` |
| 2 | 딥링크로 띄우기 | `sdk/DeepLinkRouter.kt` |
| 3 | 회원 정보 연결 | `sdk/UserSetup.kt` |
| 4 | 화면 안에 임베드 | `ui/feed/FeedScreen.kt` |
| 5 | PIP로 계속 보기 | `sdk/PipOptions.kt` |
| 6 | 이벤트 · 상품 · 쿠폰 | `sdk/DemoPlayerDelegate.kt` |
| 7 | UI 커스터마이즈 | `sdk/PlayerConfigurationFactory.kt` |
| 8 | 라이브 송출하기 | `sdk/StudioLauncher.kt` |

초기화는 `sdk/ShopliveInitializer.kt`, 런타임 제어 핸들은 `sdk/PlayerSession.kt` 입니다.
`sdk/` 아래 파일에는 **왜 그렇게 써야 하는지**를 KDoc 으로 적어 두었습니다
(Activity context 요구, configuration 불변 계약, respond 누락이 버그인 이유 등).

### 딥링크 (Mission 2)

```
shoplivedemo://live?campaign={CAMPAIGN_KEY}&ref={REFERRER}
```

앱 안의 "가짜 푸시" 배너는 실제 `ACTION_VIEW` Intent 를 발사해 `SchemeActivity` →
`MainActivity` 경로를 그대로 통과합니다. 콜드 스타트에서도 `initialize` 이후에
재생이 시작되도록 파싱과 재생을 분리해 두었습니다.

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "shoplivedemo://live?campaign=<CAMPAIGN_KEY>&ref=push_test"
```

### 다국어

- `values/` = **English** · `values-ko/` = 한국어 · `values-ja/` = 日本語
- 159개 문자열 키가 세 로케일에 모두 정의되어 있습니다(누락·잉여 0).

**기본 언어는 English 이고, 기기 언어를 따라가지 않습니다.** 한국어 기기에서도 앱은
English 로 열립니다. 여러 국가 고객사에 같은 빌드를 전달하는 앱이라, 기기 언어를 따르면
한국 기기에서 영어·일본어 화면을 확인할 방법이 없기 때문입니다.

전환은 **시작 화면 상단의 `English / 한국어 / 日本語` 세그먼트**로 하고, 선택은 기기에
저장됩니다. 구현은 [`data/LocaleSetting.kt`](app/src/main/java/cloud/shoplive/onboarding/data/LocaleSetting.kt) —
안드로이드 13+ 의 앱별 언어 설정(`LocaleManager`) 대신 자체 설정 + 각 Activity 의
`attachBaseContext` 로 처리합니다. minSdk 24 까지 동일하게 동작해야 하고, 시스템 설정과
앱 설정이 서로 덮어쓰는 상황을 피하기 위해서입니다.

기기 언어를 따르게 되돌리려면 `LocaleSetting.wrap()` 이 원본 Context 를 그대로 반환하도록
하고 각 Activity 의 `attachBaseContext` 오버라이드를 지우면 됩니다.

두 가지 예외:

- **SDK 가 그리는 화면(플레이어 오버레이·스튜디오)의 언어는 이 설정과 무관합니다.** SDK
  Activity 는 데모앱의 `attachBaseContext` 를 거치지 않고, 오버레이 문구는 SDK·서버가
  관리합니다. 앱 UI 는 English 인데 플레이어 채팅 UI 는 기기 언어로 보일 수 있습니다.
- **개발자 로그(⌗ 시트)는 의도적으로 영어 단일 언어**입니다. SDK API 호출을 그대로 비추는
  기술 로그이고, 버그 리포트에 붙여 공유되기 때문입니다.

---

## 확인이 자동으로 되는 방식

"확인됨" 배지는 사용자가 체크하는 게 아니라 **SDK 이벤트로 자동 판정**됩니다
(`data/MissionProgress.kt`).

| 판정 근거 | 미션 |
| --- | --- |
| `Playback.Started` | 1 · 2 · 3 · 4 · 7 |
| `StateChanged(IN_APP_PIP)` | 5 |
| `Navigation` / `Coupon` 요청 수신 | 6 |
| `StreamerEvent.StateChanged(LIVE)` | 8 |

---

## 프로토타입과 달라진 점 (실제 SDK 제약 반영)

| 항목 | 프로토타입 | 실제 |
| --- | --- | --- |
| 플레이어 화면 위 로그 FAB · 용어 번호 토글 | 플레이어 위에 표시 | **불가** — 플레이어·스튜디오는 SDK 소유 Activity. 로그는 쌓아 두고 앱으로 돌아와 확인 |
| `pip.autoEnterOnLeaveScreen` 옵션 | 옵션에 존재 | **공개 표면에 없음** — 화면을 벗어날 때 PIP 는 앱이 `enterPictureInPicture()` 로 직접 처리 |
| 임베드 뷰의 채팅·상품 오버레이 | 표시 | **영상 전용** — `overlayUI` 는 HIDDEN 고정(커맨드 채널은 유지) |
| 임베드 뷰 + OS PIP | 언급 | **풀스크린 전용** — 임베드는 in-App PIP 만 |
| `appearance.allowScreenCapture` 기본값 | `false` | 실제 구현 기본값 **`true`** (문서 정정 대상) |
| Mission 8 잠금 | 내 계정 모드에서만 | **토큰이 없으면 항상 잠금** — 토큰 없이는 방송을 시작할 수 없으므로 |
| 키 사전 검증 | "재생 전 검증에서 걸러짐" | SDK 에 사전 검증 API가 없음 → 형식만 로컬 검사 + error 이벤트를 원인별 문장으로 번역 |
| 상품 상세 | 모달 시트 | **별도 Activity** — SDK 플레이어 위에 올려야 보이기 때문 |
| 피드 리스트 | (미지정) | `LazyColumn` 대신 `Column + verticalScroll` — 임베드 뷰는 detach 시 자원을 해제하므로 lazy 아이템으로 두면 스크롤만 해도 재생이 끊김 |

## 검증 상태 (에뮬레이터 실측 2026-07-30)

`sdk_gphone16k_arm64` · **API 37 · 16KB 페이지 이미지** 에서 확인했습니다.

확인된 것:

- 설치·실행 정상. 크래시·`dlopen` 실패·네이티브 정렬 오류 없음 (arm64-v8a 포함)
- 기본 언어 **English** 로 기동 (기기 언어 무관), 3개 언어 전환 동작
- 기능 목록·개발자 시트·이벤트 로그 정상 렌더링
- SDK 연동 경로 정상: `initialize` → `start` → `stateChanged(LOADING)` → `analytics` → `playback` 이벤트 수신
- Toast 가 **SDK 소유 플레이어 Activity 위에** 표시됨

### ⚠️ 데모 캠페인 `faea28dd96c3` 은 재생되지 않습니다

플레이어가 검게만 나옵니다. 앱·에뮬레이터 문제가 아니라 **스트림이 없습니다**.

```
playback(requested) → playback(failed(code: 404, message: 404))   ← 5초 주기 반복
playback(ended) → stateChanged(IDLE) → stateChanged(CLOSED)
```

방송 중인(또는 VOD 자산이 있는) campaignKey 로 다시 확인해야 합니다.

### SDK 팀에 보고할 관측 3건

1. **404가 반복되고 세션이 종료돼도 `ShoplivePlayerEvent.Error` 가 한 번도 오지 않습니다.**
   설계서 계약("복구 불가로 세션이 끝날 때 `error(isRecoverable = false)` 전달")과 어긋납니다.
   error 만 구독하는 앱은 "스트림이 없다"를 영원히 알 수 없어 검은 화면만 보여주게 됩니다.
2. **`campaignInfoReceived` · `campaignStatusChanged` 도 발화되지 않았습니다.** 앱이
   READY/LIVE/ENDED 를 판별할 수단이 없습니다. (`analytics` 는 campaignKey 를 싣고 도착)
3. 오버레이 웹뷰 콘솔에 `Uncaught TypeError: window.__receiveAppEvent is not a function` ×3.

데모앱은 이 1·2번 때문에 `playback(failed)` 를 직접 세어 알립니다 —
[`sdk/DemoPlayerDelegate.kt`](app/src/main/java/cloud/shoplive/onboarding/sdk/DemoPlayerDelegate.kt)
의 `onRepeatedPlaybackFailure()`. SDK 가 error 를 제대로 주게 되면 이 우회는 지워도 됩니다.

### 아직 확인하지 못한 것 (재생되는 캠페인 필요)

- 실제 재생 시작(2~3초) · 채팅·LIVE 배지
- in-App PIP 가 상품 상세 Activity **위에** 유지되는지
- `navigation(url)` → 상품 상세 라우팅
- `sound.muteOnStart = true` 의 PIP 튕김 재현 여부
- Mission 8 송출 시작 · 카메라/마이크 권한 흐름 (에뮬레이터 카메라 제약도 있음)
- 임베드 뷰 → 풀스크린 승격 시 재조회 체감
