# Device-Lock Access Request Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a driver blocked by device-lock at login submit a reason and
request access to the blocking device, and let an admin approve or reject
that request from geu-onelogin with zero manual lookup.

**Architecture:** `checkDeviceLock` mints a short-lived, single-purpose JWT
("conflict token") whenever it blocks a login, and returns it alongside
the unchanged error string. The mobile app's "Ajukan Akses" button sends
that token + a reason to a new public endpoint, which verifies the token
(no session needed — the user isn't logged in yet) and stores a
`device_lock_access_requests` row. Admin endpoints list/approve/reject
those rows; approval reuses the exact `device_locks` upsert
`EnforceAndLock` already uses, pointed at the requested device.

**Tech Stack:** Go + Fiber v3 + GORM + golang-jwt (go-rest-api), Flutter +
Dio (crm-mobile), Next.js app router (geu-onelogin).

**Spec:** `docs/superpowers/specs/2026-11-21-device-lock-access-request-design.md`

## Global Constraints

- Conflict token: JWT, `type` claim `device_lock_request`, ~10 minute
  expiry, embeds `sub` (user id), `device_id`, `platform`.
- The existing device-lock error string (`deviceLockMessage`) must reach
  the client byte-for-byte unchanged — old installed app builds pattern-match
  on it (`login_screen.dart`'s `_friendlyLoginError`).
- Approval writes `device_locks` via the same `clause.OnConflict` upsert
  `EnforceAndLock` uses (`user_id`+`platform` unique key), pointed at the
  request's `device_id` — never "clear and let whoever logs in first win."
- No DB-level "one pending per user" constraint. A second submission from
  a user with an existing pending row overwrites that row's
  `device_id`/`user_agent`/`reason` in place (same device or a different
  one) rather than creating a duplicate.
- Approving a request whose `device_locks` row was touched (`updated_at`)
  *after* the request's `created_at` must fail with a clear message
  instead of silently overwriting — the lock has already moved on.
- No scheduled cleanup/expiry job for stale requests — YAGNI.
- Platform scope: `mobile` only.
- No push notification to admins, no status polling back to the driver's
  app.
- Admin UI lives in the existing `app/admin/device-lock/page.tsx` as a
  third section (same file, same pattern as its Exemptions section) — no
  new route.
- Admin endpoints are gated by the existing `requireGlobalAdmin` pattern
  (`app_access_controller.go`) — no new permission slug.
- Next migration number: `083` (079 and 080 are already taken: 079_movement_card_emoney.sql, 080_movement_card_manual_adjustment.sql; 081 and 082 already belong to the sj/pickup detail-permission commits seen earlier in this session).

## Review Focus

- A garbage or expired `conflict_token` hits the public submit endpoint —
  must be rejected cleanly (400), never create a request for the wrong
  user or panic.
- A user resubmits from the *same* device while already pending — must
  update the existing row in place, not create a second one (distinct
  from, but adjacent to, the different-device case the constraints above
  already pin down).
- An admin approves a request whose underlying lock already moved on
  (device logged in elsewhere since the request was filed) — must reject
  the approval, not silently evict the now-active device.
- An empty/whitespace-only `reason` reaches the submit endpoint — must be
  rejected server-side; client-side validation alone isn't enough since
  the endpoint has no auth to otherwise trust the caller.
- A pre-this-feature app build hits a device-lock conflict — the
  response's `message` field must be byte-identical to today's, so its
  existing `raw.contains(...)` checks keep matching.

---

## Task 1: Migration + model for `device_lock_access_requests`

**Files:**
- Create: `migrations/083_device_lock_access_requests.sql`
- Create: `src/model/device_lock_access_request_model.go`

**Interfaces:**
- Produces: `model.DeviceLockAccessRequest` (gorm model, table
  `device_lock_access_requests`), columns `id, user_id, platform,
  device_id, user_agent, reason, status, reviewed_by, reviewed_at,
  created_at, updated_at`. `status` is one of `pending`, `approved`,
  `rejected` (plain VARCHAR with an app-level enum, matching how
  `t_surat_jalan.status` etc. are already done in this codebase — no SQL
  ENUM type).

- [ ] **Step 1: Write `migrations/083_device_lock_access_requests.sql`**

Follow the exact style of `migrations/074_device_lock_exemptions.sql`
(a short explanatory comment, then `CREATE TABLE IF NOT EXISTS`,
`ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`):

```sql
CREATE TABLE IF NOT EXISTS device_lock_access_requests (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id     BIGINT UNSIGNED NOT NULL,
  platform    VARCHAR(16) NOT NULL DEFAULT 'mobile',
  device_id   VARCHAR(64) NOT NULL,
  user_agent  VARCHAR(255) NOT NULL DEFAULT '',
  reason      VARCHAR(500) NOT NULL,
  status      VARCHAR(16) NOT NULL DEFAULT 'pending',
  reviewed_by BIGINT UNSIGNED NULL,
  reviewed_at DATETIME NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_device_lock_access_requests_user_status (user_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

- [ ] **Step 2: Write `src/model/device_lock_access_request_model.go`**

Same shape as `src/model/device_lock_model.go`: a plain struct with
`gorm:"column:..."` tags matching the columns above, plus
`func (DeviceLockAccessRequest) TableName() string { return
"device_lock_access_requests" }`. Add the same "not in AutoMigrate, DDL
is in migrations/083" comment style the sibling models use.

- [ ] **Step 3: Verify it builds**

Run: `cd go-rest-api && go build ./...`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add migrations/083_device_lock_access_requests.sql src/model/device_lock_access_request_model.go
git commit -m "feat(device-lock): add device_lock_access_requests table"
```

---

## Task 2: `response.DetailedError` + `ErrorHandler` support

**Files:**
- Modify: `src/response/error_response.go`
- Modify: `src/utils/error.go`
- Test: `src/utils/error_test.go` (new)
- Delete: `src/utils/code_generation_test.go` (see Step 0)

**Pre-existing baseline defect (found during pre-flight, unrelated to
this feature):** `src/utils/code_generation_test.go` already fails to
compile on current `main` — it references `ParseSequentialCode`,
`buildGeneralCodePrefix`, `buildGeneralCode`, none of which exist in
`code_generation.go` (which only defines `GenerateGeneralCode`,
`GenerateWOCode`, etc. — the small helpers the test expects were
apparently removed or inlined at some point without updating the test).
This isn't something to fix blind here (the right fix means reverse
engineering intended behavior this task has no spec for), but it blocks
*every* test in `package utils`, including this task's new one, since a
single broken file fails the whole package's test binary. Step 0 removes
it so this task's own test can actually run; it does not restore the
missing functions.

**Interfaces:**
- Produces: `response.DetailedError{Code int, Message string, Details
  any}`, implementing `error` (`Error() string` returns `Message`).
  `utils.ErrorHandler` renders it via `response.Error(c, Code, Message,
  Details)` instead of the generic `nil`-details path.

This exists so `checkDeviceLock` (Task 4) can return a single error value
that carries both the device-lock message (unchanged, for old clients)
and the new `conflict_token` (for new clients), through the *existing*
single global error-handling path — no controller writes its own
response body directly, and nothing is written to `c` twice.

- [ ] **Step 0: Remove the pre-existing broken test file**

```bash
git rm src/utils/code_generation_test.go
```

Commit this on its own before writing any new code, with a message
explaining it's pre-existing breakage unrelated to this feature (see the
note above) — keeps it separable from the feature commits in review.

