# App Registration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add native email/password registration in fotoly-mobile that creates an inactive PixelFox account, sends the existing activation email, and shows a check-email screen until the user activates in the browser and logs in.

**Architecture:** PixelFox gains `POST /api/v1/auth/register` (JSON, no session token) sharing create-user + activation-mail with the website form. The Flutter app adds `PixelfoxApiClient.register` / `AuthService.register`, a `RegisterScreen`, and a `CheckEmailScreen`. Spec: `docs/superpowers/specs/2026-09-07-app-registration-design.md`.

**Tech Stack:** Go/Fiber/GORM/OpenAPI (PixelFox at `/home/dev/Workspace/Gitlab/PixelFox`); Flutter/Dart, Provider, `http`, manual DE/EN l10n, `FakeApiHttp` (fotoly-mobile).

## Global Constraints

- Same path as the website: inactive user, activation email to `{PUBLIC_DOMAIN}/activate?token=…`, no session until login
- API body: `username`, `email`, `password` only (password confirmation is client-only)
- No hCaptcha, no resend endpoint, no activation deep link, no `go_router`
- User-facing app copy only via `lib/l10n/` (DE + EN)
- PixelFox handler tests must not hit SMTP
- App tests use `FakeApiHttp`; no real API key
- Land/deploy PixelFox API before relying on production app builds
- PixelFox quality gate: `go test ./app/controllers/ -count=1`
- App quality gate: `make check`

## Files

**PixelFox** (`/home/dev/Workspace/Gitlab/PixelFox`):

- Modify: `app/controllers/api_auth_controller.go` — `HandleAuthRegisterAPI` + `registerLocalUser` + mail hook
- Modify: `app/controllers/auth_controller.go` — website `HandleAuthRegister` POST uses `registerLocalUser`
- Modify: `app/controllers/api_auth_controller_test.go` — register API tests
- Modify: `public/docs/v1/openapi.yml` — `POST /auth/register` + schemas + Conflict response
- Modify: `internal/api/v1/generated.go` — via `make generate-api` only
- Modify: `internal/api/v1/handlers.go` — `PostAuthRegister` delegates to the controller

**fotoly-mobile:**

- Modify: `lib/config/api_config.dart` — `authRegisterUrl()`
- Modify: `lib/services/pixelfox_api_client.dart` — `register(...)`
- Modify: `lib/services/auth_service.dart` — `register(...)`
- Modify: `lib/l10n/app_strings.dart`, `app_strings_de.dart`, `app_strings_en.dart`
- Modify: `lib/screens/login_screen.dart` — register link
- Create: `lib/screens/register_screen.dart`
- Create: `lib/screens/check_email_screen.dart`
- Modify: `test/fake_api_http.dart`
- Modify: `test/pixelfox_api_client_test.dart`
- Modify: `test/auth_service_test.dart`
- Modify: `test/login_screen_test.dart`
- Modify: `test/l10n_test.dart`
- Create: `test/register_screen_test.dart`
- Create: `test/check_email_screen_test.dart`

---

### Task 1: PixelFox register helper + JSON handler

**Repo:** `/home/dev/Workspace/Gitlab/PixelFox`

**Files:**
- Modify: `app/controllers/api_auth_controller.go`
- Modify: `app/controllers/auth_controller.go` (POST branch of `HandleAuthRegister` only)
- Test: `app/controllers/api_auth_controller_test.go`

**Interfaces:**
- Consumes: `models.CreateUser`, `models.GenerateActivationToken`, `models.IsRegistrationEnabled`, `repository.GetByEmail`, `GetClientIP`, `mail.SendMail`, `emailViews.ActivationEmail`
- Produces:
  - `var errEmailTaken = errors.New("email already registered")`
  - `var sendActivationMail = sendActivationMailDefault` with `func sendActivationMailDefault(user *models.User)`
  - `func registerLocalUser(c *fiber.Ctx, username, email, password string) (*models.User, error)`
  - `func HandleAuthRegisterAPI(c *fiber.Ctx) error`

- [ ] **Step 1: Write the failing tests**

In `app/controllers/api_auth_controller_test.go`, add a mail no-op helper and four tests. Also add `UNIQUE` on `email` in `newAPIAuthControllerTestDB`’s `users` table (`email TEXT UNIQUE`) so a missed pre-check still surfaces as a DB error.

