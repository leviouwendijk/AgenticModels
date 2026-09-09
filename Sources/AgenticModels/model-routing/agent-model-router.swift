import Agentic

public protocol AgentModelRouter: Sendable {
    func route(
        _ request: AgentModelRouteRequest,
        catalog: AgentModelProfileCatalog
    ) throws -> AgentModelRouteResult
}

public struct StaticAgentModelRouter: AgentModelRouter {
    public var defaults: [AgentModelRoutePurpose: AgentModelProfileIdentifier]
    public var defaultProfileIdentifier: AgentModelProfileIdentifier?

    public init(
        defaults: [AgentModelRoutePurpose: AgentModelProfileIdentifier] = [:],
        defaultProfileIdentifier: AgentModelProfileIdentifier? = nil
    ) {
        self.defaults = defaults
        self.defaultProfileIdentifier = defaultProfileIdentifier
    }

    public func route(
        _ request: AgentModelRouteRequest,
        catalog: AgentModelProfileCatalog
    ) throws -> AgentModelRouteResult {
        let selection = request.selection
        let eligible = catalog.profiles(
            for: selection.purpose
        ).filter { profile in
            profile.supports(
                selection
            )
        }

        guard !eligible.isEmpty else {
            throw AgentModelRoutingError.noRoute(
                selection.purpose
            )
        }

        var diagnostics: [AgentModelSelectionDiagnostic] = []
        var preferenceFailed = false

        if let preferredProfileIdentifier =
            selection.preferences.preferredProfileIdentifier
        {
            if let profile = try? catalog.profile(
                preferredProfileIdentifier
            ) {
                if profile.supports(selection) {
                    diagnostics.append(
                        .init(
                            code: .preferred_profile_selected,
                            metadata: [
                                "profile": profile.identifier.rawValue,
                            ]
                        )
                    )

                    return result(
                        profile: profile,
                        request: request,
                        diagnostics: diagnostics
                    )
                }

                preferenceFailed = true
                diagnostics.append(
                    .init(
                        code: .preference_rejected_by_constraint,
                        severity: .warning,
                        message: "Preferred profile does not satisfy the effective model requirements or constraints.",
                        metadata: [
                            "profile": preferredProfileIdentifier.rawValue,
                        ]
                    )
                )
            } else {
                preferenceFailed = true
                diagnostics.append(
                    .init(
                        code: .preference_unavailable,
                        severity: .warning,
                        message: "Preferred model profile is unavailable.",
                        metadata: [
                            "profile": preferredProfileIdentifier.rawValue,
                        ]
                    )
                )
            }
        }

        if let preferredModelID = selection.preferences.preferredModelID {
            let matchingProfiles = catalog.profiles(
                for: preferredModelID
            )

            if matchingProfiles.isEmpty {
                preferenceFailed = true
                diagnostics.append(
                    .init(
                        code: .preference_unavailable,
                        severity: .warning,
                        message: "Preferred model is unavailable.",
                        metadata: [
                            "model": preferredModelID.rawValue,
                        ]
                    )
                )
            } else {
                let matchingEligible = ranked(
                    matchingProfiles.filter { profile in
                        profile.supports(selection)
                    },
                    preferences: selection.preferences
                )

                if let profile = matchingEligible.first {
                    diagnostics.append(
                        .init(
                            code: .preferred_model_selected,
                            metadata: [
                                "model": preferredModelID.rawValue,
                                "profile": profile.identifier.rawValue,
                            ]
                        )
                    )

                    return result(
                        profile: profile,
                        request: request,
                        diagnostics: diagnostics
                    )
                }

                preferenceFailed = true
                diagnostics.append(
                    .init(
                        code: .preference_rejected_by_constraint,
                        severity: .warning,
                        message: "Preferred model exists, but none of its profiles satisfy the effective model requirements or constraints.",
                        metadata: [
                            "model": preferredModelID.rawValue,
                        ]
                    )
                )
            }
        }

        if let defaultIdentifier = defaults[selection.purpose],
           let profile = try? catalog.profile(defaultIdentifier),
           profile.supports(selection)
        {
            appendFallbackDiagnostic(
                to: &diagnostics,
                if: preferenceFailed,
                profile: profile
            )
            diagnostics.append(
                .init(
                    code: .purpose_default_selected,
                    metadata: [
                        "profile": profile.identifier.rawValue,
                    ]
                )
            )

            return result(
                profile: profile,
                request: request,
                diagnostics: diagnostics
            )
        }

        if let defaultProfileIdentifier,
           let profile = try? catalog.profile(defaultProfileIdentifier),
           profile.supports(selection)
        {
            appendFallbackDiagnostic(
                to: &diagnostics,
                if: preferenceFailed,
                profile: profile
            )
            diagnostics.append(
                .init(
                    code: .global_default_selected,
                    metadata: [
                        "profile": profile.identifier.rawValue,
                    ]
                )
            )

            return result(
                profile: profile,
                request: request,
                diagnostics: diagnostics
            )
        }

        guard let profile = ranked(
            eligible,
            preferences: selection.preferences
        ).first else {
            throw AgentModelRoutingError.noRoute(
                selection.purpose
            )
        }

        appendFallbackDiagnostic(
            to: &diagnostics,
            if: preferenceFailed,
            profile: profile
        )
        diagnostics.append(
            .init(
                code: .purpose_match_selected,
                metadata: [
                    "profile": profile.identifier.rawValue,
                ]
            )
        )

        return result(
            profile: profile,
            request: request,
            diagnostics: diagnostics
        )
    }
}

