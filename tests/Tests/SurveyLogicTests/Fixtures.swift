import Foundation

/// fixtures are shared with the future Kotlin port
func loadFixture(_ name: String) -> Any {
    let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
    return try! JSONSerialization.jsonObject(with: Data(contentsOf: url), options: [])
}