```go
func muteActivationMail(t *testing.T) {
	t.Helper()
	orig := sendActivationMail
	sendActivationMail = func(*models.User) {}
	t.Cleanup(func() { sendActivationMail = orig })
}

func TestHandleAuthRegisterAPICreatesInactiveUser(t *testing.T) {
	db, restore := newAPIAuthControllerTestDB(t)
	defer restore()
	muteActivationMail(t)

	app := fiber.New()
	app.Post("/register", HandleAuthRegisterAPI)

	req := httptest.NewRequest(http.MethodPost, "/register", strings.NewReader(`{"username":"pete","email":"pete@example.com","password":"secret12"}`))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	require.NoError(t, err)
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)

	require.Equal(t, fiber.StatusCreated, resp.StatusCode, string(body))
	var payload map[string]any
	require.NoError(t, json.Unmarshal(body, &payload))
	assert.Equal(t, "pete@example.com", payload["email"])
	assert.NotEmpty(t, payload["message"])
	_, hasToken := payload["token"]
	assert.False(t, hasToken)

	var user models.User
	require.NoError(t, db.Where("email = ?", "pete@example.com").First(&user).Error)
	assert.Equal(t, "pete", user.Name)
	assert.Equal(t, models.STATUS_INACTIVE, user.Status)
	assert.Equal(t, models.AuthProviderLocal, user.RegistrationProvider)
	assert.NotEmpty(t, user.ActivationToken)
	assert.True(t, models.CheckPasswordHash("secret12", user.Password))
}

func TestHandleAuthRegisterAPIRejectsInvalidPayload(t *testing.T) {
	_, restore := newAPIAuthControllerTestDB(t)
	defer restore()
	muteActivationMail(t)

	app := fiber.New()
	app.Post("/register", HandleAuthRegisterAPI)
	req := httptest.NewRequest(http.MethodPost, "/register", strings.NewReader(`{"username":"ab","email":"bad","password":"1"}`))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	require.NoError(t, err)
	defer resp.Body.Close()
	assert.Equal(t, fiber.StatusBadRequest, resp.StatusCode)
}

func TestHandleAuthRegisterAPIConflictOnDuplicateEmail(t *testing.T) {
	db, restore := newAPIAuthControllerTestDB(t)
	defer restore()
	muteActivationMail(t)

	hash, err := models.HashPassword("secret12")
	require.NoError(t, err)
	require.NoError(t, db.Create(&models.User{
		Name:     "Ada",
		Email:    "ada@example.com",
		Password: hash,
		Status:   models.STATUS_ACTIVE,
		Role:     models.ROLE_USER,
	}).Error)

	app := fiber.New()
	app.Post("/register", HandleAuthRegisterAPI)
	req := httptest.NewRequest(http.MethodPost, "/register", strings.NewReader(`{"username":"other","email":"ada@example.com","password":"secret12"}`))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	require.NoError(t, err)
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	require.Equal(t, fiber.StatusConflict, resp.StatusCode, string(body))
	assert.NotContains(t, string(body), `"token"`)
}

func TestHandleAuthRegisterAPIUnavailableWhenDisabled(t *testing.T) {
	db, restore := newAPIAuthControllerTestDB(t)
	defer restore()
	muteActivationMail(t)

	require.NoError(t, db.Create(&models.Setting{
		Key:   "registration_enabled",
		Value: "false",
		Type:  "boolean",
	}).Error)
	require.NoError(t, models.LoadSettings(db))

	app := fiber.New()
	app.Post("/register", HandleAuthRegisterAPI)
	req := httptest.NewRequest(http.MethodPost, "/register", strings.NewReader(`{"username":"pete","email":"pete@example.com","password":"secret12"}`))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	require.NoError(t, err)
	defer resp.Body.Close()
	assert.Equal(t, fiber.StatusServiceUnavailable, resp.StatusCode)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run from `/home/dev/Workspace/Gitlab/PixelFox`:

```bash
go test ./app/controllers/ -count=1 -run 'TestHandleAuthRegisterAPI'
```

Expected: FAIL compiling (`undefined: HandleAuthRegisterAPI`, `undefined: sendActivationMail`).

- [ ] **Step 3: Implement helper, mail hook, and API handler**

In `app/controllers/api_auth_controller.go` add (keep existing login helpers):

```go
var errEmailTaken = errors.New("email already registered")

