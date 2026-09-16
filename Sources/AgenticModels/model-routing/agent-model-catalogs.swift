import Agentic

public struct AgentModelCatalogs:
    Sendable
{
    public let profiles: AgentModelProfileCatalog
    public let gateways: AgentModelGatewayCatalog

    public init(
        modelProviders: [any AgentModelProvider],
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

        for gateway in gatewayOverrides {
            unavailabilityByIdentifier.removeValue(
                forKey: gateway.identifier
            )
        }

        realizedGateways.append(
            contentsOf: gatewayOverrides
        )

        self.profiles = try AgentModelProfileCatalog(
            modelProviders: modelProviders
        )
        self.gateways = try AgentModelGatewayCatalog(
            gateways: realizedGateways,
            unavailabilityByIdentifier: unavailabilityByIdentifier
        )
    }
}
