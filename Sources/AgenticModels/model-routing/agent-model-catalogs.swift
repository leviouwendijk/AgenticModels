import Agentic

public struct ModelCatalogs:
    Sendable
{
    public let profiles: ProfileCatalog
    public let routableProfiles: ProfileCatalog
    public let gateways: GatewayCatalog

    public init(
        modelProviders: [any AgentModelProvider],
        gatewayFactories: [AgentModelGatewayFactory] = [],
        gatewayOverrides: [any AgentModelGateway] = []
    ) async throws {
        // Later registrations win within each layer. Explicit factories override
        // integration factories; realized gateways override both factory layers.
        // Choose registrations before resolving any environment or client.
        var factories: [AgentModelGatewayIdentifier: AgentModelGatewayFactory] = [:]
        for provider in modelProviders {
            for factory in provider.gateways {
                factories[factory.identifier] = factory
            }
        }
        for factory in gatewayFactories {
            factories[factory.identifier] = factory
        }

        var overrides: [AgentModelGatewayIdentifier: any AgentModelGateway] = [:]
        for gateway in gatewayOverrides {
            overrides[gateway.identifier] = gateway
            factories.removeValue(forKey: gateway.identifier)
        }

        let identifiers = Set(factories.keys).union(overrides.keys)
        for identifier in identifiers where identifier.rawValue.isEmpty {
            throw AgentModelRoutingError.emptyIdentifier("gateway")
        }

        let profiles = try ProfileCatalog(modelProviders: modelProviders)
        var realized: [any AgentModelGateway] = []
        var unavailable: [AgentModelGatewayIdentifier: AgentModelGatewayUnavailability] = [:]

        for identifier in identifiers.sorted(by: { $0.rawValue < $1.rawValue }) {
            try Task.checkCancellation()
            if let gateway = overrides[identifier] {
                realized.append(gateway)
            } else if let factory = factories[identifier] {
                switch try await factory.resolve() {
                case .available(let gateway):
                    realized.append(gateway)
                case .unavailable(let reason):
                    unavailable[identifier] = reason
                }
            }
        }

        let gateways = try GatewayCatalog(
            gateways: realized,
            unavailabilityByIdentifier: unavailable
        )

        self.profiles = profiles
        self.gateways = gateways
        self.routableProfiles = profiles.routable(
            using: gateways
        )
    }
}
