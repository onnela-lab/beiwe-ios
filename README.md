**NOTE:**
In order to build the app you have to comment out lines 41 and 47 of `PKHUDAssents.swift`. (Located at `pods/PKHUD/PKHUDAssents.swift`) For some reason `IS_FRAMEWORK_TARGET` is not getting set to true at build time.

### Building the Beiwe iOS app
1. Install Xcode
    1. If you're on a Mac with an M1 processor, **open Xcode using Rosetta**.  Locate Xcode in Finder, right-click and choose "Get Info", and check the box that says "Open using Rosetta".
2. In Xcode, open Beiwe.xcworkspace, **not** Beiwe.xcodeproj
3. Install Cocoapods.  We recommend installing via Homebrew, because that version supports Macs running Apple M1 (ARM) processors _without_ you needing to prepend `arch -x86_64` to your ` pod install` commands.
    1. [Install Homebrew](https://brew.sh/)
    2. Install Cocoapods: `brew install cocoapods`
4. Inside this project directory (inside the `beiwe-ios` directory), run `pod install`.
5. Add a `GoogleService-Info.plist` file.
    1. Note: this is connected to your specific Firebase account.  If you're using the Beiwe Service Center but still want to build your own version of the Beiwe iOS app, you'll need to ask someone at the Onnela Lab to provide this file to you.
    2. To add the file to the Xcode project, drag it from Finder into the Xcode project navigator, just under the folder icon named "Beiwe" (not the top level "Beiwe" icon).  This should bring up a dialog that says "Choose options for adding these files:"- in that, select "Copy items if needed" and "Add to targets: Beiwe".  It's not enough to move it into the beiwe-ios directory using Finder or `mv`/`cp` in Terminal.
6. Build the app
    1. To build for the Simulator, click the "Run" arrow button.
    2. To build for release, click Product -> Archive.

### Build Configurations
There are two important Build Configurations:
* "Beiwe": the study server is hardcoded to studies.beiwe.org
* "Beiwe2": the study server URL gets set after you install the app, on the registration screen.
