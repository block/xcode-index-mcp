import XCTest
@testable import IndexStoreMCPService

final class IndexStoreMCPServiceTests: XCTestCase {
    
    var manager: MockSymbolManager!
    
    override func setUp() {
        super.setUp()
        manager = MockSymbolManager()
    }
    
    override func tearDown() {
        manager = nil
        super.tearDown()
    }
    
    func testServiceAvailability() {
        let status = manager.isAvailable(projectName: "TestProject")
        XCTAssertFalse(status.available, "Initial status should not be available")
        XCTAssertEqual(status.error, "Index is still loading", "Initial error should indicate loading")
        
        // Simulate loading completion
        manager.completeLoading()
        
        let updatedStatus = manager.isAvailable(projectName: "TestProject")
        XCTAssertTrue(updatedStatus.available, "Status should be available after loading")
        XCTAssertNil(updatedStatus.error, "Error should be nil when available")
    }
    
    func testSymbolOccurrences() {
        let filePath = "/test/file.swift"
        let lineNumber = 10
        
        let result = manager.symbolOccurrences(filePath: filePath, lineNumber: lineNumber)
        
        XCTAssertFalse(result.symbols.isEmpty, "Should return some symbols")
        XCTAssertEqual(result.location, "\(filePath):\(lineNumber)", "Location should match input")
        
        let symbol = result.symbols.first
        XCTAssertNotNil(symbol, "Should have at least one symbol")
        XCTAssertEqual(symbol?.kind, "function", "Should be a function symbol")
        XCTAssertEqual(symbol?.name, "mockFunction", "Should have correct name")
        XCTAssertEqual(symbol?.usr, "s:8MockTest0A8FunctionyyF", "Should have correct USR")
    }
    
    func testGetOccurrences() {
        let usr = "s:8MockTest0A8FunctionyyF"
        let roles = ["reference"]
        
        let result = manager.getOccurrences(usr: usr, roles: roles)
        
        XCTAssertFalse(result.occurrences.isEmpty, "Should return some occurrences")
        XCTAssertEqual(result.usr, usr, "USR should match input")
        XCTAssertEqual(result.roles, roles, "Roles should match input")
        
        let occurrence = result.occurrences.first
        XCTAssertNotNil(occurrence, "Should have at least one occurrence")
        XCTAssertEqual(occurrence?.role, "reference", "Role should match input")
        XCTAssertEqual(occurrence?.usr, usr, "USR should match")
        XCTAssertEqual(occurrence?.name, "mockFunction", "Should have correct name")
        XCTAssertEqual(occurrence?.location, "/test/file.swift:10", "Should have correct location")
    }

    func testPatternSearch() {
        let pattern = "mockFunction"
        let options = ["anchorStart", "ignoreCase"]
        
        let result = manager.findOccurrences(pattern: pattern, options: options)
        
        XCTAssertFalse(result.occurrences.isEmpty, "Should return some occurrences")
        XCTAssertEqual(result.pattern, pattern, "Pattern should match input")
        XCTAssertEqual(result.searchOptions, options, "Options should match input")
        
        let occurrence = result.occurrences.first
        XCTAssertNotNil(occurrence, "Should have at least one occurrence")
        XCTAssertEqual(occurrence?.name, "mockFunction", "Should have correct name")
        XCTAssertEqual(occurrence?.location, "/test/file.swift:10", "Should have correct location")
        XCTAssertEqual(occurrence?.usr, "s:8MockTest0A8FunctionyyF", "Should have correct USR")
    }
    
    func testMCPRequestCreation() {
        // Test is_available request
        let availabilityRequest = MCPRequest(
            id: "test-1",
            method: "is_available",
            params: ["projectName": "TestProject"]
        )
        XCTAssertEqual(availabilityRequest.method, "is_available")
        XCTAssertEqual(availabilityRequest.params["projectName"], "TestProject")
        
        // Test symbol_occurrences request
        let symbolRequest = MCPRequest(
            id: "test-2",
            method: "symbol_occurrences",
            params: [
                "filePath": "/test/file.swift",
                "lineNumber": "10"
            ]
        )
        XCTAssertEqual(symbolRequest.method, "symbol_occurrences")
        XCTAssertEqual(symbolRequest.params["filePath"], "/test/file.swift")
        XCTAssertEqual(symbolRequest.params["lineNumber"], "10")
        
        // Test get_occurrences request
        let occurrencesRequest = MCPRequest(
            id: "test-3",
            method: "get_occurrences",
            params: [
                "usr": "test-usr",
                "roles": "reference,definition"
            ]
        )
        XCTAssertEqual(occurrencesRequest.method, "get_occurrences")
        XCTAssertEqual(occurrencesRequest.params["roles"], "reference,definition")

        // Test search_pattern request
        let patternRequest = MCPRequest(
            id: "test-4",
            method: "search_pattern",
            params: [
                "pattern": "TestPattern",
                "options": "anchorStart,ignoreCase"
            ]
        )
        XCTAssertEqual(patternRequest.method, "search_pattern")
        XCTAssertEqual(patternRequest.params["pattern"], "TestPattern")
        XCTAssertEqual(patternRequest.params["options"], "anchorStart,ignoreCase")
    }
    
