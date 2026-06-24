// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "SurveyLogicTests",
    targets: [
        .target(
            name: "SurveyQuestionDisplayLogic",
            path: "Sources/SurveyQuestionDisplayLogic"
        ),
        .testTarget(
            name: "SurveyLogicTests",
            dependencies: ["SurveyQuestionDisplayLogic"],
            path: "Tests"
        ),
    ]
)
