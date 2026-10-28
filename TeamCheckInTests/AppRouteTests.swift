// AppRouteTests.swift
// Purpose: Reject malformed or unrelated URLs and notification routing payloads.
import Foundation
import Testing
@testable import TeamCheckInCore

struct AppRouteTests {
    @Test func acceptsOnlyExactAppRoutes() {
        let id = UUID()
        #expect(AppRoute.parse(URL(string: "teamcheckin://game/\(id)")!) == .game(id))
        let token = String(repeating: "a", count: 48)
        #expect(AppRoute.parse(URL(string: "teamcheckin://join/\(token)")!) == .invite(token))
        for value in [
            "https://game/\(id)", "teamcheckin://game/\(id)?other=1",
            "teamcheckin://game/\(id)/extra", "teamcheckin://person@game/\(id)",
            "teamcheckin://game:123/\(id)", "teamcheckin://join/bad", "teamcheckin://unknown/\(id)",
        ] {
            #expect(AppRoute.parse(URL(string: value)!) == nil)
        }
    }
    @Test func notificationRequiresUUIDAndIgnoresMissingIdentifier() {
        let id = UUID()
        #expect(AppRoute.notification(gameID: id.uuidString) == .game(id))
        #expect(AppRoute.notification(gameID: nil) == nil)
        #expect(AppRoute.notification(gameID: "private text") == nil)
    }
    @MainActor @Test func inboxPreservesNewerTapAndRejectsMalformedInput() {
        let inbox = NotificationRouteInbox()
        let first = UUID(), second = UUID()
        inbox.receive(gameID: first.uuidString)
        inbox.receive(gameID: "bad")
        #expect(inbox.gameID == first)
        inbox.receive(gameID: second.uuidString)
        inbox.consume(first)
        #expect(inbox.gameID == second)
        inbox.consume(second)
        #expect(inbox.gameID == nil)
    }

}
