import Agentic
import AgenticModels
import TestFlows

extension AgenticModelsFlowTesting {
    static func runMultipleGatewayResolution()
        async throws
        -> [TestFlowDiagnostic]
    {
        let primaryGatewayIdentifier = AgentModelGatewayIdentifier(
            "fixture.gateway.primary"
        )
        let secondaryGatewayIdentifier = AgentModelGatewayIdentifier(
            "fixture.gateway.secondary"
        )

        let primaryProfile = AgentModelProfile(
            identifier: "fixture.profile.primary",
            gatewayIdentifier: primaryGatewayIdentifier,
            model: "fixture-model-primary"
        )
        let secondaryProfile = AgentModelProfile(
            identifier: "fixture.profile.secondary",
            gatewayIdentifier: secondaryGatewayIdentifier,
            model: "fixture-model-secondary"
        )

        let profiles = try AgentModelProfileCatalog(
            profiles: [
                primaryProfile,
                secondaryProfile,
            ]
        )
        let gateways = try AgentModelGatewayCatalog(
            gateways: [
                MultipleGatewayFixtureGateway(
                    identifier: primaryGatewayIdentifier
                ),
                MultipleGatewayFixtureGateway(
                    identifier: secondaryGatewayIdentifier
                ),
            ]
        )
        let broker = AgentModelBroker(
            profiles: profiles,
            gateways: gateways
        )

        let primaryResult = try await broker.buffered(
            .init(
                request: .init(
                    messages: [
                        .init(
                            role: .user,
                            text: "primary"
                        ),
                    ]
                ),
                selection: .init(
                    purpose: .executor,
                    preferences: .init(
                        preferredProfileIdentifier: primaryProfile.identifier
                    )
                )
            )
        )
        let secondaryResult = try await broker.buffered(
            .init(
                request: .init(
                    messages: [
                        .init(
                            role: .user,
                            text: "secondary"
                        ),
                    ]
                ),
                selection: .init(
                    purpose: .executor,
                    preferences: .init(
                        preferredProfileIdentifier: secondaryProfile.identifier
                    )
                )
            )
        )

        try Expect.equal(
            primaryResult.route.route.profile.gatewayIdentifier,
            primaryGatewayIdentifier,
            "primary profile retains its gateway identity"
        )
        try Expect.equal(
            secondaryResult.route.route.profile.gatewayIdentifier,
            secondaryGatewayIdentifier,
            "secondary profile retains its gateway identity"
        )
        try Expect.equal(
            primaryResult.response.metadata["fixture_gateway"],
            primaryGatewayIdentifier.rawValue,
            "broker dispatches the primary profile through its named gateway"
        )
        try Expect.equal(
            secondaryResult.response.metadata["fixture_gateway"],
            secondaryGatewayIdentifier.rawValue,
            "broker dispatches the secondary profile through its named gateway"
        )
        try Expect.equal(
            gateways.gatewaysByIdentifier.count,
            2,
            "two independently identified gateways coexist in one catalog"
        )

        return [
            .field(
                "primary_gateway",
                primaryGatewayIdentifier.rawValue
            ),
            .field(
                "secondary_gateway",
                secondaryGatewayIdentifier.rawValue
            ),
            .field(
                "gateway_count",
                String(gateways.gatewaysByIdentifier.count)
            ),
        ]
    }
}

private struct MultipleGatewayFixtureGateway:
    AgentModelGateway
{
    let identifier: AgentModelGatewayIdentifier

    var response: AgentModelResponseProviding {
        MultipleGatewayFixtureResponseProvider(
            gatewayIdentifier: identifier
        )
    }
}

private struct MultipleGatewayFixtureResponseProvider:
    AgentModelResponseProviding
{
    let gatewayIdentifier: AgentModelGatewayIdentifier

    func buffered(
        request _: AgentRequest,
        route _: AgentModelRoute,
        context _: AgentModelInvocationContext
    ) async throws -> AgentResponse {
        .init(
            message: .init(
                role: .assistant,
                text: gatewayIdentifier.rawValue
            ),
            stopReason: .end_turn,
            metadata: [
                "fixture_gateway": gatewayIdentifier.rawValue,
            ]
        )
    }

    func stream(
        request _: AgentRequest,
        route _: AgentModelRoute,
        context _: AgentModelInvocationContext
    ) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}
