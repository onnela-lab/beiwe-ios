// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "SurveyLogicTests",
    dependencies: [
        // matches Podfile.lock (the Podfile pins a commit that reports 4.2.0)
        .package(url: "https://github.com/tristanhimmelman/ObjectMapper.git", .exact("4.2.0")),
        // matches Podfile.lock; SwiftyRSA is built from Pods/ instead (target below), it needs a macOS shim
        .package(url: "https://github.com/iosdevzone/IDZSwiftCommonCrypto.git", .exact("0.16.1")),
    ],
    targets: [
        .target(
            name: "SurveyQuestionDisplayLogic",
            dependencies: ["ObjectMapper"],
            path: "Sources/SurveyQuestionDisplayLogic"
        ),
        // Pods/SwiftyRSA/Source copied into Pod/ by run_tests.sh, plus MacOSSecKeyLegacy.swift
        .target(
            name: "SwiftyRSA",
            path: "Sources/SwiftyRSA"
        ),
        // Beiwe/Util/Crypto.swift + Encryption.swift, copied in by run_tests.sh
        .target(
            name: "AppEncryption",
            dependencies: ["IDZSwiftCommonCrypto", "SwiftyRSA"],
            path: "Sources/AppEncryption"
        ),
        .testTarget(
            name: "SurveyLogicTests",
            dependencies: ["SurveyQuestionDisplayLogic", "AppEncryption"],
            path: "Tests",
            resources: [.copy("SurveyLogicTests/Fixtures")]
        ),
    ]
)
