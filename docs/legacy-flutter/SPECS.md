# SPECS.md — Private Fitness Competition App

**Status:** Product / Technical Specification  
**Version:** 0.1  
**Audience:** Product owner + developer(s)  
**App type:** Private, non-commercial mobile app for exactly 4 known users  
**Platforms:** iOS + Android  
**Initial device mix:** 2 iPhones + 2 Android phones  
**Primary stack:** Flutter + Supabase + Apple HealthKit + Android Health Connect

---

## 1. Product summary

This app is a **private social fitness game for four friends**.

It is not intended to be a commercial product, public social network, SaaS, marketplace, or app for arbitrary groups. The entire product can be optimized around exactly four known people.

The app combines:

- automatic health/activity data;
- step competitions;
- daily time-segment rankings;
- workouts;
- running/walking routes;
- calories and nutrition;
- meal logging;
- barcode food scanning;
- social posts and photos;
- reactions/comments;
- achievements;
- streaks;
- missions;
- seasons;
- trophies;
- private shared statistics.

The core idea is:

> **Real-world movement and nutrition become the input to a private game between four friends.**

The app should feel like a combination of:

- a step leaderboard;
- a private fitness dashboard;
- a lightweight Strava-style workout feed;
- a MyFitnessPal-style nutrition tracker;
- a private social feed;
- a game with missions, streaks, trophies and seasons.

---

# 2. Product principles

## 2.1 Exactly four users

The product is deliberately optimized for four fixed users.

There is no need for:

- public registration;
- group creation;
- invitation codes;
- searching for friends;
- public profiles;
- discovery;
- followers;
- moderation systems;
- billing;
- subscriptions;
- micropayments;
- virtual purchases;
- commercial scalability.

The four accounts can be pre-created or allowlisted.

---

## 2.2 Health data first, manual activity last

Physical activity data should be read automatically whenever possible.

For steps specifically:

- **manual step entry must not exist in the app;**
- manually entered steps from the health platform must not count when they can be identified;
- only automatic/device-recorded step data should contribute to rankings and achievements.

Supported sources may include:

### iOS

- iPhone;
- Apple Watch;
- other apps/devices that write valid automatic data into Apple Health / HealthKit.

### Android

- phone step sensor;
- Wear OS / compatible wearable;
- Samsung Health or other compatible sources when bridged through Health Connect;
- other automatic sources represented in Health Connect.

---

## 2.3 Everything is private to the four-person group

The app is private, but within the four-person group the default experience is highly transparent.

The other three users may see:

- steps;
- workout summaries;
- calories burned;
- distance;
- workout route when available;
- nutrition totals;
- meal posts;
- photos;
- achievements;
- streaks;
- rankings;
- seasonal score;
- social posts;
- comments and reactions.

There is no public web profile.

---

## 2.4 Social motivation over medical tracking

The app is not intended to diagnose, treat or provide medical advice.

It should frame data as:

- movement;
- activity;
- friendly competition;
- nutrition tracking;
- personal goals;
- social motivation.

Avoid medical interpretations.

---

# 3. Scope

## 3.1 In scope

### Activity

- automatic step synchronization;
- daily steps;
- morning steps;
- afternoon steps;
- night steps;
- daily total;
- active calories;
- distance;
- exercise minutes when available;
- workouts;
- workout duration;
- workout distance;
- workout calories;
- pace/speed when calculable;
- workout route when available.

### Nutrition

- daily calorie target;
- calories consumed;
- remaining calories;
- meal count;
- breakfast/lunch/dinner/snack;
- protein;
- carbohydrates;
- fat;
- food search;
- barcode scan;
- custom foods;
- custom meals;
- meal photos.

### Competition

- daily ranking;
- morning ranking;
- afternoon ranking;
- night ranking;
- full-day ranking;
- weekly/monthly stats;
- missions;
- trophies;
- achievements;
- streaks;
- seasons;
- season winners;
- historical records.

### Social

- private feed;
- manual posts;
- automatic activity posts;
- photos;
- captions;
- comments;
- emoji reactions;
- optional post location;
- workout-sharing cards;
- meal-sharing cards;
- route cards;
- achievement cards.

### Maps

- workout route map;
- route history;
- map inside workout detail;
- optional location attached to social posts.

---

## 3.2 Explicitly out of scope

For the initial private app:

- user-generated groups;
- group management;
- public signup;
- public profiles;
- payments;
- subscriptions;
- ads;
- micropayments;
- stores;
- virtual currency;
- marketplace;
- public leaderboards;
- coaching marketplace;
- chat/DM system;
- live location tracking;
- navigation app features;
- turn-by-turn directions;
- medical diagnosis;
- clinical recommendations;
- enterprise scaling;
- multi-tenant architecture;
- admin moderation console.

---

# 4. Users

Exactly four user profiles exist.

Each profile has:

```text
id
display_name
avatar_url
email / auth identity
platform
timezone
daily_calorie_target
daily_step_target
weekly_workout_target
profile_created_at
```

Optional personal settings:

```text
preferred_units
notification_preferences
default_meal_visibility
default_workout_visibility
allow_post_location
```

Because the app is private, visibility defaults to the four-person group.

---

# 5. Authentication

Recommended:

- Supabase Auth;
- four pre-approved accounts;
- email + password, magic link, Apple sign-in and/or Google sign-in.

Simplest implementation:

1. Pre-create four users.
2. Store four corresponding rows in `profiles`.
3. Reject any authenticated user not present in the allowlist.

There is no registration flow for unknown users.

---

# 6. Main navigation

Recommended bottom navigation:

```text
🏠 HOY
📊 RANKING
➕ REGISTRAR
🏆 JUEGO
👥 NOSOTROS
```

