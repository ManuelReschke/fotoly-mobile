# App Registration — Design Spec

**Date:** 2026-09-07  
**Status:** Approved for planning  
**Repos:** fotoly-mobile (Flutter) and PixelFox (`/home/dev/Workspace/Gitlab/PixelFox`)

## Problem

The mobile app can log in (email/password, social, API key) but cannot create an account. New users must register on the website first. Social login already creates an account on first use; email/password does not.

The website has `GET`/`POST /register` as an HTML form (CSRF, hCaptcha, redirects). The public JSON API has `/auth/login`, `/auth/token`, `/auth/logout`, and `/auth/{provider}/start`, but no register endpoint. The app cannot call the HTML form.

## Goals

- Native registration in the app: username, email, password, password confirmation.
- Same server path as the website: create an **inactive** user, send the existing activation email, user activates in the **browser** at `{PUBLIC_DOMAIN}/activate?token=…`, then logs in in the app.
- New JSON API `POST /api/v1/auth/register` in PixelFox, documented in OpenAPI and wired like the other auth routes.
- After a successful API call, show a dedicated **check-email** screen (not a snackbar on login).
- DE + EN copy via existing `lib/l10n/`.
- Unit-testable with `FakeApiHttp`; PixelFox handler tests with sqlite, no SMTP.

## Non-goals

- Immediate login / session token after register.
- Deep links or Universal/App Links for the activation URL.
- In-app activation API (`POST /auth/activate`).
- Resend-activation API or “open mail app” button.
- hCaptcha on the app register call.
- Embedding `fotoly.eu/register` in a WebView.
- Changing social-login first-use account creation.
- Changing backup, gallery, or folder-picker behavior.
- A named router (`go_router`); keep `Navigator.push` from `LoginScreen`.

## Product decisions (locked)

| Topic | Decision |
|-------|----------|
| Flow | Login → Register form → Check-email screen → activate in browser → login in app |
| Fields | Username, email, password, password confirmation |
| Password confirm | Client-only; API body has `username`, `email`, `password` |
| Activation | Existing email + `{PUBLIC_DOMAIN}/activate?token=…` |
| After submit | Dedicated check-email screen (email address visible, “Back to login”) |
| Session | None until the user logs in after activation |
| Captcha | None on the API; use existing `/api` rate limit |
| Registration kill switch | Same `IsRegistrationEnabled()` as the website |
| Duplicate identity | Email unique (409). Display name is not unique (same as web `CreateUser`) |
| Mail send failure | Log only; still return 201 if the user row was created (same as website) |
| Unactivated login | Existing API 403: “Please activate your account via email.” |

## User flow

1. Unauthenticated `LoginScreen` shows “No account yet? Register”.
2. `RegisterScreen`: four fields, submit “Create account”, AppBar back to login.
3. Client rejects mismatched passwords before any HTTP call.
4. `POST /api/v1/auth/register` succeeds → push `CheckEmailScreen(email)`.
5. Check-email screen explains that an activation link was sent to that address. Primary action pops back to login.
6. User opens the mail in a browser, activates, returns to the app, signs in.

If registration is disabled on the server, the form shows the API error and stays on the register screen.

## Architecture

```
LoginScreen
  → Navigator.push RegisterScreen
       → AuthService.register → PixelfoxApiClient.register
            → POST /api/v1/auth/register
       → on success: Navigator.push CheckEmailScreen(email)
            → “Back to login” pops to LoginScreen

PixelFox
  OpenAPI postAuthRegister
    → APIServer.PostAuthRegister
    → HandleAuthRegisterAPI
    → CreateUser + activation token + activation email
    → 201 { email, message }  (no token)
```

Website `HandleAuthRegister` and the new API handler must share the create-user + token + mail sequence so the two surfaces cannot drift. Prefer a small helper next to the existing auth controllers over copying the block.

## PixelFox API

### Endpoint

`POST /api/v1/auth/register`

- No `Authorization` / `X-API-Key`.
- Add to `public/docs/v1/openapi.yml` (Auth tag), regenerate `internal/api/v1/generated.go` with the existing oapi-codegen Make target, implement `PostAuthRegister` in `internal/api/v1/handlers.go` by delegating to `HandleAuthRegisterAPI` in `app/controllers/api_auth_controller.go`.

### Request

```json
{
  "username": "pete",
  "email": "pete@example.com",
  "password": "secret12"
}
```

Validation (same as `models.User` / `CreateUser`):

- `username` required, 3–150 characters (maps to `User.Name`)
- `email` required, valid email, 5–200 characters
- `password` required, min 6 characters
- Trim username and email; reject empty-after-trim

Also:

