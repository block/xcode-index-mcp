//
// Copyright © Block, Inc. All rights reserved.
//

import IndexStoreDB

// MARK: - Protocol that exposes IndexStoreDB methods
protocol IndexStore {
    /// Polls for any changes to units and waits until they have been registered.
    /// This scans through all unit files on the file system and is a costly operation.
    /// - Parameter isInitialScan: If true, indicates this is the first scan during initialization
    func pollForUnitChangesAndWait(isInitialScan: Bool)
    
    /// Returns all symbol occurrences in the specified file.
    /// - Parameter path: The file path to search in
    /// - Returns: Array of all symbol occurrences found in the file
    func symbolOccurrences(inFilePath path: String) -> [SymbolOccurrence]
    
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
    func canonicalOccurrences(containing pattern: String, anchorStart: Bool, anchorEnd: Bool, subsequence: Bool, ignoreCase: Bool) -> [SymbolOccurrence]
}

extension IndexStoreDB: IndexStore {
}
