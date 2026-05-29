
# Schedula Flutter Design System

This document defines the Flutter design system for the Schedula app on both Android and iOS. The goal is visual parity with the current app, not a generic Material or Cupertino interpretation. The Flutter build should match the existing web app's shell, spacing, type, colors, and navigation behavior as closely as possible.

## 1. Design Goal

- The app must look the same on Android and iOS.
- Use one shared visual language across platforms.
- Respect safe areas, but do not change the overall styling per platform.
- Keep the app compact, polished, and phone-first.
- On larger screens, preserve the centered phone-frame presentation used by the current app.

## 2. Visual Identity

The current app has a bright, clean, slightly premium mobile-dashboard look.

- Base surface: white and very light gray.
- Primary accent: teal.
- Typography: rounded, friendly, high-legibility sans serif.
- Headings: bold and compact.
- Body text: clean and neutral.
- Navigation: fixed teal bottom bar with a floating add button.
- Device presentation: centered phone canvas with soft shadow on desktop/tablet.

## 3. Color Tokens

Use these as the source of truth for Flutter `ColorScheme`, custom theme extensions, and component styling.

### 3.1 Core Colors

- `background`: `#FFFFFF`
- `foreground`: `#030213`
- `card`: `#FFFFFF`
- `cardForeground`: `#030213`
- `popover`: `#FFFFFF`
- `popoverForeground`: `#030213`
- `primary`: `#030213`
- `primaryForeground`: `#FFFFFF`
- `secondary`: `#F2F2F7`
- `secondaryForeground`: `#030213`
- `accent`: `#E9EBEF`
- `accentForeground`: `#030213`
- `muted`: `#ECECF0`
- `mutedForeground`: `#717182`
- `border`: `rgba(0, 0, 0, 0.10)`
- `inputBackground`: `#F3F3F5`
- `input`: transparent
- `ring`: `#B5B5BC`

### 3.2 Semantic Colors

- `destructive`: `#D4183D`
- `destructiveForeground`: `#FFFFFF`
- `success`: use a muted green only when needed; do not introduce a new visual style unless the current screen already uses it.

### 3.3 Brand and Chrome Colors

- `tealPrimary`: `#22AFC2`
- `tealPrimarySoft`: `#58D8E3`
- `tealShadow`: `rgba(34, 175, 194, 0.45)`
- `desktopCanvasBg`: `#F0EEF8`
- `loadingBg`: `#F8F7FF`

### 3.4 Sidebar and Admin Tokens

If the Flutter port includes the admin area, keep the same neutral palette.

- `sidebar`: `#FCFCFD`
- `sidebarForeground`: `#030213`
- `sidebarPrimary`: `#030213`
- `sidebarPrimaryForeground`: `#FFFFFF`
- `sidebarAccent`: `#F7F7FA`
- `sidebarAccentForeground`: `#1F1F28`
- `sidebarBorder`: `rgba(0, 0, 0, 0.08)`
- `sidebarRing`: `#B5B5BC`

## 4. Typography

The app uses two distinct families.

- Headings and numeric emphasis: Bricolage Grotesque.
- Body, labels, buttons, and inputs: Raleway.

If the fonts are not available in Flutter, bundle them as assets and declare them in `pubspec.yaml`. Do not replace them with default system fonts.

### 4.1 Font Rules

- Root font size equivalent: 16 px.
- Headings should feel tight and strong.
- Body text should stay calm and readable.
- Numbers should use the heading font and bold weight when possible.

### 4.2 Flutter Text Styles

- `headlineLarge`: Bricolage Grotesque, 700, 26 px, letter spacing `-0.02 em`
- `headlineMedium`: Bricolage Grotesque, 600, 18 px, letter spacing `-0.015 em`
- `headlineSmall`: Bricolage Grotesque, 600, 16 px, letter spacing `-0.01 em`
- `titleMedium`: Bricolage Grotesque, 500, 15 px
- `bodyLarge`: Raleway, 400, 16 px
- `bodyMedium`: Raleway, 400, 14 px
- `bodySmall`: Raleway, 400, 12 px
- `labelLarge`: Raleway, 500, 14 px
- `labelMedium`: Raleway, 500, 12 px
- `labelSmall`: Raleway, 500, 10 px

### 4.3 Numeric and Name Styling

- Numeric values should use Bricolage Grotesque Bold and slight negative letter spacing.
- Prominent names or labels should use bold weight.
- Avoid over-weighting body copy.

## 5. Layout System

### 5.1 App Shell

- Phone width target: 430 dp.
- Mobile behavior: full-screen, edge-to-edge.
- Tablet and desktop behavior: centered phone column with a soft outer studio background.
- Desktop outer canvas: `#F0EEF8`.
- Desktop phone card: max width 430 dp, rounded 40 dp corners, subtle shadow.

### 5.2 Shell Shape

- App container radius on desktop: 40 dp.
- Base radius for cards and controls: 10 dp to 20 dp depending on component.
- Floating add button: circular.

### 5.3 Spacing

Use a compact spacing scale.

- 4 dp: micro spacing, icon gaps, minor padding.
- 8 dp: small component spacing.
- 12 dp: standard internal spacing.
- 16 dp: section spacing.
- 24 dp: larger vertical rhythm.
- 32 dp: major grouping gaps.

Keep the UI tight. Do not inflate spacing just because Flutter defaults are larger.

## 6. Flutter Theme Setup

### 6.1 ThemeMode

- Prefer a single light theme that mirrors the current app.
- Do not introduce dark mode unless the product explicitly requires it.
- If dark mode is needed later, derive it from the same token set, but preserve the current app's light-first identity.