- If `!models.IsRegistrationEnabled()` → 503 `service_unavailable`
- If email already exists → 409 `conflict` (do not leak whether the other account is active)
- Invalid JSON or failed field validation → 400 `bad_request`

### Success (201)

```json
{
  "email": "pete@example.com",
  "message": "Registration successful. Please check your inbox for the activation link."
}
```

Side effects, matching `HandleAuthRegister`:

- `CreateUser` with `STATUS_INACTIVE` and `RegistrationProvider` local
- Persist IPv4/IPv6 when the API request has them
- `GenerateActivationToken`
- Send the existing activation email template (`ActivationEmail`) with `{PUBLIC_DOMAIN}/activate?token=…`
- Do **not** call `issueAppAuthSession`

### Errors

| HTTP | `error` code | When |
|------|----------------|------|
| 400 | `bad_request` | Missing/invalid JSON or field validation |
| 409 | `conflict` | Email already registered |
| 429 | (existing limiter) | Global `/api` rate limit |
| 503 | `service_unavailable` | Registration disabled |
| 500 | `internal_server_error` | Persist/token generation failed |

Mail send errors are logged; they do not turn a successful insert into 500.

### Out of this endpoint

No `password_confirm`, no captcha token, no session cookie, no app session token.

## fotoly-mobile

### Config and client

- `ApiConfig.authRegisterUrl()` → `{apiRoot}/auth/register`
- `PixelfoxApiClient.register({username, email, password})`  
  POST JSON, expect 201, return the registered email (from the body, falling back to the request email). Other statuses throw `PixelfoxApiException` with the server `message` when present.

### AuthService

```dart
Future<bool> register({
  required String username,
  required String email,
  required String password,
});
```

- Trim username/email; reject empty username, email, or password locally (same style as `loginWithPassword`).
- Sets `loading` / `error`; does **not** persist a session or call `_validateAndStore`.
- Returns `true` only on 201.

Password confirmation is **not** an `AuthService` concern; the screen compares the two fields first.

### Screens

`LoginScreen`  
Text button under the existing sign-in actions: localized “No account yet? Register” → `Navigator.push` `RegisterScreen`.

`RegisterScreen` (`lib/screens/register_screen.dart`)  
AppBar back. Fields: username, email, password, password confirmation (obscure toggles like login). Submit disabled while `auth.loading`. On mismatch, show localized error and skip the request. On `register` success, `pushReplacement` to `CheckEmailScreen` with the email so Back from that screen cannot return to a filled register form. Check-email’s “Back to login” `pop`s once to `LoginScreen`.

`CheckEmailScreen` (`lib/screens/check_email_screen.dart`)  
Constructor takes `email`. No `AuthService` calls. Copy explains the activation mail. Shows the address. Primary button returns to login. No resend, no “open mail app”.

### l10n

Add DE + EN strings for: register link on login, register title/subtitle, username label, create-account button, password-mismatch, check-email title/body, back-to-login. Reuse existing email/password labels.

Do not hard-code English in the new screens.

## Error handling

| Case | UI |
|------|----|
| Empty fields / mismatch | Inline or snackbar on `RegisterScreen`, no HTTP |
| 400 / 409 / 503 / 500 | `AuthService.error` from API `message`, shown like login |
| Inactive user later logs in | Unchanged 403 copy from login |
| Network failure | Existing “Login failed: …” style message, adapted for register |

## Testing

### PixelFox

Extend `app/controllers/api_auth_controller_test.go` (sqlite helper already there):

- 201 creates `STATUS_INACTIVE` user, stores activation token, response has `email` and no `token`
- 400 on missing/invalid fields
- 409 on duplicate email
- 503 when registration is disabled
- Stub or no-op mail so tests do not hit SMTP

### fotoly-mobile

- `FakeApiHttp`: handle `POST` path ending `/auth/register` with configurable status/body
- `pixelfox_api_client_test`: 201 parse; non-201 throws
- `auth_service_test`: success does not write a session token; failure sets `error`
- `login_screen_test`: register link visible
- `register_screen_test`: mismatch does not POST; success shows check-email with the address
- `check_email_screen_test`: shows email and back-to-login

Quality gate: PixelFox handler tests + app `make check`.

## Implementation order

1. PixelFox: OpenAPI → codegen → `HandleAuthRegisterAPI` + tests (ship/deploy this before the app depends on it in production).
2. fotoly-mobile: client + `AuthService` + screens + l10n + tests.

The app can be developed against a local PixelFox (`PIXELFOX_API_BASE`) before production deploy.

## Risks

- Production app store builds will 404 until PixelFox with `/auth/register` is deployed. Land and deploy the API first. The app always shows the register link; a 404 is displayed as a normal `PixelfoxApiException` (no special hiding).
- Activation still requires a working mail setup; that is an existing website dependency, not a new one.
