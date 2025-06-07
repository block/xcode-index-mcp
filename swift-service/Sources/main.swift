import Foundation

// MARK: - Main

print("Starting IndexStore MCP Server...")
let server = TCPServer(port: 7949)
server.start()