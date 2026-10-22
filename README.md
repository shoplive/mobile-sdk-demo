# ShopLive Mobile SDK Demos

Demo apps for the two ShopLive mobile SDKs. Each SDK has its own directory, its own README and its own docs.

> **📘 Official integration guide: <https://sdk.shoplive.cloud/>** (한국어 / English / 日本語)

| | Directory | What the demo shows | Platforms |
|---|---|---|---|
| 🔴 **Live SDK v3** | [`LiveSDK/`](LiveSDK/README.md) | Onboarding walkthrough — 8 missions from opening the player to going live, with copy-ready integration code | iOS (UIKit) · Android (Compose) · Flutter |
| 🎬 **Shortform SDK** | [`ShortformSDK/`](ShortformSDK/README.md) | A commerce-style demo app — search → product list → product detail with a shortform collection whose layout you can switch on the spot | iOS (UIKit) · Android (Views) |

---

## Which one do I need?

- **You are integrating live commerce (broadcasts, PIP, the studio)** → start at [`LiveSDK/README.md`](LiveSDK/README.md), then [Getting Started](LiveSDK/docs/01-getting-started.md).
- **You want to see how shortform video looks inside a shopping app**, or decide where shortform goes on your product page → [`ShortformSDK/README.md`](ShortformSDK/README.md).

The two SDKs are independent: different packages, different version lines, and neither depends on the other.

| | Live SDK | Shortform SDK |
|---|---|---|
| iOS package | [`shoplive/shoplive-sdk-ios`](https://github.com/shoplive/shoplive-sdk-ios) (SPM) | [`shoplive/shortform-ios`](https://github.com/shoplive/shortform-ios) (SPM) |
| Android artifacts | `cloud.shoplive:shoplive-player-sdk` · `shoplive-streamer-sdk` | `cloud.shoplive:shoplive-short-form` |
| Maven repository | `https://sdk.shoplive.cloud/maven-repo` | `https://sdk.shoplive.cloud/maven-repo` |

---

## Repository layout

```
mobile-sdk-demo/
├── README.md            ← you are here
├── LiveSDK/             Live SDK v3 onboarding demo
│   ├── README.md
│   ├── docs/            getting started · missions 1–8 · API reference · known issues
│   ├── iOS/
│   ├── Android/
│   └── Flutter/
└── ShortformSDK/        Shortform SDK commerce demo
    ├── README.md
    ├── demo-config/     demo catalog format and a sample
    ├── iOS/
    └── Android/
```

> **Moved paths.** The Live SDK demos used to sit at the repository root (`iOS/`, `Android/`, `Flutter/`, `docs/`).
> They now live under `LiveSDK/` with the same structure, so an old link such as `…/tree/main/iOS` becomes
> `…/tree/main/LiveSDK/iOS`.

## CI

| Workflow | Runs when | What it checks |
|---|---|---|
| [`live-android-ci.yml`](.github/workflows/live-android-ci.yml) | `LiveSDK/Android/**` changes | integration boundary, `:integration` in isolation, demo app build, `check` |
| [`shortform-ci.yml`](.github/workflows/shortform-ci.yml) | `ShortformSDK/**` changes | demo catalog schema, Android build, iOS build |
