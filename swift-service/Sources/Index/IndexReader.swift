//
// Copyright © Block, Inc. All rights reserved.
//

import IndexStoreDB
import Foundation

protocol IndexReader {
    /// The name of the project this index reader is associated with
    var projectName: String { get }
    
    /// Returns all symbol occurrences in the specified file at the given line number.
    /// - Parameters:
    ///   - path: The file path to search in
    ///   - lineNumber: The line number to search at
    /// - Returns: Array of symbol occurrences found at the specified location
    /// - Throws: IndexReaderError if the file is not found
    func symbolOccurrences(inFilePath path: String, lineNumber: Int) throws -> [SymbolOccurrence]
    
    /// Returns all occurrences of a symbol with the given USR (Unified Symbol Resolution) identifier.
    /// - Parameters:
    ///   - usr: The USR identifier of the symbol to search for
    ///   - roles: The roles to filter occurrences by
    /// - Returns: Array of symbol occurrences matching the USR and roles
    func occurrences(ofUSR usr: String, roles: SymbolRole) -> [SymbolOccurrence]
    
    /// Finds canonical symbol occurrences matching the given pattern with various matching options.
    /// - Parameters:
    ///   - pattern: The pattern to match against symbol names
    ///   - anchorStart: If true, pattern must match the start of the symbol name
    ///   - anchorEnd: If true, pattern must match the end of the symbol name
    ///   - subsequence: If true, pattern can match any subsequence of the symbol name
    ///   - ignoreCase: If true, case is ignored when matching
    /// - Returns: Array of matching symbol occurrences
    func findCanonicalOccurrences(
        matching pattern: String, 
        anchorStart: Bool, 
        anchorEnd: Bool, 
        subsequence: Bool, 
        ignoreCase: Bool
    ) -> [SymbolOccurrence]
    
    /// Returns the current status of the index reader
    /// - Returns: The current ReaderStatus indicating if the index is available, loading, or unavailable
    func isAvailable() -> ReaderStatus
}

enum ReaderStatus {
    case available
    case loading
    case unavailable
}

enum IndexReaderError: Error, LocalizedError {
    case fileNotFound(path: String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File does not exist at path: \(path)"
        }
    }
}

final class RealIndexReader: IndexReader {

    let projectName: String
    private let indexStore: IndexStore
    private var status: ReaderStatus = .loading
    
    init(indexStore: IndexStore, projectName: String) {
        self.projectName = projectName
        self.indexStore = indexStore

        pollForUnitChangesAndWait(isInitialScan: true)
        print("Done initializing")
        status = .available
    }
    
    // MARK: - Internal Methods

    func isAvailable() -> ReaderStatus {
        status
    }

    func symbolOccurrences(inFilePath path: String, lineNumber: Int) throws -> [SymbolOccurrence] {
        print("Getting symbol occurrences from Index Reader \(path) at line \(lineNumber)")
        
        // Validate file path
        let fileManager = FileManager.default
        let absolutePath: String
        
        if path.hasPrefix("/") {
            absolutePath = path
        } else {
            // Convert relative path to absolute path using current working directory
            absolutePath = fileManager.currentDirectoryPath + "/" + path
        }
        
        guard fileManager.fileExists(atPath: absolutePath) else {
            throw IndexReaderError.fileNotFound(path: absolutePath)
        }
        
        let occurrences = indexStore.symbolOccurrences(inFilePath: absolutePath)
        print("Filtering \(occurrences.count) occurrences for lineNumber:\(lineNumber)")
        return occurrences.filter { occurrence in
            let location = occurrence.location
            return location.path == absolutePath && location.line == lineNumber
        }
    }

    func occurrences(ofUSR usr: String, roles: SymbolRole) -> [SymbolOccurrence] {
        indexStore.occurrences(ofUSR: usr, roles: roles)
    }

    func findCanonicalOccurrences(
        matching pattern: String, 
        anchorStart: Bool, 
        anchorEnd: Bool, 
        subsequence: Bool, 
        ignoreCase: Bool
    ) -> [SymbolOccurrence] {
        indexStore.canonicalOccurrences(
            containing: pattern, 
            anchorStart: anchorStart, 
            anchorEnd: anchorEnd, 
            subsequence: subsequence, 
            ignoreCase: ignoreCase
        )
    }

    // MARK: - Private Methods

    // Goose has no concept of time, so best to just block. This can take up to 30 seconds.
    private func pollForUnitChangesAndWait(isInitialScan: Bool) {
        indexStore.pollForUnitChangesAndWait(isInitialScan: isInitialScan)
    }
}