private extension StaticAgentModelRouter {
    func result(
        profile: AgentModelProfile,
        request: AgentModelRouteRequest,
        diagnostics: [AgentModelSelectionDiagnostic]
    ) -> AgentModelRouteResult {
        var metadata = request.metadata
        metadata.merge(
            request.selection.metadata
        ) { _, new in
            new
        }

        return .init(
            route: .init(
                purpose: request.selection.purpose,
                profile: profile,
                metadata: metadata
            ),
            diagnostics: diagnostics
        )
    }

    func ranked(
        _ profiles: [AgentModelProfile],
        preferences: AgentModelPreferences
    ) -> [AgentModelProfile] {
        profiles.sorted { lhs, rhs in
            let lhsScore = preferenceScore(
                lhs,
                preferences: preferences
            )
            let rhsScore = preferenceScore(
                rhs,
                preferences: preferences
            )

            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }

            if lhs.cost.rank != rhs.cost.rank {
                return lhs.cost.rank < rhs.cost.rank
            }

            if lhs.latency.rank != rhs.latency.rank {
                return lhs.latency.rank < rhs.latency.rank
            }

            if lhs.privacy.rank != rhs.privacy.rank {
                return lhs.privacy.rank > rhs.privacy.rank
            }

            return lhs.identifier.rawValue < rhs.identifier.rawValue
        }
    }

    func preferenceScore(
        _ profile: AgentModelProfile,
        preferences: AgentModelPreferences
    ) -> Int {
        var score = 0

        if let cost = preferences.cost,
           profile.cost == cost {
            score += 2
        }

        if let latency = preferences.latency,
           profile.latency == latency {
            score += 1
        }

        return score
    }

    func appendFallbackDiagnostic(
        to diagnostics: inout [AgentModelSelectionDiagnostic],
        if preferenceFailed: Bool,
        profile: AgentModelProfile
    ) {
        guard preferenceFailed else {
            return
        }

        diagnostics.append(
            .init(
                code: .fallback_selected,
                message: "A preferred model selection could not be used; an eligible fallback profile was selected.",
                metadata: [
                    "profile": profile.identifier.rawValue,
                ]
            )
        )
    }
}
