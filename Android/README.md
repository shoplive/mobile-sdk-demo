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

**데모 키는 비워 둬도 됩니다.** 비어 있으면 리포에 들어 있는 데모 계정
([`demo/DemoDefaults.kt`](app/src/main/java/cloud/shoplive/onboarding/demo/DemoDefaults.kt))으로
폴백하므로, 클론 직후 바로 "둘러보기"가 동작합니다. iOS 쪽
`DemoCredentials.swift` 의 `DemoDefaults` 와 같은 값이므로 **한쪽 토큰을 교체하면 다른
쪽도 함께 교체**해야 합니다.

`local.properties`(또는 환경변수)에 값이 있으면 그것이 이깁니다. 자기 계정으로 확인할
때는 `local.properties` 에 넣거나 시작 화면에서 직접 입력하세요 — `DemoDefaults.kt` 는
고치지 않습니다.

> ⚠️ `DemoDefaults.kt` 에 들어가는 값은 **공개된 것으로 취급**하세요. 버려도 되는 데모
> 계정 전용이며, 고객사·운영 자격증명은 절대 넣지 않습니다. 토큰을 교체해도 git 이력에서
> 사라지지 않으므로, 무효화는 Shoplive 콘솔에서 해야 합니다. 송출 토큰은 수명이 짧아
> 만료되면 Mission 8 이 멈추고, 콘솔에서 새로 받아 Android·iOS 양쪽에 넣어야 합니다.

기본 저장소는 개발용(`repo.us1`)입니다. 고객사 배포용을 쓰려면
`shoplive.maven.url=https://repo-mig.us1.shoplive.cloud/repository/shoplive/` 를 추가하세요.

## 2. 빌드

```bash
./gradlew :app:assembleDebug
```

---

## 로컬 SDK 소스로 빌드하기 (SDK 개발자용)

`matrix-sdk-android` 를 사설 Maven AAR 대신 **로컬 경로 그대로** 물어서 빌드할 수 있다
(Gradle composite build). SDK 를 고치고 바로 이 데모앱에서 확인할 때 쓴다.

- 기본 경로는 이 프로젝트 옆의 `../matrix-sdk-android` 다. 그 경로가 있으면 **자동으로** 켜지고,
  없으면 조용히 Maven AAR 로 폴백한다. 켜지면 설정 단계에 `[shoplive] 로컬 SDK 소스 사용: ...` 이 찍힌다.
- `app/build.gradle.kts` 의 의존성 선언(`libs.shoplive.player.sdk` 등)은 **바꾸지 않는다** —
  `settings.gradle.kts` 의 `dependencySubstitution` 이 `cloud.shoplive:shoplive-player-sdk` /
  `:shoplive-streamer-sdk` 좌표를 로컬 프로젝트로 치환한다.

`local.properties` 로 조절한다(환경변수 `SHOPLIVE_SDK_LOCAL_PATH` / `SHOPLIVE_SDK_USE_LOCAL` 도 가능):

```properties
# 다른 위치에 클론했을 때
shoplive.sdk.localPath=/Users/me/work/matrix-sdk-android
# 로컬 소스 대신 다시 Maven AAR 로 받고 싶을 때
shoplive.sdk.useLocal=false
```

치환이 실제로 걸렸는지 확인:

```bash
./gradlew :app:dependencyInsight --configuration debugCompileClasspath --dependency shoplive-player-sdk
```