---

# 7. Screen: HOY

`HOY` is the default home screen.

It combines:

- current personal stats;
- group leaderboard snapshot;
- shared social feed;
- automatic events;
- manual posts.

Suggested top summary:

```text
HOY

Tu actividad:
👟 8,420 pasos
🔥 510 kcal activas
🏋️ 1 entrenamiento
🍽️ 1,540 / 2,200 kcal
```

Then:

```text
Ranking actual

1. Diego  9,800
2. Nico   8,950
3. Pedro  8,420
4. Juan   7,310
```

Then the social/activity timeline.

---

# 8. Shared social feed

The feed is private to the four users.

There are two post families:

1. **automatic system/activity events;**
2. **manual user posts.**

---

## 8.1 Automatic feed events

Examples:

### Steps

- user reached 5,000 steps;
- user reached 10,000 steps;
- user reached 15,000 steps;
- user reached 20,000 steps;
- user broke personal daily record;
- user became daily leader;
- user overtook another user;
- morning round ended;
- afternoon round ended;
- night round ended;
- daily winner was decided.

Example:

```text
⚔️ CAMBIO DE POSICIÓN

Nico acaba de superar a Diego.
Diferencia: 41 pasos
```

---

### Workouts

- workout completed;
- first workout of day;
- 5 km run completed;
- 10 km run completed;
- longest distance record;
- best pace record;
- longest workout record.

Example:

```text
🏃 Diego terminó una corrida

7.24 km
41:18
5:42 / km
612 kcal

[Ver ruta]
```

---

### Nutrition

Optional automatic events:

- daily calorie target hit;
- protein target hit if configured;
- all meals logged;
- calorie target respected;
- nutrition streak achieved.

Avoid automatic shame-oriented messages.

---

### Achievements

All meaningful achievements may generate a feed event.

```text
🏆 Pedro desbloqueó:
VAMPIRO

5,000 pasos después de las 22:00
```

---

### Missions

- mission started;
- mission completed;
- group mission completed;
- daily mission winner.

---

### Seasons

- new season started;
- season ended;
- final standings;
- champion announcement.

---

## 8.2 Manual posts

Users can publish:

- photo;
- text;
- meal;
- food;
- workout;
- route;
- location;
- achievement;
- combination of the above.

A manual post can include:

```text
author
caption
photo(s)
created_at
optional_location
optional_meal_id
optional_workout_id
optional_achievement_id
```

Example:

```text
📸 Nico

“Desayuno de campeón”

[PHOTO]

Yogur + avena + fruta

540 kcal
31 g protein
72 g carbs
```

---

## 8.3 Reactions

Recommended initial reactions:

```text
🔥
😂
💀
❤️
👏
🤡
```

A user can react once per emoji per post.

---

## 8.4 Comments

Simple thread under each feed item.

Initial requirements:

- text comments;
- author;
- timestamp;
- delete own comment.

No nested replies required.

---

# 9. Photos

Photos may be attached to:

- social posts;
- meals;
- workouts;
- locations;
- achievement celebrations.

Recommended storage:

- Supabase Storage.

Recommended image behavior:

- compress client-side before upload;
- keep original orientation;
- generate reasonable thumbnail;
- retain enough quality for mobile viewing;
- do not store unnecessarily huge files.

Suggested buckets:

```text
avatars
feed-media
meal-media
workout-media
```

---

# 10. Optional location sharing

A social post may optionally contain a location.

Examples:

- gym;
- park;
- restaurant;
- city location;
- trail start.

This is **not live tracking**.

The user explicitly attaches location to the post.

Data:

```text
latitude
longitude
place_name
optional_address
```

A post can display:

```text
📍 Parque Bicentenario
```

No background continuous user location sharing is required.

---

# 11. Automatic health data integrations

## 11.1 iOS

Use Apple HealthKit.

Potential data types:

- step count;
- active energy burned;
- distance walking/running;
- workouts;
- workout duration;
- workout distance;
- workout energy;
- workout route;
- nutrition data if another app writes it and permission is granted.

Health access must be permission-based.

---

## 11.2 Android

Use Android Health Connect.

Potential data types:

- steps;
- distance;
- active calories;
- exercise sessions;
- routes;
- nutrition records;
- related exercise metrics where available.

---

## 11.3 Flutter abstraction

Preferred approach:

Use an existing Flutter health abstraction package before writing platform-native code.

Candidates discussed:

- `health` / flutter health plugin;
- CARP Health Flutter;
- ConnectKit.

The chosen package must be validated against:

- current iOS HealthKit support;
- current Android Health Connect support;
- step interval queries;
- source metadata;
- manual-entry filtering;
- workouts;
- nutrition;
- route access;
- background synchronization.

Native platform channels are acceptable only for gaps not covered by the plugin.

---

# 12. Step synchronization

Steps are the most important automatic data source.

The app must provide:

```text
morning_steps
afternoon_steps
night_steps
daily_steps
```

Default competition windows:

```text
Morning:   06:00–12:00
Afternoon: 12:00–18:00
Night:     18:00–24:00
Total:     00:00–24:00
```

These windows should be globally configurable in the app config.

---

## 12.1 Competition timezone

Use one shared `competition_timezone`.

All daily rounds and season cutoffs use that timezone.

This prevents different device timezone settings from breaking rankings.

---

## 12.2 No manual step entry

There is no UI to type step counts.

Ingestion must attempt to exclude user-entered step records.

### Android

Prefer records whose metadata indicates automatic or actively recorded activity.

Reject data marked as manual entry where available.

### iOS

Reject samples identified as user-entered using HealthKit metadata when available.

