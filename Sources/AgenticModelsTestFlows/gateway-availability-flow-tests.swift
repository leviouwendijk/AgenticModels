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

    static func runGatewayAwareRouting()
        async throws
        -> [TestFlowDiagnostic]
    {
        let availableA: AgentModelGatewayIdentifier =
            "fixture.gateway.available.a"
        let availableB: AgentModelGatewayIdentifier =
            "fixture.gateway.available.b"
        let unavailable: AgentModelGatewayIdentifier =
            "fixture.gateway.unavailable"
        let unknown: AgentModelGatewayIdentifier =
            "fixture.gateway.unknown"

        let profileA = AgentModelProfile(
            identifier: "fixture.profile.available.a",
            gateway: .init(
                id: availableA,
                model: "fixture-model-a"
            )
        )
        let profileB = AgentModelProfile(
            identifier: "fixture.profile.available.b",
            gateway: .init(
                id: availableB,
                model: "fixture-model-b"
            )
        )
        let unavailableProfile = AgentModelProfile(
            identifier: "fixture.profile.unavailable",
            gateway: .init(
                id: unavailable,
                model: "fixture-model-unavailable"
            )
        )

        let profiles = try AgentModelProfileCatalog(
            profiles: [
                profileA,
                profileB,
                unavailableProfile,
            ]
        )
        let gateways = try AgentModelGatewayCatalog(
            gateways: [
                GatewayAvailabilityFixtureGateway(
                    identifier: availableA
                ),
                GatewayAvailabilityFixtureGateway(
                    identifier: availableB
                ),
            ],
            unavailabilityByIdentifier: [
                unavailable: .init(
                    kind: .missing_configuration,
                    message: "Fixture endpoint is not configured.",
                    metadata: [
                        "variable": "FIXTURE_ENDPOINT",
                    ]
                ),
            ]
        )
        let routable = profiles.routable(
            using: gateways
        )
        let broker = AgentModelBroker(
            profiles: profiles,
            gateways: gateways
        )

        try Expect.equal(
            profiles.profilesByIdentifier.count,
            3,
            "declared catalog retains unavailable profiles"
        )
        try Expect.equal(
            routable.profilesByIdentifier.count,
            2,
            "routable catalog excludes unavailable gateway profiles"
        )
        try Expect.equal(
            broker.routableProfiles.profilesByIdentifier.count,
            2,
            "broker routes against the routable profile view"
        )

        let preferredGateway = try broker.route(
            selection: .init(
                purpose: .executor,
                preferences: .init(
                    gateway: availableB
                )
            )
        )

        try Expect.equal(
            preferredGateway.route.profile.identifier,
            profileB.identifier,
            "gateway preference selects the preferred available gateway"
        )
        try Expect.true(
            preferredGateway.diagnostics.contains { diagnostic in
                diagnostic.code == .preferred_gateway_selected
                    && diagnostic.metadata["gateway"]
                        == availableB.rawValue
            },
            "preferred gateway selection is observable"
        )

        let fallback = try broker.route(
            selection: .init(
                purpose: .executor,
                preferences: .init(
                    gateway: unavailable
                )
            )
        )

        try Expect.equal(
            fallback.route.profile.identifier,
            profileA.identifier,
            "unavailable soft gateway preference falls back deterministically"
        )
        try Expect.true(
            fallback.diagnostics.contains { diagnostic in
                diagnostic.code == .preference_unavailable
                    && diagnostic.metadata["gateway"]
                        == unavailable.rawValue
            },
            "unavailable soft gateway preference is observable"
        )
        try Expect.true(
            fallback.diagnostics.contains { diagnostic in
                diagnostic.code == .fallback_selected
            },
            "unavailable soft gateway preference records fallback"
        )

        do {
            _ = try broker.route(
                selection: .init(
                    purpose: .executor,
                    constraints: .init(
                        allowedProfileIdentifiers: [
                            unavailableProfile.identifier,
                        ]
                    )
                )
            )
            throw GatewayAvailabilityFixtureError
                .expectedProfileUnavailable
        } catch let error as AgentModelRoutingError {
            switch error {
            case .profileUnavailable(
                let profile,
                let gateway,
                let reason
            ):
                try Expect.equal(
                    profile,
                    unavailableProfile.identifier,
                    "unavailable exact profile preserves profile identity"
                )
                try Expect.equal(
                    gateway,
                    unavailable,
                    "unavailable exact profile preserves gateway identity"
                )
                try Expect.equal(
                    reason.kind,
                    .missing_configuration,
                    "unavailable exact profile preserves structured reason"
                )

            default:
                throw error
            }
        }

        let missingProfile: AgentModelProfileIdentifier =
            "fixture.profile.missing"

        do {
            _ = try broker.route(
                selection: .init(
                    purpose: .executor,
                    constraints: .init(
                        allowedProfileIdentifiers: [
                            missingProfile,
                        ]
                    )
                )
            )
            throw GatewayAvailabilityFixtureError
                .expectedProfileNotFound
        } catch let error as AgentModelRoutingError {
            switch error {
            case .profileNotFound(let profile):
                try Expect.equal(
                    profile,
                    missingProfile,
                    "missing exact profile remains not-found"
                )

            default:
                throw error
            }
        }

        do {
            _ = try broker.route(
                selection: .init(
                    purpose: .executor,
                    constraints: .init(
                        allowedGatewayIdentifiers: [
                            unavailable,
                        ]
                    )
                )
            )
            throw GatewayAvailabilityFixtureError
                .expectedGatewayUnavailable
        } catch let error as AgentModelRoutingError {
            switch error {
            case .gatewayUnavailable(
                let gateway,
                let reason
            ):
                try Expect.equal(
                    gateway,
                    unavailable,
                    "known unavailable gateway preserves identity"
                )
                try Expect.equal(
                    reason.metadata["variable"],
                    "FIXTURE_ENDPOINT",
                    "known unavailable gateway preserves structured reason"
                )

            default:
                throw error
            }
        }

        do {
            _ = try broker.route(
                selection: .init(
                    purpose: .executor,
                    constraints: .init(
                        allowedGatewayIdentifiers: [
                            unknown,
                        ]
                    )
                )
            )
            throw GatewayAvailabilityFixtureError
                .expectedGatewayNotFound
        } catch let error as AgentModelRoutingError {
            switch error {
            case .gatewayNotFound(let gateway):
                try Expect.equal(
                    gateway,
                    unknown,
                    "unknown gateway remains not-found"
                )

            default:
                throw error
            }
        }

        return [
            .field(
                "declared_profiles",
                String(profiles.profilesByIdentifier.count)
            ),
            .field(
                "routable_profiles",
                String(routable.profilesByIdentifier.count)
            ),
            .field(
                "preferred_gateway",
                preferredGateway.route.profile.gateway.id.rawValue
            ),
            .field(
                "fallback_gateway",
                fallback.route.profile.gateway.id.rawValue
            ),
        ]
    }
}

private enum GatewayAvailabilityFixtureError:
    Error
{
    case expectedAvailable
    case expectedUnavailable
    case expectedProfileUnavailable
    case expectedProfileNotFound
    case expectedGatewayUnavailable
    case expectedGatewayNotFound
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
