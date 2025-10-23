// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MessageAI",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "MessageAI",
            targets: ["MessageAI"]
        )
    ],
    dependencies: [
        // Firebase SDK
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0"),
        // GIF Support
        .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "MessageAI",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
                .product(name: "SDWebImageSwiftUI", package: "SDWebImageSwiftUI")
            ]
        )
    ]
)

