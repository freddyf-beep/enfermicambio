---
name: Enfermicambio
description: Private four-person fitness competition with a focused sports-club scoreboard aesthetic.
colors:
  primary: "#C7FF00"
  primary-deep: "#8EBA00"
  secondary: "#FF5A26"
  neutral-background: "#111211"
  neutral-surface: "#1C1D1C"
  neutral-surface-strong: "#292A28"
  neutral-border: "#343632"
  neutral-text: "#F4F5EE"
  neutral-muted: "#A9ABA3"
typography:
  display:
    fontFamily: "Roboto, SF Pro Display, system-ui, sans-serif"
    fontSize: "32px"
    fontWeight: 800
    lineHeight: 1.1
    letterSpacing: "-0.5px"
  headline:
    fontFamily: "Roboto, SF Pro Display, system-ui, sans-serif"
    fontSize: "24px"
    fontWeight: 800
    lineHeight: 1.2
  title:
    fontFamily: "Roboto, SF Pro Display, system-ui, sans-serif"
    fontSize: "18px"
    fontWeight: 700
    lineHeight: 1.25
  body:
    fontFamily: "Roboto, SF Pro Text, system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.4
  label:
    fontFamily: "Roboto, SF Pro Text, system-ui, sans-serif"
    fontSize: "12px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "0.2px"
rounded:
  sm: "8px"
  md: "12px"
  lg: "16px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.neutral-background}"
    rounded: "{rounded.md}"
    padding: "14px 20px"
  button-secondary:
    backgroundColor: "{colors.neutral-surface-strong}"
    textColor: "{colors.neutral-text}"
    rounded: "{rounded.md}"
    padding: "14px 20px"
  card:
    backgroundColor: "{colors.neutral-surface}"
    textColor: "{colors.neutral-text}"
    rounded: "{rounded.lg}"
    padding: "16px"
  nav-selected:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.neutral-background}"
    rounded: "{rounded.pill}"
    padding: "10px 14px"
  chip-selected:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.neutral-background}"
    rounded: "{rounded.pill}"
    padding: "8px 16px"
---

# Design System: Enfermicambio

## 1. Overview

**Creative North Star: "The Club Scoreboard"**

Enfermicambio should feel like opening the private scoreboard of a small,
competitive sports club. It is dark, immediate, and a little cheeky, but it
never sacrifices the trust needed for health data. The interface prioritizes
today's position, the next action, and evidence of progress over decoration.

The system rejects clinical wellness dashboards, public social-network patterns,
casino-like gamification, and dense enterprise administration. It uses a
restrained dark canvas with a committed lime accent only where the user needs
to see selection, progress, or a meaningful action.

**Key Characteristics:**

- Dark-first, high-contrast mobile surfaces.
- Acid-lime action and selection states.
- Orange reserved for heat, calories, duels, and warnings.
- Bold hierarchy with calm secondary copy.
- Flat surfaces with state-based emphasis rather than permanent shadows.

## 2. Colors

The palette is charcoal and warm off-white, with a single electric lime voice
and a controlled orange counterpoint.

### Primary

- **Scoreboard Lime** (`#C7FF00`): Primary actions, selected navigation,
  progress, winning rank, and positive activity states.
- **Lime Shadow** (`#8EBA00`): Darker lime for pressed states, subtle borders,
  and situations where the primary accent would lose contrast.

### Secondary

- **Heat Orange** (`#FF5A26`): Calories, active duels, warnings, and energetic
  workout moments. It never competes with the lime selection state.

### Neutral

- **Night Canvas** (`#111211`): App background and safe visual rest space.
- **Training Surface** (`#1C1D1C`): Cards, list rows, and content containers.
- **Raised Surface** (`#292A28`): Inputs, segmented controls, selected-area
  contrast, and bottom navigation chrome.
- **Graphite Border** (`#343632`): One-pixel container boundaries and dividers.
- **Warm White** (`#F4F5EE`): Headings, primary values, and high-priority copy.
- **Quiet Ash** (`#A9ABA3`): Supporting text, inactive labels, and stale data.

**The Accent-Has-a-Job Rule.** Lime and orange must communicate a state or
action. Never use them as an ornamental gradient or as decoration behind
ordinary body copy.

## 3. Typography

**Display Font:** Roboto / SF Pro Display (system fallback)

**Body Font:** Roboto / SF Pro Text (system fallback)

**Label/Mono Font:** System sans with tabular figures for metrics; use a
monospace fallback only for dense numeric comparisons when alignment matters.

**Character:** One familiar sans family keeps the app trustworthy and fast to
scan. Weight and size create hierarchy; font variety does not.

