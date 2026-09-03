import Agentic

public struct AgentModelBrokerAdapter: AgentModelAdapter {
    private let provider: AgentModelBrokerResponseProvider

    public init(
        broker: AgentModelBroker,
        policy: AgentModelUsePolicy = .executor
    ) {
        self.provider = .init(
            broker: broker,
            policy: policy
        )
    }

    public var response: AgentModelResponseProviding {
        provider
    }
}

public struct AgentModelBrokerResponseProvider: AgentModelResponseProviding {
    public let broker: AgentModelBroker
    public let policy: AgentModelUsePolicy

    public init(
        broker: AgentModelBroker,
        policy: AgentModelUsePolicy = .executor
    ) {
        self.broker = broker
        self.policy = policy
    }

    public func buffered(
        request: AgentRequest
    ) async throws -> AgentResponse {
        try await broker.buffered(
            request: request,
            policy: policy
        )
    }

    public func buffered(
        request: AgentRequest,
        context: AgentModelInvocationContext
    ) async throws -> AgentResponse {
        try await broker.buffered(
            request: request,
            policy: policy,
            context: context
        )
    }

    public func stream(
        request: AgentRequest
    ) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        broker.stream(
            request: request,
            policy: policy
        )
    }

    public func stream(
        request: AgentRequest,
        context: AgentModelInvocationContext
    ) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        broker.stream(
            request: request,
            policy: policy,
            context: context
        )
    }
}
