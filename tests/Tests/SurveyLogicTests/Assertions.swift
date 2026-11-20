import XCTest

// short names for XCTest assertions (beiwe-app-test-rules.md TR5); file/line pass through so failures point at the test

func AssertTrue(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "",
                file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(try expression(), message(), file: file, line: line)
}

func AssertFalse(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "",
                 file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertFalse(try expression(), message(), file: file, line: line)
}

func AssertEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T,
                               _ message: @autoclosure () -> String = "",
                               file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(try a(), try b(), message(), file: file, line: line)
}

func AssertNotEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T,
                                  _ message: @autoclosure () -> String = "",
                                  file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertNotEqual(try a(), try b(), message(), file: file, line: line)
}

func AssertNil(_ expression: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "",
               file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertNil(try expression(), message(), file: file, line: line)
}

func AssertNotNil(_ expression: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "",
                  file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertNotNil(try expression(), message(), file: file, line: line)
}

func AssertThrowsError<T>(_ expression: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "",
                          file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertThrowsError(try expression(), message(), file: file, line: line)
}
