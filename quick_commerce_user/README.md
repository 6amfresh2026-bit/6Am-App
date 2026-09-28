# Suvio Quick — user app

A premium quick-commerce Flutter app for **Suvio Quick**, built against the
existing Node/Express + MongoDB backend that ships in
`backend/quick-commerce/Backend`.

Every screen reads and writes real data. There is no mock repository, no
hardcoded catalog, and no fabricated endpoint.

---

## Connecting to the Existing Backend

The app ships pointing at the hosted backend, so a plain `flutter run` works
with no configuration:

```
https://6amfresh.in/api/v1
```

Per `backend/quick-commerce/FLUTTER_API_SPEC.md` the base is `{HOST}/api/v1`
and every route is written as `/food/...` on top of it — the `/v1` segment
belongs in the base URL, never in the paths. `AppConfig` asserts this in debug,
because a base missing `/v1` 404s every call silently at runtime.

### 1. Running against a local backend instead

The backend is not part of this Flutter project and is **not** modified by it.
Start it with its own existing instructions, from
`backend/quick-commerce/Backend`:

```bash
cd backend/quick-commerce/Backend
npm run dev        # or: npm start
```

It listens on `PORT` from its `.env` (default **5000**) and mounts everything
under `/api`, versioned to `/api/v1` (`src/app.js` → `src/routes/index.js`).
Confirm it is up:

```bash
curl http://localhost:5000/api/v1/health
# {"status":"UP","message":"Server is healthy"}
```

### 2. Pointing the app somewhere else

The base URL is a compile-time define, so one binary serves every environment.
It must include the `/api/v1` suffix.

```bash
# Hosted backend — this is the default, no define needed
flutter run

# Android emulator (10.0.2.2 is the host machine from inside the emulator)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api/v1

# iOS simulator / macOS / web
flutter run --dart-define=API_BASE_URL=http://localhost:5000/api/v1

# Physical device on the same Wi-Fi — use your machine's LAN IP
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5000/api/v1

# Production build (disables request logging)
flutter build apk --dart-define=APP_ENV=production
```

Defaults live in `lib/core/config/app_config.dart`: `API_BASE_URL` falls back to
`https://6amfresh.in/api/v1` and `APP_ENV` to `development` (which enables
request logging).

### 3. Sign in

Login is phone + OTP against the real endpoints
(`POST /api/v1/food/auth/user/request-otp` → `/verify-otp`). Outside production
the backend echoes the OTP in its response; the app shows it on the OTP screen
as a test-environment hint so you do not have to read server logs.

The returned JWT is stored via `LocalStorage` and attached as
`Authorization: Bearer <token>` by the Dio interceptor. A 401 triggers one
transparent refresh-and-retry through `POST /food/auth/refresh-token`; if that
fails the session is cleared.

### Endpoints this app calls

Every path is declared in one place —
`lib/data/repository_impl/api_paths.dart` — and each was verified against the
backend's route files and controllers.

| Area | Endpoint |
|---|---|
| Auth | `POST /food/auth/user/request-otp`, `/verify-otp`, `/refresh-token`, `/logout`, `GET /food/auth/me` |
| Profile & wallet | `GET·PATCH·DELETE /food/user/profile`, `GET /food/user/wallet` |
| Addresses | `GET·POST /food/user/addresses`, `PATCH·DELETE /food/user/addresses/:id`, `PATCH /food/user/addresses/:id/default` |
| Wishlist | `GET /food/user/favorites`, `POST·DELETE /food/user/favorites/foods/:id` |
| Cart mirror | `PUT /food/user/cart` |
| Catalog | `GET /food/search/products`, `GET /food/restaurant/restaurants/:id/menu`, `GET /food/restaurant/restaurants/:id/addons` |
| Categories | `GET /food/search/categories/admin` |
| Offers | `GET /food/restaurant/offers` |
| Banners | `GET /food/hero-banners/public`, `/top-banners/public`, `/hero-banners/home-promotion/public` |
| Fees | `GET /food/admin/fee-settings/public` |
| Pricing | `POST /food/orders/calculate` |
| Orders | `POST /food/orders`, `POST /food/orders/verify-payment`, `GET /food/orders`, `GET /food/orders/:id`, `/route`, `/drop-otp`, `PATCH /:id/cancel`, `/ratings`, `/instructions`, `DELETE /:id/pending-payment` |
| Notifications | `GET /food/notifications/inbox`, `PATCH /:id/read`, `DELETE /:id` |
| Support | `POST /food/user/support/ticket` |