    func testMCPResponseCreation() {
        // Test is_available response
        let statusResponse = MCPResponse(
            id: "test-1",
            result: .status(ServiceStatus(available: true, error: nil)),
            error: nil
        )
        XCTAssertEqual(statusResponse.id, "test-1")
        XCTAssertNil(statusResponse.error)
        
        // Test symbol_occurrences response
        let symbols = [
            CodableSymbol(
                name: "TestSymbol",
                kind: "class",
                location: "/test/file.swift:10",
                usr: "test-usr"
            )
        ]
        let symbolsResult = SymbolOccurrences(
            symbols: symbols,
            location: "/test/file.swift:10"
        )
        let symbolsResponse = MCPResponse(
            id: "test-2",
            result: .symbols(symbolsResult),
            error: nil
        )
        XCTAssertEqual(symbolsResponse.id, "test-2")
        XCTAssertNil(symbolsResponse.error)
        
        // Test get_occurrences response
        let occurrences = [
            CodableOccurrence(
                usr: "test-usr",
                name: "TestSymbol",
                location: "/test/file.swift:10",
                role: "reference"
            )
        ]
        let occurrencesResult = OccurrenceResults(
            occurrences: occurrences,
            usr: "test-usr",
            roles: ["reference"]
        )
        let occurrencesResponse = MCPResponse(
            id: "test-3",
            result: .occurrences(occurrencesResult),
            error: nil
        )
        XCTAssertEqual(occurrencesResponse.id, "test-3")
        XCTAssertNil(occurrencesResponse.error)

        // Test pattern search response
        let patternOccurrences = [
            CodableOccurrence(
                usr: "test-usr",
                name: "TestPattern",
                location: "/test/file.swift:10",
                role: "definition"
            )
        ]
        let patternResult = PatternSearchResults(
            occurrences: patternOccurrences,
            pattern: "TestPattern",
            searchOptions: ["anchorStart", "ignoreCase"]
        )
        let patternResponse = MCPResponse(
            id: "test-4",
            result: .patternSearch(patternResult),
            error: nil
        )
        XCTAssertEqual(patternResponse.id, "test-4")
        XCTAssertNil(patternResponse.error)
    }
    
    func testMCPResponseResultCoding() throws {
        // Test encoding/decoding status
        let status = ServiceStatus(available: true, error: nil)
        let statusResult = MCPResponseResult.status(status)
        let statusData = try JSONEncoder().encode(statusResult)
        let decodedStatusResult = try JSONDecoder().decode(MCPResponseResult.self, from: statusData)
        
        if case .status(let decodedStatus) = decodedStatusResult {
            XCTAssertTrue(decodedStatus.available)
            XCTAssertNil(decodedStatus.error)
        } else {
            XCTFail("Decoded result should be status")
        }
        
        // Test encoding/decoding symbols
        let symbols = SymbolOccurrences(
            symbols: [
                CodableSymbol(
                    name: "TestSymbol",
                    kind: "class",
                    location: "/test/file.swift:10",
                    usr: "test-usr"
                )
            ],
            location: "/test/file.swift:10"
        )
        let symbolsResult = MCPResponseResult.symbols(symbols)
        let symbolsData = try JSONEncoder().encode(symbolsResult)
        let decodedSymbolsResult = try JSONDecoder().decode(MCPResponseResult.self, from: symbolsData)
        
        if case .symbols(let decodedSymbols) = decodedSymbolsResult {
            XCTAssertEqual(decodedSymbols.symbols.first?.name, "TestSymbol")
            XCTAssertEqual(decodedSymbols.symbols.first?.kind, "class")
            XCTAssertEqual(decodedSymbols.symbols.first?.usr, "test-usr")
        } else {
            XCTFail("Decoded result should be symbols")
        }

        // Test encoding/decoding pattern search results
        let patternOccurrences = [
            CodableOccurrence(
                usr: "test-usr",
                name: "TestPattern",
                location: "/test/file.swift:10",
                role: "definition"
            )
        ]
        let patternResults = PatternSearchResults(
            occurrences: patternOccurrences,
            pattern: "TestPattern",
            searchOptions: ["anchorStart", "ignoreCase"]
        )
        let patternResult = MCPResponseResult.patternSearch(patternResults)
        let patternData = try JSONEncoder().encode(patternResult)
        let decodedPatternResult = try JSONDecoder().decode(MCPResponseResult.self, from: patternData)
        
        if case .patternSearch(let decodedPattern) = decodedPatternResult {
            XCTAssertEqual(decodedPattern.occurrences.first?.name, "TestPattern")
            XCTAssertEqual(decodedPattern.pattern, "TestPattern")
            XCTAssertEqual(decodedPattern.searchOptions, ["anchorStart", "ignoreCase"])
        } else {
            XCTFail("Decoded result should be pattern search")
        }
    }
    
    func testTCPServerCreation() {
        let server = TCPServer(port: 9998)
        XCTAssertNotNil(server)
    }
}