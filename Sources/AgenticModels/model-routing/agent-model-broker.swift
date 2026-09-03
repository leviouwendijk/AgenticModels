import Agentic

public struct AgentModelBroker: Sendable, AgentAdvisorModelProviding {
    public let profiles: AgentModelProfileCatalog
    public let adapters: AgentModelAdapterCatalog
    public let router: any AgentModelRouter
    public let ledger: (any AgentModelRouteLedger)?

    public init(
        profiles: AgentModelProfileCatalog,
        adapters: AgentModelAdapterCatalog,
        router: any AgentModelRouter = StaticAgentModelRouter(),
        ledger: (any AgentModelRouteLedger)? = nil
    ) {
        self.profiles = profiles
        self.adapters = adapters
        self.router = router
        self.ledger = ledger
    }

    public func buffered(
        request: AgentRequest,
        policy: AgentModelUsePolicy = .executor
    ) async throws -> AgentResponse {
        try await buffered(
            request: request,
            policy: policy,
            context: .default
        )
    }

    public func buffered(
        request: AgentRequest,
        policy: AgentModelUsePolicy = .executor,
        context: AgentModelInvocationContext
    ) async throws -> AgentResponse {
        let routeResult = try route(
            request: request,
            policy: policy
        )
        let adapter = try adapters.adapter(
            for: routeResult.route.profile.adapterIdentifier
        )
        let routedRequest = request.routed(
            through: routeResult
        )
        let response = try await adapter.respond(
            request: routedRequest,
            context: context
        ).routed(
            through: routeResult
        )

        try await record(
            routeResult,
            request: routedRequest,
            response: response
        )

        return response
    }

    public func stream(
        request: AgentRequest,
        policy: AgentModelUsePolicy = .executor
    ) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        stream(
            request: request,
            policy: policy,
            context: .default
        )
    }

    public func stream(
        request: AgentRequest,
        policy: AgentModelUsePolicy = .executor,
        context: AgentModelInvocationContext
    ) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let routeResult = try route(
                        request: request,
                        policy: policy
                    )
                    let adapter = try adapters.adapter(
                        for: routeResult.route.profile.adapterIdentifier
                    )
                    let routedRequest = request.routed(
                        through: routeResult
                    )

                    for try await event in adapter.respond(
                        request: routedRequest,
                        delivery: .stream,
                        context: context
                    ) {
                        let routedEvent = event.routed(
                            through: routeResult
                        )

                        if case .completed(let response) = routedEvent {
                            try await record(
                                routeResult,
                                request: routedRequest,
                                response: response
                            )
                        }

                        continuation.yield(
                            routedEvent
                        )
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(
                        throwing: error
                    )
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func route(
        request: AgentRequest,
        policy: AgentModelUsePolicy = .executor
    ) throws -> AgentModelRouteResult {
        try router.route(
            .init(
                request: request,
                policy: policy
            ),
            catalog: profiles
        )
    }
}

private extension AgentModelBroker {
    func record(
        _ routeResult: AgentModelRouteResult,
        request: AgentRequest,
        response: AgentResponse
    ) async throws {
        try await ledger?.record(
            .init(
                route: routeResult.route,
                reasons: routeResult.reasons,
                warnings: routeResult.warnings,
                requestMetadata: request.metadata,
                responseMetadata: response.metadata,
                usage: response.usage
            )
        )
    }
}
