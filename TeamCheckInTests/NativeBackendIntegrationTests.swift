// NativeBackendIntegrationTests.swift
// Purpose: Verify the shipped Swift account/team/photo services with real isolated Auth, REST, and Storage responses.
#if os(macOS)
    import Foundation
    import Testing
    @testable import TeamCheckInCore

    @MainActor
    struct NativeBackendIntegrationTests {
        @Test(
            .enabled(
                if: ProcessInfo.processInfo.environment["TEAM_CHECK_IN_LOCAL_INTEGRATION"] == "1"))
        func liveServicesPreserveAccountPairPhotoAndWarmupPrivacy() async throws {
            let publicKey = try #require(
                ProcessInfo.processInfo.environment["TEAM_CHECK_IN_LOCAL_ANON_KEY"])
            var accounts: [NativeBackendAccount] = []
            for _ in 0..<7 {
                accounts.append(try await NativeBackendAccount.create(publicKey: publicKey))
            }
            let captain = accounts[0], outsider = accounts[6]
            try await captain.service.create(name: "Synthetic native team", displayName: "Captain")
            let team = try #require(try await captain.service.load(teamID: nil).teams.first)
            let invite = try InviteToken.parse(try await captain.service.invite(teamID: team.id))
            for account in accounts[1..<6] {
                try await account.service.join(token: invite, displayName: "Synthetic member")
                try await account.service.join(token: invite, displayName: "Synthetic member")
            }
            #expect(try await captain.service.load(teamID: team.id).roster.count == 6)
            #expect(try await outsider.service.load(teamID: team.id).teams.isEmpty)
            let game = makeGame(teamID: team.id, delay: 1800)
            try await captain.service.save(game: game)
            #expect(try await captain.service.teamID(forGame: game.id) == team.id)
            #expect(try await outsider.service.teamID(forGame: game.id) == nil)
            do {
                try await accounts[1].service.save(game: game);
                Issue.record("Member changed a schedule")
            } catch BackendError.rejected {}
            try await captain.service.generate(gameID: game.id)
            let snapshots = try await load(accounts: Array(accounts[0..<6]), teamID: team.id)
            let captainAssignment = try #require(snapshots[0].connections.first?.assignment_id)
            let authorIndex = try #require(
                (1..<6).first {
                    snapshots[$0].connections.first?.assignment_id != captainAssignment
                })
            let assignment = try #require(snapshots[authorIndex].connections.first?.assignment_id)
            let partnerIndex = try #require(
                (1..<6).first {
                    $0 != authorIndex
                        && snapshots[$0].connections.first?.assignment_id == assignment
                })
            try await verifyPrivateConnection(
                author: accounts[authorIndex], partner: accounts[partnerIndex],
                captain: captain, outsider: outsider, assignment: assignment, teamID: team.id,
                publicKey: publicKey)
            try await verifyPrivateParticipation(
                member: accounts[5], captain: captain, teamID: team.id)
            try await accounts[5].service.deleteAccount(password: accounts[5].password)
            #expect(accounts[5].client.userID == nil)
            #expect(accounts[5].vault.bytes == nil)
            try await verifyTrio(
                accounts: Array(accounts[0..<5]), captain: captain, teamID: team.id)
        }
        private func makeGame(teamID: UUID, delay: TimeInterval) -> LiveGame {
            LiveGame(
                id: UUID(), team_id: teamID, title: "Native fixture",
                starts_at: ISO8601DateFormatter().string(from: .now.addingTimeInterval(delay)),
                location: "Fixture warmups", time_zone_identifier: "America/New_York",
                is_canceled: false, assignments_generated_at: nil)
        }
        private func load(accounts: [NativeBackendAccount], teamID: UUID) async throws
            -> [LiveSnapshot]
        {
            var values: [LiveSnapshot] = []
            for account in accounts {
                values.append(try await account.service.load(teamID: teamID))
            }
            return values
        }
        private func verifyPrivateConnection(
            author: NativeBackendAccount, partner: NativeBackendAccount,
            captain: NativeBackendAccount, outsider: NativeBackendAccount, assignment: UUID,
            teamID: UUID, publicKey: String
        ) async throws {
            try await author.service.share(
                assignmentID: assignment, feeling: .nervous, support: .encouragement,
                note: "Synthetic Swift response")
            try await author.service.share(
                assignmentID: assignment, feeling: .nervous, support: .encouragement,
                note: "Synthetic Swift response")
            try await author.service.requestWarmup(assignmentID: assignment)
            try await author.service.requestWarmup(assignmentID: assignment)
            try await partner.service.acknowledgeWarmup(
                assignmentID: assignment, requesterID: try #require(author.client.userID))
            try await partner.service.encourage(
                assignmentID: assignment, recipientID: try #require(author.client.userID))
            let photos = PrivatePhotoService(client: author.client), photoID = UUID(),
                bytes = try integrationJPEG()
            try await photos.save(assignmentID: assignment, photoID: photoID, data: bytes)
            try await photos.save(assignmentID: assignment, photoID: photoID, data: bytes)
            let restored = try await partner.restoredService(publicKey: publicKey)
            let snapshot = try await restored.load(teamID: teamID)
            #expect(snapshot.responses.filter { $0.assignment_id == assignment }.count == 1)
            #expect(snapshot.responses.first?.note == "Synthetic Swift response")
            #expect(snapshot.warmupRequests.count == 1)
            #expect(snapshot.warmupAcknowledgments.count == 1)
            let photo = try #require(snapshot.photos.first)
            #expect(
                try await PrivatePhotoService(client: partner.client).download(photo: photo)
                    == bytes)
            #expect(try await captain.service.load(teamID: teamID).responses.isEmpty)
            #expect(try await captain.service.load(teamID: teamID).photos.isEmpty)
            do {
                _ = try await PrivatePhotoService(client: outsider.client).download(photo: photo);
                Issue.record("Outsider downloaded a photo")
            } catch BackendError.rejected {}
            try await photos.remove(photo: photo)
            #expect(try await partner.service.load(teamID: teamID).photos.isEmpty)
        }
        private func verifyPrivateParticipation(
            member: NativeBackendAccount, captain: NativeBackendAccount, teamID: UUID
        ) async throws {
            let game = makeGame(teamID: teamID, delay: 7200)
            try await captain.service.save(game: game)
            try await member.service.setParticipation(gameID: game.id, isOptedOut: true)
            #expect(try await member.service.load(teamID: teamID).optOuts.count == 1)
            #expect(try await captain.service.load(teamID: teamID).optOuts.isEmpty)
            try await member.service.setParticipation(gameID: game.id, isOptedOut: false)
            #expect(try await member.service.load(teamID: teamID).optOuts.isEmpty)
        }
        private func verifyTrio(
            accounts: [NativeBackendAccount], captain: NativeBackendAccount, teamID: UUID
        ) async throws {
            let game = makeGame(teamID: teamID, delay: 2400)
            try await captain.service.save(game: game)
            try await captain.service.generate(gameID: game.id)
            let snapshots = try await load(accounts: accounts, teamID: teamID)
            let trioIndex = try #require(
                snapshots.indices.first {
                    snapshots[$0].connections.filter { $0.game_id == game.id }.count == 3
                })
            let connection = try #require(
                snapshots[trioIndex].connections.first { $0.game_id == game.id })
            let author = accounts[trioIndex]
            let recipientIndex = try #require(
                accounts.indices.first {
                    $0 != trioIndex
                        && snapshots[$0].connections.contains {
                            $0.assignment_id == connection.assignment_id
                        }
                })
            try await author.service.requestWarmup(assignmentID: connection.assignment_id)
            try await accounts[recipientIndex].service.acknowledgeWarmup(
                assignmentID: connection.assignment_id,
                requesterID: try #require(author.client.userID))
            let snapshot = try await author.service.load(teamID: teamID)
            #expect(
                snapshot.warmupAcknowledgments.filter {
                    $0.assignment_id == connection.assignment_id
                }.count == 1)
            let members = Set(snapshot.connections.filter { $0.game_id == game.id }.map(\.user_id))
            #expect(members.count == 3)
        }
    }
#endif