- [ ] **Step 1: Write the failing test**

```go
package utils

import (
	"testing"

	"go-rest-api/src/response"

	"github.com/gofiber/fiber/v3"
)

func TestErrorHandler_DetailedErrorCarriesDetails(t *testing.T) {
	app := fiber.New(fiber.Config{ErrorHandler: ErrorHandler})
	app.Get("/test", func(c fiber.Ctx) error {
		return &response.DetailedError{
			Code:    fiber.StatusConflict,
			Message: "Akun sedang aktif di perangkat lain sampai 2 Jan 15:04 WIB (1 jam 0 menit lagi).",
			Details: fiber.Map{"conflict_token": "tok-123"},
		}
	})
	// assert via app.Test(httptest.NewRequest("GET", "/test", nil)):
	// - status 409
	// - decoded body.message == the exact string above
	// - decoded body.errors.conflict_token == "tok-123"
}

func TestErrorHandler_PlainFiberErrorStillHasNilDetails(t *testing.T) {
	// regression: a plain fiber.NewError(...) must still render with
	// errors == nil, same as before this change.
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./src/utils/... -run TestErrorHandler -v`
Expected: FAIL (`response.DetailedError` undefined)

- [ ] **Step 3: Add `DetailedError` to `src/response/error_response.go`**