Use platform-level aggregation/query semantics carefully to avoid duplicate counting from phone + wearable sources.

---

## 12.3 Sync frequency

Sync should occur:

- when app opens;
- when app returns to foreground;
- when user manually pulls to refresh;
- during background refresh when OS permits;
- when HealthKit/Health Connect notifies of new data, where supported.

Do not promise second-by-second synchronization.

The UI must show:

```text
Last synced: 2 min ago
```

for each user or ranking source when freshness matters.

---

## 12.4 Sync conflict rules

Data synced from health platforms is authoritative for automatic activity.

Backend should upsert aggregates rather than blindly append duplicate totals.

Suggested unique key:

```text
(user_id, date)
```

for daily stats.

---

# 13. Daily step competition

Each day has four rankings:

1. morning;
2. afternoon;
3. night;
4. full day.

Example:

```text
MORNING

1. Pedro  4,210
2. Diego  3,980
3. Nico   3,210
4. Juan   2,950
```

At the end of each window, record the winner.

---

# 14. Rankings

The `RANKING` tab should support multiple categories.

## 14.1 Today

- total steps;
- morning steps;
- afternoon steps;
- night steps;
- active calories;
- distance;
- workouts completed;
- exercise duration;
- calories consumed;
- remaining calorie budget.

---

## 14.2 Week

- total steps;
- average steps/day;
- active calories;
- distance;
- number of workouts;
- workout minutes;
- days within calorie target;
- streaks;
- game points.

---

## 14.3 Month / season

- season points;
- daily wins;
- round wins;
- missions completed;
- total steps;
- total workouts;
- total distance;
- achievements unlocked.

---

# 15. Workouts

Workouts should be imported automatically from HealthKit / Health Connect where possible.

Supported initial types may include:

- running;
- walking;
- cycling;
- strength training;
- HIIT;
- hiking;
- general workout / other.

Workout detail:

```text
type
start_time
end_time
duration
distance
active_calories
pace
speed
route_available
source
```

Example:

```text
🏃 RUN

42:18
7.42 km
612 kcal
5:42/km
```

---

# 16. Workout routes and maps

When a workout includes GPS route data:

- import route;
- store associated route points;
- render map in workout detail;
- optionally generate a route preview image or polyline.

Potential map stack:

- `flutter_map`;
- OpenStreetMap tiles;
- MapLibre if vector styling/offline support becomes desirable.

Do not build navigation.

---

## 16.1 Route point model

```text
workout_id
timestamp
latitude
longitude
altitude
accuracy
bearing
```

Only fields actually available need to be stored.

---

## 16.2 Route feed card

Example:

```text
🏃 Pedro

6.8 km
37 min

[MAP PREVIEW]

🔥 580 kcal
```

---

## 16.3 Offline maps

Not required for MVP.

Can be explored later if desired using:

- MapLibre offline regions;
- Mapsforge or similar offline map solutions.

---

# 17. Nutrition

Nutrition is a first-class feature.

Each user has:

```text
daily_calorie_target
```

Optional macro targets:

```text
protein_target_g
carb_target_g
fat_target_g
```

---

# 18. Calorie logic

The default concept of “deficit” inside this app should be relative to the user's configured calorie goal.

Example:

```text
Target:    2200 kcal
Consumed:  1850 kcal
Remaining: 350 kcal
```

Avoid automatically claiming:

```text
food calories - exercise calories = real metabolic deficit
```

unless a separate energy-expenditure model is deliberately implemented.

For MVP:

```text
within_calorie_target = consumed_calories <= daily_calorie_target
```

---

# 19. Meal structure

Meals:

```text
Breakfast
Lunch
Dinner
Snack
Other
```

Each food log includes:

```text
user_id
date_time
meal_type
food_name
quantity
unit
calories
protein_g
carbs_g
fat_g
barcode
source
photo_url
```

---

# 20. Nutrition source priority

When adding food:

1. scan barcode;
2. search public food database;
3. search group/private food cache;
4. create custom food manually.

Manual food entry **is allowed**.

The manual-entry restriction applies to **steps**, not nutrition.

---

# 21. Barcode scanning

Use mobile camera to scan:

- EAN;
- UPC;
- compatible retail food barcodes.

Recommended Flutter library:

- `mobile_scanner`.

Flow:

```text
Camera
  ↓
Barcode
  ↓
Lookup
  ↓
Food data
  ↓
Select serving / quantity
  ↓
Add to meal
```

---

# 22. Food APIs

## 22.1 Primary: Open Food Facts

Use Open Food Facts as the first lookup source.

Expected fields:

- barcode;
- product name;
- brand;
- image;
- calories / energy;
- protein;
- carbohydrates;
- fat;
- sugars;
- fiber;
- salt;
- serving information where available.

Reasons:

- open data;
- public API;
- barcode-oriented;
- appropriate for personal use;
- strong fit for packaged foods.

---

## 22.2 Secondary: USDA FoodData Central

Use as fallback/search source.

Useful for:

- common foods;
- branded products where available;
- nutrition details.

---

## 22.3 Optional later source

Nutritionix or another commercial nutrition API can be added only if coverage is insufficient.

For a four-user personal app, avoid paid dependencies unless necessary.

---

# 23. Private food cache

If a barcode is missing from public APIs, users can create it once.

Store locally/backend:

```text
barcode
name
brand
serving_size
serving_unit
calories
protein_g
carbs_g
fat_g
created_by
```

Next scan by any of the four users should use this private record immediately.

---

# 24. Meal photos

A meal entry may include a photo.

Example:

```text
📸 Lunch

Chicken + rice + salad
712 kcal
52 g protein
81 g carbs
19 g fat
```

