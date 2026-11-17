// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "SurveyLogicTests",
    dependencies: [
        // matches Podfile.lock (the Podfile pins a commit that reports 4.2.0)
        .package(url: "https://github.com/tristanhimmelman/ObjectMapper.git", .exact("4.2.0")),
    ],
    targets: [
        .target(
            name: "SurveyQuestionDisplayLogic",
            dependencies: ["ObjectMapper"],
            path: "Sources/SurveyQuestionDisplayLogic"
        ),
        .testTarget(
            name: "SurveyLogicTests",
            dependencies: ["SurveyQuestionDisplayLogic"],
            path: "Tests",
            resources: [.copy("SurveyLogicTests/Fixtures")]
        ),
    ]
)