**Pricing is server-owned.** `POST /food/orders/calculate` is the only source of
subtotal, delivery fee, platform fee, GST, discount and total. The app displays
exactly what it returns and echoes the same `pricing` object back on
`POST /food/orders`. `CartPricingService` arranges those numbers for display and
owns cart-mutation logic; it never invents a fee.

---

## Backend Gaps

Features this app needs that the existing backend does not expose. None are
silently mocked — each is either derived from real data (and says so in the
code) or degrades visibly.

| Gap | What the backend has | What the app does |
|---|---|---|
| **No single-product endpoint** | Items appear only inside `/search/products` (paginated) or `/restaurants/:id/menu` | `ApiProductRepository.getById` reads the seller's menu when the seller is known, else scans the paginated catalog. A cold deep link to `/product/:id` costs extra requests. |
| **No brand resource** | `brand` is a free-text field on each item | Brands are derived from distinct `brand` values by `CatalogGroupingService`. The "logo" is a representative product image. |
| **No sub-category tree** | Categories are flat | The sub-category rail is derived from the brands present within a category. |
| **No product reviews** | Ratings exist only inside `order.ratings.items[]` on a delivered order | `ApiReviewRepository` assembles reviews from the signed-in user's own order history and writes via `PATCH /orders/:id/ratings`. A customer therefore sees their own reviews, not everyone's. |
| **No merchandising sections** | No trending / best-seller / flash-sale endpoints | Home sections are ranked client-side from a fetched catalog page by `CatalogGroupingService`. |
| **No free-delivery threshold** | Fees are banded by *distance*, not order value | The cart's "add ₹X more" nudge uses a zero-fee distance band when one exists, else a 199 default. The real fee always comes from the pricing call. |
| **`DELETE /notifications/inbox/all` is shadowed** | `DELETE /:id` is registered first, so `/inbox/all` fails ObjectId validation | "Mark all read" issues one `PATCH /:id/read` per unread item. |
| **Catalog surfaces disagree** | `/restaurant/public/foods` omits `mrp`/`stockQty`/`brand`/`packSize`; `/search/products` includes them | The app uses `/search/products` everywhere, since it is the only surface with MRP, stock and pagination. |
| **No ingredients / nutrition fields** | Only a free-text `description` | Product details shows a "Product details" panel built from real attributes (brand, pack size, category, veg status) rather than inventing nutrition tables. |
| **No profile image upload wired** | `POST /food/user/profile/profile-image` exists but needs multipart file picking | The avatar picker shows an explicit "coming soon" message instead of a broken control. |
| **Payment gateway is simulated** | Real `/orders` and `/verify-payment` endpoints exist | Per the scope contract no payment SDK is embedded. The app creates the order for real, shows a processing animation, then calls the real `verify-payment`. A signature rejection from a live gateway is surfaced honestly with a retry. |
| **Maps / geolocation are simulated** | — | `SimulatedLocationService` returns a fixed serviceable coordinate and the map is a branded illustration. Both sit behind interfaces (`LocationService`, `PermissionService`), so swapping in `geolocator` touches one class. |

---

## Architecture

Strict one-directional layering, enforced by the import graph:

```
UI  →  Domain  →  Data  →  Platform / Backend
```

- **Domain** is pure Dart. No Flutter, no Riverpod, no Dio, no JSON.
- **Data** implements Domain's repository interfaces and owns every DTO,
  mapper and HTTP call. It never imports a widget.
- **UI** depends only on Domain models and providers.
- **DI** (`lib/di/`) binds interfaces to their API implementations, all built
  from a single `DioApiClient`.

```
lib/
├── core/        constants, config, theme, network, errors, utils, storage
├── domain/      model, repository (interfaces), service, usecase, validator
├── data/        dto, mapper, repository_impl
├── platform/    location, notification, permission
├── di/          repository / service / usecase providers + global app state
├── navigation/  go_router config and route paths
└── ui/          common widgets + one folder per screen
```

Each screen folder follows `x_screen.dart` / `x_provider.dart` /
`x_state.dart` / `widgets/`.