> SDK 라이브러리 모듈은 `distribution` 플레이버 차원(develop/qa/qaUs/ebay)을 갖는다. 이 앱은
> 플레이버가 없으므로 `app/build.gradle.kts` 의 `missingDimensionStrategy("distribution", "develop")`
> 로 develop 을 고른다. AAR 경로에서는 무해하다.

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
implementation "cloud.shoplive:shoplive-core:$shoplive_sdk_version"
```

- **시청만** 쓰면 `shoplive-player-sdk` 만
- **송출만** 쓰면 `shoplive-streamer-sdk` 만
- 둘 다 쓰면 둘 다 (exoplayer · webrtc · android-webrtc 는 내부 의존이라 선언하지 않아도
  되고, 겹치는 의존성도 SDK 쪽에서 정리됩니다)
- **`shoplive-core` 는 선언해야 합니다.** `Shoplive`·`ShopliveUser`·
  `ShopliveConfiguration`·`ShopliveError`(= `cloud.shoplive.core.publicsurface`)가 이
  아티팩트에 있고, player/streamer 두 모듈은 이를 `implementation`/`compileOnly` 로 물고
  있어 **컴파일 클래스패스에 전이되지 않습니다**. 없으면
  `Unresolved reference 'core'` 로 떨어집니다.
  (2026-07-30 로컬 SDK 소스 기준 실측. 발행된 AAR 에서도 같은지는 미확인 —
  `gradle/libs.versions.toml` 의 `TODO(verify)` 참조.)

**minSdk 는 23 이상이어야 합니다.** 문서상 하한은 player 19 / streamer 21 이지만, 전이
의존하는 `shoplive-android-webrtc` 가 minSdk 23 을 선언해 21 로는 매니페스트 병합이
실패합니다(`minSdkVersion 21 cannot be smaller than version 23 declared in library
[org.webrtc]`). 2026-07-30 실측.

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
- compileSdk 35 / minSdk 24 (`:integration` 은 23) / Java 17 / Kotlin 2.0.21 / AGP 8.7.3
- 모듈 2개 — `:app` (데모 하네스) · `:integration` (**그대로 복사하는 연동 코드**, 아래 참조)
- applicationId `cloud.shoplive.onboarding` — SDK 내부 데모앱(`cloud.shoplive.demo`)과
  한 기기에 함께 설치할 수 있습니다.

### 화면

| | 화면 | 소유 |
| --- | --- | --- |
| S1 | 시작 (둘러보기 / 내 계정) | 데모앱 |
| S2 | 기능 목록 8개 — **카드 탭 = 즉시 실행** | 데모앱 |
| S3 | 플레이어 · 스튜디오 | **SDK** (Activity) |
| S3 | 홈 피드 (Mission 4) | 데모앱 (레이아웃) + `:integration` (플레이어 생성·제어) |
| V1 | 개발자 시트 (로그 / 옵션) | 데모앱 · ModalBottomSheet |
| V2 | 상품 상세 | 데모앱 · Activity |

### 그대로 복사해 쓰는 층 — `:integration`

**연동 코드는 전부 `integration/` 한 곳에 있고, 파일을 그대로 복사해 자기 앱에 붙여넣을 수
있습니다.** 복사 대상이 되려면 SDK 와 표준 프레임워크만 참조해야 하므로, 이 모듈은 데모앱
(`:app`)에 **의존하지 않습니다**. 의존 방향은 `:app → :integration` 한쪽뿐이고, 반대 방향
참조가 하나라도 생기면 `:integration` 이 컴파일되지 않습니다 — 고객사가 파일만 복사해 간
상황과 같은 조건입니다.

| # | 기능 | 파일 (`integration/src/main/java/cloud/shoplive/onboarding/integration/`) | 복사 |
| --- | --- | --- | --- |
| 1 | 플레이어 띄우기 | `ShoplivePlayerLauncher.kt` | ✅ |
| 2 | 딥링크로 띄우기 | `ShopliveDeepLinkRouter.kt` | ✅ |
| 3 | 회원 정보 연결 | `ShopliveUserSetup.kt` | ✅ |
| 4 | 화면 안에 임베드 | `ShopliveEmbeddedPlayer.kt` | ✅ |
| 5 | PIP로 계속 보기 | `ShoplivePipPresets.kt` | ✅ |
| 6 | 이벤트 · 상품 · 쿠폰 | `ShoplivePlayerEventLogger.kt` | ✅ |
| 7 | UI 커스터마이즈 | `ShoplivePlayerPresets.kt` | ✅ |
| 8 | 라이브 송출하기 | `ShopliveStudioLauncher.kt` | ✅ |
| — | 초기화 · 로그아웃 · 키 형식 검증 | `ShopliveInitializer.kt` | ✅ |
| — | 실행 중 제어 핸들 (`isMuted`·`resizeMode`·`reload`·PIP) | `ShoplivePlayerSession.kt` | ✅ |
| — | 로그 훅 (기본값 no-op) · 토큰 마스킹 | `ShopliveLog.kt` | ✅ |
| — | SDK enum → 읽을 수 있는 라벨 · 오류 원인 분류 | `ShopliveEventLabels.kt` | ✅ |

이 12개 파일에는 **왜 그렇게 써야 하는지**를 KDoc(영어)으로 적어 두었습니다 — Activity
context 요구, configuration 불변 계약, respond 누락이 버그인 이유, 실측 사실과 날짜까지.
고객사가 주석만 읽고 이해할 수 있어야 하므로 이 프로젝트의 코드 주석은 전부 영어입니다.

#### 복사할 때 하는 일

1. 12개 파일을 자기 소스 트리로 복사하고 `package` 선언만 자기 패키지로 바꿉니다.
   (그 외에는 아무것도 고칠 필요가 없습니다.)
2. `build.gradle` 에 SDK 3줄을 넣습니다 — `shoplive-player-sdk` ·
   `shoplive-streamer-sdk` · `shoplive-core`. (`shoplive-core` 에 `Shoplive`·
   `ShopliveUser`·`ShopliveError` 가 있고 두 SDK 가 이를 전이 노출하지 않습니다.)
3. 로그를 보고 싶으면 `Application.onCreate()` 에 한 줄:
   `shopliveLog = { kind, message -> Log.d("Shoplive", "${kind.tag} $message") }`

#### 주입 지점은 1개입니다

`shopliveLog` 하나뿐입니다(기본값 no-op). 나머지 앱별 결정 — 상품 URL 라우팅, 사용자에게
보여줄 문구, 진행도 기록, 쿠폰 문구 — 는 전부 `ShoplivePlayerEventLogger` 의 **생성자
콜백**으로 받습니다. 전역 상태가 아니라서 인스턴스마다 다르게 줄 수 있습니다.

iOS 판에는 딥링크 라우터에 `configurationProvider`·`delegateProvider` 2개가 더 있지만,
Android 판에는 **의도적으로 넣지 않았습니다.** 이 앱의 딥링크 경로는 콜드 스타트 안전성
때문에 파싱(`SchemeActivity`)과 재생(`MainActivity`)을 분리하고, 라우터는 재생을 직접
시작하지 않습니다. 재생을 시작하지 않는 객체에 설정·델리게이트 주입 지점을 두면 쓰이지 않는
표면만 늘어납니다.

#### 하네스 (복사 대상 아님)

| 위치 | 무엇 | 왜 하네스인가 |
| --- | --- | --- |
| `app/.../demo/DemoLogBridge.kt` | `shopliveLog` → 데모 이벤트 로그 연결 | 고객사는 자기 로거를 꽂습니다 |
| `app/.../demo/DemoConfigurationFactory.kt` | 옵션 탭의 **전 필드**를 configuration 으로 조립 | 데모 화면 상태에 묶임 (고객사용 예시는 `ShoplivePlayerPresets`) |
| `app/.../demo/DemoLabels.kt` | SDK 오류 원인 enum → `R.string` | 지역화는 리소스를 가진 앱의 몫 |
| `app/.../data/` | 미션 진행도 · 옵션 탭 상태 · 자격증명 저장 · 언어 설정 | 데모 전용 상태 |
| `app/.../ui/` | Compose 화면 전부 | 데모 UI |

`DemoConfigurationFactory` 가 경계선입니다. "configuration 조립" 은 한 덩어리로 보이지만
실제로는 두 가지입니다 — 고객사가 복사할 **예시**(`branded()`·`overlayHidden()`·
`embeddedPreview()`)와, 데모 화면의 가변 상태를 전 필드에 반영하는 **조립**. iOS 판에서는
후자가 복사 대상에 섞여 있었고 격리 컴파일 타깃이 그것을 잡아냈습니다.

### 경계를 지키는 방법 (사람 리뷰 아님)

로그 한 줄 넣는 것은 너무 쉬워서 리뷰로는 막히지 않습니다. 두 겹으로 막습니다.

| | 무엇을 잡나 |
| --- | --- |
| **격리 컴파일** — `./gradlew :integration:assembleDebug` | 하네스 심볼·`R`·`BuildConfig` 등 컴파일이 깨지는 모든 것. 정규식이 놓치는 것(enum 확장·팩토리 함수)까지 잡는 최종 방어선 |
| **경계 스캐너** — `python3 scripts/integration_boundary_scanner.py` | 컴파일은 되지만 고객사를 해치는 것: `android.util.Log`·Timber·`@Inject`·`@Composable`·ViewBinding·비영어 주석 |

스캐너는 **주석을 제거하고** 검사합니다 — "이 값은 데모에서 이벤트 로그로 흘러간다" 같은
설명은 위반이 아닙니다. 코드만 봅니다. `./gradlew check` 에 물려 있고
[CI](.github/workflows/ci.yml) 에서 두 겹 모두 돕니다(스캐너는 SDK 자격증명 없이 돌도록
분리).

```bash
# 경계 점검 (자격증명 불필요)
python3 scripts/integration_boundary_scanner.py