The user may optionally publish it to the feed.

---

# 25. Photo-based calorie estimation

Optional feature, not required for the first functional build.

Flow:

```text
Take food photo
  ↓
Vision/AI estimates components
  ↓
User adjusts portions
  ↓
Approximate nutrition
```

This must be labeled as an estimate.

A photo alone cannot reliably know:

- exact grams;
- hidden oils;
- sauces;
- cooking method;
- ingredient composition.

Recommended UX:

```text
Detected:
Chicken 180 g ?
Rice    220 g ?
Avocado 60 g ?

[Adjust]

Estimated total: 742 kcal
```

---

# 26. Game layer

The game layer converts real-world activity into fun competition.

It includes:

- points;
- missions;
- streaks;
- achievements;
- trophies;
- seasons.

No virtual money or paid mechanics.

---

# 27. Game points

Game points should not equal raw step count.

Reason:

A user who naturally walks much more would dominate permanently.

Points should reward multiple behaviors.

Example initial point system:

```text
Daily step rank:
1st  +10
2nd  +7
3rd  +4
4th  +2

Round winner:
Morning    +3
Afternoon  +3
Night      +3

Step goal hit:
+2

Workout completed:
+3

Within calorie target:
+2

Mission completed:
variable
```

All scoring values must be configurable from backend/app config.

---

# 28. Personal improvement ranking

Optional but recommended.

Besides raw steps, calculate improvement against personal baseline.

Example:

```text
PERSONAL IMPROVEMENT

1. Pedro +42%
2. Nico  +18%
3. Juan  +11%
4. Diego  +4%
```

Possible baseline:

- average of previous 14 days;
- average of previous 30 days.

This creates fairness between users with different lifestyles.

---

# 29. Streaks

Examples:

```text
10,000 steps/day
Workout/day
Within calorie target/day
3,000 steps before noon
8 km/day
Meal logging complete/day
```

Streak values:

```text
current_streak
longest_streak
last_qualifying_date
```

---

# 30. Daily perfect-day concept

Possible combined achievement:

```text
PERFECT DAY

✓ step target
✓ at least 1 workout
✓ within calorie target
✓ all meals logged
```

This can create:

- streak;
- achievement;
- feed event;
- season points.

---

# 31. Missions

Missions can be:

- individual;
- competitive;
- cooperative.

---

## 31.1 Individual mission examples

```text
EARLY BIRD
2,500 steps before 09:00
```

```text
PUSH
Beat your 14-day step average by 20%
```

```text
RUN FORREST
Run at least 5 km today
```

```text
BALANCED
Hit step target + workout + calorie target
```

---

## 31.2 Competitive missions

Example:

```text
DUEL

Diego vs Nico
18:00–20:00

Most steps wins
```

A duel may award:

- season points;
- achievement progress;
- feed event.

No coins are needed.

---

## 31.3 Cooperative missions

Example:

```text
THE FOUR

Combined today:
40,000 steps
+
3 workouts
+
25 km
```

All users win if the group reaches the target.

---

# 32. Achievements / trophies

Achievements can be serious or intentionally humorous.

Examples:

## Step milestones

```text
100,000 lifetime steps
1,000,000 lifetime steps
20,000 steps in one day
25,000 steps in one day
```

## Workout

```text
10 workouts
50 workouts
100 workouts
100 km running
```

## Streak

```text
7 active days
30 active days
7 days within calorie target
```

## Time-of-day

```text
🐓 GALLO
Win 5 morning rounds
```

```text
🧛 VAMPIRO
5,000 steps after 22:00
```

## Dominance

```text
👑 DICTATOR
Win morning + afternoon + night + daily total
```

## Humorous

```text
🛋️ SOFÁ DE ORO
Finish last in steps 3 consecutive days
```

Humorous achievements should be configurable so the group controls tone.

---

# 33. Achievement engine

Recommended generic rule model:

```text
achievement_id
name
description
icon
metric
operator
threshold
time_window
repeatable
hidden
points
```

Examples:

```text
metric = daily_steps
operator = >=
threshold = 25000
```

or:

```text
metric = morning_round_wins
operator = >=
threshold = 5
```

Avoid hardcoding every achievement into UI logic.

---

# 34. Seasons

Seasons provide periodic resets while preserving history.

Recommended default:

- monthly season.

Alternative:

- weekly season.

Season config:

```text
season_id
name
starts_at
ends_at
status
```

At season end:

- freeze standings;
- determine champion;
- store final positions;
- publish feed result;
- award season trophy;
- start new season at zero game points.

Historical activity stats do not reset.

---

# 35. Season history

Example:

```text
Champions

Aug 2026 — Diego
Sep 2026 — Pedro
Oct 2026 — Nico
```

Store:

```text
season_id
user_id
final_points
final_rank
```

---

# 36. Profile / NOSOTROS

The `NOSOTROS` tab shows the four people.

Each profile includes:

```text
Avatar
Name
Current level / season rank
Steps today
Current streaks
Workouts this week
Distance this week
Calories today
Season points
Trophies
```

Historical stats may include:

```text
lifetime_steps
lifetime_distance
lifetime_workouts
lifetime_active_calories
daily_wins
morning_wins
afternoon_wins
night_wins
season_wins
longest_step_streak
longest_workout_streak
```

---

# 37. Timeline examples

Example full-day feed:

```text
08:34
🏃 Diego finished a run
6.2 km · 36 min

09:01
👟 Nico reached 5,000 steps

11:58
🏆 Pedro won the morning round

13:12
🥗 Juan logged lunch
712 kcal

16:21
🔥 Diego reached 10,000 steps

18:00
🏆 Diego won the afternoon round

19:42
🏋️ Pedro finished a workout
58 min

21:04
👑 Nico passed Diego
by 214 steps
```

