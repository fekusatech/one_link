# Device-Lock Access Request

## Intent / Why

When a driver's account is already locked to another device
(`device_locks`, one row per `(user_id, platform)`, 24h expiry), login
shows a flat string: "Akun sedang aktif di perangkat lain sampai ... ".
Today the only way out is an admin manually clearing the lock (WA'd by
the driver) or an NFC recovery card issued ahead of time by an admin.
Both require the admin to go find the right user first.

This adds a self-service request: the driver submits a reason right
from the error screen, an admin sees it with full context already
attached (name, email, device, reason — no lookup needed) and approves
or rejects with one tap.

## Goals

- "Ajukan Akses" button appears on the mobile device-lock error.
- Driver submits a reason; request is stored with their identity,
  device, and reason attached — no manual admin lookup needed to act on it.
- Admin list in geu-onelogin shows pending requests with everything
  needed to decide, approve/reject inline.
- Approving deterministically hands the lock to the device that asked
  for it (no race with whichever device logs in first).

## Non-goals

- Not replacing the existing "Cabut kunci" (manual clear) or NFC
  recovery card flows — this is a third, additional path.
- Not covering the `web` platform lock — only `mobile`, matching what
  the user actually hit.
- No push notification to admins on new requests, and no polling/
  realtime status back to the driver's app — they just try logging in
  again once they expect it's been handled.

## Anti-goals

- Admin still has to search for the user elsewhere before acting —
  defeats the entire point.
- Two devices can end up both racing for the lock after an approval.
- The temporary credential used to submit the request outlives or
  outscopes this one action.

## Constraints (from the existing codebase)

- `checkDeviceLock` (`auth_controller.go`) runs *after* password/OTP is
  already verified, in several login call sites — the backend already
  knows who the user is at the point it blocks them; no re-auth should
  be needed to submit a request.
- The current error is a bare string in a `fiber.NewError(409, ...)` —
  older installed app builds only read that string. Any response-shape
  change must keep that string in place and add new fields instead of
  replacing them.
- `device_locks` upsert logic (used by `EnforceAndLock`) is the existing
  mechanism for pointing the lock at a device; approval should reuse it
  rather than re-implement it.
- Admin endpoints under `/api-admin` here are gated by `middleware.Auth()`
  plus an in-controller admin check (see `RemoveDeviceLock`/
  `ListDeviceLocks` in `app_access_controller.go`) — not a route-level
  `RequirePermission`. Follow that same pattern, don't invent a new
  permission slug.
- geu-onelogin's admin API client (`lib/admin.ts`) is a thin typed
  `call<T>(path, {method, body})` per endpoint — new calls follow that
  shape.
- Next migration number is `080_...` (last is `079_cro_performance_permission.sql`).

## Approach (decided)