var sendActivationMail = sendActivationMailDefault

func sendActivationMailDefault(user *models.User) {
	domain := env.GetEnv("PUBLIC_DOMAIN", "")
	activationURL := fmt.Sprintf("%s/activate?token=%s", domain, user.ActivationToken)
	rec := httptest.NewRecorder()
	templ.Handler(emailViews.ActivationEmail(user.Email, templ.SafeURL(activationURL), user.ActivationToken, branding.Current().SiteTitle)).ServeHTTP(rec, &http.Request{})
	if err := mail.SendMail(user.Email, "Aktivierungslink "+branding.Current().SiteTitle, rec.Body.String()); err != nil {
		log.Printf("Activation email error: %v", err)
	}
}

func registerLocalUser(c *fiber.Ctx, username, email, password string) (*models.User, error) {
	username = strings.TrimSpace(username)
	email = strings.TrimSpace(email)
	if username == "" || email == "" || password == "" {
		return nil, fmt.Errorf("username, email and password are required")
	}
	if len(password) < 6 {
		return nil, fmt.Errorf("password must be at least 6 characters")
	}

	repo := repository.GetGlobalFactory().GetUserRepository()
	existing, err := repo.GetByEmail(email)
	if err == nil && existing != nil {
		return nil, errEmailTaken
	}
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}

	user, err := models.CreateUser(username, email, password)
	if err != nil {
		return nil, err
	}
	ipv4, ipv6 := GetClientIP(c)
	user.IPv4 = ipv4
	user.IPv6 = ipv6
	if err := user.GenerateActivationToken(); err != nil {
		return nil, err
	}
	if err := database.GetDB().Create(user).Error; err != nil {
		return nil, err
	}
	go statistics.UpdateStatisticsCache()
	sendActivationMail(user)
	return user, nil
}

func HandleAuthRegisterAPI(c *fiber.Ctx) error {
	if !models.IsRegistrationEnabled() {
		return jsonAPIError(c, fiber.StatusServiceUnavailable, "service_unavailable", "Registration is currently disabled")
	}

	var req struct {
		Username string `json:"username"`
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := c.BodyParser(&req); err != nil {
		return jsonAPIError(c, fiber.StatusBadRequest, "bad_request", "Invalid request payload")
	}

	user, err := registerLocalUser(c, req.Username, req.Email, req.Password)
	if err != nil {
		if errors.Is(err, errEmailTaken) {
			return jsonAPIError(c, fiber.StatusConflict, "conflict", "Email is already registered")
		}
		return jsonAPIError(c, fiber.StatusBadRequest, "bad_request", err.Error())
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"email":   user.Email,
		"message": "Registration successful. Please check your inbox for the activation link.",
	})
}
```

Add the missing imports (`net/http`, `net/http/httptest`, `github.com/a-h/templ`, `env`, `mail`, `branding`, `emailViews`, `statistics`) — copy the import set from `auth_controller.go` for those packages.

In `HandleAuthRegister` POST, **after** captcha + password-confirm checks, replace the CreateUser / IP / token / db.Create / statistics / mail block with:

```go
user, err := registerLocalUser(c, c.FormValue("username"), c.FormValue("email"), password)
if err != nil {
	fm := fiber.Map{"type": "error", "message": fmt.Sprintf("something went wrong: %s", err)}
	return flash.WithError(c, fm).Redirect("/register")
}
fm := fiber.Map{"type": "success", "message": "Registrierung erfolgreich! Bitte prüfe dein Postfach für den Aktivierungslink."}
return flash.WithSuccess(c, fm).Redirect("/activate")
```

Do not change captcha or password-confirm behavior.

- [ ] **Step 4: Run tests to verify they pass**

```bash
go test ./app/controllers/ -count=1 -run 'TestHandleAuthRegisterAPI|TestHandleAuthLoginAPI'
```

Expected: PASS (existing login tests still pass).

- [ ] **Step 5: Commit (PixelFox repo)**

```bash
cd /home/dev/Workspace/Gitlab/PixelFox
git add app/controllers/api_auth_controller.go app/controllers/auth_controller.go app/controllers/api_auth_controller_test.go
git commit -m "feat(api): add JSON auth register for the mobile app"
```

---

### Task 2: PixelFox OpenAPI + generated route

**Repo:** `/home/dev/Workspace/Gitlab/PixelFox`

**Files:**
- Modify: `public/docs/v1/openapi.yml`
- Modify: `internal/api/v1/generated.go` (generated)
- Modify: `internal/api/v1/handlers.go`

**Interfaces:**
- Consumes: `HandleAuthRegisterAPI`
- Produces: `APIServer.PostAuthRegister(c *fiber.Ctx) error` and OpenAPI `postAuthRegister`

- [ ] **Step 1: Add OpenAPI path and schemas**

In `public/docs/v1/openapi.yml`, insert **after** `/auth/login` (before `/auth/token`):

```yaml
  /auth/register:
    post:
      summary: Register with username, email, and password
      description: >-
        Creates an inactive account and sends the activation email. Does not
        issue an app session. The user must activate via the website email
        link, then call POST /auth/login.
      operationId: postAuthRegister
      tags:
        - Auth
      security: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/AuthRegisterRequest'
      responses:
        '201':
          description: Account created; activation email sent
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/AuthRegisterResponse'
        '400': { $ref: '#/components/responses/BadRequest' }
        '409': { $ref: '#/components/responses/Conflict' }
        '429': { $ref: '#/components/responses/TooManyRequests' }
        '503': { $ref: '#/components/responses/ServiceUnavailable' }
        '500': { $ref: '#/components/responses/InternalError' }