---

# 38. Notifications

Notifications should feel social and playful.

Examples:

```text
🚨 Juan just passed you by 127 steps.
```

```text
👀 Pedro is 341 steps away from taking your position.
```

```text
🌙 32 minutes left in the night round.
```

```text
🏆 Nico won the morning round.
```

```text
🔥 Diego unlocked a new achievement.
```

```text
🏃 Pedro completed a 7.1 km run.
```

Notification preferences can be per user.

Recommended categories:

- overtakes;
- round endings;
- achievement;
- workout posts;
- comments/reactions;
- mission progress;
- season results.

---

# 39. Backend

Recommended backend:

- Supabase.

Use:

- Auth;
- PostgreSQL;
- Realtime;
- Storage;
- Edge Functions where useful.

The app has only four users, so optimize for simplicity and maintainability.

---

# 40. Suggested database schema

## 40.1 `profiles`

```text
id uuid primary key
display_name text
avatar_url text
platform text
timezone text
daily_step_target integer
daily_calorie_target integer
protein_target_g numeric nullable
carb_target_g numeric nullable
fat_target_g numeric nullable
created_at timestamptz
```

---

## 40.2 `daily_activity`

```text
id uuid primary key
user_id uuid
date date
morning_steps integer
afternoon_steps integer
night_steps integer
daily_steps integer
active_calories numeric
distance_meters numeric
exercise_minutes numeric
synced_at timestamptz

unique(user_id, date)
```

---

## 40.3 `workouts`

```text
id uuid primary key
user_id uuid
external_id text nullable
source text
workout_type text
started_at timestamptz
ended_at timestamptz
duration_seconds integer
distance_meters numeric nullable
active_calories numeric nullable
avg_pace numeric nullable
avg_speed numeric nullable
route_available boolean
created_at timestamptz
```

---

## 40.4 `workout_route_points`

```text
id bigint primary key
workout_id uuid
timestamp timestamptz
latitude double precision
longitude double precision
altitude numeric nullable
accuracy numeric nullable
bearing numeric nullable
```

Index:

```text
(workout_id, timestamp)
```

---

## 40.5 `foods`

Private/cache/custom food table:

```text
id uuid primary key
barcode text nullable
name text
brand text nullable
serving_size numeric
serving_unit text
calories numeric
protein_g numeric
carbs_g numeric
fat_g numeric
source text
created_by uuid nullable
created_at timestamptz
```

---

## 40.6 `food_entries`

```text
id uuid primary key
user_id uuid
food_id uuid nullable
logged_at timestamptz
meal_type text
quantity numeric
unit text
calories numeric
protein_g numeric
carbs_g numeric
fat_g numeric
photo_url text nullable
notes text nullable
source text
created_at timestamptz
```

---

## 40.7 `posts`

```text
id uuid primary key
author_id uuid
post_type text
caption text nullable
workout_id uuid nullable
food_entry_id uuid nullable
achievement_id uuid nullable
location_name text nullable
latitude double precision nullable
longitude double precision nullable
created_at timestamptz
system_generated boolean
```

Post types:

```text
text
photo
meal
workout
route
achievement
steps
ranking_change
round_result
mission
season
```

---

## 40.8 `post_media`

```text
id uuid primary key
post_id uuid
url text
media_type text
sort_order integer
```

---

## 40.9 `comments`

```text
id uuid primary key
post_id uuid
author_id uuid
body text
created_at timestamptz
```

---

## 40.10 `reactions`

```text
post_id uuid
user_id uuid
emoji text
created_at timestamptz

primary key(post_id, user_id, emoji)
```

---

## 40.11 `achievements`

```text
id uuid primary key
code text unique
name text
description text
icon text
metric text
operator text
threshold numeric
time_window text
repeatable boolean
hidden boolean
season_points integer
```

---

## 40.12 `user_achievements`

```text
id uuid primary key
user_id uuid
achievement_id uuid
unlocked_at timestamptz
context jsonb
```

---

## 40.13 `streaks`

```text
id uuid primary key
user_id uuid
streak_type text
current_count integer
longest_count integer
last_qualified_date date
updated_at timestamptz
```

---

## 40.14 `missions`

```text
id uuid primary key
name text
description text
mission_type text
rules jsonb
reward_points integer
starts_at timestamptz
ends_at timestamptz
```

---

## 40.15 `mission_progress`

```text
mission_id uuid
user_id uuid nullable
progress jsonb
completed boolean
completed_at timestamptz nullable
```

For group missions, `user_id` may be null or use a separate group-progress record.

---

## 40.16 `seasons`

```text
id uuid primary key
name text
starts_at timestamptz
ends_at timestamptz
status text
```

---

## 40.17 `season_points`

Prefer an immutable ledger:

```text
id uuid primary key
season_id uuid
user_id uuid
points integer
reason text
reference_type text
reference_id uuid nullable
created_at timestamptz
```

Standings are derived from the sum.

---

## 40.18 `season_results`

```text
season_id uuid
user_id uuid
final_points integer
final_rank integer

primary key(season_id, user_id)
```

---

# 41. Realtime behavior

Use Supabase Realtime for:

- new posts;
- comments;
- reactions;
- ranking updates;
- mission completion;
- achievement events.

With four users, this is low volume.

Do not use Realtime as the only source of truth.

The database remains authoritative.

---

# 42. Background processing

Some rules are best handled server-side.

Possible Edge Functions / scheduled jobs:

- close morning round;
- close afternoon round;
- close night round;
- close daily ranking;
- award daily points;
- evaluate daily streaks;
- generate daily result post;
- close season;
- create next season;
- award season trophy.

