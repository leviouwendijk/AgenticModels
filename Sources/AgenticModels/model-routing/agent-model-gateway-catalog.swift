import Agentic

public struct AgentModelGatewayCatalog: Sendable {
    public let gatewaysByIdentifier: [
        AgentModelGatewayIdentifier: any AgentModelGateway
    ]

    public init(
        gateways: [any AgentModelGateway] = []
    ) throws {
        var gatewaysByIdentifier: [
            AgentModelGatewayIdentifier: any AgentModelGateway
        ] = [:]

        for gateway in gateways {
            let identifier = gateway.identifier

            guard !identifier.rawValue.isEmpty else {
                throw AgentModelRoutingError.emptyIdentifier(
                    "gateway"
                )
            }

            gatewaysByIdentifier[identifier] = gateway
        }

        self.gatewaysByIdentifier = gatewaysByIdentifier
    }

    public func gateway(
        for identifier: AgentModelGatewayIdentifier
    ) throws -> any AgentModelGateway {
        guard let gateway = gatewaysByIdentifier[identifier] else {
            throw AgentModelRoutingError.gatewayNotFound(
                identifier
            )
        }

        return gateway
    }
}
