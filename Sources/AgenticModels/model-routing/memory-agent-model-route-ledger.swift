import Agentic

public actor MemoryModelRouteLedger: AgentModelRouteLedger {
    private var records: [AgentModelRouteRecord]

    public init(
        records: [AgentModelRouteRecord] = []
    ) {
        self.records = records
    }

    public func record(
        _ record: AgentModelRouteRecord
    ) async throws {
        records.append(
            record
        )
    }

    public func list() -> [AgentModelRouteRecord] {
        records
    }
}
