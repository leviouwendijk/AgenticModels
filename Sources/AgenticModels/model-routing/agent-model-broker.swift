import Agentic

public struct AgentModelBroker: Sendable, AgentModelInvoking {
    public let profiles: AgentModelProfileCatalog
    public let gateways: AgentModelGatewayCatalog
    public let router: any AgentModelRouter
    public let selectionResolver: AgentModelSelectionResolver
    public let ledger: (any AgentModelRouteLedger)?

    public init(
        profiles: AgentModelProfileCatalog,
        gateways: AgentModelGatewayCatalog,
        router: any AgentModelRouter = StaticAgentModelRouter(),
        selectionResolver: AgentModelSelectionResolver = .init(),
        ledger: (any AgentModelRouteLedger)? = nil
    ) {
        self.profiles = profiles
        self.gateways = gateways
        self.router = router
        self.selectionResolver = selectionResolver
        self.ledger = ledger
    }

    public func buffered(
        _ invocation: AgentModelInvocation
    ) async throws -> AgentModelInvocationResult {
        let prepared = try prepare(
            invocation
        )
        let gateway = try gateways.gateway(
            for: prepared.routeResult.route.profile.gatewayIdentifier
        )
        let response = try await gateway.respond(
            request: invocation.request,
            route: prepared.routeResult.route,
            context: invocation.context
        )
        let routeRecord = try await record(
            prepared.routeResult,
            requestMetadata: prepared.requestMetadata,
            response: response
        )

        return .init(
            response: response,
            route: routeRecord
        )
    }

    public func stream(
        _ invocation: AgentModelInvocation
    ) -> AsyncThrowingStream<AgentModelInvocationEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let prepared = try prepare(
                        invocation
                    )
                    let gateway = try gateways.gateway(
                        for: prepared.routeResult.route.profile.gatewayIdentifier
                    )

                    continuation.yield(
                        .routed(
                            prepared.routeResult
                        )
                    )

                    for try await event in gateway.respond(
                        request: invocation.request,
                        route: prepared.routeResult.route,
                        delivery: .stream,
                        context: invocation.context
                    ) {
                        switch event {
                        case .completed(let response):
                            let routeRecord = try await record(
                                prepared.routeResult,
                                requestMetadata: prepared.requestMetadata,
                                response: response
                            )

                            continuation.yield(
                                .completed(
                                    .init(
                                        response: response,
                                        route: routeRecord
                                    )
                                )
                            )

                        default:
                            continuation.yield(
                                .model(event)
                            )
                        }
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
        selection: AgentModelSelection,
        metadata: [String: String] = [:]
    ) throws -> AgentModelRouteResult {
        let resolution = try selectionResolver.resolve(
            selection
        )
        let routed = try router.route(
            .init(
                selection: resolution.selection,
                metadata: metadata
            ),
            catalog: profiles
        )

        return .init(
            route: routed.route,
            diagnostics:
                resolution.diagnostics
                + routed.diagnostics
        )
    }
}

private extension AgentModelBroker {
    struct PreparedInvocation {
        var routeResult: AgentModelRouteResult
        var requestMetadata: [String: String]
    }

    func prepare(
        _ invocation: AgentModelInvocation
    ) throws -> PreparedInvocation {
        var selection = invocation.selection
        selection.requirements = selection.requirements.merging(
            .init(
                capabilities:
                    invocation.request.responseFormat
                        .requiredCapabilities
            )
        )

        let resolution = try selectionResolver.resolve(
            selection
        )
        var requestMetadata = invocation.request.metadata
        requestMetadata.merge(
            invocation.metadata
        ) { _, new in
            new
        }

        let routed = try router.route(
            .init(
                selection: resolution.selection,
                metadata: requestMetadata
            ),
            catalog: profiles
        )

        return .init(
            routeResult: .init(
                route: routed.route,
                diagnostics:
                    resolution.diagnostics
                    + routed.diagnostics
            ),
            requestMetadata: requestMetadata
        )
    }

    @discardableResult
    func record(
        _ routeResult: AgentModelRouteResult,
        requestMetadata: [String: String],
        response: AgentResponse
    ) async throws -> AgentModelRouteRecord {
        let record = AgentModelRouteRecord(
            route: routeResult.route,
            diagnostics: routeResult.diagnostics,
            requestMetadata: requestMetadata,
            responseMetadata: response.metadata,
            usage: response.usage
        )

        try await ledger?.record(
            record
        )

        return record
    }
}
