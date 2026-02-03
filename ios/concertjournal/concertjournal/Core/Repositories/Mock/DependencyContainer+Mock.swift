//
//  DependencyContainer+Mock.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.02.26.
//

extension DependencyContainer {

    static func preview(scenario: PreviewDependencyContainer.PreviewScenario = .happyPath) -> PreviewDependencyContainer {
        return PreviewDependencyContainer(scenario: scenario)
    }
}
