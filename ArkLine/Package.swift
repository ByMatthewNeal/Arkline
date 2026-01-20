// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ArkLine",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ArkLine",
            targets: ["ArkLine"]
        ),
    ],
    dependencies: [
        // Supabase Swift SDK
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0"),
        // Image Loading
        .package(url: "https://github.com/onevcat/Kingfisher", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "ArkLine",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "Kingfisher", package: "Kingfisher"),
            ],
            path: "."
        ),
    ]
)
