# LATAM Barcode Food Lookup Design

**Status:** Accepted (pending user review of this file)
**Date:** 2026-08-12
**Scope:** Flutter nutrition feature — barcode resolution only (Open Food Facts + group cache)

## Context

Enfermicambio already has:

- `mobile_scanner` barcode camera UI (`BarcodeScanScreen`)
- `OpenFoodFactsRepository` calling `world.openfoodfacts.org/api/v2/product/{barcode}`
- REGISTRAR tab wiring scan → resolve → meal dialog / custom-food dialog
- Supabase table `public.foods` with unique `barcode`

Gaps for LATAM/Chile-first use:

- No Spanish language preference on OFF requests
- No User-Agent (Open Food Facts etiquette / contact)
- No preference for `product_name_es` / regional names
- No group cache read/write path in the client
- RLS on `foods` is select-only; authenticated users cannot insert/upsert cache rows
- Custom food UI does not persist to `foods`
- Meal log dialog does not write `food_entries` (explicitly out of this slice)

Product constraints from `SPECS.md` / `CODESTYLE.md`:

- Open Food Facts first
- Private group cache next
- No paid nutrition API without a proven gap
- USDA deferred
- Manual food creation allowed; manual steps never allowed

## Goals

- Resolve packaged-food barcodes quickly for Chile/LATAM products when OFF has them.
- Prefer Spanish product naming when OFF provides it.
- Cascade: OFF → group `foods` cache → not-found → create custom food.
- Cache successful OFF hits into `foods` so later scans (any of the four users) hit the group first path after the first success.
- Persist custom foods created from unknown barcodes into `foods` so the second group scan reuses them.
- Keep external failures recoverable: timeout, network, malformed, not-found never crash the tab; custom creation remains available.
- Cover the cascade and OFF edge cases with unit tests.

## Non-goals

- Persisting meal logs to `food_entries` (portion → save entry).
- USDA fallback.
- Separate `cl.openfoodfacts.org` host (same dataset, extra latency).
- Text food search UI.
- Meal photos.
- Nutritionix / FatSecret / any paid API.
- Changing ranking, points, or step rules.

## Architecture

```
BarcodeScanScreen / manual barcode
        │
        ▼
 FoodLookupService.resolve(barcode)
        │
        ├─1─ normalize + validate barcode
        │
        ├─2─ OpenFoodFactsRepository.resolveByBarcode
        │       hit → FoodsRepository.upsertFromResolved (best effort)
        │       return Food(source: 'off')
        │
        ├─3─ FoodsRepository.findByBarcode
        │       hit → return Food(source: cached source, typically 'group' or 'off')
        │
        └─4─ throw FoodLookupFailure.notFound
                UI offers “Crear alimento”
                → FoodsRepository.insertCustom(...)
```

### Components

| Unit | Responsibility | Depends on |
|------|----------------|------------|
| `FoodLookupService` | Orchestrate cascade; single entry for UI | OFF repo, foods repo |
| `OpenFoodFactsRepository` | HTTP to OFF v2 product endpoint; map nutriments → `Food` | `http.Client` |
| `FoodsRepository` (Supabase) | `findByBarcode`, `upsertFromResolved`, `insertCustom` | Supabase client |
| `RegisterTab` | Scan UI, loading, errors ES, meal dialog (no entry save), custom create → cache | `FoodLookupService` |
| Migration (RLS) | Allow allowlisted users to insert/update `foods` | Postgres |

UI must not call OFF or Supabase foods tables directly except through the service/repos above.

## Open Food Facts contract

- **URL:** `https://world.openfoodfacts.org/api/v2/product/{barcode}.json`
- **Query:**
  - `lc=es` (Spanish preference for localized fields)
  - `fields=product_name,product_name_es,product_name_en,brands,nutriments,serving_size,serving_quantity,quantity`
- **Headers:**
  - `User-Agent: Enfermicambio/1.0 (private four-user app; contact via app repo)`
  - `Accept: application/json`
- **Timeout:** 8 seconds (existing default)
- **Name selection order:** `product_name_es` → `product_name` → `product_name_en`; blank after trim → malformed
- **Nutrition mapping (unchanged priority):**
  - Prefer `*_serving` nutriment keys when present
  - Else `*_100g`
  - Calories from `energy-kcal_serving` / `energy-kcal_100g`
  - Serving size: `serving_quantity` or default `100`; unit `serving_quantity_unit` or `g`
- **Status handling:**
  - HTTP non-200 → `network`
  - JSON parse fail / missing product object / blank name → `malformed`
  - `status != 1` → `notFound`
  - Client timeout / transport exception → `timeout`
- **Source string on `Food`:** `'off'`

No scraping. One real user scan = one product request. Full DB dumps are out of scope.

