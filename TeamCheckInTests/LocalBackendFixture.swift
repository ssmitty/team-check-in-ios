// LocalBackendFixture.swift
// Purpose: Support opt-in Swift service integration against only the isolated loopback backend.
#if os(macOS) || os(iOS)
    import Foundation
    import CoreGraphics
    import ImageIO
    import UniformTypeIdentifiers
    #if canImport(TeamCheckIn)
        @testable import TeamCheckIn
    #else
        @testable import TeamCheckInCore
    #endif

    /// Redirects one reserved test host only in test bundles; never compiled into the shipped app module.
    @MainActor
    struct LocalBackendTransport: BackendTransport {
        let session = URLSession(configuration: .ephemeral)
        func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
            guard let source = request.url, source.scheme == "https",
                source.host == "native-integration.example",
                var parts = URLComponents(url: source, resolvingAgainstBaseURL: false)
            else { throw BackendError.configuration }
            parts.scheme = "http"; parts.host = "127.0.0.1"; parts.port = 54321
            guard let url = parts.url else { throw BackendError.configuration }
            var local = request; local.url = url
            return try await session.data(for: local)
        }
    }
    @MainActor
    final class IntegrationSessionVault: SessionStoring {
        var bytes: Data?
        func read() throws -> Data? { bytes }
        func write(_ data: Data) throws { bytes = data }
        func clear() throws { bytes = nil }
    }
    /// Synthetic account with isolated memory storage on Mac and real app Keychain storage on iOS.
    @MainActor
    struct NativeBackendAccount {
        let service: LiveTeamService
        let client: BackendClient
        let vault: any SessionStoring
        let password: String
        static func create(publicKey: String) async throws -> Self {
            #if os(iOS)
                let vault: any SessionStoring = SessionVault(
                    account: "native-backend-test." + UUID().uuidString)
            #else
                let vault: any SessionStoring = IntegrationSessionVault()
            #endif
            let config = try BackendConfiguration(
                url: URL(string: "https://native-integration.example")!, publicKey: publicKey)
            let client = BackendClient(
                config: config, network: LocalBackendTransport(), vault: vault)
            let service = LiveTeamService(client: client)
            let password = UUID().uuidString + "Aa9!"
            guard
                try await service.authenticate(
                    email: "native-\(UUID())@example.test", password: password, create: true)
            else {
                throw BackendError.invalidResponse
            }
            return Self(service: service, client: client, vault: vault, password: password)
        }
        func restoredService(publicKey: String) async throws -> LiveTeamService {
            let config = try BackendConfiguration(
                url: URL(string: "https://native-integration.example")!, publicKey: publicKey)
            let fresh = LiveTeamService(
                client: BackendClient(
                    config: config, network: LocalBackendTransport(), vault: vault))
            try await fresh.restore()
            return fresh
        }
    }

    /// Generates an original one-pixel JPEG for actual binary Storage transport verification.
    func integrationJPEG() throws -> Data {
        guard
            let context = CGContext(
                data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
            let image = context.makeImage()
        else { throw BackendError.invalidResponse }
        let data = NSMutableData()
        guard
            let output = CGImageDestinationCreateWithData(
                data, UTType.jpeg.identifier as CFString, 1, nil)
        else {
            throw BackendError.invalidResponse
        }
        CGImageDestinationAddImage(output, image, nil)
        guard CGImageDestinationFinalize(output) else { throw BackendError.invalidResponse }
        return data as Data
    }
#endif
