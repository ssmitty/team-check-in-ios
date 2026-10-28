// HostedBackendFixture.swift
// Purpose: Gate real HTTPS integration behind explicitly provisioned synthetic development accounts.
// Notes: Test-only source. No administrative credential or email delivery is used.
#if os(macOS) || os(iOS)
    import Foundation

    /// Credentials for a disposable test identity, never an athlete account.
    struct HostedFixtureAccount: Decodable {
        let id: UUID
        let email: String
        let password: String
    }

    /// Restricts integration to the user-authorized development project and seven synthetic accounts.
    struct HostedBackendFixture: Decodable {
        let url: URL
        let marker: String
        let accounts: [HostedFixtureAccount]

        /// Reads a private fixture file only when explicitly requested by the test runner.
        static func load(
            path: String? = ProcessInfo.processInfo.environment["TEAM_CHECK_IN_HOSTED_FIXTURE"]
        ) throws -> Self? {
            guard let path
            else { return nil }
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            guard let permissions = attributes[.posixPermissions] as? NSNumber,
                permissions.intValue & 0o077 == 0
            else { throw CocoaError(.fileReadNoPermission) }
            let fixture = try JSONDecoder().decode(
                Self.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
            guard fixture.url.absoluteString == "https://jdwrtscsjilmnurmhrez.supabase.co",
                fixture.marker.hasPrefix("hosted-review-"), fixture.accounts.count == 7,
                Set(fixture.accounts.map(\.id)).count == 7,
                Set(fixture.accounts.map(\.email)).count == 7,
                fixture.accounts.allSatisfy({
                    $0.email.hasPrefix("hosted-review-") && $0.email.hasSuffix("@example.test")
                        && $0.password.count >= 32
                })
            else { throw CocoaError(.fileReadCorruptFile) }
            return fixture
        }
    }
#endif
