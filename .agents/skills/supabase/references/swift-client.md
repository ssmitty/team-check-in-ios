# Supabase with Swift (supabase-swift)

Read this when the project uses Supabase from iOS, macOS, or other Apple platforms. Pair with the `swift` and `coding-standards` skills. Verify API details against https://github.com/supabase/supabase-swift and the Supabase Swift docs, since the library evolves.

## Setup

Add the package in Xcode (File > Add Package Dependencies) or Package.swift:

```swift
.package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0")
```

Import the products you need (`Supabase` covers Auth, PostgREST, Storage, Realtime, Functions).

## Single client, configured once

Create one client and share it through dependency injection. Never put the service role key in the app. Only the project URL and the publishable (anon) key belong in the client.

```swift
//
//  SupabaseClientProvider.swift
//
//  Purpose: Creates the shared SupabaseClient used by all services.
//  Reads project URL and public key from app configuration.
//

import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? "")!
    static let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLIC_KEY") as? String ?? ""
}

extension SupabaseClient {
    static let shared = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.publicKey
    )
}
```

Load values from an `.xcconfig` file that is excluded from version control, surfaced through Info.plist. Do not hardcode keys in source.

## Models

Use `Codable` structs with `CodingKeys` mapping snake_case columns to camelCase properties. Separate read models from insert and update payloads so the client never sends server-owned fields (`id`, `created_at`).

```swift
struct Note: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var title: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case createdAt = "created_at"
    }
}

struct NewNote: Encodable, Sendable {
    let title: String
}
```

Do not send `user_id` from the client for ownership. Set it with a column default of `auth.uid()` or enforce with RLS `with check`.

## Service layer

Wrap Supabase calls in a protocol-backed service so view models depend on an abstraction and can be tested with a mock.

```swift
protocol NotesServicing: Sendable {
    func fetchNotes() async throws -> [Note]
    func addNote(_ note: NewNote) async throws -> Note
}

struct NotesService: NotesServicing {
    let client: SupabaseClient

    func fetchNotes() async throws -> [Note] {
        try await client
            .from("notes")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func addNote(_ note: NewNote) async throws -> Note {
        try await client
            .from("notes")
            .insert(note)
            .select()
            .single()
            .execute()
            .value
    }
}
```

Calls throw on failure, so use `do/catch` in the caller and surface a user-friendly message. Do not expose raw server errors in the UI.

## Auth

- Use `client.auth.signIn`, `signUp`, `signOut`, and observe `client.auth.authStateChanges` in an `async` loop owned by a long-lived object, cancelled on teardown.
- Session storage is handled by the SDK using the Keychain. Do not store tokens yourself.
- For OAuth and magic links, register a custom URL scheme or universal link and forward incoming URLs to `client.auth.session(from:)`.
- Sign in with Apple: use `ASAuthorizationAppleIDProvider`, then pass the identity token to `client.auth.signInWithIdToken`.
- Gate UI on auth state in one place (an app-level `AuthViewModel`), not in every screen.

## Storage

```swift
let path = "\(userId.uuidString)/avatar.jpg"
try await client.storage
    .from("avatars")
    .upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg", upsert: true))

let url = try await client.storage.from("avatars").createSignedURL(path: path, expiresIn: 3600)
```

Use per-user folder paths that match the storage RLS policies. Prefer signed URLs for private buckets.

## Realtime

Subscribe in a task tied to the view or view model lifecycle and cancel it when the screen disappears. Remove channels you no longer need so connections are released.

## Concurrency notes

- Service calls are `async`. Call them from `Task` blocks or `.task` modifiers, and update UI state on `@MainActor`.
- Keep models `Sendable` to satisfy Swift 6 strict concurrency.
- Cancel in-flight tasks when a screen goes away (`.task` does this automatically).
