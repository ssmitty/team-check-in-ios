// HostedBackendFixtureTests.swift
// Purpose: Prevent opt-in hosted integration from using other projects, real accounts, or exposed credentials.
#if os(macOS) || os(iOS)
    import Foundation
    import Testing

    struct HostedBackendFixtureTests {
        @Test
        func missingFixtureKeepsHostedTestingDisabled() throws {
            #expect(try HostedBackendFixture.load(path: nil) == nil)
        }

        @Test
        func explicitSyntheticFixtureCanLoad() throws {
            try withFixture { path in
                let fixture = try HostedBackendFixture.load(path: path)
                #expect(fixture?.accounts.count == 7)
            }
        }

        @Test
        func otherHostIsRejectedBeforeAnyNetworking() throws {
            try withFixture(host: "https://unrelated.example") { path in
                #expect(throws: CocoaError.self) { try HostedBackendFixture.load(path: path) }
            }
        }

        @Test
        func realAddressIsRejectedBeforeAnyNetworking() throws {
            try withFixture(email: "person@example.com") { path in
                #expect(throws: CocoaError.self) { try HostedBackendFixture.load(path: path) }
            }
        }

        @Test
        func readableCredentialsAreRejected() throws {
            try withFixture(permissions: 0o644) { path in
                #expect(throws: CocoaError.self) { try HostedBackendFixture.load(path: path) }
            }
        }

        /// Create private, synthetic input with no real identity or network side effect.
        private func withFixture(
            host: String = "https://jdwrtscsjilmnurmhrez.supabase.co",
            email: String? = nil, permissions: Int = 0o600,
            operation: (String) throws -> Void
        ) throws {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
                UUID().uuidString)
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            defer {
                do { try FileManager.default.removeItem(at: directory) } catch {
                    Issue.record("Synthetic fixture file cleanup failed")
                }
            }
            let accounts = (0..<7).map { index in
                [
                    "id": UUID().uuidString,
                    "email": index == 0
                        ? email ?? "hosted-review-0@example.test"
                        : "hosted-review-\(index)@example.test",
                    "password": UUID().uuidString + UUID().uuidString,
                ]
            }
            let data = try JSONSerialization.data(withJSONObject: [
                "url": host, "marker": "hosted-review-unit", "accounts": accounts,
            ])
            let file = directory.appendingPathComponent("fixture.json")
            try data.write(to: file)
            try FileManager.default.setAttributes(
                [.posixPermissions: permissions], ofItemAtPath: file.path)
            try operation(file.path)
        }
    }
#endif
