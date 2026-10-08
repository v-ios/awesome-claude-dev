import Foundation
import Testing

/// The second enforcement of the module boundaries in `.claude/rules/architecture.md`.
///
/// `.swiftlint.yml`'s `no_ui_import_in_core` / `no_sibling_import_in_*` rules are the first enforcement (the
/// PostToolUse hook and the CI `lint` job), this suite is the second (the CI `build-test` job), and
/// `scripts/arch-check.sh` the third (CI `lint` job and the `architecture-guardian` subagent). Removing any one
/// still leaves the others catching a regression. SwiftPM's target graph withholds modules only until someone
/// adds a dependency edge; this suite is what makes that edit fail a check rather than compile.
///
/// Core also never names a Foundation type an adapter owns (`URLSession`, `UserDefaults`, `FileManager`):
/// Core imports Foundation, so no import ban can see one, and this suite is the only enforcement.
///
/// Adapted from tomada1114/ios-template's ArchitectureBoundaryTests (research notes, governance KQ8).
/// composed: the module map and repo-root discovery below are this playbook's own — edit the `Layout` constants.
/// Requires Swift Testing (Xcode 16+) and `Regex` (iOS 16 / tvOS 16 / macOS 13+).
@Suite("Architecture boundary")
struct ArchitectureBoundaryTests {
    // MARK: - Configure for your repo

    enum Layout {
        /// Directory (relative to the repo root) that holds each module's sources.
        static let sources: [String: String] = [
            "MyAppCore": "Sources/MyAppCore",
            "MyAppUI": "Sources/MyAppUI",
            "MyAppPlatform": "Sources/MyAppPlatform",
            "MyAppFeatures": "Sources/MyAppFeatures",
            "MyApp": "App",
        ]
        static let core = "MyAppCore"
        static let ui = "MyAppUI"
        static let platform = "MyAppPlatform"
        static let features = "MyAppFeatures"
        static let testSupportModules = ["MyAppTestSupport"]
        /// Set `ARCH_SOURCES_ROOT` in the test plan / scheme environment to override root discovery.
        static let rootEnvironmentKey = "ARCH_SOURCES_ROOT"
    }

    static let forbiddenInCore = [
        "SwiftUI", "UIKit", "AppKit", "Cocoa", "TVUIKit", "TVServices",
        "SwiftData", "CoreData", "CloudKit",
        "UserNotifications", "CoreLocation", "Photos", "PhotosUI", "StoreKit", "WidgetKit",
    ]
    static let forbiddenFoundationTypesInCore = ["URLSession", "UserDefaults", "FileManager"]

    // MARK: - Tests

    @Test("Core imports no UI, persistence, or OS-integration framework")
    func coreImportsNoFrameworks() throws {
        try Self.expectNoImports(of: Self.forbiddenInCore, in: Layout.core)
    }

    @Test("Core imports no other project module")
    func coreImportsNoProjectModule() throws {
        let others = Layout.sources.keys.filter { $0 != Layout.core }.sorted()
        try Self.expectNoImports(of: others, in: Layout.core)
    }

    @Test("Core never names URLSession, UserDefaults or FileManager")
    func coreNamesNoAdapterOwnedFoundationTypes() throws {
        try Self.expectNoIdentifiers(Self.forbiddenFoundationTypesInCore, in: Layout.core)
    }

    @Test("UI never imports Platform or persistence frameworks")
    func uiImportsNoPlatform() throws {
        try Self.expectNoImports(of: [Layout.platform, "SwiftData", "CoreData"], in: Layout.ui)
    }

    @Test("Platform never imports UI or SwiftUI")
    func platformImportsNoUI() throws {
        try Self.expectNoImports(of: [Layout.ui, "SwiftUI"], in: Layout.platform)
    }

    @Test("Features never import Platform directly or persistence frameworks")
    func featuresImportNoPlatform() throws {
        try Self.expectNoImports(of: [Layout.platform, "SwiftData", "CoreData"], in: Layout.features)
    }

    @Test("no shipped module imports a test-support module")
    func shippedModulesImportNoTestSupport() throws {
        for module in Layout.sources.keys.sorted() {
            try Self.expectNoImports(of: Layout.testSupportModules, in: module)
        }
    }

    // MARK: - Helpers

    /// Same shape as the SwiftLint rule: optional attributes (`@preconcurrency`, `@_exported`, `@testable`),
    /// `import`, an optional kind (`struct`, `class`, ...), then the module name. Catches
    /// `import struct SwiftUI.Color` too.
    static func pattern(forAnyOf modules: [String]) -> String {
        #"^\s*(@[\w()]+\s+)*import\s+((typealias|struct|class|enum|protocol|let|var|func)\s+)?("#
            + modules.joined(separator: "|")
            + #")\b"#
    }

    static func importRegex(forAnyOf modules: [String]) throws -> Regex<AnyRegexOutput> {
        try Regex(pattern(forAnyOf: modules))
    }

    static func identifierRegex(forAnyOf identifiers: [String]) throws -> Regex<AnyRegexOutput> {
        try Regex(#"\b("# + identifiers.joined(separator: "|") + #")\b"#)
    }

    /// Walks up from this file until a directory containing `Sources` (or the first configured layer) exists.
    static var repoRoot: URL {
        if let override = ProcessInfo.processInfo.environment[Layout.rootEnvironmentKey] {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fm = FileManager.default
        for _ in 0..<8 {
            let candidates = ["Sources"] + Layout.sources.values.map { $0.components(separatedBy: "/").first ?? $0 }
            if candidates.contains(where: { fm.fileExists(atPath: directory.appendingPathComponent($0).path) }) {
                return directory
            }
            directory = directory.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    static func sourcesDirectory(of module: String) throws -> URL {
        let relative = try #require(Layout.sources[module], "no source directory configured for module \(module)")
        return repoRoot.appendingPathComponent(relative, isDirectory: true)
    }

    static func swiftFiles(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var files: [URL] = []
        for case let url as URL in enumerator {
            let path = url.path
            if path.contains("/.build/") || path.contains("/DerivedData/") || path.contains("/Generated/") { continue }
            if url.pathExtension == "swift" { files.append(url) }
        }
        return files.sorted { $0.path < $1.path }
    }

    static func expectNoImports(of modules: [String], in module: String) throws {
        let directory = try sourcesDirectory(of: module)
        let files = swiftFiles(in: directory)
        try #require(!files.isEmpty, "no .swift files found under \(directory.path) — is Layout.sources right?")
        let regex = try importRegex(forAnyOf: modules)
        for file in files {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() where line.firstMatch(of: regex) != nil {
                Issue.record("\(file.path):\(index + 1): forbidden import in \(module): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
    }

    static func expectNoIdentifiers(_ identifiers: [String], in module: String) throws {
        let directory = try sourcesDirectory(of: module)
        let files = swiftFiles(in: directory)
        try #require(!files.isEmpty, "no .swift files found under \(directory.path) — is Layout.sources right?")
        let regex = try identifierRegex(forAnyOf: identifiers)
        for file in files {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                let code = line.components(separatedBy: "//").first ?? line   // ignore trailing comments
                if code.firstMatch(of: regex) != nil {
                    Issue.record("\(file.path):\(index + 1): \(module) must not name an adapter-owned type: \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
    }
}
