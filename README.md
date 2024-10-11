**NOTE:**
In order to build the app you have to comment out lines 41 and 47 of `PKHUDAssets.swift`. For unknown reasons `IS_FRAMEWORK_TARGET` of this package is not getting set to `true` at build time. (This file is located at `{REPO}/pods/PKHUD/PKHUDAssents.swift` after you install the Cocoapods requirements.) You will have to do this every time you run `pod update` or `pod install`. __If you work out how to fix this please let us know.__

### Building the Beiwe iOS app
1. This is an iOS app, you need to be on a mac running a modern (usually within the most recent 3 macOS releases). You need to then install Xcode and the Xcode CLI tools.
    - You may need to consent to the CLI tools before step 2 works.
2. Install an up-to-date version of Cocoapods.
    - There may already be a version of Cocoapods from Xcode/CLI Tools automatically installed via `gem`, but it is usually out of date. We recommend using Homebrew a version installed via the Homebrew package manager.
    - [Install Homebrew](https://brew.sh/)
    - Install Cocoapods: `brew install cocoapods`.
3. In Xcode, open Beiwe.xcworkspace, (**not** Beiwe.xcodeproj)
4. Inside this project directory (inside the `beiwe-ios` directory), run `pod install`.
5. Add a `GoogleService-Info.plist` file.
    - **Note:** this is a credentials file connected to your specific Firebase account.
    - In order for push notifications to work on iOS, which is necessary for most use cases, [please see the documentation]( LINK_HERE )), requires that you set up with valid Apple Push Notification Service (APNS)credentials from the App Store account that you will publish your app on, and that you then add them to the Firebase Online Console.  You do not need functional APNS credentials to just build the app.
    
    TODO: check and link to the credentials documentation on the beiwe-backend wiki, it is probable out of date.

    - To add the credential file to the Xcode project, drag it from the Finder into the Xcode project navigator, just under the folder icon named "Beiwe" (**not on** the top level "Beiwe" icon).  This will bring up a dialog that says "Choose options for adding these files:" - select "Copy items if needed" and "Add to targets: Beiwe".  (You cannot just move it into the beiwe-ios repository folder.)
6. Build the app!
    - To build for the Simulator or to a local device select one from the dropdown, click the **Run** arrow button in Xcode with an appropriate simulator version selected. (You can also press __command-R__.)
    - To build for release and upload to the App Store, go to **Product -> Archive** in the menu bar and follow the guide after clicking Distribute App button.
    - We recommend you ensure Debug Symbols are included in your app build. Beiwe is not a performance-critical app.
    - (You can also bring up the existing released App "Archives" view by going to the Window > Organizer in the menu bar.)
7. Configure Sentry for error reporting
    - Sentry.io is an error reporting service, The Beiwe Platform centralizes all error reports to Sentry. They have a free plan with various limitations, but as long as you have a low error count it should be sufficient. You also have the option of a self-hosted Sentry server.
    - Sentry documentation is excellent, it even prints out __your specific DSNs__ in the code snippets and directions that it generates for you on it's documentation pages! (A DSN is the identifying error report upload endpoint for that project.)
    - Create two Sentry Projects. (It is advantageous to create two, one for development builds and one for App Store deployments.) Copy their DSNs into the `repo/Beiwe/Private/Private.swift` file.
    - First you need to [install and configure the sentry-cli](https://docs.sentry.io/cli/installation/) tool.
    - The Beiwe App (should) have a script that executes when running the Archive process to [upload Debug Symbols to Sentry](https://docs.sentry.io/platforms/apple/guides/ios/dsym/), but you may have to do this manually. Here's how:
        1. In a terminal, `cd` into the Archives folder, which is usually located at `/Users/my_username/Library/Developer/Xcode/Archives/`
        2. In this folder you will see folders organized by date. `cd` into the correct date of your target build, which will in turn be labelled by the time of the build.
        3. Run this command: `sentry-cli difutil upload the_name_of_the_folder`. The tool will find, extract, and upload the appropriate dSYM files to Sentry.io.  It will tell you if any uploaded files were new to your Sentry account.
        - (You can also run this command on a target higher up in the folder hierarchy, and it will recursively search for all dSYMs across many Archives. This may take a long time to process and upload _many_ already-uploaded files. About 30 are generated for every Archived build of the Beiwe iOS app.)


### Build Configurations
There are two important Build Configurations:
* "Beiwe": the study server is hardcoded to studies.beiwe.org
* "Beiwe2": the study server URL gets set after you install the app, on the registration screen.
