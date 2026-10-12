// BackendConfiguration.swift
// Purpose: Validate public backend settings without accepting privileged credentials.
import Foundation

/// Runtime configuration supplied through an ignored xcconfig file.
struct BackendConfiguration: Sendable {
    let url: URL
    let publicKey: String

    init(url: URL, publicKey: String) throws {
        guard url.scheme == "https", url.host != nil,
            publicKey.hasPrefix("sb_publishable_") || publicKey.hasPrefix("eyJ")
        else { throw BackendError.configuration }
        // Legacy JWT keys are allowed only when their embedded role is anon.
        if publicKey.hasPrefix("eyJ") {
            let parts = publicKey.split(separator: ".")
            guard parts.count == 3 else { throw BackendError.configuration }
            var encoded = String(parts[1]).replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
            guard let data = Data(base64Encoded: encoded),
                let claims = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                claims["role"] as? String == "anon"
            else { throw BackendError.configuration }
        }
        self.url = url
        self.publicKey = publicKey
    }

    static func load(bundle: Bundle = .main) throws -> Self? {
        guard let host = bundle.object(forInfoDictionaryKey: "SUPABASE_HOST") as? String,
            !host.isEmpty, !host.contains("$(")
        else { return nil }
        guard let url = URL(string: "https://" + host),
            let key = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String
        else { throw BackendError.configuration }
        return try Self(url: url, publicKey: key)
    }
}
