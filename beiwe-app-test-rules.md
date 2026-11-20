# Beiwe app test rules

How tests in this repo are structured. These rules apply to test code and test comments only, never to app code.
Existing tests are brought in line as each one is reviewed or touched.

This document is edited only at the direction of the project maintainer.

## TR1. Repository layout stays out of tests

- Fixture file names, folders, extensions and bundle lookups are written once, in
  `tests/Tests/SurveyLogicTests/Fixtures.swift`.
- Each fixture is a well-named member of `Fixtures`, for example `Fixtures.randomizeWithMemory`.
- A test reads a fixture as if it were a constant or a function call. It never builds a path, names a folder or
  calls `Bundle`.

## TR2. Helpers go at the top of the file

- Small helpers (builders such as `makeSurvey`, `question`) go above the tests, not between them.

## TR3. Free functions over methods

- A helper that does not need the test instance is a file-level `private` function, not a method inside the test
  class.
- The same goes for helper types, such as the struct for one row of a fixture.
- The test class holds the tests.

## TR4. "Push" is never used on its own

- In test names and comments, say "push notification" when the notification itself is meant.
- Say "new survey" when the point is a survey arriving or being activated, for example
  `testNewSurveysDrawUnseenQuestionsUntilRoundEnds`.

## TR5. Short assertion names

- Tests call `AssertTrue`, `AssertFalse`, `AssertEqual`, `AssertNotEqual`, `AssertNil`, `AssertNotNil`, not the
  `XCTAssert...` forms.
- They are defined in `tests/Tests/SurveyLogicTests/Assertions.swift` and report failures at the test's own line.
  Add a new one there when a test needs it.

## TR6. Every test says why it exists

- One comment line directly above each test function, stating why the test exists: the bug, rule or behavior it
  protects.
- Not a restatement of the name.

## TR7. A test's name says what it does

- The name describes the behavior being checked, for example `testUnopenedNewSurveysLeaveMemoryEmpty`, not the
  setup or the technique (`testFixtureCases`, `testPushes`).