Health data itself originates on the devices and must sync from the authorized device.

---

# 43. Data consistency

Key rules:

- health-derived daily totals are idempotent;
- updating the same day replaces/recalculates totals;
- workouts should use external source ID when available to prevent duplicates;
- food entries are append/edit/delete records;
- points should use an immutable ledger to avoid double awards;
- achievements should have uniqueness rules when not repeatable.

---

# 44. Privacy and security

Even though all four users intentionally share data, health/location data is still sensitive.

Requirements:

- authenticated access only;
- no public bucket access to private media;
- signed URLs or authenticated storage access;
- row-level security;
- only the four allowlisted users can read app data;
- only a user can modify their own health/nutrition records;
- all four can read the shared feed and stats;
- system-generated posts can only be inserted by trusted backend logic or validated client paths.

---

# 45. Row Level Security concept

`profiles`:

- four users can read all four profiles;
- user can update own profile.

`daily_activity`:

- all four can read;
- only owner can upsert own data.

`workouts`:

- all four can read;
- only owner can create/update/delete own workout sync records.

`food_entries`:

- all four can read;
- only owner can modify own entries.

`posts`:

- all four can read;
- author can modify own manual posts;
- system posts protected from arbitrary editing.

`comments/reactions`:

- all four can create;
- user can delete own.

---

# 46. Permissions

Request only permissions actually used.

Possible permissions:

### iOS

- HealthKit read access for selected data types;
- HealthKit nutrition access if needed;
- camera;
- photo library;
- location only when user explicitly uses location/route features;
- notifications.

### Android

- Health Connect permissions for selected data types;
- camera;
- photos/media;
- location when required;
- notifications.

Explain permissions clearly in onboarding/settings.

---

# 47. Onboarding

Because the four users are known, onboarding can be extremely short.

Flow:

```text
Login
  ↓
Connect Health
  ↓
Choose permissions
  ↓
Set calorie target
  ↓
Set step target
  ↓
Ready
```

Optional:

- avatar;
- notification preferences.

There is no group creation.

---

# 48. Health connection screen

Suggested copy:

```text
CONNECT YOUR ACTIVITY

Your steps and workouts are read automatically
from Apple Health or Health Connect.

Manual steps do not count.

The other three members of this private app
will be able to see your shared fitness stats.

[CONNECT]
```

---

# 49. REGISTER tab

The `REGISTRAR` tab is mainly for nutrition and social content.

Actions:

```text
📷 Scan barcode
🔎 Search food
📸 Photograph meal
🍽️ Create meal
📝 New post
📍 Post location
🏋️ Share workout
```

Do not show:

```text
Add steps manually
```

---

# 50. Food entry flow

## Barcode

```text
REGISTRAR
  ↓
Scan barcode
  ↓
Open Food Facts lookup
  ↓
Private cache lookup / fallback
  ↓
Product screen
  ↓
Choose serving/quantity
  ↓
Choose meal type
  ↓
Save
  ↓
Optional: publish to feed
```

---

## Search

```text
Search
  ↓
Open Food Facts / USDA / private foods
  ↓
Choose food
  ↓
Quantity
  ↓
Meal type
  ↓
Save
```

---

## Custom

```text
Create custom food
  ↓
Name
Serving
Calories
Protein
Carbs
Fat
Barcode optional
  ↓
Save to private cache
```

---

# 51. Meal summary screen

Example:

```text
TODAY

Breakfast     430
Lunch         720
Snack         160
Dinner        430
----------------
Consumed     1740
Target       2200
Remaining     460

Protein       132 g
Carbs         186 g
Fat            61 g
```

---

# 52. Workout detail screen

Example:

```text
RUN

Pedro
18:24

7.42 km
42:18
5:42/km
612 kcal

[MAP]

Route stats
Splits optional later

[Publish to feed]
```

---

# 53. Ranking screen structure

Suggested segmented control:

```text
Today | Week | Season
```

Then category selector:

```text
Steps
Rounds
Distance
Workouts
Calories
Nutrition
Game Points
```

---

# 54. Game screen

Contains:

```text
Current season
Season standings
Today's missions
Current streaks
Achievements
Trophy cabinet
Season history
```

---

# 55. Daily lifecycle

At the start of each competition day:

1. initialize today's state;
2. load current season;
3. assign daily missions if used.

During day:

1. devices sync health data;
2. backend updates aggregates;
3. ranking changes;
4. automatic feed events may be created;
5. missions and achievement progress update.

At 12:00:

- close morning round;
- record winner;
- award points;
- publish result.

At 18:00:

- close afternoon round.

At 24:00:

- close night round;
- close daily total;
- award daily ranking points;
- evaluate daily streaks;
- update historical stats;
- publish daily summary.

All times use `competition_timezone`.

---

# 56. Season lifecycle

At season end:

1. stop awarding points to old season;
2. compute final standings;
3. store results;
4. award champion trophy;
5. create season result feed post;
6. start new season.

Historical trophies remain forever.

---

# 57. Anti-cheat / data trust

This is a friendly competition, but basic integrity is important.

Requirements:

- no manual step input;
- reject step data flagged as manually entered where platform metadata supports it;
- store health source metadata for troubleshooting;
- display `last synced`;
- do not let client directly award game points;
- server verifies point-awarding events where practical.

Potential stored source metadata:

```text
platform
source_app
source_device
recording_method
manual_entry_detected
```

Avoid exposing unnecessary low-level health metadata in the UI.

---

# 58. Duplicate step handling

Phone + wearable data can overlap.

Implementation must not naively sum all raw source samples.

Use platform-supported aggregation/deduplication behavior where possible.

