// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "IndexStoreMCPService",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/indexstore-db.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "IndexStoreMCPService",
            dependencies: [
                .product(name: "IndexStoreDB", package: "indexstore-db"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "IndexStoreMCPServiceTests",
            dependencies: ["IndexStoreMCPService"]
        )
    ]
)