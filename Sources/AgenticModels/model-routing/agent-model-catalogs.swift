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

        for provider in modelProviders {
            for factory in provider.gateways {
                realizedGateways.append(
                    try await factory.make()
                )
            }
        }

        realizedGateways.append(
            contentsOf: gatewayOverrides
        )

        self.profiles = try AgentModelProfileCatalog(
            modelProviders: modelProviders
        )
        self.gateways = try AgentModelGatewayCatalog(
            gateways: realizedGateways
        )
    }
}
