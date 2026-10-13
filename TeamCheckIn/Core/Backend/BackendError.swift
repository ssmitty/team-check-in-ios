// BackendError.swift
// Purpose: Present safe, actionable auth and data errors without server details.
import Foundation

/// Recoverable failures at the backend boundary.
enum BackendError: LocalizedError {
    case configuration, signedOut, rejected(Int), invalidResponse, secureStorage, notificationRevoke
    var errorDescription: String? {
        switch self {
        case .configuration: "Backend settings are invalid. Check the development configuration."
        case .signedOut: "Sign in to continue."
        case .rejected(let status):
            status == 401
                ? "Your session expired. Sign in again."
                : "Couldn't complete that. Check your details and connection, then try again."
        case .invalidResponse: "Couldn't read the server response. Refresh and try again."
        case .notificationRevoke:
            "Signed out locally and stopped device alerts. Server registration removal could not be confirmed."
        case .secureStorage: "Couldn't securely save your session. Please try signing in again."
        }
    }
}