### Hierarchy

- **Display** (800, 32px, 1.1): Screen titles and the most important personal
  metric.
- **Headline** (800, 24px, 1.2): Section titles and player names.
- **Title** (700, 18px, 1.25): Card headings, mission names, and navigation
  context.
- **Body** (400, 15px, 1.4): Explanations, feed copy, and permission details.
- **Label** (700, 12px, 1.2, sentence case or short uppercase): Metric names,
  freshness, badges, and compact controls.

**The Number-First Rule.** Numeric values use tabular figures, strong weight,
and enough surrounding space to scan at a glance. Labels stay subordinate and
never compete with the score.

## 4. Elevation

The system is flat by default. Depth comes from tonal layers and one-pixel
borders, not stacked shadows. A restrained lime glow is allowed only for the
currently selected tab, live leader, or an action that has just completed.

### Shadow Vocabulary

- **Active glow** (`0 0 18px rgba(199,255,0,0.16)`): Selected or live
  competition state only.
- **Warm lift** (`0 4px 16px rgba(0,0,0,0.18)`): Optional on dialogs and the
  bottom navigation surface, never on every card.

**The Flat-at-Rest Rule.** A screen should still be legible if all shadows are
removed. State must be encoded by surface, border, icon, and text as well as
glow.

## 5. Components

### Buttons

- **Shape:** Confident twelve-pixel corners (`12px`), 44px minimum height.
- **Primary:** Scoreboard Lime with Night Canvas text, medium horizontal padding.
- **Hover / Focus:** Darken toward Lime Shadow and add a visible two-pixel focus
  ring; do not rely on glow alone.
- **Secondary / Ghost / Tertiary:** Raised Surface or transparent background,
  Warm White text, Graphite Border when an outline is needed.

### Chips

- **Style:** Pill shape (`999px`), compact horizontal padding, no permanent
  shadow.
- **State:** Selected chips use Scoreboard Lime and dark text. Unselected chips
  use transparent or Raised Surface backgrounds with Quiet Ash text and a
  Graphite Border.

### Cards / Containers

- **Corner Style:** Twelve to sixteen pixels (`12px` to `16px`) according to
  hierarchy.
- **Background:** Training Surface on Night Canvas; Raised Surface only for
  controls or nested emphasis.
- **Shadow Strategy:** Flat at rest; Active glow only for live or selected
  states.
- **Border:** One-pixel Graphite Border, with Lime Shadow for the live leader.
- **Internal Padding:** Sixteen pixels by default, eight for compact rows.

### Inputs / Fields

- **Style:** Raised Surface, Graphite Border, twelve-pixel corners, 44px minimum
  height.
- **Focus:** Lime border and a non-color focus outline visible at keyboard or
  accessibility focus.
- **Error / Disabled:** Error copy and icon accompany color; disabled controls
  reduce contrast without disappearing.

### Navigation

- **Header:** Shared row with avatar, wordmark, and notification action, plus a
  subtle divider. Screen-specific titles appear below or inside the content,
  not in five unrelated app bars.
- **Bottom navigation:** Raised Surface with five destinations. The active
  destination receives a lime pill, active icon, and active label. Inactive
  destinations remain quiet but readable.
- **Health entry:** The same primary action vocabulary is used by the `Conectar
  salud` card in `HOY` and the settings action in `NOSOTROS`.

### Health Connection Card

The signature empty state for missing automatic data. It uses a health icon,
one clear explanation, a platform label, and a single primary action. It must
teach why the data is needed and never imply that manually entering steps is
allowed.

## 6. Do's and Don'ts

### Do:

- **Do** make today's competition the first meaningful visual on `HOY`.
- **Do** use Scoreboard Lime for the selected tab, primary action, progress,
  and current leader.
- **Do** use Orange only for calories, duels, workouts, and warnings.
- **Do** keep minimum touch targets at 44 logical pixels and label icon-only
  actions.
- **Do** pair every permission or sync error with a recovery action.
- **Do** preserve readability when color vision, text scaling, or reduced motion
  settings are enabled.

### Don't:

- **Don't** make the interface look like a clinical or medical dashboard.
- **Don't** add public social-network discovery, follower mechanics, or noisy
  engagement patterns.
- **Don't** use casino-like gamification, random rewards, virtual currency, or
  excessive animation.
- **Don't** build dense enterprise admin screens for a four-person group.
- **Don't** use gradients, decorative glow, or saturated accents on inactive
  content.
- **Don't** communicate rank, freshness, permission, or failure with color alone.