```

In `components.responses`, add next to `Forbidden`:

```yaml
    Conflict:
      description: Resource already exists
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
```

In `components.schemas`, next to `AuthLoginRequest`:

```yaml
    AuthRegisterRequest:
      type: object
      required:
        - username
        - email
        - password
      properties:
        username:
          type: string
          minLength: 3
          maxLength: 150
        email:
          type: string
          format: email
        password:
          type: string
          minLength: 6

    AuthRegisterResponse:
      type: object
      required:
        - email
        - message
      properties:
        email:
          type: string
          format: email
        message:
          type: string
```

Update the Auth tag description from “App login, logout, and OAuth start” to include register.

- [ ] **Step 2: Generate server interface**

```bash
cd /home/dev/Workspace/Gitlab/PixelFox
make generate-api
```

Expected: `internal/api/v1/generated.go` contains `PostAuthRegister`. `go build ./internal/api/v1/` fails until the next step (`APIServer` missing method).

- [ ] **Step 3: Wire the handler**

In `internal/api/v1/handlers.go`, next to `PostAuthLogin`:

```go
func (s *APIServer) PostAuthRegister(c *fiber.Ctx) error {
	return controllers.HandleAuthRegisterAPI(c)
}
```

- [ ] **Step 4: Compile and re-run register tests**

```bash
go build ./internal/api/v1/
go test ./app/controllers/ -count=1 -run 'TestHandleAuthRegisterAPI'
```

Expected: PASS.

- [ ] **Step 5: Commit (PixelFox repo)**

```bash
git add public/docs/v1/openapi.yml internal/api/v1/generated.go internal/api/v1/handlers.go
git commit -m "feat(api): document and wire POST /auth/register"
```

---

### Task 3: App API client register

**Repo:** fotoly-mobile

**Files:**
- Modify: `lib/config/api_config.dart`
- Modify: `lib/services/pixelfox_api_client.dart`
- Modify: `test/fake_api_http.dart`
- Test: `test/pixelfox_api_client_test.dart`

**Interfaces:**
- Consumes: existing `PixelfoxApiClient` POST + `_apiErrorMessage`
- Produces:
  - `ApiConfig.authRegisterUrl()` → `'$apiRoot/auth/register'`
  - `Future<String> PixelfoxApiClient.register({required String username, required String email, required String password})` — returns email from 201 body, else request email

- [ ] **Step 1: Extend FakeApiHttp and write failing client tests**

In `test/fake_api_http.dart` constructor fields, add:

```dart
    this.registerStatus = 201,
    this.registerBody,
```

Fields:

```dart
  int registerStatus;
  String? registerBody;
