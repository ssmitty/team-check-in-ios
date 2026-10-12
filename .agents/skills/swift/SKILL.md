---
name: swift
description: Best practices for writing modern Swift and SwiftUI for iOS, macOS, and other Apple platforms, covering project structure, MVVM with the Observation framework, async/await and structured concurrency, Swift 6 data race safety, error handling, protocol-based dependency injection, SwiftData, Keychain, accessibility, and testing. Use this skill whenever the user is writing, reviewing, debugging, or architecting Swift, SwiftUI, UIKit, or Xcode project code, building an iOS or Mac app, or mentions Swift, SwiftUI, Xcode, or Apple platforms, even if they only ask for a small view or function. Pair with the coding-standards skill for style rules and the supabase skill when the backend is Supabase.
---

# Swift

Guidance for writing clear, safe, modern Swift. Prefer current language features and Apple frameworks. When an API's availability or behavior is uncertain (new iOS releases change things often), check Apple's documentation rather than guessing, and state the minimum OS version your code requires.

Always apply the `coding-standards` skill as well: header comment on every file, small focused files, no em dashes, no emojis (use SF Symbols for icons, never emoji characters in UI).

## File header and comment style

Use this header at the top of every Swift file:

```swift
//
//  NotesListViewModel.swift
//
//  Purpose: Holds state and logic for the notes list screen.
//  Loads notes through NotesServicing and exposes loading and error state.
//
//  Depends on: NotesServicing, Note
//

import Foundation
```

Additional conventions:
- Use `///` doc comments on every public and internal type, property, and function that is not trivially obvious. Document parameters and thrown errors with `- Parameter`, `- Returns`, and `- Throws`.
- Use `// MARK: - Section` to divide a file (Properties, Lifecycle, Actions, Private helpers).
- Comment the why, not the what.

## Project structure

Group by feature, with shared code separated. Typical layout:

```
AppName/
  App/
    AppNameApp.swift          # entry point
    AppEnvironment.swift      # dependency wiring
  Features/
    Notes/
      Views/
        NotesListView.swift
        NoteRowView.swift
      ViewModels/
        NotesListViewModel.swift
      Models/
        Note.swift
      Services/
        NotesService.swift
    Auth/
      ...
  Core/
    Networking/
    Persistence/
    Extensions/
    Utilities/
  UI/
    Components/               # reusable views
    Styles/                   # colors, fonts, modifiers
  Resources/
    Assets.xcassets
    Localizable.xcstrings
  Tests/
```

Rules:
- One primary type per file, and the file is named after it.
- Keep views small. When a `body` grows past roughly 60 lines, extract subviews into their own structs (not computed properties that hide state, unless trivial).
- Use Swift Package Manager local packages to modularize larger apps (Core, Networking, FeatureX) with explicit `public` APIs.
- Put extensions in files named `Type+Purpose.swift` (for example `Date+Formatting.swift`).

## Architecture

Use **MVVM** with a clear service layer for SwiftUI apps:
- **View**: declarative UI only. No networking, no business logic.
- **ViewModel**: owns screen state, calls services, maps errors to user messages.
- **Service**: talks to the network, database, or system APIs. Defined behind a protocol.
- **Model**: plain value types (`struct`) conforming to `Codable`, `Identifiable`, `Sendable` and `Equatable` or `Hashable` as needed.

Use the Observation framework (iOS 17+):

```swift
@MainActor
@Observable
final class NotesListViewModel {
    // MARK: - State
    private(set) var notes: [Note] = []
    private(set) var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies
    private let service: NotesServicing

    init(service: NotesServicing) {
        self.service = service
    }

    // MARK: - Actions
    /// Loads the latest notes and updates published state.
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            notes = try await service.fetchNotes()
        } catch {
            errorMessage = "Could not load notes. Please try again."
        }
    }
}
```

For apps that must support iOS 16 or earlier, use `ObservableObject` with `@Published`, `@StateObject`, and `@ObservedObject` instead.

Property wrapper guide:
- `@State`: view-local value state, and ownership of an `@Observable` view model created by the view.
- `@Bindable`: create bindings to properties of an `@Observable` object.
- `@Binding`: two-way connection passed from a parent.
- `@Environment`: system values and injected app-wide objects.
- Avoid `@EnvironmentObject` in new iOS 17+ code, prefer `@Environment` with `@Observable`.

Use `NavigationStack` with a typed path or `navigationDestination(for:)`. Do not use the deprecated `NavigationView` in new code.

## Dependency injection

Depend on protocols, inject through initializers, and wire everything in one composition root (`AppEnvironment`). This keeps view models testable and previews easy.

```swift
protocol NotesServicing: Sendable {
    func fetchNotes() async throws -> [Note]
}
```

Provide mock implementations for previews and tests. Avoid singletons for anything with state or side effects.

## Concurrency

- Use `async/await` and structured concurrency. Do not introduce new completion-handler APIs or Combine pipelines when `async` suffices.
- Mark UI-facing types `@MainActor`. Do heavy work off the main actor.
- Use `actor` to protect shared mutable state. Make cross-boundary types `Sendable` (value types are usually fine).
- Prefer `.task { }` in SwiftUI for work tied to a view's lifetime, since it cancels automatically. Use `.task(id:)` to restart on input change.
- Use `async let` and `TaskGroup` for parallel work. Check `Task.isCancelled` or call `try Task.checkCancellation()` in long loops.
- Never block with `DispatchSemaphore` or call `Thread.sleep` in async code. Use `try await Task.sleep(for:)`.
- Aim for clean builds under Swift 6 language mode and strict concurrency checking. Do not silence warnings with `@unchecked Sendable` or `nonisolated(unsafe)` unless you can justify it in a comment.

