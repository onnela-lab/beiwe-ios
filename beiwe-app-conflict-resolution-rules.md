# Beiwe app conflict resolution rules

Answers to logical questions about real-world conflicts the app can run into, such as a survey notification
arriving while that survey is open. When code and these rules disagree, the rules describe the intended behavior.

This document is edited only at the direction of the project maintainer.

## Survey Rules

### SR1. New survey event while that survey is open

If a new survey event (usually a push notification) occurs and That Exact Survey is literally open for taking by the
user, then the state of the open survey should be preserved, e.g. not modified. But, If there is a survey id tracking
feature implemented, then the survey id of the open survey should be updated so that it is recorded as if it were the
new survey. (To a reviewer, it should look like the old survey was missed by the user.)

### SR2. New survey event while that survey has saved, unsubmitted state

If a new survey event (usually a push notification) occurs and that survey has saved state but is not submitted or
open, that survey state should be cleared.

### SR3. Survey content changes while that survey is open

If there is a change to a survey's content when that survey is literally open, a dialog should display with a message
stating that "This study has made a change to the survey you are taking, we apologize but you will need to restart
this survey." It should have one system localized "ok" option. The open survey should be closed before this dialog
opens, and its saved state cleared. The button to take this survey should have been present before, it should
continue to be present.
