// InviteToken.swift
// Purpose: Validate invitation input before any redemption request.
import Foundation

/// Accepts only generated tokens or the app's exact invitation URL structure.
enum InviteToken {
    static func parse(_ input: String) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let token: String
        if trimmed.contains("://") {
            guard let url = URL(string: trimmed), url.scheme == "teamcheckin", url.host == "join",
                url.query == nil, url.fragment == nil, url.pathComponents.count == 2
            else {
                throw PrototypeError.invalidInvite
            }
            token = url.lastPathComponent
        } else {
            token = trimmed
        }
        guard token.count == 48, token.allSatisfy({ "0123456789abcdef".contains($0) }) else {
            throw PrototypeError.invalidInvite
        }
        return token
    }
}
