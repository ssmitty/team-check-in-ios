// NotificationRegistrationInbox.swift
// Purpose: Retain iOS registration callbacks until the live account dependency is ready.
import Foundation
import Observation

/// Tokens are transient app memory and are never written to preferences or logs.
@MainActor @Observable
final class NotificationRegistrationInbox {
    var token: Data?
    var failureID: UUID?
    func clear() { token = nil; failureID = nil }
}
