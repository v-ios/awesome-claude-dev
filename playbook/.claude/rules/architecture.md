---
paths:
  - "Sources/**/*.swift"
  - "App/**/*.swift"
  - "Packages/**/*.swift"
  - "**/Package.swift"
  - "project.yml"
  - "Project.swift"
---

# Architecture: layers, import bans, and the gate that enforces each one

<!-- composed: not from official docs; the "state the rule and name the gate" pattern and the Core import ban are from tomada1114/ios-template (research notes KQ2/KQ8). Replace MyApp* module names with yours. -->

Dependency direction is one-way: `MyAppCore` <- `MyAppUI`, `MyAppCore` <- `MyAppPlatform`, both <- `MyAppFeatures` <- `App`.
`MyAppUI` and `MyAppPlatform` are siblings and never import each other. `App/` is the composition root that hands
Platform adapters, as Core ports, to the view models.

| Layer (directory)       | May import                                   | Must never import                                                                                   | Enforced by                                                                                                   |
| ----------------------- | -------------------------------------------- | --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `Sources/MyAppCore`     | Foundation, Observation                      | SwiftUI, UIKit, AppKit, TVUIKit, TVServices, SwiftData, CoreData, CloudKit, UserNotifications, CoreLocation, Photos, StoreKit, WidgetKit, any other project module | `.swiftlint.yml` `no_ui_import_in_core` (hook + CI lint); `Tests/ArchitectureBoundaryTests.swift` (CI test); `scripts/arch-check.sh` (CI + architecture-guardian) |
| `Sources/MyAppUI`       | MyAppCore, SwiftUI, UIKit (tvOS: TVUIKit)    | MyAppPlatform, SwiftData, CoreData, networking types (`URLSession`)                                 | `no_sibling_import_in_ui`; boundary test; `scripts/arch-check.sh`                                            |
| `Sources/MyAppPlatform` | MyAppCore, SwiftData, URLSession, OS frameworks | MyAppUI, SwiftUI                                                                                  | `no_sibling_import_in_platform`; boundary test; `scripts/arch-check.sh`                                      |
| `Sources/MyAppFeatures` | MyAppCore, MyAppUI                           | MyAppPlatform directly (receive adapters as Core ports), SwiftData, CoreData                        | boundary test; `scripts/arch-check.sh`                                                                       |
| `App/`                  | everything above                             | business logic (composition only)                                                                   | code review (`/review-pr`, REVIEW.md)                                                                        |

Additional rules the import bans cannot see:

- Core never names `URLSession`, `UserDefaults`, `FileManager` directly: those are adapter concerns behind a protocol (port) declared in Core. Enforced by `ArchitectureBoundaryTests` (`forbiddenFoundationTypes`).
- `@Model` / `ModelContainer` / `ModelContext` live only under `Sources/MyAppPlatform/Persistence/`. Enforced by `no_ui_import_in_core` (SwiftData is banned elsewhere) and review.
- No shipped module imports a test-support module. Enforced by `ArchitectureBoundaryTests`.
- A new module or a new edge in `Package.swift`/`project.yml` is an architecture decision: stop and ask before adding it (CLAUDE.md > Needs human sign-off), then update this table, `scripts/arch-check.sh` rules and the boundary test together.

If a change needs an exception, stop and ask. Do not add `// swiftlint:disable`, edit the lint config, or weaken the
boundary test to get past a gate. Each boundary is enforced twice on different CI jobs on purpose: disabling one
still leaves the other red.
