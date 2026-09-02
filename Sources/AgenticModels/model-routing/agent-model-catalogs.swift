import Agentic

public struct AgentModelCatalogs:
    Sendable
{
    public let profiles: AgentModelProfileCatalog
    public let adapters: AgentModelAdapterCatalog

    public init(
        modelProviders: [any AgentModelProvider],
        adapterOverrides: [
            (
                AgentModelAdapterIdentifier,
                any AgentModelAdapter
            )
        ] = []
    ) async throws {
        var realizedAdapters: [
            (
                AgentModelAdapterIdentifier,
                any AgentModelAdapter
            )
        ] = []

        realizedAdapters.reserveCapacity(
            modelProviders.count + adapterOverrides.count
        )

        for provider in modelProviders {
            guard let factory = provider.adapter else {
                continue
            }

            realizedAdapters.append(
                (
                    provider.descriptor.adapterIdentifier,
                    try await factory.make()
                )
            )
        }

        realizedAdapters.append(
            contentsOf: adapterOverrides
        )

        self.profiles = try AgentModelProfileCatalog(
            modelProviders: modelProviders
        )
        self.adapters = try AgentModelAdapterCatalog(
            adapters: realizedAdapters
        )
    }
}