## Group cache (`public.foods`)

Existing columns (no schema change required beyond RLS):

- `id`, `barcode`, `name`, `brand`, `serving_size`, `serving_unit`, `calories`, `protein_g`, `carbs_g`, `fat_g`, `source`, `created_by`, `created_at`
- `unique(barcode)` — nullable barcodes allowed for non-barcode customs without collision if barcode is null

### Repository behavior

1. **`findByBarcode(barcode)`**  
   Select one row where `barcode` equals normalized value. Map to `Food` with `id` set and `source` from row.

2. **`upsertFromResolved(food, {createdBy})`**  
   Best-effort after OFF hit. Upsert on `barcode` with `source = 'off'`. Failures are logged/swallowed by the lookup service so a cache write failure never blocks showing the resolved product.

3. **`insertCustom({...})`**  
   Insert with `source = 'group'`, optional barcode from the failed scan, `created_by = current user`. On unique barcode conflict, return the existing row instead of failing hard (second user creating the same code).

### RLS (migration required)

Current state: only `foods_select_for_allowlisted`.

Add:

- `foods_insert_for_allowlisted`: `authenticated` + `is_allowlisted_user()`; `with check` same; optional `created_by = auth.uid()` when provided.
- `foods_update_for_allowlisted`: allowlisted users may update any food row (group shared catalog; four fixed users). Needed for OFF upsert refresh of nutrition/name.

Grants: `insert, update` on `public.foods` to `authenticated` (select already granted).

No delete policy in this slice.

## Barcode normalization

Before any network/DB call:

- Trim whitespace
- Keep digits only for lookup key (EAN/UPC); reject empty or non-digit-only after strip if length not in `{8, 12, 13, 14}` → treat as invalid and surface a Spanish validation message without calling OFF
- Do not invent check digits; pass through valid-length digit strings as-is

## UI changes (REGISTRAR + scanner)

- All user-visible strings for this flow in Spanish (scanner title, hints, errors, loading).
- While resolving: non-blocking loading indicator (dialog or overlay).
- `notFound` → existing create-custom dialog; on confirm, **persist** via `insertCustom`, then show success snackbar.
- `timeout` / `network` / `malformed` → snackbar explaining failure; offer retry and/or create custom with the scanned barcode prefilled.
- Meal dialog after successful resolve: keep current portion UI; **do not** write `food_entries` in this slice (snackbar-only remains acceptable for “Guardar Comida” until the next nutrition slice).
- No step-entry control anywhere.

## Error handling summary

| Condition | Result |
|-----------|--------|
| Invalid barcode shape | UI validation; no API call |
| OFF hit | Return food; best-effort cache upsert |
| OFF notFound | Try group cache |
| OFF timeout/network/malformed | Try group cache; if miss, surface that failure (prefer network/timeout message over notFound) |
| Cache hit | Return food |
| Cache miss after OFF miss | notFound → create custom |
| Cache upsert fails | Ignore; still return OFF food |
| Custom insert unique conflict | Return existing food |

## Testing

Unit tests (no device camera required):

1. OFF resolves with Spanish name preference when `product_name_es` present.
2. OFF notFound / timeout / malformed (existing cases kept).
3. `FoodLookupService`: OFF hit returns OFF food and attempts upsert.
4. `FoodLookupService`: OFF notFound + cache hit returns cache food.
5. `FoodLookupService`: OFF notFound + cache miss → notFound.
6. `FoodLookupService`: OFF network failure + cache hit returns cache food.
7. Barcode normalization rejects garbage; accepts 13-digit EAN.

Optional: repository mapping test for Supabase row → `Food` with a fake client if pattern exists elsewhere; otherwise keep foods repo thin and cover via service fakes.

## Acceptance criteria

- Scanning a known OFF product shows name (Spanish when available), brand, and per-serving macros.
- Scanning an unknown product with a prior group custom row returns that row without requiring OFF success.
- First OFF success for a barcode leaves a `foods` row (when online and RLS allows) so a later resolve can use cache if OFF is down.
- Creating a custom food from an unknown barcode inserts into `foods` with that barcode.
- API outage does not block opening the custom-food dialog.
- No `food_entries` writes and no paid APIs introduced.
- `flutter test` covers the cases above; `flutter analyze` clean on touched files.

## Rollout notes

- Private four-user app: User-Agent identifies the app; volume is negligible.
- Chile coverage depends on OFF community data; group cache + custom create closes gaps for local brands the four users actually buy.

## Open decisions (resolved)

- Host: world only (not cl mirror).
- Post-OFF miss: group cache only (no USDA this slice).
- Persist custom + OFF cache into `foods`: yes.
- Persist meal entries: no (next slice).