# 복사 가능함을 컴파일로 증명 — SDK 만 있는 환경에서 빌드
./gradlew :integration:assembleDebug
```

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
[`ShoplivePlayerEventLogger.kt`](integration/src/main/java/cloud/shoplive/onboarding/integration/ShoplivePlayerEventLogger.kt)
의 `onRepeatedPlaybackFailure()`. SDK 가 error 를 제대로 주게 되면 이 우회는 지워도 됩니다.

### 아직 확인하지 못한 것 (재생되는 캠페인 필요)

- 실제 재생 시작(2~3초) · 채팅·LIVE 배지
- in-App PIP 가 상품 상세 Activity **위에** 유지되는지
- `navigation(url)` → 상품 상세 라우팅
- `sound.muteOnStart = true` 의 PIP 튕김 재현 여부
- Mission 8 송출 시작 · 카메라/마이크 권한 흐름 (에뮬레이터 카메라 제약도 있음)
- 임베드 뷰 → 풀스크린 승격 시 재조회 체감

---

## 복사 가능성 검증 상태 (2026-07-30)

`:integration` 분리 리팩터의 검증 결과입니다. 주장 전에 실행한 것만 적습니다.

| 항목 | 결과 |
| --- | --- |
| 하네스 의존 개수 (리팩터 전 → 후) | **88 → 0** (grep, 아래 명령) |
| 경계 스캐너 | PASS — 12개 파일, 위반 0 |
| 격리 컴파일 `:integration:assembleDebug` | ✅ 성공 (SDK 만, `:app` 무의존) |
| 앱 빌드 `:app:assembleDebug` | ✅ 성공 |
| 손으로 복사해 보기 | ✅ 빈 프로젝트(`com.acme.shop`)에 SDK 3줄만 넣고 12개 파일 복사 → `package` 선언 한 줄만 바꿔 APK 조립 성공. 12개 공개 API 전부를 **다른 패키지**에서 호출하는 코드까지 컴파일됨 |
| 코드 주석 한글 | 0건 (`values-ko/` 등 지역화 리소스와 언어 선택기의 `한국어` 라벨 제외) |
| 주입 지점 | 1개 — `shopliveLog` |
| **에뮬레이터 실행** | ❌ **미확인** — 이 머신에 AVD·연결 기기가 없습니다(`adb devices` 비어 있음, 시스템 이미지 미설치). 리팩터 후 앱을 실기기에서 다시 돌려 봐야 합니다 |
| AAR(사설 Maven) 모드 빌드 | ❌ **미확인** — 이 머신의 `local.properties` 에 Maven 자격증명이 비어 있어 로컬 SDK 소스(composite build)로만 검증했습니다 |

```bash
# 리팩터 전 숫자를 재현하려면 이전 커밋의 app/.../sdk/ 에 대해 같은 grep 을 돌립니다.
grep -rn "DemoLog\|DemoContainer\|ProductRouter\|MissionProgress\|DemoOptions\|BuildConfig\|R\.string\.\|R\.drawable\.\|onboarding\.data\." \
  integration/src/main/java | wc -l   # → 0
```

### 리팩터가 실제로 잡아낸 것 (스캐너가 아니라 컴파일이 잡음)

1. **`ShopliveError.cause` 확장은 침묵으로 무력화됩니다.** `ShopliveError` 가 `Throwable`
   을 상속하므로 `cause` 확장 프로퍼티는 모든 호출 지점에서 `Throwable.cause` 에 가려집니다
   — 오류 원인 분류 대신 `Throwable?` 이 넘어옵니다. `causeGroup` 으로 이름을 바꿨습니다.
2. **`shoplive-core` 는 전이되지 않습니다.** 위 "의존성 — app 모듈" 참조.
3. **minSdk 실질 하한은 23** 입니다(문서상 19/21). 위 같은 절 참조.
