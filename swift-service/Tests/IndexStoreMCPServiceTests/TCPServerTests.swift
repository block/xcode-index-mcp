import XCTest
@testable import IndexStoreMCPService
import IndexStoreDB

final class TCPServerTests: XCTestCase {
    // MARK: - Test Factory
    struct Factory {
        static func makeServer(
            port: UInt16 = 8080,
            symbolProvider: SymbolProvider? = nil
        ) -> TCPServer {
            return TCPServer(
                port: port,
                symbolProvider: symbolProvider ?? RealSymbolProvider()
            )
        }
        
        static func makeMockSymbolProvider() -> MockSymbolProvider {
            return MockSymbolProvider()
        }
    }
    
    // MARK: - Tests
    func testHandleRequest_IsAvailable_ReturnsCorrectResponse() {
        // Given
        let mockProvider = Factory.makeMockSymbolProvider()
        mockProvider.isAvailableResult = ServiceStatus(available: true, error: nil)
        let server = Factory.makeServer(symbolProvider: mockProvider)
        let request = MCPRequest(
            id: "1",
            method: "is_available",
            params: ["projectName": "TestProject"]
        )
        
        // When
        let response = server.handleRequest(request)
        
        // Then
        XCTAssertEqual(response.id, "1")
        XCTAssertNil(response.error)
        if case .status(let status) = response.result {
            XCTAssertTrue(status.available)
            XCTAssertNil(status.error)
        } else {
            XCTFail("Expected status result")
        }
    }
    
    func testHandleRequest_SymbolOccurrences_ReturnsCorrectResponse() {
        // Given
        let mockProvider = Factory.makeMockSymbolProvider()
        let mockSymbol = CodableSymbol(
            name: "testName",
            kind: "function",
            location: "test.swift:1",
            usr: "test-usr"
        )
        mockProvider.symbolOccurrencesResult = SymbolOccurrences(
            symbols: [mockSymbol],
            location: "test.swift:1"
        )
        let server = Factory.makeServer(symbolProvider: mockProvider)
        let request = MCPRequest(
            id: "1",
            method: "symbol_occurrences",
            params: [
                "filePath": "test.swift",
                "lineNumber": "1"
            ]
        )
        
        // When
        let response = server.handleRequest(request)
        
        // Then
        XCTAssertEqual(response.id, "1")
        XCTAssertNil(response.error)
        if case .symbols(let result) = response.result {
            XCTAssertEqual(result.symbols.count, 1)
            XCTAssertEqual(result.symbols.first?.usr, "test-usr")
            XCTAssertEqual(result.location, "test.swift:1")
        } else {
            XCTFail("Expected symbols result")
        }
    }
    
    func testHandleRequest_GetOccurrences_ReturnsCorrectResponse() {
        // Given
        let mockProvider = Factory.makeMockSymbolProvider()
        let mockOccurrence = CodableOccurrence(
            usr: "test-usr",
            name: "testName",
            location: "test.swift:1",
            role: "definition"
        )
        mockProvider.getOccurrencesResult = OccurrenceResults(
            occurrences: [mockOccurrence],
            usr: "test-usr",
            roles: ["definition"]
        )
        let server = Factory.makeServer(symbolProvider: mockProvider)
        let request = MCPRequest(
            id: "1",
            method: "get_occurrences",
            params: [
                "usr": "test-usr",
                "roles": "definition"
            ]
        )
        
        // When
        let response = server.handleRequest(request)
        
        // Then
        XCTAssertEqual(response.id, "1")
        XCTAssertNil(response.error)
        if case .occurrences(let result) = response.result {
            XCTAssertEqual(result.occurrences.count, 1)
            XCTAssertEqual(result.usr, "test-usr")
            XCTAssertEqual(result.roles, ["definition"])
        } else {
            XCTFail("Expected occurrences result")
        }
    }
    
    func testHandleRequest_FindCanonicalOccurrences_ReturnsCorrectResponse() {
        // Given
        let mockProvider = Factory.makeMockSymbolProvider()
        let mockOccurrence = CodableOccurrence(
            usr: "test-usr",
            name: "testName",
            location: "test.swift:1",
            role: "definition"
        )
        mockProvider.findCanonicalOccurrencesResult = PatternSearchResults(
            occurrences: [mockOccurrence],
            pattern: "test",
            searchOptions: ["anchorStart"]
        )
        let server = Factory.makeServer(symbolProvider: mockProvider)
        let request = MCPRequest(
            id: "1",
            method: "search_pattern",
            params: [
                "pattern": "test",
                "options": "anchorStart"
            ]
        )
        
        // When
        let response = server.handleRequest(request)
        
        // Then
        XCTAssertEqual(response.id, "1")
        XCTAssertNil(response.error)
        if case .patternSearch(let result) = response.result {
            XCTAssertEqual(result.occurrences.count, 1)
            XCTAssertEqual(result.pattern, "test")
            XCTAssertEqual(result.searchOptions, ["anchorStart"])
        } else {
            XCTFail("Expected pattern search result")
        }
    }
    
    func testHandleRequest_UnknownMethod_ReturnsError() {
        // Given
        let server = Factory.makeServer()
        let request = MCPRequest(
            id: "1",
            method: "unknown_method",
            params: [:]
        )
        
        // When
        let response = server.handleRequest(request)
        
        // Then
        XCTAssertEqual(response.id, "1")
        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error, "Unknown method")
    }
    
    func testHandleRequest_MissingParameters_ReturnsError() {
        // Given
        let server = Factory.makeServer()
        let request = MCPRequest(
            id: "1",
            method: "is_available",
            params: [:]
        )
        
        // When
        let response = server.handleRequest(request)
        
        // Then
        XCTAssertEqual(response.id, "1")
        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error, "Missing projectName parameter")
    }
} 