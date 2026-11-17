#! /bin/bash

# These tests are very cursory and hacky.
# We literally copy the source file into the test directory before running tests.
# This was done to create tests for survey logic, which was found to have at least 4 bad bugs.

cp Beiwe/RK/surveyQuestionDisplayLogic.swift tests/Sources/SurveyQuestionDisplayLogic/surveyQuestionDisplayLogic.swift 

{ echo "import Foundation"; sed -n '/^\/\/ BEGIN isoStringToTimeInterval/,/^\/\/ END isoStringToTimeInterval/p' Beiwe/Common.swift; } > tests/Sources/SurveyQuestionDisplayLogic/isoStringToTimeInterval.swift
{ echo "import Foundation"; sed -n '/^\/\/ BEGIN leftBehindFiles/,/^\/\/ END leftBehindFiles/p' Beiwe/Common.swift; } > tests/Sources/SurveyQuestionDisplayLogic/leftBehindFiles.swift
mkdir -p tests/Sources/SurveyQuestionDisplayLogic/Models
cp Beiwe/Models/*.swift tests/Sources/SurveyQuestionDisplayLogic/Models/
{ echo "import Foundation"; echo "import ObjectMapper"; sed -n "/^\\/\\/ BEGIN modelTransforms/,/^\\/\\/ END modelTransforms/p" Beiwe/Util/MiscHelpers.swift; } > tests/Sources/SurveyQuestionDisplayLogic/Models/ModelTransforms.swift
{ echo "import Foundation"; cat Beiwe/Models/GenericSurveyQuestion.swift; } > tests/Sources/SurveyQuestionDisplayLogic/Models/GenericSurveyQuestion.swift  # needs Foundation under SwiftPM

cd tests
swift test -v
