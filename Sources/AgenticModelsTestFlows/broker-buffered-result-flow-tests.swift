import Agentic
import AgenticModels
import TestFlows

extension AgenticModelsFlowTesting {
    static func runBrokerModelInvocation()
        async throws
        -> [TestFlowDiagnostic]
    {
        let profile = AgentModelProfile(
            identifier: "fixture.profile",
            adapterIdentifier: "fixture.adapter",
            model: "fixture-model"
        )
        let profiles = try AgentModelProfileCatalog(
            profiles: [
                profile,
            ]
        )
        let adapters = try AgentModelAdapterCatalog(
            adapters: [
                (
                    "fixture.adapter",
                    FixtureModelAdapter()
                ),
            ]
        )
        let ledger = MemoryAgentModelRouteLedger()
        let broker = AgentModelBroker(
            profiles: profiles,
            adapters: adapters,
            router: StaticAgentModelRouter(
                defaultProfileIdentifier: profile.identifier
            ),
            ledger: ledger
        )
        let result = try await broker.buffered(
            .init(
                request: .init(
                    messages: [
                        .init(
                            role: .user,
                            text: "hello"
                        ),
                    ],
                    metadata: [
                        "request_fixture": "present",
                    ]
                ),
                selection: .executor,
                metadata: [
                    "invocation_fixture": "present",
                ]
            )
        )
        let records = await ledger.list()

        try Expect.equal(
            result.response.metadata["fixture_response"],
            "true",
            "broker returns the provider-neutral adapter response"
        )
        try Expect.equal(
            result.response.usage?.totalTokens,
            5,
            "broker preserves response usage"
        )
        try Expect.equal(
            result.route.route.profile.identifier,
            profile.identifier,
            "invocation result exposes the selected profile"
        )
        try Expect.equal(
            result.route.requestMetadata["request_fixture"],
            "present",
            "route record preserves request metadata"
        )
        try Expect.equal(
            result.route.requestMetadata["invocation_fixture"],
            "present",
            "route record preserves invocation metadata"
        )
        try Expect.equal(
            result.route.responseMetadata["fixture_response"],
            "true",
            "route record preserves response metadata"
        )
        try Expect.equal(
            result.route.usage?.totalTokens,
            5,
            "route record preserves response usage"
        )
        try Expect.equal(
            records.count,
            1,
            "one model invocation creates one ledger record"
        )
        try Expect.equal(
            records.first,
            result.route,
            "broker returns the exact route record appended to the ledger"
        )
        try Expect.true(
            result.route.diagnostics.contains { diagnostic in
                diagnostic.code == .global_default_selected
            },
            "broker exposes the typed global-default routing diagnostic"
        )

        return [
            .field(
                "profile",
                result.route.route.profile.identifier.rawValue
            ),
            .field(
                "usage",
                String(result.route.usage?.totalTokens ?? 0)
            ),
            .field(
                "ledger_records",
                String(records.count)
            ),
        ]
    }

