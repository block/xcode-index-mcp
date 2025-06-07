import Foundation

enum XcodePath {
    private static let defaultPath = "/Applications/Xcode.app"
    
    /// Detects the Xcode.app installation path
    static var installPath: URL {
        if FileManager.default.fileExists(atPath: defaultPath) {
            return URL(fileURLWithPath: defaultPath)
        }
        
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["-p"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                // xcode-select returns the Contents/Developer directory path, so we need to go up two levels
                let url = URL(fileURLWithPath: path)
                return url.deletingLastPathComponent().deletingLastPathComponent()
            }
        } catch {
            print("Error getting Xcode path: \(error)")
        }
        
        return URL(fileURLWithPath: defaultPath)
    }
}