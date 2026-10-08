---
paths:
  - "**/Tests/**/*.swift"
  - "**/*Tests.swift"
  - "**/*UITests/**/*.swift"
  - "**/*.xctestplan"
---

# Testing rules

<!-- composed: not from official docs; adapted from tomada1114/ios-template .claude/rules/testing.md plus Duolingo's reported failure mode "SwiftTesting/XCTest mixing" (research notes). Validate in your repo. -->

## Framework: Swift Testing for unit tests, XCTest only for UI tests — never both in one target

- Unit and integration test targets use Swift Testing only: `import Testing`, `@Suite`, `@Test`, `#expect`, `#require`, `#expect(throws:)`. No `XCTestCase`, `XCTAssert*`, or `setUp/tearDown` in these targets.
- XCUITest targets (`*UITests`) use XCTest only (`XCUIApplication`, `XCUIRemote` on tvOS). No `import Testing` there.
- Check the target's existing imports before writing a test; match them. Mixing frameworks in one target is a review blocker and the most common agent mistake in generated tests.

## Writing tests

- Write the failing test first, run it, watch it fail for the right reason, then implement.
- Test behavior and contracts (inputs -> outputs, thrown errors with their payloads), not private implementation details.
- Fakes, not mocks: hand-written fakes that implement the Core port protocols; no mocking frameworks.
- Deterministic: no `sleep`, no timing-based assertions, no shared mutable state between tests, no network (`URLProtocol` stubs or a fake client), no real `ModelContainer` (use an in-memory configuration).
- Each `@Test` covers one behavior; parameterize with `@Test(arguments:)` instead of loops.
- NEVER weaken, delete, or `.disabled()` an assertion or test to make a run pass — fix the code or stop and ask.

## Naming and layout

- File name mirrors the subject: `Sources/MyAppCore/Cart/CartTotals.swift` -> `Tests/MyAppCoreTests/Cart/CartTotalsTests.swift`.
- Suite per type: `@Suite("CartTotals")`; test display names are sentences: `@Test("applies the discount once per order") func appliesDiscountOncePerOrder()`. (Backtick raw identifiers with spaces need Swift 6.2+; the display-name form works on every Swift Testing version.)
- Shared fixtures live in `Tests/<Module>Tests/Support/`; test-only helper modules are never imported by shipped code (boundary test).

## Running tests (narrowest first)

| What you changed                 | Run this                                                                              |
| -------------------------------- | ------------------------------------------------------------------------------------- |
| one function in a Swift package  | `swift test --filter <SuiteName>` from the package directory                          |
| one test class in the app target | `scripts/xcb.sh test ios --only-testing MyAppTests/CartTotalsTests`                   |
| one test                         | `scripts/xcb.sh test ios --only-testing MyAppTests/CartTotalsTests/appliesDiscount`   |
| a tvOS-only code path            | `scripts/xcb.sh test tvos --only-testing MyAppTVTests/<Class>`                        |
| re-running after a fix, no rebuild | `scripts/xcb.sh test-without-building ios --only-testing ... --xctestrun <path>`    |
| everything (before a PR)         | `scripts/xcb.sh test ios` and `scripts/xcb.sh test tvos` (or let CI do it)            |

Identifier form is `TestTarget[/TestClass[/TestMethod]]`. After a failing run, `scripts/xcresult-failures.sh <bundle>`
prints the failing tests, messages and exports failure attachments; paste only those, never the raw xcodebuild log.
