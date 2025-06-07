import Foundation
import IndexStoreDB

/// Converts IndexReader responses into wire-serializable formats for TCP communication.
/// This layer acts as an adapter between the IndexReader's native types and the network-serializable types.
protocol SymbolProvider {
    /// Checks if the index service is available for the given project.
    /// - Parameter projectName: The name of the project to check availability for
    /// - Returns: A ServiceStatus object indicating if the service is available and any error messages
    func isAvailable(projectName: String) -> ServiceStatus
    
    /// Retrieves all symbol occurrences at a specific location in a file.
    /// Converts IndexReader's SymbolOccurrence to wire-serializable CodableSymbol.
    /// - Parameters:
    ///   - filePath: The path to the file to search in
    ///   - lineNumber: The line number to search at
    /// - Returns: A SymbolOccurrences object containing the serializable symbols and location information
    func symbolOccurrences(filePath: String, lineNumber: Int) -> SymbolOccurrences
    
    /// Retrieves all occurrences of a symbol with a specific USR and roles.
    /// Converts IndexReader's SymbolOccurrence to wire-serializable CodableOccurrence.
    /// - Parameters:
    ///   - usr: The USR identifier of the symbol to search for
    ///   - roles: Array of role strings to filter occurrences by (e.g., "reference", "definition")
    /// - Returns: An OccurrenceResults object containing the serializable occurrences and search parameters
    func getOccurrences(usr: String, roles: [String]) -> OccurrenceResults
    
    /// Finds canonical symbol occurrences matching a pattern with various search options.
    /// Converts IndexReader's SymbolOccurrence to wire-serializable CodableOccurrence.
    /// - Parameters:
    ///   - pattern: The pattern to match against symbol names
    ///   - options: Array of search option strings (e.g., "anchorStart", "ignoreCase")
    /// - Returns: A PatternSearchResults object containing the serializable occurrences and search parameters
    func findCanonicalOccurrences(pattern: String, options: [String]) -> PatternSearchResults
} 

class RealSymbolProvider: SymbolProvider {
    private var reader: IndexReader?
    static var libIndexStore: String {
        XcodePath.installPath
            .appendingPathComponent("Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib")
            .path
    }
    private let homeRelativeDerivedDataPath = "/Library/Developer/Xcode/DerivedData"
    
    init(indexReader: IndexReader? = nil) {
        self.reader = indexReader
    }
    
    private func findStorePath(projectName: String) -> String? {
        let fileManager = FileManager.default
        let derivedDataURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(homeRelativeDerivedDataPath)
        print(derivedDataURL)
        guard let contents = try? fileManager.contentsOfDirectory(at: derivedDataURL, includingPropertiesForKeys: nil) else {
            return nil
        }
        return contents
            .filter { $0.lastPathComponent.contains(projectName) }
            .map { $0.appendingPathComponent("Index.noindex/DataStore").path }
            .first
    }
    
    func isAvailable(projectName: String) -> ServiceStatus {
        if reader == nil || reader?.projectName != projectName {
            guard let storePath = findStorePath(projectName: projectName) else {
                print("Store path not found")
                return ServiceStatus(available: false, error: "Store path not found for project: \(projectName)")
            }
            
            do {
                let databasePath = NSTemporaryDirectory() + "index_\(getpid())"
                print(RealSymbolProvider.libIndexStore)
                let library = try IndexStoreLibrary(dylibPath: RealSymbolProvider.libIndexStore)
                let indexStore = try IndexStoreDB(
                    storePath: storePath,
                    databasePath: databasePath,
                    library: library
                )
                print("Initializing index reader")
                reader = RealIndexReader(
                    indexStore: indexStore, 
                    projectName: projectName
                )
                print("Done initializing index reader")
            } catch let error {
                print("Failed to initialize index reader: \(error)")
                return ServiceStatus(available: false, error: "Failed to initialize index reader: \(error)")
            }
        }
        
        guard let reader = reader else {
            return ServiceStatus(available: false, error: "Index reader is nil after initialization")
        }
        
        let status: ReaderStatus = reader.isAvailable()
        
        switch status {
        case .available:
            return ServiceStatus(available: true, error: nil)
        case .loading:
            return ServiceStatus(available: false, error: "Index is still loading")
        case .unavailable:
            return ServiceStatus(available: false, error: "Index is unavailable")
        }
    }
    
    func symbolOccurrences(filePath: String, lineNumber: Int) -> SymbolOccurrences {
        print("Receved request for symbol occurrences for \(filePath):\(lineNumber)")
        guard let reader = reader else {
            return SymbolOccurrences(symbols: [], location: "\(filePath):\(lineNumber)")
        }
        do {
            let occurrences = try reader.symbolOccurrences(inFilePath: filePath, lineNumber: lineNumber)
            print("==== occurrences ====\n\(occurrences)")
            let symbols = occurrences.map { CodableSymbol(from: $0.symbol) }
            print("==== symbols =====\n\(symbols)")
            return SymbolOccurrences(
                symbols: symbols,
                location: "\(filePath):\(lineNumber)"
            )
        } catch {
            print("Error getting symbol occurrences: \(error)")
            return SymbolOccurrences(
                symbols: [],
                location: "\(filePath):\(lineNumber)",
                error: error.localizedDescription
            )
        }
    }
    
    func getOccurrences(usr: String, roles: [String]) -> OccurrenceResults {
        guard let reader = reader else {
            return OccurrenceResults(occurrences: [], usr: usr, roles: roles)
        }
        let symbolRoles = roles.reduce(into: SymbolRole()) { result, role in
            switch role {
                case "reference":
                    result.insert(.reference)
                case "definition":
                    result.insert(.definition)
                case "declaration":
                    result.insert(.declaration)
                case "read":
                    result.insert(.read)
                case "write":
                    result.insert(.write)
                case "call":
                    result.insert(.call)
                case "dynamic":
                    result.insert(.dynamic)
                case "addressOf":
                    result.insert(.addressOf)
                default:
                    break
            }
        }
        
        let occurrences = reader.occurrences(ofUSR: usr, roles: symbolRoles)
        let codableOccurrences = occurrences.map { CodableOccurrence(from: $0) }
        
        return OccurrenceResults(
            occurrences: codableOccurrences,
            usr: usr,
            roles: roles
        )
    }

    func findCanonicalOccurrences(pattern: String, options: [String]) -> PatternSearchResults {
        guard let reader = reader else {
            return PatternSearchResults(occurrences: [], pattern: pattern, searchOptions: options)
        }

        let anchorStart = options.contains("anchorStart")
        let anchorEnd = options.contains("anchorEnd")
        let subsequence = options.contains("subsequence")
        let ignoreCase = options.contains("ignoreCase")

        let occurrences = reader.findCanonicalOccurrences(
            matching: pattern,
            anchorStart: anchorStart,
            anchorEnd: anchorEnd,
            subsequence: subsequence,
            ignoreCase: ignoreCase
        )

        let codableOccurrences = occurrences.map { CodableOccurrence(from: $0) }

        return PatternSearchResults(
            occurrences: codableOccurrences,
            pattern: pattern,
            searchOptions: options
        )
    }
}