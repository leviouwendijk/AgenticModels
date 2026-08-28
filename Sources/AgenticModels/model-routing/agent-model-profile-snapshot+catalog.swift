import Agentic

public extension AgentModelProfileCatalog {
    init(
        snapshot: AgentModelProfileSnapshot
    ) throws {
        try self.init(
            profiles: snapshot.profiles
        )
    }

    init(
        snapshots: [AgentModelProfileSnapshot]
    ) throws {
        try self.init(
            profiles: snapshots.flatMap(\.profiles)
        )
    }
}
