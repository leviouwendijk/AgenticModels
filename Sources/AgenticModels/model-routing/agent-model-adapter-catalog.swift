import Agentic

public struct AgentModelAdapterCatalog: Sendable {
    public let adaptersByIdentifier: [AgentModelAdapterIdentifier: any AgentModelAdapter]

    public init(
        adaptersByIdentifier: [AgentModelAdapterIdentifier: any AgentModelAdapter] = [:]
    ) throws {
        for identifier in adaptersByIdentifier.keys {
            guard !identifier.rawValue.isEmpty else {
                throw AgentModelRoutingError.emptyIdentifier(
                    "adapter"
                )
            }
        }

        self.adaptersByIdentifier = adaptersByIdentifier
    }

    public init(
        adapters: [(AgentModelAdapterIdentifier, any AgentModelAdapter)]
    ) throws {
        var adaptersByIdentifier: [AgentModelAdapterIdentifier: any AgentModelAdapter] = [:]

        for (identifier, adapter) in adapters {
            guard !identifier.rawValue.isEmpty else {
                throw AgentModelRoutingError.emptyIdentifier(
                    "adapter"
                )
            }

            adaptersByIdentifier[identifier] = adapter
        }

        try self.init(
            adaptersByIdentifier: adaptersByIdentifier
        )
    }

    public func adapter(
        for identifier: AgentModelAdapterIdentifier
    ) throws -> any AgentModelAdapter {
        guard let adapter = adaptersByIdentifier[identifier] else {
            throw AgentModelRoutingError.adapterNotFound(
                identifier
            )
        }

        return adapter
    }
}
