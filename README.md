# FreeTune

A free, ad-free, local-first YouTube music player for **Android** and **iOS**.

- Streams audio from YouTube with no ads
- Downloads songs for offline playback, with per-playlist folders
- Background playback with lock-screen and Control Center / notification controls
- Playlists, liked songs, recent history and a local library
- Quality selection (best / balanced / data saver) and Wi-Fi-only downloads
- Autoplay keeps the queue going with related songs
- No account, no analytics, no cloud sync, no tracking

## Download

Grab the latest installers from **[Releases](https://github.com/ThatAerospaceandTechGuy/FreeTune/releases/latest)**.

| Platform | File | Requirements |
| --- | --- | --- |
| Android | `FreeTune-0.3.0.apk` | Android 8.0+ |
| iOS | `FreeTune-0.3.0-ios-unsigned.ipa` | iOS 16.0+, signed with Sideloadly |

Both builds are version **0.3.0** and share the same bundle identifier (`com.freetune.app`).

### Android install

1. Download the APK and transfer it to the phone.
2. Tap it and allow "install unknown apps" for your file manager or browser.
3. Open FreeTune, grant notification permission, and search for music.

Upgrading from 0.1.0 or 0.2.0 keeps your library, history and downloads.

### iOS install (free Apple ID)

The IPA is **unsigned** — iOS will not install it directly, and it cannot go through the App Store. Sign it yourself with a free Apple ID:

1. Install [Sideloadly](https://sideloadly.io) and iTunes on a Windows PC or Mac.
2. Connect the iPhone by USB and tap **Trust This Computer**.
3. Drag the `.ipa` into Sideloadly, enter your Apple ID, and click **Start**.
4. On the iPhone, trust the developer certificate in **Settings → General → VPN & Device Management**.
5. If the bundle ID is unavailable, enable **Change Bundle ID** in Sideloadly.

The free certificate expires after **7 days**; re-sideload the IPA to keep using the app (your library and downloads survive). A paid Apple Developer account removes the 7-day limit.

## Repository layout

```
android/   Kotlin + Jetpack Compose app (Media3, Room, WorkManager)
ios/       Swift + SwiftUI app (AVPlayer, URLSession background downloads, XcodeGen)
.github/   macOS workflow that builds the unsigned iOS IPA
```

## Build from source

**Android** — JDK 21, Android SDK 35:

```bash
cd android
./gradlew :app:assembleDebug
```

Release builds read `keystore.properties` (not committed). See [android/README.md](android/README.md) for details.

**iOS** — macOS with Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
cd ios
xcodegen generate
open FreeTune.xcodeproj
```

Or push to `main` and download the IPA from the **Build iOS IPA** GitHub Actions run.

## Android-only: floating controls

Android has an optional floating playback bar over other apps. iOS does not allow this, so the iOS build relies on the lock screen and Control Center instead.

## Privacy

- No analytics, ads, crash reporting or telemetry SDKs
- No account or sign-in
- Library, history, playlists and downloads stay on the device
- Network access is used only for YouTube requests and downloading audio

## Legal

FreeTune is an unofficial client, not affiliated with YouTube or Google. Downloading audio from YouTube may violate YouTube's Terms of Service and copyright law depending on the content and your jurisdiction. Downloads are intended for personal use only; you are responsible for what you access and download.

Both apps depend on YouTube's internal APIs / NewPipeExtractor, which Google changes without notice — search, streaming or downloads can break until the extractor is updated.

Licensed under GPL-3.0.
