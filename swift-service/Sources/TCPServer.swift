import Foundation
import IndexStoreDB

// MARK: - Server written in Swift that listens for MCP requests and responds with MCP responses

class TCPServer {
    private let symbolProvider: SymbolProvider
    private let port: UInt16
    
    init(port: UInt16, symbolProvider: SymbolProvider = RealSymbolProvider()) {
        self.port = port
        self.symbolProvider = symbolProvider
    }
    
    func start() {
        let queue = DispatchQueue(label: "com.indexstore.mcp")
        
        queue.async {
            self.runServer()
        }
        
        // Keep main thread running
        dispatchMain()
    }
    
    private func runServer() {
        guard let serverSocket = createServerSocket() else {
            print("Failed to create server socket")
            return
        }
        
        print("Server listening on port \(port)")
        
        while true {
            guard let clientSocket = accept(serverSocket) else {
                continue
            }
            
            // Handle client in a separate queue
            DispatchQueue.global().async {
                self.handleClient(clientSocket)
            }
        }
    }
    
    private func createServerSocket() -> Int32? {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else {
            print("Failed to create socket")
            return nil
        }
        
        var value: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(MemoryLayout<Int32>.size))
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY.bigEndian
        
        let addrSize = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bindResult = withUnsafePointer(to: addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { ptr in
                Darwin.bind(sock, ptr, addrSize)
            }
        }
        
        guard bindResult == 0 else {
            print("Failed to bind socket. Bind result: \(bindResult)")
            close(sock)
            return nil
        }
        
        guard listen(sock, 5) == 0 else {
            print("Failed to listen on socket")
            close(sock)
            return nil
        }
        
        return sock
    }
    
    private func accept(_ serverSocket: Int32) -> Int32? {
        var addr = sockaddr_in()
        var addrSize = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        let clientSocket = withUnsafeMutablePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { ptr in
                Darwin.accept(serverSocket, ptr, &addrSize)
            }
        }
        
        guard clientSocket >= 0 else {
            print("Failed to accept client connection")
            return nil
        }
        
        return clientSocket
    }
    
    private func handleClient(_ clientSocket: Int32) {
        var buffer = [UInt8](repeating: 0, count: 1024)
        
        while true {
            let bytesRead = read(clientSocket, &buffer, buffer.count)
            
            if bytesRead <= 0 {
                print("Client disconnected")
                break
            }
            
            print("Bytes read: \(bytesRead)")
            let data = Data(bytes: buffer, count: bytesRead)
            print("Received raw data: \(String(data: data, encoding: .utf8) ?? "Invalid data")")
            
            if let request = try? JSONDecoder().decode(MCPRequest.self, from: data) {
                let response = handleRequest(request)
                
                if let responseData = try? JSONEncoder().encode(response) {
                    _ = responseData.withUnsafeBytes { ptr in
                        write(clientSocket, ptr.baseAddress, responseData.count)
                    }
                    // Add newline for message framing
                    _ = "\n".data(using: .utf8)!.withUnsafeBytes { ptr in
                        write(clientSocket, ptr.baseAddress, 1)
                    }
                    print("=== Response Sent === size: \(responseData.count)")
                } else {
                    print("Failed to encode response")
                }
            } else {
                print("Failed to decode request")
            }
        }
        
        close(clientSocket)
    }
    
    func handleRequest(_ request: MCPRequest) -> MCPResponse {
        print("Received request: \(request)")
        switch request.method {
        case "is_available":
            guard let projectName = request.params["projectName"] else {
                return MCPResponse(
                    id: request.id,
                    result: .status(ServiceStatus(available: false, error: "Missing projectName parameter")),
                    error: "Missing projectName parameter"
                )
            }
            let status = symbolProvider.isAvailable(projectName: projectName)
            return MCPResponse(id: request.id, result: .status(status), error: status.error)
            
        case "symbol_occurrences":
            guard let filePath = request.params["filePath"],
                  let lineNumberStr = request.params["lineNumber"],
                  let lineNumber = Int(lineNumberStr) else {
                return MCPResponse(
                    id: request.id,
                    result: .symbols(SymbolOccurrences(symbols: [], location: "")),
                    error: "Missing or invalid parameters"
                )
            }
            let result = symbolProvider.symbolOccurrences(filePath: filePath, lineNumber: lineNumber)
            if let error = result.error {
                return MCPResponse(
                    id: request.id,
                    result: .symbols(result),
                    error: error
                )
            }
            return MCPResponse(id: request.id, result: .symbols(result), error: nil)
            
        case "get_occurrences":
            guard let usr = request.params["usr"],
                  let rolesStr = request.params["roles"] else {
                return MCPResponse(
                    id: request.id,
                    result: .occurrences(OccurrenceResults(occurrences: [], usr: "", roles: [])),
                    error: "Missing parameters"
                )
            }
            let roles = rolesStr.components(separatedBy: ",")
            let result = symbolProvider.getOccurrences(usr: usr, roles: roles)
            return MCPResponse(id: request.id, result: .occurrences(result), error: nil)
            
        case "search_pattern":
            guard let pattern = request.params["pattern"] else {
                return MCPResponse(
                    id: request.id,
                    result: .patternSearch(PatternSearchResults(occurrences: [], pattern: "", searchOptions: [])),
                    error: "Missing pattern parameter"
                )
            }
            let optionsStr = request.params["options"] ?? ""
            let options = optionsStr.isEmpty ? [] : optionsStr.components(separatedBy: ",")
            let result = symbolProvider.findCanonicalOccurrences(pattern: pattern, options: options)
            return MCPResponse(id: request.id, result: .patternSearch(result), error: nil)
            
        default:
            return MCPResponse(
                id: request.id,
                result: .status(ServiceStatus(available: false, error: "Unknown method")),
                error: "Unknown method"
            )
        }
    }
}