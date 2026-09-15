# Fotoly Mobile

Flutter app for [fotoly.eu](https://fotoly.eu) — back up photos from selected folders.

This repo is the Fotoly white-label of the PixelFox mobile app. Fotoly is the default flavor (Schiefer theme, `fotoly.eu` API). PixelFox remains available as `FLAVOR=pixelfox`.

## Features

- **Email / password or social login** — same account as fotoly.eu
- **Folder selection** — pick (or type) local folders under Settings; selection is persisted
- **Backup** — creates an upload session per image, multipart-uploads (`original_only` processing)
- **Home status** — idle / working / success visuals while the queue runs
- **Gallery** — bottom-nav tab lists account images, swipeable viewer; image files are disk-cached on Android / iOS / Linux (browser cache on Web)

## Setup

```bash
make get && make check
make run-linux                 # Fotoly (default)
make build-apk-debug           # fotoly-debug.apk
```

Platforms: **Android**, **iOS**, **Web**, **Linux** desktop.

### Chrome / Web

Gallery works in the browser (API list + network image URLs; browser/memory cache). Folder pick and local backup still require Linux desktop or a phone/emulator.

### Linux desktop

Needs a C/C++ desktop toolchain once:

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev
make doctor    # Linux toolchain should be green
make run-linux # folder picker + backup work here (not on Chrome)
```

### Sign in

1. Launch the app and sign in with the same **email and password** as fotoly.eu
2. Or use Google / Discord / Facebook / Patreon if the instance has them enabled
3. The app stores a session token (`Authorization: Bearer pxls_…`) in secure storage
4. Optional: **Sign in with API key** still works for power users (`X-API-Key`)

### Folders

1. Open **Settings** (gear icon)
2. **Pick folder** or paste a path (e.g. `/storage/emulated/0/DCIM/Camera`)
3. Allow **Photos / storage** when the system asks (Android & iOS runtime permission)
4. Back on Home, tap **Start backup**

> **Permissions (Android):** The app declares `READ_MEDIA_IMAGES` (API 33+) and
> `READ_EXTERNAL_STORAGE` (API ≤32). Access is **requested at runtime** when you
> pick a folder, refresh, or start a backup. Without that grant, folder scans fail.
>
> **iOS:** Folder backup uses the system folder picker (security-scoped access).
> The Photos library permission is **not** required for path-based scans.

## Architecture

| Layer | Role |
|-------|------|
| `lib/config/app_brand.dart` | Flavor pack (Fotoly default / PixelFox) |
| `lib/services/pixelfox_api_client.dart` | Real API client (profile, sessions, multipart upload) |
| `lib/services/auth_service.dart` | Key persistence + profile gate |
| `lib/services/settings_service.dart` | Folder list persistence |
| `lib/services/backup_service.dart` | Scan → queue → status model |
| `lib/services/gallery_service.dart` | Account image list + cursor paging |
| `lib/widgets/backup_status_view.dart` | Idle / working / success UI |

Pure logic is unit-tested with a fake HTTP layer (no real API key required).

```bash
make check
```

## Releases

Push a semver tag. GitHub Actions runs `make check`, builds the Fotoly release APK and Play App Bundle, and publishes a GitHub Release (notes from commits since the previous tag). Tags with a hyphen (`v1.2.3-rc.1`) are marked as pre-release.

```bash
git tag v1.2.3
git push origin v1.2.3
```

Assets: `fotoly-1.2.3.apk` (sideload), `fotoly-1.2.3.aab` (Play Console), plus `SHA256SUMS`.

Without signing secrets the APK/AAB is **debug-signed** (fine for sideloading, not for Play). For a Play-ready signature, add these repository secrets and a keystore (see `android/key.properties.example`):

| Secret | Value |
|--------|--------|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias (often `upload`) |
| `ANDROID_KEY_PASSWORD` | key password (defaults to the keystore password if omitted) |

## API reference

See https://fotoly.eu/docs/api — base URL `https://fotoly.eu/api/v1`.