If filtering requires raw records:

- remove manual records;
- respect source priorities/overlap;
- verify results against the platform's own displayed daily total during testing.

Acceptance requirement:

> For a test day, the app's accepted automatic-step total should closely match the user's Health/Health Connect step total after excluding known manual entries.

---

# 59. Offline behavior

The app should remain usable when temporarily offline.

Client may cache:

- latest daily stats;
- feed;
- rankings;
- profile data;
- pending food logs;
- pending posts.

When connection returns:

- retry uploads;
- upsert health data;
- upload pending media;
- resolve optimistic UI.

Media upload failures must be visible and retryable.

---

# 60. Error states

Important errors:

- Health permission denied;
- Health Connect unavailable;
- no step data;
- route permission unavailable;
- barcode not found;
- food API unavailable;
- photo upload failed;
- backend offline;
- stale sync.

Examples:

```text
No automatic steps available yet.
Open your health app and confirm that step tracking is enabled.
```

```text
Product not found.
Create it once and it will be available to all four users.
```

---

# 61. Recommended technology stack

## Mobile

```text
Flutter
Dart
```

## Health

```text
iOS: HealthKit
Android: Health Connect
Flutter health abstraction package
```

## Backend

```text
Supabase
PostgreSQL
Auth
Realtime
Storage
Edge Functions
```

## Barcode

```text
mobile_scanner
```

## Food data

```text
Open Food Facts
USDA FoodData Central fallback
Private cached/custom foods
```

## Maps

```text
flutter_map + OpenStreetMap
or
MapLibre
```

## Notifications

```text
FCM/APNs through a Flutter-compatible push setup
```

---

# 62. External dependencies discussed

Potential open-source components to evaluate:

- Flutter;
- `health` Flutter plugin;
- CARP Health Flutter;
- ConnectKit;
- `mobile_scanner`;
- `flutter_map`;
- MapLibre;
- Open Food Facts;
- Supabase Flutter SDK.

Selection should prioritize:

- active maintenance;
- iOS/Android parity;
- Health Connect support;
- HealthKit support;
- clear licensing;
- stable API.

---

# 63. MVP definition

The first useful version should include:

## Accounts

- four fixed users;
- login;
- profiles.

## Health

- Apple HealthKit connection;
- Android Health Connect connection;
- automatic steps;
- manual step rejection where identifiable;
- active calories;
- distance;
- workout import.

## Competition

- morning ranking;
- afternoon ranking;
- night ranking;
- daily ranking;
- season points;
- simple monthly season.

## Social

- shared feed;
- auto step/workout events;
- photo posts;
- comments;
- reactions.

## Nutrition

- calorie target;
- food entries;
- meal categories;
- barcode scanner;
- Open Food Facts;
- custom food fallback;
- calories/macros.

## Game

- streaks;
- initial achievement set;
- initial mission set;
- season trophy.

## Routes

- workout route import when available;
- route map inside workout detail.

---

# 64. Suggested implementation phases

## Phase 1 — Foundation

- Flutter project;
- Supabase project;
- auth;
- four allowlisted profiles;
- navigation;
- database migrations;
- RLS.

Success condition:

> All four can log in and see the same private app shell.

---

## Phase 2 — Steps

- HealthKit;
- Health Connect;
- permissions;
- step sync;
- manual-entry filtering;
- day segmentation;
- daily activity storage;
- ranking.

Success condition:

> Two iPhones and two Android phones show trustworthy automatic step rankings.

---

## Phase 3 — Game core

- round winners;
- daily points;
- season ledger;
- streak engine;
- first achievements;
- mission engine.

Success condition:

> One full competition day can run automatically.

---

## Phase 4 — Social

- feed;
- system posts;
- photo posts;
- comments;
- reactions;
- notifications.

Success condition:

> The four users can follow the day through the shared timeline.

---

## Phase 5 — Nutrition

- calorie targets;
- food log;
- barcode scanner;
- Open Food Facts;
- custom foods;
- meal photos;
- macros.

Success condition:

> A packaged food can be scanned and added to today's nutrition in seconds.

---

## Phase 6 — Workouts and routes

- workout import;
- workout details;
- route import;
- maps;
- feed cards.

Success condition:

> A completed outdoor run appears with stats and route.

---

## Phase 7 — Polish

- historical profiles;
- season history;
- trophy cabinet;
- personalized notifications;
- performance;
- offline behavior;
- data cleanup;
- backup strategy.

---

# 65. Initial achievement pack

Suggested launch set:

```text
FIRST BLOOD
First workout synced

5K CLUB
5,000 steps in one day

10K CLUB
10,000 steps in one day

20K CLUB
20,000 steps in one day

MARATHON LEGS
25,000 steps in one day

GALLO
Win 5 morning rounds

VAMPIRO
5,000 steps after 22:00

DICTATOR
Win all 3 rounds + total in one day

ON FIRE
7-day step-goal streak

GYM RAT
5 workouts in 7 days

RUN FORREST
Run 5 km in one workout

DOUBLE DIGITS
Run 10 km in one workout

SOFÁ DE ORO
Finish last 3 days in a row

PERFECT DAY
Step goal + workout + calorie target + meals logged

SEASON CHAMPION
Finish first in a season
```

---

# 66. Initial mission pack

Examples:

```text
EARLY BIRD
2,500 steps before 09:00

MORNING PUSH
3,000 steps before 12:00

BEAT YOURSELF
Beat your 14-day average by 20%

RUN FORREST
Run at least 5 km

ACTIVE DAY
Hit step goal + one workout

BALANCED DAY
Hit step goal + stay within calorie target

THE FOUR
Combined 40,000 steps

TEAM TRAINING
At least 3 of 4 users complete a workout

LAST CHANCE
Most steps from 20:00–23:59

DUEL
Random pair: most steps in a 2-hour window
```

