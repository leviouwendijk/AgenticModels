import TestFlows

@main
enum AgenticModelsFlowTestMain {
    static func main() async {
        await TestFlowCLI.run(
            suite: AgenticModelsFlowSuite.self
        )
    }
}

enum AgenticModelsFlowSuite: TestFlowRegistry {
    static let title = "AgenticModels flow tests"

    static let flows: [TestFlow] = [
        TestFlow(
            "broker-model-invocation",
            tags: [
                "agentic-models",
                "broker",
                "invocation",
                "routing",
                "ledger",
            ]
        ) {
            try await AgenticModelsFlowTesting
                .runBrokerModelInvocation()
        },
        TestFlow(
            "selection-resolution",
            tags: [
                "agentic-models",
                "selection",
                "resolution",
            ]
        ) {
            try await AgenticModelsFlowTesting
                .runSelectionResolution()
        },
        TestFlow(
            "preference-fallback",
            tags: [
                "agentic-models",
                "routing",
                "preferences",
                "constraints",
            ]
        ) {
            try await AgenticModelsFlowTesting
                .runPreferenceFallback()
        },
        TestFlow(
            "multiple-gateway-resolution",
            tags: [
                "agentic-models",
                "routing",
                "gateway",
                "multiple-gateways",
            ]
        ) {
            try await AgenticModelsFlowTesting
                .runMultipleGatewayResolution()
        },
        TestFlow(
            "gateway-availability-catalog",
            tags: [
                "agentic-models",
                "gateway",
                "availability",
                "catalog",
            ]
        ) {
            try await AgenticModelsFlowTesting
                .runGatewayAvailabilityCatalog()
        },
        TestFlow(
            "gateway-aware-routing",
            tags: [
                "agentic-models",
                "routing",
                "gateway",
                "availability",
                "preferences",
                "constraints",
            ]
        ) {
            try await AgenticModelsFlowTesting
                .runGatewayAwareRouting()
        },
    ]
}

enum AgenticModelsFlowTesting {}
