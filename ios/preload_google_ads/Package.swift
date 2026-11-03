// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "preload_google_ads",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "preload-google-ads", targets: ["preload_google_ads"])
    ],
    dependencies: [
        // Resolved by Flutter to the app's copy of the google_mobile_ads plugin.
        .package(name: "google_mobile_ads", path: "../google_mobile_ads"),
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "preload_google_ads",
            dependencies: [
                .product(name: "google-mobile-ads", package: "google_mobile_ads"),
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
