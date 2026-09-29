import Agentic
import AgenticModels
import TestFlows

extension AgenticModelsFlowTesting {
    static func runRoutingBoundaries() async throws -> [TestFlowDiagnostic] {
        let id: AgentModelGatewayIdentifier = "fixture.boundary"
        let gateway = BoundaryGateway(identifier: id)
        let failing = AgentModelGatewayFactory(identifier: id, resolve: {
            throw BoundaryFailure.superseded_factory_executed
        })
        let ready = AgentModelGatewayFactory(identifier: id, make: { gateway })
        let unavailable = AgentModelGatewayFactory(identifier: id, resolve: {
            .unavailable(.init(kind: .missing_configuration))
        })

        let injected = try await ModelCatalogs(
            modelProviders: [BoundaryIntegration(gateways: [failing])],
            gatewayFactories: [failing],
            gatewayOverrides: [gateway]
        )
        try Expect.equal(injected.gateways.isAvailable(id), true,
                         "realized override skips both factory layers")

        let replaced = try await ModelCatalogs(
            modelProviders: [BoundaryIntegration(gateways: [failing])],
            gatewayFactories: [ready]
        )
        try Expect.equal(replaced.gateways.isAvailable(id), true,
                         "explicit factory skips integration factory")

        let lastWins = try await ModelCatalogs(
            modelProviders: [BoundaryIntegration(gateways: [failing, ready])]
        )
        try Expect.equal(lastWins.gateways.isAvailable(id), true,
                         "only the last registration within a layer resolves")

        let disabled = try await ModelCatalogs(
            modelProviders: [BoundaryIntegration(gateways: [ready])],
            gatewayFactories: [unavailable]
        )
        try Expect.equal(disabled.gateways.isAvailable(id), false,
                         "unavailable override does not revive an older gateway")
        try Expect.equal(disabled.gateways.unavailability(for: id)?.kind,
                         .missing_configuration, "override retains its reason")

        let profile = AgentModelProfile(
            identifier: "fixture.boundary.profile",
            gateway: .init(id: id, model: "fixture")
        )
        let profiles = try ProfileCatalog(profiles: [profile])
        let gateways = try GatewayCatalog(gateways: [gateway])
        let unknown = AgentModelProfile(
            identifier: "fixture.unregistered",
            gateway: profile.gateway
        )
        var altered = profile
        altered.model = "different-target"

        let cases: [(AgentModelProfile, AgentModelRoutePurpose, AgentModelSelection, ModelBroker.Rejection)] = [
            (unknown, .executor, .executor, .unknown_profile(unknown.identifier)),
            (altered, .executor, .executor, .altered_profile(profile.identifier)),
            (profile, .reviewer, .executor, .purpose_mismatch),
            (profile, .executor, .init(
                purpose: .executor,
                constraints: .init(allowedProfileIdentifiers: [])
            ), .ineligible_profile(profile.identifier)),
        ]

        for (selected, purpose, selection, expected) in cases {
            let broker = ModelBroker(
                profiles: profiles,
                gateways: gateways,
                router: BoundaryRouter(profile: selected, purpose: purpose)
            )
            let invocation = AgentModelInvocation(
                request: .init(messages: [.init(role: .user, text: "fixture")]),
                selection: selection
            )
            do {
                _ = try await broker.buffered(invocation)
                throw BoundaryFailure.expected_rejection
            } catch let rejection as ModelBroker.Rejection {
                try Expect.equal(rejection, expected,
                                 "buffered invocation rejects invalid router output")
            }
            do {
                for try await _ in broker.stream(invocation) {}
                throw BoundaryFailure.expected_rejection
            } catch let rejection as ModelBroker.Rejection {
                try Expect.equal(rejection, expected,
                                 "streaming invocation rejects invalid router output")
            }
        }
        return [.field("rejection_cases", String(cases.count))]
    }
}

private enum BoundaryFailure: Error {
    case superseded_factory_executed
    case gateway_invoked
    case expected_rejection
}

private struct BoundaryIntegration: AgentModelProvider {
    let gateways: [AgentModelGatewayFactory]
    var descriptor: AgentModelProviderDescriptor {
        .init(source: "fixture.boundary", displayName: "Boundary")
    }
}

private struct BoundaryRouter: ModelRouter {
    let profile: AgentModelProfile
    let purpose: AgentModelRoutePurpose

    func route(
        _ request: AgentModelRouteRequest,
        catalog: ProfileCatalog
    ) throws -> AgentModelRouteResult {
        .init(route: .init(purpose: purpose, profile: profile))
    }
}

private struct BoundaryGateway: AgentModelGateway, AgentModelResponseProviding {
    let identifier: AgentModelGatewayIdentifier
    var response: AgentModelResponseProviding { self }

    func buffered(
        request: AgentRequest,
        route: AgentModelRoute,
        context: AgentModelInvocationContext
    ) async throws -> AgentResponse {
        throw BoundaryFailure.gateway_invoked
    }

    func stream(
        request: AgentRequest,
        route: AgentModelRoute,
        context: AgentModelInvocationContext
    ) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: BoundaryFailure.gateway_invoked)
        }
    }
}
