import Foundation

// a missing or broken fixture should crash the test run loudly, hence the force tries

/// fixtures are shared with the future Kotlin port
func loadFixture(_ name: String) -> Any {
    return try! JSONSerialization.jsonObject(with: fixtureData(name), options: [])  // swiftlint:disable:this force_try
}

private func fixtureData(_ name: String) -> Data {
    let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
    return try! Data(contentsOf: url)  // swiftlint:disable:this force_try
}

/// Fixtures/*.json by name, so tests never deal with paths (beiwe-app-test-rules.md TR1)
enum Fixtures {
    /// the survey list the backend sends on survey download
    static var surveyDownloadPayload: Any { loadFixture("survey_download_payload") }
    /// BS7 selection table, decoded by RandomizeWithMemoryTests
    static var randomizeWithMemory: Data { fixtureData("randomize_with_memory") }
    /// test-only RSA key + encryption vectors from tests/scripts/make_encryption_vectors.py, decoded by EncryptionTests
    static var encryptionVectors: Data { fixtureData("encryption_vectors") }
}