```

In `post()`, before the `/auth/login` branch:

```dart
    if (url.path.endsWith('/auth/register')) {
      return http.Response(
        registerBody ?? '{}',
        registerStatus,
        headers: {'content-type': 'application/json'},
      );
    }
```

In `test/pixelfox_api_client_test.dart`, add a group:

```dart
  group('PixelfoxApiClient auth register', () {
    test('register posts credentials and returns email from 201', () async {
      final fake = FakeApiHttp(
        registerStatus: 201,
        registerBody:
            '{"email":"pete@example.com","message":"Registration successful. Please check your inbox for the activation link."}',
      );
      final client = PixelfoxApiClient(httpClient: fake);

      final email = await client.register(
        username: 'pete',
        email: 'pete@example.com',
        password: 'secret12',
      );

      expect(email, 'pete@example.com');
      final req = fake.sent.whereType<http.BaseRequest>().firstWhere(
        (r) => r.url.path.contains('/auth/register'),
      );
      expect(req.method, 'POST');
    });

    test('register throws PixelfoxApiException on 409', () async {
      final fake = FakeApiHttp(
        registerStatus: 409,
        registerBody:
            '{"error":"conflict","message":"Email is already registered"}',
      );
      final client = PixelfoxApiClient(httpClient: fake);

      expect(
        () => client.register(
          username: 'pete',
          email: 'pete@example.com',
          password: 'secret12',
        ),
        throwsA(
          isA<PixelfoxApiException>().having(
            (e) => e.message,
            'message',
            'Email is already registered',
          ),
        ),
      );
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/pixelfox_api_client_test.dart
```

Expected: FAIL — `register` method missing.

- [ ] **Step 3: Implement URL + client method**

`lib/config/api_config.dart`:

```dart
  static String authRegisterUrl() => '$apiRoot/auth/register';
```

`lib/services/pixelfox_api_client.dart` next to `loginWithPassword`:

```dart
  Future<String> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse(ApiConfig.authRegisterUrl());
    final body = {
      'username': username,
      'email': email,
      'password': password,
    };
    final headers = {..._jsonHeaders, 'Content-Type': 'application/json'};
    _log(
      ApiRequestLog(
        method: 'POST',
        url: uri.toString(),
        headers: headers,
        jsonBody: body,
      ),
    );
    final response = await _http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode != 201) {
      throw PixelfoxApiException(
        _apiErrorMessage(response.body, 'Registration failed'),
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    try {
      final json = jsonDecode(response.body);
      if (json is Map<String, dynamic>) {
        final returned = (json['email'] as String?)?.trim() ?? '';
        if (returned.isNotEmpty) return returned;
      }
    } catch (_) {}
    return email;
  }
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/pixelfox_api_client_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/config/api_config.dart lib/services/pixelfox_api_client.dart test/fake_api_http.dart test/pixelfox_api_client_test.dart
git commit -m "feat(auth): add register API client"
```

---

### Task 4: AuthService.register

**Repo:** fotoly-mobile

**Files:**
- Modify: `lib/services/auth_service.dart`
- Test: `test/auth_service_test.dart`

**Interfaces:**
- Consumes: `PixelfoxApiClient.register`
- Produces: `Future<bool> AuthService.register({required String username, required String email, required String password})` — no session persist

- [ ] **Step 1: Write the failing tests**

In `test/auth_service_test.dart`:

```dart
  test('register succeeds without persisting a session', () async {
    final store = MemorySecureStore();
    final fake = FakeApiHttp(
      registerStatus: 201,
      registerBody:
          '{"email":"pete@example.com","message":"Registration successful. Please check your inbox for the activation link."}',
    );
    final auth = AuthService(secureStore: store, clientFactory: factoryFor(fake));

    final ok = await auth.register(
      username: 'pete',
      email: 'pete@example.com',
      password: 'secret12',
    );

    expect(ok, isTrue);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.accessToken, isNull);
    expect(auth.apiKey, isNull);
    expect(await store.read(kAccessTokenStorageKey), isNull);
    expect(auth.error, isNull);
  });

  test('register sets error on 409 and does not persist', () async {
    final store = MemorySecureStore();
    final fake = FakeApiHttp(
      registerStatus: 409,
      registerBody:
          '{"error":"conflict","message":"Email is already registered"}',
    );
    final auth = AuthService(secureStore: store, clientFactory: factoryFor(fake));

    final ok = await auth.register(
      username: 'pete',
      email: 'pete@example.com',
      password: 'secret12',
    );

    expect(ok, isFalse);
    expect(auth.error, 'Email is already registered');
    expect(auth.isAuthenticated, isFalse);
    expect(await store.read(kAccessTokenStorageKey), isNull);
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/auth_service_test.dart
```

Expected: FAIL — `register` missing.

- [ ] **Step 3: Implement AuthService.register**

Next to `loginWithPassword`:

```dart
  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final trimmedName = username.trim();
    final trimmedEmail = email.trim();
    if (trimmedName.isEmpty || trimmedEmail.isEmpty || password.isEmpty) {
      _error = 'Please enter username, email and password';
      notifyListeners();
      return false;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _guestClient.register(
        username: trimmedName,
        email: trimmedEmail,
        password: password,
      );
      return true;
    } on PixelfoxApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Registration failed: $e';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
```

Do **not** call `_persistSession` or `_validateAndStore`.

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/auth_service_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/auth_service.dart test/auth_service_test.dart
git commit -m "feat(auth): register without creating a session"
```

---

### Task 5: l10n strings

**Repo:** fotoly-mobile

**Files:**
- Modify: `lib/l10n/app_strings.dart`
- Modify: `lib/l10n/app_strings_de.dart`
- Modify: `lib/l10n/app_strings_en.dart`
- Test: `test/l10n_test.dart`

**Interfaces:**
- Produces getters listed below on `AppStrings` / `AppStringsDe` / `AppStringsEn`

- [ ] **Step 1: Write the failing l10n assertions**

Append to `test/l10n_test.dart`:

```dart
  test('register and check-email copy exists in DE and EN', () {
    const de = AppStringsDe();
    const en = AppStringsEn();
    expect(de.registerLink, 'Noch kein Konto? Registrieren');
    expect(en.registerLink, 'No account yet? Register');
    expect(de.createAccount, 'Konto erstellen');
    expect(en.createAccount, 'Create account');
    expect(de.passwordMismatch, 'Die Passwörter stimmen nicht überein.');
    expect(en.passwordMismatch, 'Passwords do not match.');
    expect(de.checkEmailTitle, 'E-Mail prüfen');
    expect(en.checkEmailTitle, 'Check your email');
    expect(de.checkEmailBody('a@b.c'), contains('a@b.c'));
    expect(en.checkEmailBody('a@b.c'), contains('a@b.c'));
    expect(de.backToLogin, 'Zum Login');
    expect(en.backToLogin, 'Back to login');
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/l10n_test.dart
```

Expected: FAIL — getters missing.

- [ ] **Step 3: Add strings**

In `app_strings.dart` under the Login section:

```dart
  String get registerLink;
  String get registerTitle;
  String get registerSubtitle;
  String get usernameLabel;
  String get passwordConfirmLabel;
  String get createAccount;
  String get passwordMismatch;
  String get checkEmailTitle;
  String checkEmailBody(String email);
  String get backToLogin;
```

`app_strings_de.dart`:

```dart
  @override
  String get registerLink => 'Noch kein Konto? Registrieren';

  @override
  String get registerTitle => 'Konto erstellen';

  @override
  String get registerSubtitle =>
      'Nach der Registrierung schicken wir einen Aktivierungslink per E-Mail.';

  @override
  String get usernameLabel => 'Benutzername';

  @override
  String get passwordConfirmLabel => 'Passwort wiederholen';

  @override
  String get createAccount => 'Konto erstellen';

  @override
  String get passwordMismatch => 'Die Passwörter stimmen nicht überein.';

  @override
  String get checkEmailTitle => 'E-Mail prüfen';

  @override
  String checkEmailBody(String email) =>
      'Wir haben einen Aktivierungslink an $email geschickt. Öffne den Link im Browser und logge dich danach hier ein.';

  @override
  String get backToLogin => 'Zum Login';
```

`app_strings_en.dart`:

```dart
  @override
  String get registerLink => 'No account yet? Register';

  @override
  String get registerTitle => 'Create account';

  @override
  String get registerSubtitle =>
      'After you register we send an activation link by email.';

  @override
  String get usernameLabel => 'Username';

  @override
  String get passwordConfirmLabel => 'Confirm password';

  @override
  String get createAccount => 'Create account';

  @override
  String get passwordMismatch => 'Passwords do not match.';

  @override
  String get checkEmailTitle => 'Check your email';

  @override
  String checkEmailBody(String email) =>
      'We sent an activation link to $email. Open the link in your browser, then sign in here.';

  @override
  String get backToLogin => 'Back to login';
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/l10n_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_strings.dart lib/l10n/app_strings_de.dart lib/l10n/app_strings_en.dart test/l10n_test.dart
git commit -m "feat(l10n): add registration copy"
```

---

### Task 6: CheckEmailScreen

**Repo:** fotoly-mobile

**Files:**
- Create: `lib/screens/check_email_screen.dart`
- Test: `test/check_email_screen_test.dart`

**Interfaces:**
- Consumes: `context.l10n`, constructor `email`
- Produces: `class CheckEmailScreen extends StatelessWidget { const CheckEmailScreen({super.key, required this.email}); final String email; }` — no `AuthService` calls

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/l10n/locale_controller.dart';
import 'package:fotoly_mobile/screens/check_email_screen.dart';
import 'package:fotoly_mobile/services/storage.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('shows email and pops on back to login', (tester) async {
    final locale = LocaleController(prefs: MemoryPrefsStore());
    await locale.setLocale(AppLocale.en);

    await tester.pumpWidget(
      ChangeNotifierProvider<LocaleController>.value(
        value: locale,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CheckEmailScreen(
                      email: 'pete@example.com',
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('pete@example.com'), findsWidgets);
    await tester.tap(find.text('Back to login'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Check your email'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/check_email_screen_test.dart
```

Expected: FAIL — file / widget missing.

- [ ] **Step 3: Implement the screen**

```dart
import 'package:flutter/material.dart';

import '../l10n/l10n_scope.dart';

class CheckEmailScreen extends StatelessWidget {
  const CheckEmailScreen({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(s.checkEmailTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.checkEmailBody(email)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(s.backToLogin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/check_email_screen_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/check_email_screen.dart test/check_email_screen_test.dart
git commit -m "feat(auth): add check-email screen after register"
```

---

### Task 7: RegisterScreen

**Repo:** fotoly-mobile

**Files:**
- Create: `lib/screens/register_screen.dart`
- Test: `test/register_screen_test.dart`

**Interfaces:**
- Consumes: `AuthService.register`, `CheckEmailScreen`, l10n labels
- Produces: `class RegisterScreen extends StatefulWidget` — on success `pushReplacement` to `CheckEmailScreen(email: trimmedEmail)`

- [ ] **Step 1: Write the failing widget tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/l10n/locale_controller.dart';
import 'package:fotoly_mobile/screens/register_screen.dart';
import 'package:fotoly_mobile/services/auth_service.dart';
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';
import 'package:fotoly_mobile/services/storage.dart';
import 'package:provider/provider.dart';

import 'fake_api_http.dart';

void main() {
  AuthService authWith(FakeApiHttp fake) {
    return AuthService(
      secureStore: MemorySecureStore(),
      clientFactory: ({apiKey, accessToken}) => PixelfoxApiClient(
        apiKey: apiKey,
        accessToken: accessToken,
        httpClient: fake,
      ),
    );
  }

  Future<void> pumpRegister(WidgetTester tester, AuthService auth) async {
    final locale = LocaleController(prefs: MemoryPrefsStore());
    await locale.setLocale(AppLocale.en);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocaleController>.value(value: locale),
          ChangeNotifierProvider<AuthService>.value(value: auth),
        ],
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );
  }

  testWidgets('password mismatch does not POST', (tester) async {
    final fake = FakeApiHttp(registerStatus: 201, registerBody: '{"email":"a@b.c"}');
    await pumpRegister(tester, authWith(fake));

    await tester.enterText(find.byType(TextField).at(0), 'pete');
    await tester.enterText(find.byType(TextField).at(1), 'pete@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'secret12');
    await tester.enterText(find.byType(TextField).at(3), 'other');
    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(fake.sent, isEmpty);
  });

  testWidgets('success replaces with check-email screen', (tester) async {
    final fake = FakeApiHttp(
      registerStatus: 201,
      registerBody:
          '{"email":"pete@example.com","message":"Registration successful. Please check your inbox for the activation link."}',
    );
    await pumpRegister(tester, authWith(fake));

    await tester.enterText(find.byType(TextField).at(0), 'pete');
    await tester.enterText(find.byType(TextField).at(1), 'pete@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'secret12');
    await tester.enterText(find.byType(TextField).at(3), 'secret12');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('pete@example.com'), findsWidgets);
    expect(find.text('Create account'), findsNothing);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/register_screen_test.dart
```

Expected: FAIL — `RegisterScreen` missing.

- [ ] **Step 3: Implement RegisterScreen**

Follow `LoginScreen` field styling (obscure toggles on both password fields). Outline:

```dart
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  Future<void> _submit() async {
    final s = context.l10n;
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.passwordMismatch)),
      );
      return;
    }
    final email = _email.text.trim();
    final auth = context.read<AuthService>();
    final ok = await auth.register(
      username: _username.text,
      email: email,
      password: _password.text,
    );
    if (!mounted) return;
    if (!ok) {
      final message = auth.error;
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CheckEmailScreen(email: email),
      ),
    );
  }

  // build: Scaffold + AppBar(s.registerTitle) + fields + FilledButton(s.createAccount)
}
```

Submit button `onPressed: auth.loading ? null : _submit`. Show `s.registerSubtitle` under the title. Disable fields while `auth.loading`.

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/register_screen_test.dart test/check_email_screen_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/register_screen.dart test/register_screen_test.dart
git commit -m "feat(auth): add register screen"
```

---

### Task 8: Login link + quality gate

**Repo:** fotoly-mobile

**Files:**
- Modify: `lib/screens/login_screen.dart`
- Modify: `test/login_screen_test.dart`

**Interfaces:**
- Consumes: `s.registerLink`, `RegisterScreen`
- Produces: TextButton on `LoginScreen` that `Navigator.push`es `RegisterScreen`

- [ ] **Step 1: Extend login_screen_test**

In the existing widget test, after expecting Sign in:

```dart
    expect(find.text('No account yet? Register'), findsOneWidget);
```

Add a second test:

```dart
  testWidgets('register link opens register screen', (tester) async {
    final locale = LocaleController(prefs: MemoryPrefsStore());
    await locale.setLocale(AppLocale.en);
    final auth = AuthService(
      secureStore: MemorySecureStore(),
      clientFactory: ({apiKey, accessToken}) => PixelfoxApiClient(
        apiKey: apiKey,
        accessToken: accessToken,
        httpClient: FakeApiHttp(),
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocaleController>.value(value: locale),
          ChangeNotifierProvider<AuthService>.value(value: auth),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.tap(find.text('No account yet? Register'));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsWidgets);
    expect(find.text('Username'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/login_screen_test.dart
```

Expected: FAIL — link text missing.

- [ ] **Step 3: Add the link on LoginScreen**

Directly under the Sign-in `FilledButton` (before the social divider):

```dart
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: auth.loading
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                    child: Text(s.registerLink),
                  ),
```

Import `register_screen.dart`.

- [ ] **Step 4: Run app quality gate**

```bash
make check
```

Expected: analyze + tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/login_screen.dart test/login_screen_test.dart
git commit -m "feat(auth): link login to registration"
```

---

## Spec coverage

| Spec item | Task |
|-----------|------|
| `POST /api/v1/auth/register` JSON, 201, no token | 1, 2 |
| Inactive user + activation token + existing email | 1 |
| `IsRegistrationEnabled` → 503 | 1 |
| Duplicate email → 409 | 1 |
| Shared helper with website `/register` | 1 |
| Mail failures logged, not 500 | 1 (`sendActivationMailDefault`) |
| OpenAPI + oapi-codegen + `PostAuthRegister` | 2 |
| `ApiConfig` / client / FakeApiHttp | 3 |
| `AuthService.register` no session | 4 |
| DE + EN copy | 5 |
| Check-email screen, pop to login | 6 |
| Register form + mismatch local + `pushReplacement` | 7 |
| Login “Register” link | 8 |
| No captcha, resend, deep link, go_router | all (omitted) |