### Design system

- **Palette:** Suvio Green `#0E7C66` with citrus accent `#FFB020`. Two
  alternates ship and are switchable in Settings: Suvio Indigo `#4338CA` /
  `#FF7A59`, and Suvio Sunset `#E0533D` / `#1F9C8A`. The choice persists.
- **Type:** Manrope via `google_fonts`, applied as a full named scale
  (`app_text_styles.dart`) plus use-case styles — price with tabular figures,
  strikethrough MRP, badge label, section header.
- **Spacing:** 8pt scale (`2/4/8/12/16/24/32/48`). No raw padding numbers in
  widget code.
- **Radii & elevation:** one scale (`sm/md/lg/xl/pill`) and three shadow tokens
  (card, sheet, floating), exposed through a `ThemeExtension`.
- **Light and dark** are both hand-tuned — dark surfaces step *up* in lightness
  from the background so cards stay legible without heavy shadows.

---

## Google Maps

One key, one file. `config/keys.env` (gitignored) is the single source; three
build systems read it, so the key text appears in the repo exactly zero times.

```
config/keys.env
├─ Android → app/build.gradle.kts → manifestPlaceholders → AndroidManifest.xml
├─ iOS     → tool/generate_ios_keys.sh → Flutter/Keys.xcconfig → Info.plist → AppDelegate
└─ Dart    → --dart-define-from-file → AppConfig.mapsApiKey (Places + Geocoding REST)
```

### Setup

```bash
cp config/keys.example.env config/keys.env   # then paste your key into it
./tool/generate_ios_keys.sh                  # iOS only, re-run after any key change
flutter run --dart-define-from-file=config/keys.env
```

For the admin panel, put the **same** key in
`backend/quick-commerce/Frontend/.env` as `VITE_GOOGLE_MAPS_API_KEY`, and read
it through `ENV.GOOGLE_MAPS_API_KEY` from `src/config/env.js` — never
`import.meta.env` directly.

### APIs that must be enabled

| API | Used by |
|---|---|
| Maps SDK for Android / iOS | The map on address selection and order tracking |
| Places API | Address autocomplete |
| Geocoding API | Map pin → postal address, and current location → address |
| Maps JavaScript API + Directions API | Admin panel live tracking |

Billing must be active on the project, or every call returns `REQUEST_DENIED`
and the map renders blank.

### Key restriction

The Android key must be restricted to package `com.sixamfreshuser.app` plus your
signing SHA-1; the iOS key to bundle id `com.sixamfreshuser.app`. Both were renamed
from the Flutter defaults to match `google-services.json`.

### Degrading without a key

`AppConfig.hasMapsKey` is false when the key is missing or still the template
placeholder. In that state the app falls back to the illustrated map and hides
the search field, rather than showing a blank grey tile that looks like a bug.

---

## Running the tests

```bash
flutter test
```

`test/domain_test.dart` covers the logic that would silently corrupt a bill or a
cart: line merging and identity, stock and per-order caps, seller conflicts,
savings, coupon eligibility and caps, search ranking, the backend's three
pagination envelopes and loose JSON types, and Indian currency grouping.

---

## Verification checklist

- `flutter analyze` — no issues.
- `flutter test` — 26 tests, all passing.
- `flutter build web --release` — builds clean.
- Every network call maps to an endpoint verified in the backend source; the
  full list is in `api_paths.dart`.
- Public paths verified live against `https://6amfresh.in/api/v1`:
  `/health`, `/food/admin/business-settings/public`,
  `/food/admin/fee-settings/public`, `/food/search/products`,
  `/food/search/categories/admin`, `/food/hero-banners/public`,
  `/food/top-banners/public`, `/food/hero-banners/home-promotion/public`,
  `/food/restaurant/offers`, `/food/restaurant/restaurants` — all 200.
  Authed paths answer 401 rather than 404, confirming they exist and are
  mounted where the app expects them. The live `/food/search/products` payload
  matches `ProductDto` field for field.
- Loading (shimmer skeletons shaped like their content), empty (tailored copy),
  error (typed `Failure` plus a working retry) and content states on every
  screen that fetches.
- Light and dark both checked, including card elevation and contrast.
- All 33 screens are reachable through real UI from Splash — no orphans.
