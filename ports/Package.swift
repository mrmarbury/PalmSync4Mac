// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "EKCalendarInterface",
    platforms: [
        .macOS("15.0")
    ],
    products: [
        .executable(name: "ek_calendar_interface", targets: ["EKCalendarInterface"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "EKCalendarInterface",
            dependencies: []
        ),
        .testTarget(
            name: "EKCalendarInterfaceTests",
            dependencies: ["EKCalendarInterface"]
        ),
    ]
)
