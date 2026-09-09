import Agentic

/// The observable result of one buffered broker invocation.
///
/// `route` is the exact route record produced for `response` and, when a
/// ledger is configured, the same value appended to that ledger.
public struct AgentModelBrokerResult: Sendable {
    public let response: AgentResponse
    public let route: AgentModelRouteRecord

    public init(
        response: AgentResponse,
        route: AgentModelRouteRecord
    ) {
        self.response = response
        self.route = route
    }
}
