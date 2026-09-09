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
            "broker-buffered-result",
            tags: [
                "agentic-models",
                "broker",
                "routing",
                "ledger",
            ]
        ) {
            try await AgenticModelsFlowTesting
                .runBrokerBufferedResult()
        },
    ]
}

enum AgenticModelsFlowTesting {}
