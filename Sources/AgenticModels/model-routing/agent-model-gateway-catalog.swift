import Agentic

public struct AgentModelGatewayCatalog: Sendable {
    public let gatewaysByIdentifier: [
        AgentModelGatewayIdentifier: any AgentModelGateway
    ]
    public let unavailabilityByIdentifier: [
        AgentModelGatewayIdentifier: AgentModelGatewayUnavailability
    ]

    public init(
        gateways: [any AgentModelGateway] = [],
        unavailabilityByIdentifier: [
            AgentModelGatewayIdentifier: AgentModelGatewayUnavailability
        ] = [:]
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

        var retainedUnavailability: [
            AgentModelGatewayIdentifier: AgentModelGatewayUnavailability
        ] = [:]

        for (identifier, reason) in unavailabilityByIdentifier {
            guard !identifier.rawValue.isEmpty else {
                throw AgentModelRoutingError.emptyIdentifier(
                    "gateway"
                )
            }

            guard gatewaysByIdentifier[identifier] == nil else {
                continue
            }

            retainedUnavailability[identifier] = reason
        }

        self.gatewaysByIdentifier = gatewaysByIdentifier
        self.unavailabilityByIdentifier = retainedUnavailability
    }

    public var identifiers: Set<AgentModelGatewayIdentifier> {
        Set(gatewaysByIdentifier.keys)
            .union(unavailabilityByIdentifier.keys)
    }

    public func contains(
        _ identifier: AgentModelGatewayIdentifier
    ) -> Bool {
        gatewaysByIdentifier[identifier] != nil
            || unavailabilityByIdentifier[identifier] != nil
    }

    public func resolution(
        for identifier: AgentModelGatewayIdentifier
    ) -> AgentModelGatewayResolution? {
        if let gateway = gatewaysByIdentifier[identifier] {
            return .available(gateway)
        }

        if let reason = unavailabilityByIdentifier[identifier] {
            return .unavailable(reason)
        }

        return nil
    }

    public func unavailability(
        for identifier: AgentModelGatewayIdentifier
    ) -> AgentModelGatewayUnavailability? {
        unavailabilityByIdentifier[identifier]
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