**Authenticating the request submission:** when `checkDeviceLock` blocks
a login, mint a short-lived (~10 min), single-purpose JWT ("conflict
token", new token type `device_lock_request`) embedding `user_id`,
`device_id`, `platform`. Return it alongside the unchanged error string.
The driver's "Ajukan Akses" call carries this token + their reason —
no password resent, no new session issued.

Rejected alternative: resending email+password to a new public endpoint
and re-verifying there. Simpler conceptually, but means the app holds
onto the password past the first attempt and duplicates login's
credential-check logic.

**What approval does:** writes directly into `device_locks` for
`(user_id, platform)` with `device_id` = the request's device, same
upsert the normal login path uses, `locked_until = now + 24h`. Not "just
clear and let whoever logs in first win."

## Data model

New table `device_lock_access_requests` (migration `080_...sql`):

| column | type | notes |
|---|---|---|
| id | PK | |
| user_id | bigint | |
| platform | varchar | always `mobile` for now |
| device_id | varchar | from the conflict token |
| user_agent | varchar | the device description string already sent by the app (see `device_identity_service.dart` — e.g. "OneLink-Mobile/2.2.17 (Android 14; SDK 34; samsung SM-G991B; id ...)"), stored at submit time so the admin list needs no extra join to describe the device |
| reason | text | required, from the driver |
| status | enum(pending, approved, rejected) | |
| reviewed_by | bigint, nullable | admin user id |
| reviewed_at | timestamp, nullable | |
| created_at, updated_at | timestamp | |

No DB-level "one pending per user" constraint — the create endpoint
checks for an existing pending row for that user first and returns it
instead of creating a duplicate (matches how the rest of this codebase
handles this kind of guard, in application code rather than a
constraint).

**Resubmission from a different device while a request is pending (my
call):** overwrite `device_id`/`user_agent`/`reason` on the existing
pending row rather than keeping the first one or creating a second. The
driver is standing at a specific device asking for access *now*; the
latest submission is the one that reflects reality, and a single row
per user keeps the admin list from showing stale duplicates.

**Approving a request whose underlying lock has moved on (my call):**
before the upsert, compare `device_locks.updated_at` for that user
against the request's `created_at`. If the lock row was touched *after*
the request was filed (the driver already got in some other way, or
filed again more recently — same mechanism doubles as the de-dup check
above), reject the approval attempt with a clear message instead of
silently overwriting a lock that's no longer the problem; don't treat
"always overwrite" as safe by default, since that recreates the exact
two-devices-fighting anti-goal this feature exists to avoid, just moved
to after admin action instead of before it.

**Stale pending requests (my call):** no scheduled cleanup job — YAGNI
until it's actually a problem. The staleness check above means a
request whose lock has already moved on fails cleanly if someone tries
to approve it; that's enough for now without building expiry/cron
machinery nobody's asked for yet.

## Backend (go-rest-api)

1. `checkDeviceLock` conflict path: alongside the existing
   `fiber.NewError(409, deviceLockMessage(...))`, mint the conflict
   token and return it in the response body under a new field — old app
   builds that only read `message` are unaffected.
2. `POST /api/device-lock/access-requests` — no `middleware.Auth()`
   (the conflict token *is* the credential here); body `{conflict_token,
   reason}`. Verifies the token's type/expiry, reuses an existing
   pending request for that user if one exists, otherwise creates one.
3. `GET /api-admin/device-lock-requests` — list (default: pending),
   joined to `s_users` for name/email so the admin payload is
   self-contained.
4. `POST /api-admin/device-lock-requests/:id/approve` — sets
   `status=approved`, `reviewed_by`, `reviewed_at`; upserts the
   `device_locks` row per the approach above.
5. `POST /api-admin/device-lock-requests/:id/reject` — sets
   `status=rejected`, `reviewed_by`, `reviewed_at`. No lock change.

## Mobile (crm-mobile)

1. `login_screen.dart`: where the device-lock string is currently
   detected and shown, also read the new conflict-token field off the
   response. If present, show an "Ajukan Akses" button next to the
   existing message.
2. Tapping it opens a small sheet: a required reason field + submit.
3. New `DeviceLockRequestService` (same `GeuApiClient` pattern as the
   rest of the app) posts `{conflict_token, reason}`.
4. On success: a confirmation message ("Pengajuan terkirim, menunggu
   persetujuan admin.") The driver just tries logging in again later —
   no in-app status polling (non-goal above).

## Admin UI (geu-onelogin)

New page (alongside `app/admin/device-lock/page.tsx`, same visual
pattern — card list, not a data table) listing each pending request's
name, email, device description string, reason, and requested-at, with
Approve / Reject buttons inline. New typed client functions in
`lib/admin.ts`: `listDeviceLockRequests()`,
`approveDeviceLockRequest(id)`, `rejectDeviceLockRequest(id)`.

## Left to the builder

- Exact admin-check helper to call from the two new admin endpoints —
  copy whatever `RemoveDeviceLock`/`ListDeviceLocks` already use.
- Exact JWT claim/signing helper to reuse for the conflict token (there
  is already a token-issuing utility in `utils/` for the real
  access/refresh tokens — follow its shape, new `TokenType` constant).
- Whether the new admin page is its own route or a second tab on the
  existing device-lock page — whichever reads cleaner against the
  current page's layout.
- Minor copy/styling to match geu-onelogin's existing conventions.
