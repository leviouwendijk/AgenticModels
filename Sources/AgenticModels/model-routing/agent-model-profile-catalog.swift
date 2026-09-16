import Agentic
import Foundation

public struct AgentModelProfileCatalog: Sendable {
    public let profilesByIdentifier: [AgentModelProfileIdentifier: AgentModelProfile]

    public init(
        profiles: [AgentModelProfile] = []
    ) throws {
        var profilesByIdentifier: [AgentModelProfileIdentifier: AgentModelProfile] = [:]

        for profile in profiles {
            guard !profile.identifier.rawValue.isEmpty else {
                throw AgentModelRoutingError.emptyIdentifier(
                    "profile"
                )
            }

            guard !profile.gatewayIdentifier.rawValue.isEmpty else {
                throw AgentModelRoutingError.emptyIdentifier(
                    "gateway"
                )
            }

            guard !profile.model.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty else {
                throw AgentModelRoutingError.emptyModel(
                    profile.identifier
                )
            }

            profilesByIdentifier[profile.identifier] = profile
        }

        self.profilesByIdentifier = profilesByIdentifier
    }

    private init(
        validatedProfilesByIdentifier: [
            AgentModelProfileIdentifier: AgentModelProfile
        ]
    ) {
        self.profilesByIdentifier = validatedProfilesByIdentifier
    }

    public init(
        providers: [any AgentModelProfileProvider]
    ) throws {
        var profiles: [AgentModelProfile] = []

        for provider in providers {
            profiles.append(
                contentsOf: try provider.profiles()
            )
        }

        try self.init(
            profiles: profiles
        )
    }

    public func profile(
        _ identifier: AgentModelProfileIdentifier
    ) throws -> AgentModelProfile {
        guard let profile = profilesByIdentifier[identifier] else {
            throw AgentModelRoutingError.profileNotFound(
                identifier
            )
        }

        return profile
    }

    public func profiles(
        for purpose: AgentModelRoutePurpose
    ) -> [AgentModelProfile] {
        profilesByIdentifier.values
            .filter {
                $0.purposes.contains(
                    purpose
                )
            }
            .sorted(
                by: AgentModelProfileOrdering.preferred
            )
    }

    public func profiles(
        for modelID: AgentModelID
    ) -> [AgentModelProfile] {
        profilesByIdentifier.values
            .filter {
                $0.modelID == modelID
            }
            .sorted(
                by: AgentModelProfileOrdering.preferred
            )
    }

    public func routable(
        using gateways: AgentModelGatewayCatalog
    ) -> Self {
        var routable: [
            AgentModelProfileIdentifier: AgentModelProfile
        ] = [:]

        for (identifier, profile) in profilesByIdentifier {
            guard gateways.isAvailable(
                profile.gateway.id
            ) else {
                continue
            }

            routable[identifier] = profile
        }

        return .init(
            validatedProfilesByIdentifier: routable
        )
    }
}

private enum AgentModelProfileOrdering {
    static func preferred(
        lhs: AgentModelProfile,
        rhs: AgentModelProfile
    ) -> Bool {
        if lhs.cost.rank != rhs.cost.rank {
            return lhs.cost.rank < rhs.cost.rank
        }

        if lhs.latency.rank != rhs.latency.rank {
            return lhs.latency.rank < rhs.latency.rank
        }

        if lhs.privacy.rank != rhs.privacy.rank {
            return lhs.privacy.rank > rhs.privacy.rank
        }

        return lhs.identifier.rawValue < rhs.identifier.rawValue
    }
}

// providers
public extension AgentModelProfileCatalog {
    init(
        modelProviders: [any AgentModelProvider]
    ) throws {
        var providers: [any AgentModelProfileProvider] = []

        for modelProvider in modelProviders {
            providers.append(
                contentsOf: modelProvider.profileProviders
            )
        }

        try self.init(
            providers: providers
        )
    }

    static func discovered(
        from discoveries: [any AgentModelProfileDiscovery],
        request: AgentModelProfileDiscoveryRequest = .manual
    ) async throws -> AgentModelProfileCatalog {
        var snapshots: [AgentModelProfileSnapshot] = []

        for discovery in discoveries {
            snapshots.append(
                try await discovery.snapshot(
                    request: request
                )
            )
        }

        return try .init(
            snapshots: snapshots
        )
    }
}