    static func runSelectionResolution()
        async throws
        -> [TestFlowDiagnostic]
    {
        let resolver = AgentModelSelectionResolver()
        let resolution = try resolver.resolve(
            [
                .init(
                    source: .mode_default,
                    selection: .init(
                        purpose: .coder,
                        requirements: .init(
                            capabilities: [
                                .text,
                            ],
                            minimumInputCapacity: 1_000
                        ),
                        preferences: .init(
                            preferredProfileIdentifier: "mode.profile"
                        ),
                        constraints: .init(
                            allowedAdapterIdentifiers: [
                                "fixture.adapter",
                                "other.adapter",
                            ],
                            maximumEstimatedUsd: 12
                        )
                    )
                ),
                .init(
                    source: .optimized_realization,
                    selection: .init(
                        purpose: .coder,
                        requirements: .init(
                            capabilities: [
                                .reasoning,
                            ],
                            minimumInputCapacity: 2_000
                        ),
                        preferences: .init(
                            preferredProfileIdentifier: "optimized.profile"
                        ),
                        constraints: .init(
                            allowedAdapterIdentifiers: [
                                "fixture.adapter",
                            ]
                        )
                    )
                ),
                .init(
                    source: .user,
                    selection: .init(
                        purpose: .coder,
                        requirements: .init(
                            capabilities: [],
                            minimumOutputCapacity: 400
                        ),
                        preferences: .init(
                            preferredProfileIdentifier: "user.profile"
                        ),
                        constraints: .init(
                            allowsExternal: false,
                            maximumEstimatedUsd: 2
                        )
                    )
                ),
            ]
        )

        try Expect.equal(
            resolution.selection.requirements.capabilities,
            Set<AgentModelCapability>([
                .text,
                .reasoning,
            ]),
            "requirements union required capabilities"
        )
        try Expect.equal(
            resolution.selection.requirements.minimumInputCapacity,
            2_000,
            "requirements retain the strictest minimum input capacity"
        )
        try Expect.equal(
            resolution.selection.requirements.minimumOutputCapacity,
            400,
            "requirements retain the strictest minimum output capacity"
        )
        try Expect.equal(
            resolution.selection.constraints.allowedAdapterIdentifiers,
            Set<AgentModelAdapterIdentifier>([
                "fixture.adapter",
            ]),
            "constraints intersect allowed adapters"
        )
        try Expect.false(
            resolution.selection.constraints.allowsExternal,
            "constraints cannot loosen external-provider restrictions"
        )
        try Expect.equal(
            resolution.selection.constraints.maximumEstimatedUsd,
            2,
            "constraints retain the lowest hard cost ceiling"
        )
        try Expect.equal(
            resolution.selection.preferences.preferredProfileIdentifier,
            AgentModelProfileIdentifier("user.profile"),
            "higher-precedence user preference overrides realization and mode preferences"
        )

        return [
            .field(
                "preferred_profile",
                resolution.selection.preferences
                    .preferredProfileIdentifier?.rawValue
                    ?? "<none>"
            ),
            .field(
                "minimum_input",
                String(
                    resolution.selection.requirements
                        .minimumInputCapacity
                        ?? 0
                )
            ),
            .field(
                "maximum_cost",
                String(
                    resolution.selection.constraints
                        .maximumEstimatedUsd
                        ?? 0
                )
            ),
        ]
    }

    static func runPreferenceFallback()
        async throws
        -> [TestFlowDiagnostic]
    {
        let rejected = AgentModelProfile(
            identifier: "rejected.profile",
            adapterIdentifier: "fixture.adapter",
            model: "rejected-model",
            purposes: [
                .executor,
            ]
        )
        let eligible = AgentModelProfile(
            identifier: "eligible.profile",
            adapterIdentifier: "fixture.adapter",
            model: "eligible-model",
            purposes: [
                .executor,
            ]
        )
        let catalog = try AgentModelProfileCatalog(
            profiles: [
                rejected,
                eligible,
            ]
        )
        let router = StaticAgentModelRouter()
        let result = try router.route(
            .init(
                selection: .init(
                    purpose: .executor,
                    preferences: .init(
                        preferredProfileIdentifier: rejected.identifier
                    ),
                    constraints: .init(
                        allowedProfileIdentifiers: [
                            eligible.identifier,
                        ]
                    )
                )
            ),
            catalog: catalog
        )

        try Expect.equal(
            result.route.profile.identifier,
            eligible.identifier,
            "hard constraints win over a rejected soft preference"
        )
        try Expect.true(
            result.diagnostics.contains { diagnostic in
                diagnostic.code
                    == .preference_rejected_by_constraint
            },
            "rejected preference is observable"
        )
        try Expect.true(
            result.diagnostics.contains { diagnostic in
                diagnostic.code == .fallback_selected
            },
            "fallback selection is observable"
        )
        try Expect.true(
            result.diagnostics.contains { diagnostic in
                diagnostic.code == .purpose_match_selected
            },
            "eligible same-purpose profile is selected deterministically"
        )

        return [
            .field(
                "selected_profile",
                result.route.profile.identifier.rawValue
            ),
            .field(
                "diagnostics",
                result.diagnostics
                    .map { diagnostic in
                        diagnostic.code.rawValue
                    }
                    .joined(separator: ",")
            ),
        ]
    }
}

private struct FixtureModelAdapter: AgentModelAdapter {
    var response: AgentModelResponseProviding {
        FixtureModelResponseProvider()
    }
}

private struct FixtureModelResponseProvider:
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
                text: "fixture response"
            ),
            stopReason: .end_turn,
            usage: .init(
                inputTokens: 3,
                outputTokens: 2,
                totalTokens: 5
            ),
            metadata: [
                "fixture_response": "true",
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
