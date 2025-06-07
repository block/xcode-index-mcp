import XCTest
@testable import IndexStoreMCPService
import IndexStoreDB

// MARK: - Tests
final class SymbolProviderTests: XCTestCase {
    // MARK: - Test Factory
    struct Factory {
        static func makeProvider(withMockReader: MockIndexReader? = nil) -> RealSymbolProvider {
            return RealSymbolProvider(indexReader: withMockReader)
        }
        
        static func makeMockReader(projectName: String = "TestProject") -> MockIndexReader {
            return MockIndexReader(projectName: projectName)
        }
    }
    
    func testIsAvailable_WhenReaderIsNil_ReturnsUnavailable() {
        // Given
        let provider = Factory.makeProvider()
        
        // When
        let status = provider.isAvailable(projectName: "TestProject")
        
        // Then
        XCTAssertFalse(status.available)
        XCTAssertNotNil(status.error)
    }
    
    func testIsAvailable_WhenReaderIsAvailable_ReturnsAvailable() {
        // Given
        let mockReader = Factory.makeMockReader()
        mockReader.isAvailableResult = .available
        let provider = Factory.makeProvider(withMockReader: mockReader)
        
        // When
        let status = provider.isAvailable(projectName: "TestProject")
        
        // Then
        XCTAssertTrue(status.available)
        XCTAssertNil(status.error)
    }
    
    func testSymbolOccurrences_WhenReaderIsNil_ReturnsEmptyResults() {
        // Given
        let provider = Factory.makeProvider()
        
        // When
        let result = provider.symbolOccurrences(filePath: "test.swift", lineNumber: 1)
        
        // Then
        XCTAssertTrue(result.symbols.isEmpty)
        XCTAssertEqual(result.location, "test.swift:1")
    }
    
    func testSymbolOccurrences_WhenReaderReturnsOccurrences_ReturnsMappedResults() {
        // Given
        let mockReader = Factory.makeMockReader()
        let mockSymbol = Symbol(
            usr: "test-usr",
            name: "testName",
            kind: .function,
            language: .swift
        )
        let mockOccurrence = SymbolOccurrence(
            symbol: mockSymbol,
            location: SymbolLocation(
                path: "test.swift",
                timestamp: Date(),
                moduleName: "TestModule",
                isSystem: false,
                line: 1,
                utf8Column: 1
            ),
            roles: .definition,
            symbolProvider: .swift
        )
        mockReader.symbolOccurrencesResult = [mockOccurrence]
        let provider = Factory.makeProvider(withMockReader: mockReader)
        
        // When
        let result = provider.symbolOccurrences(filePath: "test.swift", lineNumber: 1)
        
        // Then
        XCTAssertEqual(result.symbols.count, 1)
        XCTAssertEqual(result.symbols.first?.usr, "test-usr")
        XCTAssertEqual(result.location, "test.swift:1")
    }
    
    func testGetOccurrences_WhenReaderIsNil_ReturnsEmptyResults() {
        // Given
        let provider = Factory.makeProvider()
        
        // When
        let result = provider.getOccurrences(usr: "test-usr", roles: ["definition"])
        
        // Then
        XCTAssertTrue(result.occurrences.isEmpty)
        XCTAssertEqual(result.usr, "test-usr")
        XCTAssertEqual(result.roles, ["definition"])
    }
    
    func testGetOccurrences_WhenReaderReturnsOccurrences_ReturnsMappedResults() {
        // Given
        let mockReader = Factory.makeMockReader()
        let mockSymbol = Symbol(
            usr: "test-usr",
            name: "testName",
            kind: .function,
            language: .swift
        )
        let mockOccurrence = SymbolOccurrence(
            symbol: mockSymbol,
            location: SymbolLocation(
                path: "test.swift",
                timestamp: Date(),
                moduleName: "TestModule",
                isSystem: false,
                line: 1,
                utf8Column: 1
            ),
            roles: .definition,
            symbolProvider: .swift
        )
        mockReader.occurrencesResult = [mockOccurrence]
        let provider = Factory.makeProvider(withMockReader: mockReader)
        
        // When
        let result = provider.getOccurrences(usr: "test-usr", roles: ["definition"])
        
        // Then
        XCTAssertEqual(result.occurrences.count, 1)
        XCTAssertEqual(result.usr, "test-usr")
        XCTAssertEqual(result.roles, ["definition"])
    }
    
    func testFindCanonicalOccurrences_WhenReaderIsNil_ReturnsEmptyResults() {
        // Given
        let provider = Factory.makeProvider()
        
        // When
        let result = provider.findCanonicalOccurrences(pattern: "test", options: ["anchorStart"])
        
        // Then
        XCTAssertTrue(result.occurrences.isEmpty)
        XCTAssertEqual(result.pattern, "test")
        XCTAssertEqual(result.searchOptions, ["anchorStart"])
    }
    
    func testFindCanonicalOccurrences_WhenReaderReturnsOccurrences_ReturnsMappedResults() {
        // Given
        let mockReader = Factory.makeMockReader()
        let mockSymbol = Symbol(
            usr: "test-usr",
            name: "testName",
            kind: .function,
            language: .swift
        )
        let mockOccurrence = SymbolOccurrence(
            symbol: mockSymbol,
            location: SymbolLocation(
                path: "test.swift",
                timestamp: Date(),
                moduleName: "TestModule",
                isSystem: false,
                line: 1,
                utf8Column: 1
            ),
            roles: .definition,
            symbolProvider: .swift
        )
        mockReader.findCanonicalOccurrencesResult = [mockOccurrence]
        let provider = Factory.makeProvider(withMockReader: mockReader)
        
        // When
        let result = provider.findCanonicalOccurrences(pattern: "test", options: ["anchorStart"])
        
        // Then
        XCTAssertEqual(result.occurrences.count, 1)
        XCTAssertEqual(result.pattern, "test")
        XCTAssertEqual(result.searchOptions, ["anchorStart"])
    }
} 