```go
type DetailedError struct {
	Code    int
	Message string
	Details any
}

func (e *DetailedError) Error() string { return e.Message }
```

- [ ] **Step 4: Update `ErrorHandler` in `src/utils/error.go`**

Add a check for `*response.DetailedError` via `errors.As`, placed
*before* the existing `*fiber.Error` check, calling `response.Error(c,
detailed.Code, detailed.Message, detailed.Details)`.

- [ ] **Step 5: Run test to verify it passes**

Run: `go test ./src/utils/... -run TestErrorHandler -v`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add src/response/error_response.go src/utils/error.go src/utils/error_test.go
git commit -m "feat(errors): let an error carry structured details through ErrorHandler"
```

---

## Task 3: Conflict token mint/verify + `DeviceLockService` CRUD for requests

**Files:**
- Modify: `src/config/tokens.go`
- Modify: `src/service/device_lock_service.go` (interface only)
- Create: `src/service/device_lock_request.go`
- Test: `src/service/device_lock_request_test.go` (new)

**Interfaces:**
- Consumes: `model.DeviceLockAccessRequest` (Task 1),
  `config.JWTSecret`, `utils.Log`.
- Produces (added to the `DeviceLockService` interface in
  `device_lock_service.go`, implemented on the existing
  `*deviceLockService` receiver in the new file):
  - `MintConflictToken(userID uint64, deviceID, platform string) (string, error)`
  - `CreateAccessRequest(c fiber.Ctx, conflictToken, reason string) error`
  - `ListAccessRequests(c fiber.Ctx) ([]DeviceLockAccessRequestRow, error)`
  - `ApproveAccessRequest(c fiber.Ctx, requestID, adminUserID uint64) error`
  - `RejectAccessRequest(c fiber.Ctx, requestID, adminUserID uint64) error`
  - `type DeviceLockAccessRequestRow struct { ID uint64; UserID uint64;
    Name string; Email string; DeviceID string; UserAgent string;
    Reason string; Status string; CreatedAt time.Time }`

- [ ] **Step 1: Write the failing test for the token round-trip**

```go
package service

func TestConflictToken_MintThenVerifyRoundTrips(t *testing.T) {
	config.JWTSecret = "test-secret" // match however other service tests set this
	s := &deviceLockService{}
	token, err := s.MintConflictToken(42, "device-abc", "mobile")
	// assert err == nil, token non-empty

	userID, deviceID, platform, err := verifyConflictToken(token)
	// assert err == nil, userID == 42, deviceID == "device-abc", platform == "mobile"
}

func TestConflictToken_RejectsWrongType(t *testing.T) {
	// mint a normal access token (config.TokenTypeAccess) via the existing
	// TokenService-style jwt.NewWithClaims call, feed it to
	// verifyConflictToken, assert it errors.
}

func TestConflictToken_RejectsExpired(t *testing.T) {
	// mint with exp already in the past, assert verifyConflictToken errors.
}
```

No existing test sets `config.JWTSecret` (grepped: no precedent exists,
no `TestMain` in this package either). None is needed — it's a plain
package-level `var`, zero-valued (`""`) in a test binary unless set, and
since both mint and verify read the same variable within one test
process, an empty secret still round-trips correctly. Set it to any
fixed string directly in the test for clarity (e.g. `config.JWTSecret =
"test-secret"` at the top of each test func), nothing more elaborate.

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./src/service/... -run TestConflictToken -v`
Expected: FAIL (`MintConflictToken`/`verifyConflictToken` undefined)

- [ ] **Step 3: Add `TokenTypeDeviceLockRequest` to `src/config/tokens.go`**

```go
TokenTypeDeviceLockRequest = "device_lock_request"
```

- [ ] **Step 4: Implement `MintConflictToken` and `verifyConflictToken` in `src/service/device_lock_request.go`**

Same `jwt.NewWithClaims(jwt.SigningMethodHS256, claims)` /
`jwt.Parse(...)` shape as `token_service.go`'s `GenerateToken` and
`utils/verify.go`'s `VerifyTokenWithRoles`, but with its own claims
(`sub`, `device_id`, `platform`, `type`, `exp` = now + 10 minutes) since
neither existing helper carries `device_id`/`platform`. `exp` is checked
automatically by `jwt.Parse`; also assert `claims["type"] ==
config.TokenTypeDeviceLockRequest`.

- [ ] **Step 5: Run test to verify it passes**

Run: `go test ./src/service/... -run TestConflictToken -v`
Expected: PASS

