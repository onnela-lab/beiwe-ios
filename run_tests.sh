#! /bin/bash

# These tests are very cursory and hacky.
# We literally copy the source file into the test directory before running tests.
# This was done to create tests for survey logic, which was found to have at least 4 bad bugs.

cp Beiwe/RK/surveyQuestionDisplayLogic.swift tests/Sources/SurveyQuestionDisplayLogic/surveyQuestionDisplayLogic.swift 

cd tests
swift test -v
