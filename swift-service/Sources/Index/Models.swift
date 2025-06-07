import Foundation
import IndexStoreDB

// MARK: - Codable models for objects that are sent over the wire

struct MCPRequest: Codable {
    let id: String
    let method: String
    let params: [String: String]
}

struct CodableSymbol: Codable {
    let name: String
    let kind: String
    let usr: String
    
    init(name: String, kind: String, location: String, usr: String) {
        self.name = name
        self.kind = kind
        self.usr = usr
    }
    
    init(from indexStoreSymbol: Symbol) {
        self.name = indexStoreSymbol.name
        self.kind = String(describing: indexStoreSymbol.kind)
        self.usr = indexStoreSymbol.usr
    }
}

struct CodableOccurrence: Codable {
    let usr: String
    let name: String
    let location: String
    let role: String
    
    init(usr: String, name: String, location: String, role: String) {
        self.usr = usr
        self.name = name
        self.location = location
        self.role = role
    }
    
    init(from occurrence: SymbolOccurrence) {
        self.usr = occurrence.symbol.usr
        self.name = occurrence.symbol.name
        self.location = "\(occurrence.location.path):\(occurrence.location.line)"
        self.role = String(describing: occurrence.roles)
    }
}

struct ServiceStatus: Codable {
    let available: Bool
    let error: String?
    
    init(available: Bool, error: String? = nil) {
        self.available = available
        self.error = error
    }
}

struct SymbolOccurrences: Codable {
    let symbols: [CodableSymbol]
    let location: String
    let error: String?
    
    init(symbols: [CodableSymbol], location: String, error: String? = nil) {
        self.symbols = symbols
        self.location = location
        self.error = error
    }
}

struct OccurrenceResults: Codable {
    let occurrences: [CodableOccurrence]
    let usr: String
    let roles: [String]
}

struct PatternSearchResults: Codable {
    let occurrences: [CodableOccurrence]
    let pattern: String
    let searchOptions: [String]
}

enum MCPResponseResult: Codable {
    case status(ServiceStatus)
    case symbols(SymbolOccurrences)
    case occurrences(OccurrenceResults)
    case patternSearch(PatternSearchResults)
    
    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .status(let status):
            try container.encode("status", forKey: .type)
            try container.encode(status, forKey: .value)
        case .symbols(let symbols):
            try container.encode("symbols", forKey: .type)
            try container.encode(symbols, forKey: .value)
        case .occurrences(let occurrences):
            try container.encode("occurrences", forKey: .type)
            try container.encode(occurrences, forKey: .value)
        case .patternSearch(let results):
            try container.encode("patternSearch", forKey: .type)
            try container.encode(results, forKey: .value)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "status":
            let value = try container.decode(ServiceStatus.self, forKey: .value)
            self = .status(value)
        case "symbols":
            let value = try container.decode(SymbolOccurrences.self, forKey: .value)
            self = .symbols(value)
        case "occurrences":
            let value = try container.decode(OccurrenceResults.self, forKey: .value)
            self = .occurrences(value)
        case "patternSearch":
            let value = try container.decode(PatternSearchResults.self, forKey: .value)
            self = .patternSearch(value)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Invalid type value: \(type)"
            )
        }
    }
}

struct MCPResponse: Codable {
    let id: String
    let result: MCPResponseResult
    let error: String?
}