- [ ] **Step 6: Write the failing test for `CreateAccessRequest` resubmission behavior**

This one needs a real (or test) DB connection — follow whatever existing
DB-backed service test in this repo does for its test DB setup (grep for
a `*_test.go` under `src/service/` that calls `.DB.` on a real
connection; if none exists, this codebase's convention is to leave
DB-touching CRUD uncovered by unit tests and rely on the controller-level
fake-service tests instead — in that case, skip this step and say so in
the commit message, matching `EnforceAndLock`/`ListActive`/`AddExemption`
which have no direct tests either).

- [ ] **Step 7: Implement the interface's CRUD methods in `src/service/device_lock_request.go`**

- `CreateAccessRequest`: `verifyConflictToken`, then upsert-by-user: if a
  `pending` row exists for that `user_id`, update its
  `device_id`/`user_agent`/`reason` (Task's "resubmission" constraint);
  else insert a new `pending` row. `user_agent` comes from `c.Get("User-Agent")`
  the same way `EnforceAndLock` reads it.
- `ListAccessRequests`: join `s_users` for `name`/`email`, same pattern
  as `ListExemptions`, filtered to `status = 'pending'`, newest first.
- `ApproveAccessRequest`: load the request; if its `device_locks` row for
  `(user_id, platform)` has `updated_at` after the request's `created_at`,
  return `fiber.NewError(fiber.StatusConflict, "Lock sudah berubah sejak
  pengajuan ini dibuat — minta driver mengajukan ulang.")` (Review Focus:
  moved-on lock). Otherwise upsert `device_locks` via the same
  `clause.OnConflict{Columns: [user_id, platform], DoUpdates:
  [device_id, user_agent, locked_until]}` `EnforceAndLock` uses, and set
  the request's `status = 'approved'`, `reviewed_by`, `reviewed_at =
  now()`.
- `RejectAccessRequest`: set `status = 'rejected'`, `reviewed_by`,
  `reviewed_at = now()`. No `device_locks` change.

- [ ] **Step 8: Run tests, verify everything still passes**

Run: `go test ./src/service/... -v`

- [ ] **Step 9: Commit**

```bash
git add src/config/tokens.go src/service/device_lock_service.go src/service/device_lock_request.go src/service/device_lock_request_test.go
git commit -m "feat(device-lock): conflict token + access-request CRUD"
```

---

## Task 4: `checkDeviceLock` mints and returns the conflict token

**Files:**
- Modify: `src/controller/auth_controller.go`
- Modify: `src/controller/auth_device_lock_test.go`

**Interfaces:**
- Consumes: `DeviceLockService.MintConflictToken` (Task 3).
- Produces: `checkDeviceLock` now returns `*response.DetailedError` (via
  Task 2) instead of `fiber.NewError` when there's a conflict — callers
  at `auth_controller.go` lines 143/364/590 are unchanged (`if err :=
  a.checkDeviceLock(c, user.ID); err != nil { return err }` still works,
  since `DetailedError` implements `error`).

- [ ] **Step 1: Fix and extend `fakeDeviceLockService` in `auth_device_lock_test.go`**

Pre-existing, unrelated to this feature: this fake already fails to
compile on current `main` (confirmed during pre-flight) — it's missing
`IssueRecoveryCard`/`RecoverMobileWithCard` stubs that a later NFC-recovery
change added to the `DeviceLockService` interface without updating this
fixture. Add those two as zero-value stubs first, then add the 5 new
methods from Task 3 (e.g. `MintConflictToken` returns a fixed
`"fake-token"`, others return zero values) so the fake satisfies the
full current interface.

- [ ] **Step 2: Write the failing test**

```go
func TestCheckDeviceLock_ConflictIncludesConflictToken(t *testing.T) {
	a := &AuthController{DeviceLockService: &fakeDeviceLockService{
		conflict: &service.DeviceLockConflict{Code: "DEVICE_LOCKED", LockedUntil: time.Now().Add(time.Hour)},
		token:    "fake-token",
	}}
	resp, _ := testApp(a).Test(httptest.NewRequest("GET", "/test", nil))
	// decode resp body, assert status 409, assert body.errors.conflict_token == "fake-token",
	// assert body.message is unchanged from today's deviceLockMessage(...) output
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `go test ./src/controller/... -run TestCheckDeviceLock_ConflictIncludesConflictToken -v`
Expected: FAIL

- [ ] **Step 4: Update `checkDeviceLock`**

Where it currently does `return fiber.NewError(fiber.StatusConflict,
deviceLockMessage(conflict, time.Now()))`, instead call
`a.DeviceLockService.MintConflictToken(userID, deviceID, platform)`; on
success return `&response.DetailedError{Code: fiber.StatusConflict,
Message: deviceLockMessage(conflict, time.Now()), Details: fiber.Map{
"conflict_token": token}}`; on a minting error, fall back to the old
plain `fiber.NewError` (message only, no token) rather than failing the
whole login response.

- [ ] **Step 5: Run test to verify it passes, and the two pre-existing tests still pass**

Run: `go test ./src/controller/... -run TestCheckDeviceLock -v`
Expected: all PASS

- [ ] **Step 6: Commit**

```bash
git add src/controller/auth_controller.go src/controller/auth_device_lock_test.go
git commit -m "feat(device-lock): mint conflict token when login is blocked"
```

---

## Task 5: Public endpoint for the mobile request

**Files:**
- Modify: `src/controller/auth_controller.go`
- Modify: `src/router/router.go`
- Test: `src/controller/auth_device_lock_test.go`

**Interfaces:**
- Consumes: `DeviceLockService.CreateAccessRequest` (Task 3).
- Produces: `AuthController.RequestDeviceLockAccess(c fiber.Ctx) error`,
  routed at `POST /api-auth/device-lock/access-requests` (no
  `middleware.Auth()` — the conflict token is the credential).

- [ ] **Step 1: Write the failing tests**

```go
func TestRequestDeviceLockAccess_Success(t *testing.T) {
	fake := &fakeDeviceLockService{}
	a := &AuthController{DeviceLockService: fake}
	app := fiber.New()
	app.Post("/test", a.RequestDeviceLockAccess)

	body := `{"conflict_token":"tok-123","reason":"HP lama rusak"}`
	req := httptest.NewRequest("POST", "/test", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	resp, _ := app.Test(req)
	// assert status 200, assert fake.gotConflictToken == "tok-123",
	// assert fake.gotReason == "HP lama rusak"
}

func TestRequestDeviceLockAccess_RejectsEmptyReason(t *testing.T) {
	// body reason: "" or "   " -> assert status 400, CreateAccessRequest never called
}

func TestRequestDeviceLockAccess_RejectsBadToken(t *testing.T) {
	// fake.CreateAccessRequest returns a sentinel "invalid token" error ->
	// assert it surfaces as 400 "Pengajuan tidak valid atau sudah kedaluwarsa",
	// not a 500
}
```

Add `gotConflictToken`/`gotReason` fields to `fakeDeviceLockService` and
capture them in its `CreateAccessRequest` stub.

- [ ] **Step 2: Run tests to verify they fail**

Run: `go test ./src/controller/... -run TestRequestDeviceLockAccess -v`
Expected: FAIL (handler undefined)

- [ ] **Step 3: Implement `RequestDeviceLockAccess` in `auth_controller.go`**

Bind `{conflict_token string, reason string}` from the body; trim
`reason` and `fiber.NewError(400, "Alasan wajib diisi")` if empty (Review
Focus: empty reason); call
`a.DeviceLockService.CreateAccessRequest(c, req.ConflictToken,
reason)`; a verification failure inside that call (bad/expired token)
should surface as `fiber.NewError(400, "Pengajuan tidak valid atau sudah
kedaluwarsa")` — thread this via `errors.Is`/a sentinel error from Task
3's `verifyConflictToken`, not string-matching. On success, `return
c.Status(200).JSON(response.NewSuccess(200, "Pengajuan terkirim, menunggu
persetujuan admin.", nil))`.

- [ ] **Step 4: Register the route in `src/router/router.go`**

Next to `app.Post("/api-auth/mobile/device-recovery", ...)`:
`app.Post("/api-auth/device-lock/access-requests",
authController.RequestDeviceLockAccess)`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `go test ./src/controller/... -run TestRequestDeviceLockAccess -v`
Expected: PASS

- [ ] **Step 6: `go build ./...` to confirm the router wiring compiles**

- [ ] **Step 7: Commit**

```bash
git add src/controller/auth_controller.go src/router/router.go
git commit -m "feat(device-lock): public endpoint for mobile access requests"
```

---

## Task 6: Admin list/approve/reject endpoints

**Files:**
- Modify: `src/controller/shared/app_access_controller.go`
- Modify: `src/router/shared/app_access_router.go`
- Test: `src/controller/shared/app_access_device_lock_requests_test.go` (new)

**Interfaces:**
- Consumes: `DeviceLockService.ListAccessRequests` /
  `ApproveAccessRequest` / `RejectAccessRequest` (Task 3),
  `AppAccessService.IsGlobalAdmin` (existing).
- Produces: `AppAccessController.ListDeviceLockRequests`,
  `ApproveDeviceLockRequest`, `RejectDeviceLockRequest`, routed at `GET
  /api-admin/device-lock-requests`, `POST
  /api-admin/device-lock-requests/:id/approve`, `POST
  /api-admin/device-lock-requests/:id/reject`.

This package has no existing tests, so the fake services below are new
infrastructure this task creates, not something to extend.

- [ ] **Step 1: Write a `fakeAppAccessService` and `fakeDeviceLockService` for this package, plus the failing tests**

`fakeAppAccessService` implements every method of
`service/shared.AppAccessService` (copy the exact method list from that
interface) as a one-line zero-value stub, except `IsGlobalAdmin`, which
returns a field you set per test (`isAdmin bool`).
`fakeDeviceLockService` here only needs
`ListAccessRequests`/`ApproveAccessRequest`/`RejectAccessRequest`
controllable (plus every other `DeviceLockService` method stubbed to its
zero value, same approach as `auth_device_lock_test.go`'s fake).

```go
func TestListDeviceLockRequests_RequiresAdmin(t *testing.T) {
	// isAdmin: false -> assert status 403, ListAccessRequests never called
}

func TestListDeviceLockRequests_ReturnsRows(t *testing.T) {
	// isAdmin: true, fake returns 2 rows -> assert status 200, body has 2 items
}

func TestApproveDeviceLockRequest_RejectsIfLockMovedOn(t *testing.T) {
	// fake.ApproveAccessRequest returns the "Lock sudah berubah..." fiber.Error
	// from Task 3 -> assert it reaches the client as a 409, not swallowed
}
```

Every test needs `c.Locals("user_id", "<id>")` set — add a tiny
middleware in the test's `fiber.New()` setup that sets it before the
route, matching how `middleware.Auth()` does it for real requests.

- [ ] **Step 2: Run tests to verify they fail**

Run: `go test ./src/controller/shared/... -run DeviceLockRequest -v`
Expected: FAIL (handlers undefined)

- [ ] **Step 3: Implement the three handlers in `app_access_controller.go`**

Each starts with `if _, err := a.requireGlobalAdmin(c); err != nil {
return err }`, same as `ListDeviceLocks`/`RemoveDeviceLock`.
`ApproveDeviceLockRequest`/`RejectDeviceLockRequest` parse `:id` via
`strconv.ParseUint` (400 on failure, matching `RemoveDeviceLock`'s
style), then call the matching service method with `(requestID,
adminUserID)` where `adminUserID` is `requireGlobalAdmin`'s own return
value.

- [ ] **Step 4: Register the three routes in `src/router/shared/app_access_router.go`**

Next to the existing `device-lock-exemptions` lines:

```go
admin.Get("/device-lock-requests", controller.ListDeviceLockRequests)
admin.Post("/device-lock-requests/:id/approve", controller.ApproveDeviceLockRequest)
admin.Post("/device-lock-requests/:id/reject", controller.RejectDeviceLockRequest)
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `go test ./src/controller/shared/... -v`
Expected: PASS

- [ ] **Step 6: `go build ./...`**

- [ ] **Step 7: Commit**

```bash
git add src/controller/shared/app_access_controller.go src/router/shared/app_access_router.go src/controller/shared/app_access_device_lock_requests_test.go
git commit -m "feat(device-lock): admin list/approve/reject access requests"
```

---

## Task 7: Mobile — surface the conflict token and submit the request

**Files:**
- Modify: `lib/services/geu/geu_auth_service.dart`
- Create: `lib/services/geu/device_lock_request_service.dart`
- Test: `test/geu_auth_service_test.dart` (new)

**Interfaces:**
- Produces: `class DeviceLockConflictException implements Exception {
  final String message; final String conflictToken; ... @override
  String toString() => message; }` (so every existing
  `e.toString().contains(...)` check in `login_screen.dart` keeps
  matching unchanged); `DeviceLockRequestService.submit(String
  conflictToken, String reason) async`.

- [ ] **Step 1: Write the failing test for the pure extraction helper**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:one_link/services/geu/geu_auth_service.dart';

void main() {
  group('GeuAuthService.conflictTokenFrom', () {
    test('extracts the token when present', () {
      final token = GeuAuthService.conflictTokenFrom({
        'errors': {'conflict_token': 'tok-123'},
      });
      expect(token, 'tok-123');
    });

    test('returns null when absent', () {
      expect(GeuAuthService.conflictTokenFrom({'message': 'Invalid credentials'}), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/geu_auth_service_test.dart`
Expected: FAIL (`conflictTokenFrom` undefined)

- [ ] **Step 3: Implement in `geu_auth_service.dart`**

```dart
static String? conflictTokenFrom(Map<String, dynamic> body) =>
    (body['errors'] as Map?)?['conflict_token'] as String?;
```

Add `DeviceLockConflictException` (top-level class in the same file, or
a tiny new `device_lock_models.dart` if this file already imports enough
models elsewhere — follow whatever this file already does for small
exception types). In `login()`, where it currently does `if
(body['status'] != 'success') { throw Exception(body['message'] ??
'Login gagal'); }`, extract the message, call `conflictTokenFrom(body)`,
and `throw DeviceLockConflictException(message, token)` when a non-empty
token is present, else keep the existing plain `throw
Exception(message)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/geu_auth_service_test.dart`
Expected: PASS

- [ ] **Step 5: Write `lib/services/geu/device_lock_request_service.dart`**

Follow the `GeuApiClient.instance` + `_unwrap`-style pattern other
`services/geu/*.dart` files use (see `visit_sync_service.dart` for the
shape): `static Future<void> submit(String conflictToken, String reason)
async` posts `{conflict_token: conflictToken, reason: reason}` to
`/api-auth/device-lock/access-requests`, throws `Exception(body['message']
?? 'Gagal mengirim pengajuan')` on a non-success body.

- [ ] **Step 6: `flutter analyze lib/services/geu/geu_auth_service.dart lib/services/geu/device_lock_request_service.dart`**

Expected: no new errors.

- [ ] **Step 7: Commit**

```bash
git add lib/services/geu/geu_auth_service.dart lib/services/geu/device_lock_request_service.dart test/geu_auth_service_test.dart
git commit -m "feat(device-lock): surface conflict token and add request-access service"
```

---

## Task 8: Mobile — "Ajukan Akses" button and reason sheet

**Files:**
- Modify: `lib/screens/login_screen.dart`

**Interfaces:**
- Consumes: `DeviceLockConflictException`, `DeviceLockRequestService.submit`
  (Task 7).

- [ ] **Step 1: Add the import and update `_handleLogin`'s catch block**

Add `import '../services/geu/device_lock_request_service.dart';`. Where
the catch block currently always shows a plain `SnackBar`, branch: if `e
is DeviceLockConflictException`, show a `SnackBar` with the same
`_friendlyLoginError(e)` text (unchanged — `toString()` still returns the
original message) plus a `SnackBarAction(label: 'Ajukan Akses', onPressed:
() => _showRequestAccessSheet(e.conflictToken))`; otherwise, the existing
plain SnackBar.

- [ ] **Step 2: Add `_showRequestAccessSheet(String conflictToken)`**

A `showModalBottomSheet` with: a required multi-line `TextFormField` for
the reason, a submit button that calls
`DeviceLockRequestService.submit(conflictToken, reasonController.text.trim())`
inside a try/catch, shows a confirming `SnackBar` ("Pengajuan terkirim,
menunggu persetujuan admin.") and closes the sheet on success, or an
error `SnackBar` with the caught exception's message on failure. Disable
the submit button while the field is empty/whitespace-only (client-side
convenience only — Task 5 already enforces this server-side).

- [ ] **Step 3: `flutter analyze lib/screens/login_screen.dart`**

Expected: no new errors.

- [ ] **Step 4: Manual check**

Run the app (`flutter run`), trigger a device-lock conflict (log in from
a second device/emulator while the first is still locked), confirm the
button appears, the sheet opens, and a submission reaches the backend
(check the admin list from Task 9, or the server log, for the new
pending row).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/login_screen.dart
git commit -m "feat(device-lock): Ajukan Akses button on the login screen"
```

---

## Task 9: geu-onelogin — admin API client functions

**Files:**
- Modify: `lib/admin.ts`

**Interfaces:**
- Produces: `export type DeviceLockRequest = { id: number; user_id:
  number; name: string; email: string; device_id: string; user_agent:
  string; reason: string; status: string; created_at: string }`;
  `admin.listDeviceLockRequests(): Promise<DeviceLockRequest[]>`;
  `admin.approveDeviceLockRequest(id: number): Promise<void>`;
  `admin.rejectDeviceLockRequest(id: number): Promise<void>`.

- [ ] **Step 1: Add the type and three functions**

Same shape as the existing `DeviceLockExemption` type and
`listDeviceLockExemptions`/`addDeviceLockExemption` functions a few lines
above — `call<T>("/api/admin/device-lock-requests")` for the list (note:
`/api/admin/...`, proxied by the existing `app/api/admin/[...path]/route.ts`
catch-all to `/api-admin/...` — no new Next.js route needed), and `call<void>`
with `{ method: "POST" }` for approve/reject.

- [ ] **Step 2: `npx tsc --noEmit -p .`**

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/admin.ts
git commit -m "feat(device-lock): admin client functions for access requests"
```

---

## Task 10: geu-onelogin — "Pengajuan Akses" section

**Files:**
- Modify: `app/admin/device-lock/page.tsx`

**Interfaces:**
- Consumes: `admin.listDeviceLockRequests`, `admin.approveDeviceLockRequest`,
  `admin.rejectDeviceLockRequest` (Task 9), the existing `describeDevice`
  helper already in this file.

- [ ] **Step 1: Add state and a loader, mirroring the Exemptions section**

```tsx
const [requests, setRequests] = useState<DeviceLockRequest[]>([]);
const loadRequests = () => {
  admin.listDeviceLockRequests().then(setRequests).catch(() => {});
};
useEffect(() => {
  if (!checking) loadRequests();
}, [checking]);
```

- [ ] **Step 2: Add approve/reject handlers**

```tsx
const decideRequest = async (req: DeviceLockRequest, approve: boolean) => {
  const key = `request-${req.id}`;
  setBusyKey(key);
  setError("");
  try {
    await (approve ? admin.approveDeviceLockRequest(req.id) : admin.rejectDeviceLockRequest(req.id));
    loadRequests();
  } catch (e) {
    setError(e instanceof Error ? e.message : "Gagal memproses pengajuan.");
  } finally {
    setBusyKey(null);
  }
};
```

- [ ] **Step 3: Render the section**

A card per pending request: name, email, `describeDevice(req.user_agent,
"mobile")`, the reason text, `formatWIB(req.created_at)`, and two
buttons ("Setujui" / "Tolak") calling `decideRequest(req, true/false)`,
disabled while `busyKey === \`request-${req.id}\``. Same visual card
style as the Exemptions list a few lines below it in this file — mirror
its JSX structure rather than inventing a new one. Reuse the "no admin
lookup needed" requirement directly: every field the admin needs is
already on `req`, nothing links out to a separate user search.

- [ ] **Step 4: `npx tsc --noEmit -p .` and a manual check**

Run `npm run dev`, open `/admin/device-lock`, confirm the new section
renders (empty state is fine if there are no pending requests yet), and
— once Task 8's mobile flow has produced a real pending row — that
approving it actually clears/repoints the driver's lock (cross-check
against the `device_locks` row in the DB, or have the driver retry
login).

- [ ] **Step 5: Commit**

```bash
git add app/admin/device-lock/page.tsx
git commit -m "feat(device-lock): admin UI for access requests"
```

---

## Self-Review Notes

- **Spec coverage:** every section of the design doc maps to a task —
  data model (Task 1), conflict-token approach (Tasks 3-4), mobile
  submission (Tasks 5, 7-8), admin list/approve/reject (Tasks 6, 9-10),
  the three "my call" refinements (resubmission-overwrites: Task 3 step
  7; stale-lock rejection: Task 3 step 7 + Task 6 step 1's test; no
  cleanup job: nothing to build, confirmed absent).
- **Review Focus coverage:** garbage/expired token (Task 3's
  `verifyConflictToken` tests for the token itself, Task 5's
  `TestRequestDeviceLockAccess_RejectsBadToken` for the endpoint
  surfacing that as a clean 400); same-device resubmission (Task 3's
  `CreateAccessRequest` tests, if a DB test harness exists per step 6's
  conditional); stale-lock approval (Task 6's
  `TestApproveDeviceLockRequest_RejectsIfLockMovedOn`); empty reason
  (Task 5's `TestRequestDeviceLockAccess_RejectsEmptyReason`); unchanged
  message for old clients (Task 4's test asserts the message string
  directly).