## Error handling

- Define domain errors as enums conforming to `Error` and `LocalizedError`.
- Use `throws` for recoverable failures. Catch at the layer that can act on the error (usually the view model) and convert to user-friendly text.
- Never use `try!`, and avoid `try?` when it hides an error you should report.
- **No force unwraps (`!`) and no force casts (`as!`)** outside of tests and truly impossible-to-fail cases, which must carry a comment. Use `guard let`, `if let`, nil-coalescing, or `throw`.
- Use `guard` for early exits to keep the happy path unindented.

```swift
enum NotesError: LocalizedError {
    case notSignedIn
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "You need to sign in to view notes."
        case .saveFailed: return "Your note could not be saved."
        }
    }
}
```

## Language style

Follow the Swift API Design Guidelines:
- Clarity at the point of use. Name by role, not type. Methods that read as grammatical phrases (`insert(_:at:)`).
- Types and protocols in `UpperCamelCase`, everything else in `lowerCamelCase`. Acronyms keep consistent case (`URLSession`, `userID`).
- Prefer `let` over `var`. Prefer `struct` and `enum` over `class`. Use `final class` when reference semantics are required.
- Use access control deliberately: default to `private` or `fileprivate`, widen only as needed. Mark classes `final` unless designed for subclassing.
- Use `enum` with associated values to model states instead of multiple booleans:

```swift
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}
```

- Use `switch` exhaustively without `default` when the enum is yours, so new cases cause compile errors.
- Prefer `Codable` with `CodingKeys` for JSON. Configure decoders with `.convertFromSnakeCase` and `.iso8601` where that matches the API.
- Use `Result`, optionals, and generics where they simplify code, not for their own sake.
- Avoid stringly typed code. Use enums, constants, and typed identifiers.

## SwiftUI practices

- Keep `body` cheap and free of side effects. Do not perform work or mutate state during view construction.
- Use `ForEach` with stable `Identifiable` ids. Never use array indices as ids for mutable lists.
- Prefer built-in components (`List`, `Form`, `LabeledContent`, `ContentUnavailableView`, `ProgressView`) and system styling.
- Extract repeated styling into `ViewModifier`s or `ButtonStyle`s in a `UI/Styles` folder. Centralize colors, spacing, and fonts as design tokens.
- Support Dynamic Type, Dark Mode, and different device sizes. Use semantic fonts (`.body`, `.headline`) and semantic colors.
- Accessibility is part of done: add `accessibilityLabel`, `accessibilityHint`, and `accessibilityValue` where the visual is not self-describing, and group elements sensibly.
- Localize user-facing strings with String Catalogs (`Localizable.xcstrings`) instead of hardcoding text where the app may be localized.
- Add `#Preview` for every view, using mock data and mock services.
- Use SF Symbols (`Image(systemName:)`) for icons.

## Persistence and security

- **SwiftData** (iOS 17+) for local models with `@Model`, `@Query`, and a `ModelContainer` configured at the app root. Use Core Data only when SwiftData's constraints block you or you support older OS versions.
- **UserDefaults / @AppStorage** only for small, non-sensitive preferences.
- **Keychain** for tokens, passwords, and anything sensitive. Wrap it in a small `KeychainStore` type. Never store secrets in UserDefaults, plists, or source.
- Keep API keys out of the repository. Use `.xcconfig` files that are gitignored, surfaced through Info.plist. Remember that anything shipped in the app binary can be extracted, so real secrets belong on a server.
- Use App Transport Security defaults (HTTPS only). Do not add blanket exceptions.
- Request permissions (camera, location, photos) at the moment of use, with accurate usage description strings in Info.plist.

## Networking

- Use `URLSession` with `async/await`. Wrap it in a small client that builds requests, validates status codes, and decodes into `Codable` models.
- Return typed errors and handle offline, timeout, and decoding failures distinctly.
- Do not add a third-party networking library unless it solves a real problem the project has.
- For a Supabase backend, see the supabase skill and its `references/swift-client.md`.

## Testing

- Use Swift Testing (`import Testing`, `@Test`, `#expect`) for new unit tests where the toolchain supports it, or XCTest otherwise. Use XCUITest for key UI flows.
- Test view models and services with mock dependencies. Make time, randomness, and network injectable.
- Name tests by behavior (`loadSetsErrorMessageWhenServiceFails`).
- Keep tests in a mirrored folder structure.

## Performance and quality

- Profile with Instruments before optimizing. Avoid premature optimization.
- Avoid retain cycles: use `[weak self]` in escaping closures that capture `self` on reference types, and prefer async/await to reduce closure use.
- Use `lazy` containers (`LazyVStack`, `List`) for long collections.
- Keep SwiftLint and SwiftFormat configs in the repo if the user uses them, and write code that passes them.
- Treat compiler warnings as defects and fix them.

## Checklist before delivering Swift work

- File header comment on every file, doc comments on non-trivial declarations
- One primary type per file, feature-based folders
- No force unwraps, `try!`, or `as!` without justification
- View models are `@MainActor`, services behind protocols, dependencies injected
- Concurrency uses async/await, no data race warnings
- Accessibility labels, Dynamic Type, and `#Preview` included
- Secrets in Keychain or config, never in source
- No em dashes, no emojis anywhere
