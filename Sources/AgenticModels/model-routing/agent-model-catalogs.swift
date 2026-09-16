import Agentic

public struct AgentModelCatalogs:
    Sendable
{
    public let profiles: AgentModelProfileCatalog
    public let routableProfiles: AgentModelProfileCatalog
    public let gateways: AgentModelGatewayCatalog

    public init(
        modelProviders: [any AgentModelProvider],
        gatewayFactories: [AgentModelGatewayFactory] = [],
        gatewayOverrides: [any AgentModelGateway] = []
    ) async throws {
        var realizedGateways: [any AgentModelGateway] = []
        var unavailabilityByIdentifier: [
            AgentModelGatewayIdentifier: AgentModelGatewayUnavailability
        ] = [:]

        for provider in modelProviders {
            for factory in provider.gateways {
                switch try await factory.resolve() {
                case .available(let gateway):
                    realizedGateways.append(gateway)
                    unavailabilityByIdentifier.removeValue(
                        forKey: factory.identifier
                    )

                case .unavailable(let reason):
                    unavailabilityByIdentifier[factory.identifier] = reason
                }
            }
        }

        for factory in gatewayFactories {
            realizedGateways.removeAll { gateway in
                gateway.identifier == factory.identifier
            }

            switch try await factory.resolve() {
            case .available(let gateway):
                realizedGateways.append(gateway)
                unavailabilityByIdentifier.removeValue(
                    forKey: factory.identifier
                )

            case .unavailable(let reason):
                unavailabilityByIdentifier[factory.identifier] = reason
            }
        }

        for gateway in gatewayOverrides {
            realizedGateways.removeAll { realized in
                realized.identifier == gateway.identifier
            }
            unavailabilityByIdentifier.removeValue(
                forKey: gateway.identifier
            )
            realizedGateways.append(gateway)
        }

        let profiles = try AgentModelProfileCatalog(
            modelProviders: modelProviders
        )
        let gateways = try AgentModelGatewayCatalog(
            gateways: realizedGateways,
            unavailabilityByIdentifier: unavailabilityByIdentifier
        )

        self.profiles = profiles
        self.gateways = gateways
        self.routableProfiles = profiles.routable(
            using: gateways
        )
    }
}
