import Agentic

public enum AgentModelSelectionSource:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case mode_default
    case optimized_realization
    case session
    case task
    case user
}

public struct AgentModelSelectionContribution:
    Sendable,
    Codable,
    Hashable
{
    public var source: AgentModelSelectionSource
    public var selection: AgentModelSelection
    public var metadata: [String: String]

    public init(
        source: AgentModelSelectionSource,
        selection: AgentModelSelection,
        metadata: [String: String] = [:]
    ) {
        self.source = source
        self.selection = selection
        self.metadata = metadata
    }
}

public struct AgentModelSelectionResolution:
    Sendable,
    Codable,
    Hashable
{
    public var selection: AgentModelSelection
    public var diagnostics: [AgentModelSelectionDiagnostic]

    public init(
        selection: AgentModelSelection,
        diagnostics: [AgentModelSelectionDiagnostic] = []
    ) {
        self.selection = selection
        self.diagnostics = diagnostics
    }
}

public enum AgentModelSelectionResolutionError:
    Error,
    Sendable,
    Hashable
{
    case empty_contributions
    case conflicting_purpose(
        expected: AgentModelRoutePurpose,
        actual: AgentModelRoutePurpose,
        source: AgentModelSelectionSource
    )
}

public struct AgentModelSelectionResolver: Sendable {
    public init() {}

    public func resolve(
        _ selection: AgentModelSelection
    ) throws -> AgentModelSelectionResolution {
        .init(
            selection: selection
        )
    }

    public func resolve(
        _ contributions: [AgentModelSelectionContribution]
    ) throws -> AgentModelSelectionResolution {
        guard !contributions.isEmpty else {
            throw AgentModelSelectionResolutionError
                .empty_contributions
        }

        let ordered = contributions
            .enumerated()
            .sorted { lhs, rhs in
                let lhsPrecedence = precedence(
                    lhs.element.source
                )
                let rhsPrecedence = precedence(
                    rhs.element.source
                )

                if lhsPrecedence != rhsPrecedence {
                    return lhsPrecedence < rhsPrecedence
                }

                return lhs.offset < rhs.offset
            }
            .map { element in
                element.element
            }

        let purpose = ordered[0].selection.purpose
        var requirements = AgentModelRequirements(
            capabilities: []
        )
        var preferences = AgentModelPreferences()
        var constraints = AgentModelConstraints()
        var metadata: [String: String] = [:]

        for contribution in ordered {
            guard contribution.selection.purpose == purpose else {
                throw AgentModelSelectionResolutionError
                    .conflicting_purpose(
                        expected: purpose,
                        actual: contribution.selection.purpose,
                        source: contribution.source
                    )
            }

            requirements = requirements.merging(
                contribution.selection.requirements
            )
            preferences = preferences.overriding(
                with: contribution.selection.preferences
            )
            constraints = constraints.tightened(
                by: contribution.selection.constraints
            )

            metadata.merge(
                contribution.selection.metadata
            ) { _, new in
                new
            }
            metadata.merge(
                contribution.metadata
            ) { _, new in
                new
            }
        }

        return .init(
            selection: .init(
                purpose: purpose,
                requirements: requirements,
                preferences: preferences,
                constraints: constraints,
                metadata: metadata
            )
        )
    }
}

private extension AgentModelSelectionResolver {
    func precedence(
        _ source: AgentModelSelectionSource
    ) -> Int {
        switch source {
        case .mode_default:
            0

        case .optimized_realization:
            100

        case .session,
             .task:
            200

        case .user:
            300
        }
    }
}