---

# 67. Automatic feed event rules

Suggested initial thresholds:

```text
5,000 steps
10,000 steps
15,000 steps
20,000 steps
new personal daily record
leader change
round winner
daily winner
workout completed
5 km workout
10 km workout
achievement unlocked
mission completed
season ended
```

Avoid excessive spam.

Rate-limit leader-change events.

Example:

- only publish if lead changes and remains changed for a minimum period;
- or only publish once per pair per time window.

---

# 68. UX tone

The tone should be:

- playful;
- competitive;
- casual;
- friend-group oriented;
- not corporate;
- not medical;
- not overly motivational.

Examples:

Good:

```text
💀 Pedro just stole first place.
```

```text
🔥 Nico hit 10K.
```

```text
👑 Diego owns the morning.
```

Avoid:

```text
Congratulations! You have achieved a healthy lifestyle milestone.
```

---

# 69. Visual identity

Not fully defined yet.

Suggested traits:

- dark/light mode;
- large numbers;
- strong avatars;
- clear ranking positions;
- playful trophies;
- emoji-friendly feed;
- activity cards;
- map cards;
- photo-first meal posts.

The design should prioritize readability over dashboard complexity.

---

# 70. Performance requirements

Given only four users:

- optimize for developer simplicity;
- avoid premature caching layers;
- avoid custom backend services unless needed;
- PostgreSQL queries are sufficient;
- Realtime volume is trivial;
- storage volume is mainly photos/routes.

Image compression is still recommended to control storage.

---

# 71. Backup and data ownership

Because this is a personal long-running app, backups matter more than scale.

Recommended:

- scheduled Supabase/Postgres backups if available;
- export capability later;
- photo storage retention;
- ability to rebuild derived rankings from immutable raw/summary records where practical.

Season point ledger should be append-only.

---

# 72. Configuration table

Use a backend `app_config` table or local configuration for values likely to change:

```text
competition_timezone
morning_start
morning_end
afternoon_start
afternoon_end
night_start
night_end
season_type
step_goal_default
leader_event_cooldown
daily_rank_points
round_win_points
workout_points
calorie_target_points
```

This prevents redeploying the app for every game-balance tweak.

---

# 73. Acceptance criteria — core app

The app is considered functionally successful when:

1. all four known users can authenticate;
2. no unknown user can access app data;
3. two iPhones can read steps from HealthKit;
4. two Android devices can read steps from Health Connect;
5. no app UI exists to manually enter steps;
6. manually entered health step samples are excluded when detectable;
7. daily steps are split into morning/afternoon/night;
8. rankings show all four users;
9. last-sync freshness is visible;
10. workouts sync automatically where available;
11. outdoor workout routes render on a map when route data exists;
12. users can log food;
13. barcode scanning resolves products through Open Food Facts when available;
14. missing foods can be created once and reused;
15. daily calories and macros are calculated;
16. users can publish photos/posts;
17. users can comment and react;
18. automatic feed events appear;
19. streaks and achievements are calculated;
20. season points are awarded without duplicates;
21. a season can close and store a champion.

---

# 74. Future optional ideas

Not required, but compatible with this architecture:

- AI food-photo estimation;
- weekly recap;
- personal records dashboard;
- route heatmap;
- shared route map;
- body weight tracking;
- body measurements;
- sleep competition;
- hydration;
- heart-rate zones;
- VO2 max;
- workout splits;
- challenge generator;
- “most improved” seasonal trophy;
- image collage of weekly meals;
- exported monthly report;
- home screen widgets;
- Apple Watch companion;
- Wear OS companion.

These should only be added if the four users actually want them.

---

# 75. Final product definition

This project is:

> **A private fitness/social game for exactly four friends, built for two iPhones and two Android phones, where real activity is synchronized automatically from HealthKit/Health Connect, nutrition is logged through food search/barcode scanning, workouts and routes can be shared, and the four users compete through rankings, missions, streaks, trophies, achievements and seasons while interacting in a shared photo/activity feed.**

The app should stay intentionally small, personal and fun.

Its success is not measured by number of users.

Its success is:

> **Do the four people open it every day, move more, log/share what they are doing, tease each other, and keep the competition alive?**

---

# 76. Key product decisions already made

```text
✅ Exactly 4 users
✅ 2 iPhone + 2 Android initially
✅ Flutter
✅ Apple HealthKit
✅ Android Health Connect
✅ Supabase
✅ Automatic steps only
✅ No manual step entry
✅ Morning / afternoon / night / total rankings
✅ Workouts
✅ Routes/maps
✅ Nutrition
✅ Calorie targets
✅ Barcode scanning
✅ Open Food Facts first
✅ USDA fallback
✅ Custom/private food cache
✅ Meal photos
✅ Private social feed
✅ Photos
✅ Comments
✅ Reactions
✅ Optional post location
✅ Automatic activity notifications/feed events
✅ Streaks
✅ Missions
✅ Achievements
✅ Trophies
✅ Seasons
✅ Historical stats
✅ No ads
✅ No payments
✅ No micropayments
✅ No public groups
✅ No commercial scaling requirement
✅ No live location tracking
```

---

# 77. Recommended next technical task

The first engineering spike should prove the hardest cross-platform requirement before building the rest:

> **Build one Flutter screen that reads today's automatic step count on one iPhone and one Android device, excludes manual entries where detectable, splits the total into the configured time windows, and uploads the resulting aggregates to Supabase.**

Only after that works reliably across both platforms should the full UI/game/social layer be implemented.