### 6.2 Material Styling

Use `ThemeData` as a styling carrier only. Override default Material cues where they conflict with the current app.

- `useMaterial3`: true is acceptable if the defaults are heavily customized.
- `scaffoldBackgroundColor`: `background`
- `colorScheme`: built from the tokens above.
- `fontFamily`: Raleway.
- `textTheme`: custom, with Bricolage Grotesque for headings.
- `inputDecorationTheme`: soft filled inputs with muted background and subtle border.
- `cardTheme`: white background, gentle shadow, low border contrast.
- `bottomNavigationBarTheme`: custom teal bar styling, not default Material navigation chrome.

## 7. Core Components

### 7.1 Status Bar

The app has a custom status bar on mobile screens.

- Height: 48 dp total, with 14 dp top padding.
- Time positioned left.
- Signal, Wi-Fi, and battery icons positioned right.
- Default icon color on light content areas: white.
- Default icon color on light shells: near-black.
- The time should use tabular numerals if possible.

### 7.2 Bottom Navigation

This is one of the most distinctive parts of the UI and should be matched closely.

- Background color: `tealPrimarySoft` or `tealPrimary` depending on the exact screen tone.
- Height of the main nav rail: 64 dp.
- Bottom home indicator strip: separate 5 dp bar area beneath the nav rail.
- Nav buttons: 65 x 64 dp touch targets.
- Icon size: about 22 dp.
- Label size: 10 dp.
- Active icons and labels: white.
- Inactive icons and labels: white at about 65 percent opacity.
- Center action button: floating circular plus button with a white inner button and teal outer ring.
- The add button must visually overlap the nav bar, not sit inside it.

### 7.3 App Cards and Panels

- Use white cards with subtle shadow and low-contrast borders.
- Keep corners rounded but not exaggerated.
- Backgrounds should remain light and airy.
- Avoid heavy elevation.

### 7.4 Buttons

- Primary buttons: solid teal or solid near-black depending on context.
- Secondary buttons: muted gray surface with dark text.
- Destructive buttons: red only for actual destructive actions.
- Buttons should be compact and rounded.
- Press feedback should be subtle scale or opacity, not bouncy animation.

### 7.5 Inputs

- Background: `inputBackground`.
- Border: faint, low-contrast.
- Focus state: thin ring using the ring token or teal accent.
- Corners: consistent with the rest of the app, usually 10 to 14 dp.

### 7.6 Loading State

- Use the current app's loading composition: soft background, centered logo block, and a simple spinning indicator.
- Loading background: `#F8F7FF`.
- Spinner accent: teal.

## 8. Icons

- Use outline-style icons with clean geometry.
- Keep stroke widths consistent.
- Prefer Lucide-style proportions if using a custom icon set.
- The signal, Wi-Fi, battery, home, calendar, chart, user, and plus icons should feel balanced and minimal.

## 9. Motion

Motion is subtle and functional.

- Use short transitions for taps and state changes.
- Bottom nav collapse/expand should feel spring-like but restrained.
- Floating add button should have a soft press scale effect.
- Avoid decorative motion that changes the app personality.

Recommended motion values:

- Press scale: 0.9 to 0.95.
- Nav collapse duration: about 250 to 350 ms.
- Easing: soft spring or easeOut.

## 10. Responsive Behavior

### 10.1 Android and iOS Phones

- The app should render identically on both platforms.
- Respect safe areas at the top and bottom.
- Keep the same typography, spacing, and chrome on both platforms.

### 10.2 Tablets

- Do not stretch the phone UI full width.
- Keep the centered 430 dp shell if the screen is wide enough.
- Preserve the studio background outside the shell.

### 10.3 Desktop

- Same centered phone shell as the web app.
- Use the soft lavender-tinted background outside the shell.
- Keep the shell shadow and rounded corners.

## 11. Exact Flutter Mapping

### 11.1 ThemeData

Map the design tokens into Flutter like this:

- `ColorScheme.fromSeed` is not required.
- Define a custom `ColorScheme` manually for exactness.
- Set `fontFamily` to Raleway.
- Set `textTheme` overrides for headings in Bricolage Grotesque.
- Use custom decoration and bottom navigation themes instead of defaults.

### 11.2 Suggested Widget Structure

- `SchedulaApp`
- `AppShell`
- `PhoneCanvas`
- `CustomStatusBar`
- `BottomActionNav`
- `FloatingAddButton`
- `SchedulaCard`
- `SchedulaButton`
- `SchedulaInput`

### 11.3 Shared Constants

- App width: 430 dp.
- Desktop outer radius: 40 dp.
- Primary teal: `#22AFC2`.
- Soft teal: `#58D8E3`.
- Body font: Raleway.
- Heading font: Bricolage Grotesque.

## 12. Implementation Rules

- Do not swap to default Material typography.
- Do not use purple as a default accent.
- Do not introduce heavy shadows.
- Do not use large corner radii except where the current app already does.
- Do not let Android and iOS diverge visually.
- Prefer consistency over platform-specific theming.

## 13. Design Principles

- Clean and compact.
- Mobile-first, but desktop-safe.
- Friendly, modern, and slightly premium.
- Teal-forward without becoming loud.
- Highly legible.
- Minimal visual noise.

## 14. Summary

If the Flutter app follows this document exactly, it should visually match the current Schedula app: light surfaces, teal navigation chrome, custom iPhone-style framing on larger screens, Bricolage Grotesque headings, Raleway body text, and a compact dashboard UI that looks the same on Android and iOS.

