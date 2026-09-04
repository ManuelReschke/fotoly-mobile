# AGENTS.md — Fotoly Mobile

Instructions for AI coding agents working in this repository.

## Project

Flutter app for [fotoly.eu](https://fotoly.eu): back up photos from selected local folders.

This is the Fotoly white-label of pixelfox-mobile. **Fotoly is the default flavor** (Schiefer theme, `https://fotoly.eu`). PixelFox remains `FLAVOR=pixelfox`.

- Package: `pixelfox_mobile` (Dart SDK `^3.12.2`) — shared package name with the PixelFox app
- Platforms: Android, iOS, Web, Linux desktop
- API: `https://fotoly.eu/api/v1` (see `lib/config/api_config.dart`)
- Auth: email/password or social login (app session `Authorization: Bearer pxls_…`); API key (`X-API-Key`) remains an advanced fallback. Credentials are stored via `flutter_secure_storage`.

## Code discovery — prefer codebase-memory MCP

**Always use codebase-memory MCP graph tools before raw code search** (grep/glob/filesystem).

Priority order:

1. `list_projects` / `index_status` — ensure the repo is indexed (run `index_repository` if missing or stale after large changes)
2. `search_graph` — find functions, classes, services, screens by name pattern
3. `trace_path` — who calls a symbol / what it calls
4. `get_code_snippet` — read a specific function/class by `qualified_name`
5. `query_graph` — multi-hop / structural patterns
6. `get_architecture` — high-level orientation when starting a larger task

Fall back to grep/glob only for:

- string literals, error messages, config values
- non-code files (Makefile, YAML, shell, docs)
- ranges the indexer reports as partial/missed

MCP server key: `codebase-memory`.

## Architecture

| Path | Role |
|------|------|
| `lib/main.dart`, `lib/app.dart` | Entry + app shell (Provider wiring) |
| `lib/config/` | API base URL and endpoints |
| `lib/models/` | Immutable data models |
| `lib/services/` | Business logic (auth, settings, backup queue, API, storage) |
| `lib/screens/` | Full-page UI |
| `lib/widgets/` | Reusable UI pieces |
| `lib/l10n/` | Manual DE/EN strings + locale controller |
| `lib/theme/` | Material theme |
| `test/` | Unit/widget tests; fake HTTP in `test/fake_api_http.dart` |

Key services:

- `PixelfoxApiClient` — profile, upload sessions, multipart upload
- `AuthService` — key persistence + profile gate
- `SettingsService` — folder list persistence
- `BackupService` / `BackupLedger` / `FileScanner` — scan → queue → status
- `Storage` — secure + prefs wrappers

Keep pure logic in services/models; screens/widgets should stay thin and testable.

## Commands

Prefer Make targets over raw Flutter when possible:

```bash
make get          # flutter pub get
make analyze      # flutter analyze
make test         # flutter test
make check        # get + analyze + test (default quality gate)
make format       # dart format lib test
make run          # DEVICE=chrome|linux|<id> optional; default FLAVOR=fotoly
make run-linux    # desktop: folder picker + backup work
make run-chrome   # UI/auth only — no real folder pick/backup
make build-apk-debug  # Fotoly APK (FLAVOR=pixelfox for PixelFox)
make doctor
```

Before claiming work done: run `make check` (or at least `make analyze` + `make test` for the touched area).

## Conventions

- Follow existing style in neighboring files; `flutter_lints` via `analysis_options.yaml`
- State: Provider (`provider` package)
- Network: `http` package through `PixelfoxApiClient` — do not scatter raw HTTP in widgets
- Persistence: API key → secure storage; folders/prefs → `SettingsService` / shared_preferences
- User-facing copy: go through `lib/l10n/` (DE + EN), not hard-coded English-only in screens
- Tests: pure logic with fake HTTP fixtures under `test/fixtures/`; no real API key required
- Do not commit secrets, API keys, or personal device paths

## Do / Don't

**Do**

- Extend `PixelfoxApiClient` for new API calls; keep URL helpers in `ApiConfig`
- Add/adjust unit tests when changing services or models
- Preserve backup queue semantics (session per image, `original_only` processing) unless the task explicitly changes them
- Use codebase-memory graph tools first for structural discovery

**Don't**

- Bypass auth/storage layers to “simplify” key handling
- Call the real Pixelfox API from unit tests
- Treat Chrome as a full backup target (no local folder scan)
- Commit build artifacts (`build/`, large APKs) or local SDK paths
- Drive-by refactors unrelated to the task

## Platform gotchas

- **Chrome/Web**: UI and auth only; folder pick + disk scan need Linux desktop or a phone/emulator (`make run-linux` or device)
- **Linux desktop**: needs C++/GTK toolchain + `libsecret-1-dev` for secure storage (`make doctor`)
- **Android**: `JAVA_HOME` / `ANDROID_HOME` defaults are set in the Makefile for this machine
- API docs: https://fotoly.eu/docs/api

## Docs map

| File | Use for |
|------|---------|
| `README.md` | Features, setup, user-facing architecture |
| `Makefile` | Canonical agent/dev commands |
| `lib/config/api_config.dart` | Base URL and endpoint paths |
| This file | Agent workflow, discovery order, constraints |

## Commit Messages

If you think you are done with your task then create a conventional commit message and put it at the end of your message.