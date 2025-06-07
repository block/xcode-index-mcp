import Foundation
@testable import IndexStoreMCPService

class MockSymbolManager {
    private var loadingComplete = false
    
    func isAvailable(projectName: String) -> ServiceStatus {
        if !loadingComplete {
            return ServiceStatus(available: false, error: "Index is still loading")
        }
        return ServiceStatus(available: true, error: nil)
    }
    
    func symbolOccurrences(filePath: String, lineNumber: Int) -> SymbolOccurrences {
        let symbol = CodableSymbol(
            name: "mockFunction",
            kind: "function",
            location: "\(filePath):\(lineNumber)",
            usr: "s:8MockTest0A8FunctionyyF"
        )
        return SymbolOccurrences(
            symbols: [symbol],
            location: "\(filePath):\(lineNumber)"
        )
    }
    
    func getOccurrences(usr: String, roles: [String]) -> OccurrenceResults {
        let occurrence = CodableOccurrence(
            usr: usr,
            name: "mockFunction",
            location: "/test/file.swift:10",
            role: roles.first ?? "reference"
        )
        return OccurrenceResults(
            occurrences: [occurrence],
            usr: usr,
            roles: roles
        )
    }
    
    func findOccurrences(pattern: String, options: [String]) -> PatternSearchResults {
        let occurrence = CodableOccurrence(
            usr: "s:8MockTest0A8FunctionyyF",
            name: "mockFunction",
            location: "/test/file.swift:10",
            role: "definition"
        )
        return PatternSearchResults(
            occurrences: [occurrence],
            pattern: pattern,
            searchOptions: options
        )
    }
    
    // Simulate loading completion after delay
    func completeLoading() {
        loadingComplete = true
    }
}