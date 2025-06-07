import XCTest
@testable import IndexStoreMCPService
import IndexStoreDB

class MockIndexReader: IndexReader {
    var projectName: String
    var isAvailableResult: ReaderStatus = .available
    var symbolOccurrencesResult: [SymbolOccurrence] = []
    var occurrencesResult: [SymbolOccurrence] = []
    var findCanonicalOccurrencesResult: [SymbolOccurrence] = []
    
    init(projectName: String) {
        self.projectName = projectName
    }
    
    func isAvailable() -> ReaderStatus {
        return isAvailableResult
    }
    
    func symbolOccurrences(inFilePath: String, lineNumber: Int) throws -> [SymbolOccurrence] {
        return symbolOccurrencesResult
    }
    
    func occurrences(ofUSR: String, roles: SymbolRole) -> [SymbolOccurrence] {
        return occurrencesResult
    }
    
    func findCanonicalOccurrences(matching: String, anchorStart: Bool, anchorEnd: Bool, subsequence: Bool, ignoreCase: Bool) -> [SymbolOccurrence] {
        return findCanonicalOccurrencesResult
    }
} 