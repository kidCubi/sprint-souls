// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "sprint-souls",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SprintSouls",
            path: "Sources/SprintSouls"
        )
    ]
)
