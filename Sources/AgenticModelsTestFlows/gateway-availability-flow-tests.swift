import Agentic
import AgenticModels
import TestFlows

extension AgenticModelsFlowTesting {
    static func runGatewayAvailabilityCatalog()
        async throws
        -> [TestFlowDiagnostic]
    {
        let availableIdentifier = AgentModelGatewayIdentifier(
            "fixture.gateway.available"
        )
        let unavailableIdentifier = AgentModelGatewayIdentifier(
            "fixture.gateway.unavailable"
        )

        let provider = GatewayAvailabilityFixtureProvider(
            availableIdentifier: availableIdentifier,
            unavailableIdentifier: unavailableIdentifier
        )
        let catalogs = try await AgentModelCatalogs(
            modelProviders: [provider]
        )

        try Expect.equal(
            catalogs.gateways.gatewaysByIdentifier.count,
            1,
            "only the realized gateway is present in the available gateway map"
        )
        try Expect.equal(
            catalogs.gateways.unavailabilityByIdentifier.count,
            1,
            "the unavailable gateway is retained separately"
        )
        try Expect.equal(
            catalogs.gateways.identifiers.count,
            2,
            "available and unavailable gateways remain known to the catalog"
        )
        try Expect.equal(
            catalogs.gateways.contains(availableIdentifier),
            true,
            "available gateway remains known"
        )
        try Expect.equal(
            catalogs.gateways.contains(unavailableIdentifier),
            true,
            "unavailable gateway remains known"
        )

        guard case .available(let availableGateway)? =
            catalogs.gateways.resolution(
                for: availableIdentifier
            )
        else {
            throw GatewayAvailabilityFixtureError.expectedAvailable
        }

        try Expect.equal(
            availableGateway.identifier,
            availableIdentifier,
            "available gateway resolution retains the realized gateway"
        )

        guard case .unavailable(let unavailability)? =
            catalogs.gateways.resolution(
                for: unavailableIdentifier
            )
        else {
            throw GatewayAvailabilityFixtureError.expectedUnavailable
        }

        try Expect.equal(
            unavailability.kind,
            .missing_configuration,
            "unavailable gateway retains its structured reason kind"
        )
        try Expect.equal(
            unavailability.metadata["variable"],
            "FIXTURE_ENDPOINT",
            "unavailable gateway retains structured reason metadata"
        )
        try Expect.equal(
            catalogs.gateways.unavailability(
                for: unavailableIdentifier
            )?.message,
            "Fixture endpoint is not configured.",
            "unavailability can be inspected directly by gateway identifier"
        )

        return [
            .field(
                "known_gateway_count",
                String(catalogs.gateways.identifiers.count)
            ),
            .field(
                "available_gateway_count",
                String(catalogs.gateways.gatewaysByIdentifier.count)
            ),
            .field(
                "unavailable_gateway_count",
                String(catalogs.gateways.unavailabilityByIdentifier.count)
            ),
            .field(
                "unavailability_kind",
                unavailability.kind.rawValue
            ),
        ]
    }
}

private enum GatewayAvailabilityFixtureError:
    Error
{
    case expectedAvailable
    case expectedUnavailable
}

private struct GatewayAvailabilityFixtureProvider:
    AgentModelProvider
{
    let availableIdentifier: AgentModelGatewayIdentifier
    let unavailableIdentifier: AgentModelGatewayIdentifier

    var descriptor: AgentModelProviderDescriptor {
        .init(
            source: "fixture_gateway_availability",
            displayName: "Fixture Gateway Availability"
        )
    }

    var gateways: [AgentModelGatewayFactory] {
        [
            .init(
                identifier: availableIdentifier,
                make: {
                    GatewayAvailabilityFixtureGateway(
                        identifier: availableIdentifier
                    )
                }
            ),
            .init(
                identifier: unavailableIdentifier,
                resolve: {
                    .unavailable(
                        .init(
                            kind: .missing_configuration,
                            message: "Fixture endpoint is not configured.",
                            metadata: [
                                "variable": "FIXTURE_ENDPOINT",
                            ]
                        )
                    )
                }
            ),
        ]
    }
}

private struct GatewayAvailabilityFixtureGateway:
    AgentModelGateway
{
    let identifier: AgentModelGatewayIdentifier

    var response: AgentModelResponseProviding {
        GatewayAvailabilityFixtureResponseProvider()
    }
}

private struct GatewayAvailabilityFixtureResponseProvider:
    AgentModelResponseProviding
{
    func buffered(
        request _: AgentRequest,
        route _: AgentModelRoute,
        context _: AgentModelInvocationContext
    ) async throws -> AgentResponse {
        .init(
            message: .init(
                role: .assistant,
                text: "fixture"
            ),
            stopReason: .end_turn
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
