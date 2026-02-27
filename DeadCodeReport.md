# Dead Code Report - myPlanet iOS

## 1. Swift Code

| Symbol | File Path | Why it appears unused | Suggested Action | Risk Level |
| :--- | :--- | :--- | :--- | :--- |
| `deleteComment(_:)` | `myPlanet Lite/ContentView.swift` | No references found in the codebase. | Remove | Low |
| `planetKeysData` | `myPlanet Lite/ContentView.swift` | Written to in `storeConfiguration` but never read. | Investigate / Keep (might be for future use) | Low |
| `rightMenuContent` | `myPlanet Lite/ContentView.swift` | Empty placeholder view. | Keep (UI placeholder) | Low |

## 2. Localizable Strings (`Localizable.strings`)

| Key | File Path | Why it appears unused | Suggested Action | Risk Level |
| :--- | :--- | :--- | :--- | :--- |
| `dashboard_tab_voices` | `myPlanet Lite/*/Localizable.strings` | Dashboard uses `DashboardNavItem` enum names which don't match this key. | Remove | Low |
| `dashboard_tab_teams` | `myPlanet Lite/*/Localizable.strings` | Dashboard uses `DashboardNavItem` enum names which don't match this key. | Remove | Low |
| `language_spanish` | `myPlanet Lite/*/Localizable.strings` | Languages are hardcoded in `availableLanguages` list. | Remove | Low |
| `language_english` | `myPlanet Lite/*/Localizable.strings` | Languages are hardcoded in `availableLanguages` list. | Remove | Low |
| `language_french` | `myPlanet Lite/*/Localizable.strings` | Languages are hardcoded in `availableLanguages` list. | Remove | Low |
| `language_hindi` | `myPlanet Lite/*/Localizable.strings` | Languages are hardcoded in `availableLanguages` list. | Remove | Low |
| `language_nepali` | `myPlanet Lite/*/Localizable.strings` | Languages are hardcoded in `availableLanguages` list. | Remove | Low |
| `language_portuguese` | `myPlanet Lite/*/Localizable.strings` | Languages are hardcoded in `availableLanguages` list. | Remove | Low |
| `language_arabic` | `myPlanet Lite/*/Localizable.strings` | Languages are hardcoded in `availableLanguages` list. | Remove | Low |
| `language_somali` | `myPlanet Lite/*/Localizable.strings` | Languages are hardcoded in `availableLanguages` list. | Remove | Low |
| `level_beginner` | `myPlanet Lite/*/Localizable.strings` | Levels are hardcoded in `levelOptionsByLanguage` list. | Remove | Low |
| `level_intermediate` | `myPlanet Lite/*/Localizable.strings` | Levels are hardcoded in `levelOptionsByLanguage` list. | Remove | Low |
| `level_advanced` | `myPlanet Lite/*/Localizable.strings` | Levels are hardcoded in `levelOptionsByLanguage` list. | Remove | Low |
| `level_expert` | `myPlanet Lite/*/Localizable.strings` | Levels are hardcoded in `levelOptionsByLanguage` list. | Remove | Low |

## 3. Assets (`Assets.xcassets`)

| Asset Name | File Path | Why it appears unused | Suggested Action | Risk Level |
| :--- | :--- | :--- | :--- | :--- |
| `app_white` | `myPlanet Lite/Assets.xcassets/app_white.colorset` | No references found in the codebase. | Remove | Low |
| `blueOle` | `myPlanet Lite/Assets.xcassets/blueOle.colorset` | No references found in the codebase. | Remove | Low |
| `cyanOle` | `myPlanet Lite/Assets.xcassets/cyanOle.colorset` | No references found in the codebase. | Remove | Low |
| `grayOle` | `myPlanet Lite/Assets.xcassets/grayOle.colorset` | No references found in the codebase. | Remove | Low |
| `greenOle` | `myPlanet Lite/Assets.xcassets/greenOle.colorset` | No references found in the codebase. (`greenOleLogo` is used instead). | Remove | Low |

## Dynamic/Reflection Candidates Requiring Manual Confirmation

- `appLog`: Debug utility that uses `@autoclosure`. It is used throughout the app when in `#DEBUG`.
- `UIImage(named:)` and `Color("...")` usage was checked by grepping the literal strings. All matches were found except those listed above.
- `LocalizedStringKey` is used extensively in SwiftUI views. All keys were grepped.
- `DashboardNavItem` raw values are used for icons, but the corresponding string keys for titles (`dashboard_tab_voices`, etc) were found to be unused in the current implementation.
- `availableLanguages` and `levelOptionsByLanguage` use hardcoded display names rather than looking up keys in `Localizable.strings`.
