import Agentic
import AgenticModels
import TestFlows

extension AgenticModelsFlowTesting {
    static func runBrokerBufferedResult()
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
        let result = try await broker.bufferedResult(
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
            )
        )
        let records = await ledger.list()

        try Expect.equal(
            result.response.metadata["received_model"],
            "fixture-model",
            "broker routes the request through the selected profile model"
        )
        try Expect.equal(
            result.response.usage?.totalTokens,
            5,
            "broker preserves response usage"
        )
        try Expect.equal(
            result.route.route.profile.identifier,
            profile.identifier,
            "buffered result exposes the selected profile"
        )
        try Expect.equal(
            result.route.requestMetadata["request_fixture"],
            "present",
            "route record preserves routed request metadata"
        )
        try Expect.equal(
            result.route.responseMetadata["received_model"],
            "fixture-model",
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
            "one buffered invocation creates one ledger record"
        )
        try Expect.equal(
            records.first,
            result.route,
            "broker returns the exact route record appended to the ledger"
        )

        let compatibilityResponse = try await broker.buffered(
            request: .init(
                messages: [
                    .init(
                        role: .user,
                        text: "compatibility"
                    ),
                ]
            )
        )
        let compatibilityRecords = await ledger.list()

        try Expect.equal(
            compatibilityResponse.metadata["received_model"],
            "fixture-model",
            "existing buffered API remains operational"
        )
        try Expect.equal(
            compatibilityRecords.count,
            2,
            "existing buffered API uses the same recording path"
        )

        return [
            .field(
                "profile",
                result.route.route.profile.identifier.rawValue
            ),
            .field(
                "model",
                result.response.metadata["received_model"] ?? "<none>"
            ),
            .field(
                "usage",
                String(result.route.usage?.totalTokens ?? 0)
            ),
            .field(
                "ledger_records",
                String(compatibilityRecords.count)
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
        request: AgentRequest
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
                "received_model": request.model ?? "<none>",
            ]
        )
    }

    func stream(
        request _: AgentRequest
    ) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}
