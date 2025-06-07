import Foundation
@testable import IndexStoreMCPService

class MockSymbolProvider: SymbolProvider {
    var isAvailableResult: ServiceStatus = ServiceStatus(available: true, error: nil)
    var symbolOccurrencesResult: SymbolOccurrences = SymbolOccurrences(symbols: [], location: "")
    var getOccurrencesResult: OccurrenceResults = OccurrenceResults(occurrences: [], usr: "", roles: [])
    var findCanonicalOccurrencesResult: PatternSearchResults = PatternSearchResults(occurrences: [], pattern: "", searchOptions: [])
    
    func isAvailable(projectName: String) -> ServiceStatus {
        return isAvailableResult
    }
    
    func symbolOccurrences(filePath: String, lineNumber: Int) -> SymbolOccurrences {
        return symbolOccurrencesResult
    }
    
    func getOccurrences(usr: String, roles: [String]) -> OccurrenceResults {
        return getOccurrencesResult
    }
    
    func findCanonicalOccurrences(pattern: String, options: [String]) -> PatternSearchResults {
        return findCanonicalOccurrencesResult
    }
} 