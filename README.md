# Blaze Flow

A native iPhone app for less distraction: shield chosen apps, categories, and websites during focus sessions, set a daily focus goal, and track session history and goal streaks. Built with SwiftUI for iOS 17+, with Apple's FamilyControls, ManagedSettings, and DeviceActivity frameworks. No backend, account, ads, or analytics.

## Open and run

1. On a Mac with Xcode 16 or newer, open `BlazeFlow.xcodeproj` and select the **BlazeFlow** scheme.
2. In the project's **Build Settings**, change `BASE_BUNDLE_IDENTIFIER` from `com.example.BlazeFlow` to a unique identifier you own. Set your development team for both **BlazeFlow** and **FocusMonitor** targets. Automatic signing is enabled.
3. In your Apple Developer account, register the matching App Group (`group.<your base bundle identifier>`) and enable it for both targets. Both targets also need the **Family Controls** capability. The project contains the entitlements; your provisioning profiles must authorize them. This generally requires a paid Apple Developer membership.
4. Run on a physical iPhone with iOS 17+. Allow Screen Time access when prompted, choose distractions, and start a session. Sessions support 15, 25, 45, 60, 90, and 120 minutes; DeviceActivity intervals require at least 15 minutes.

The extension clears the app's named shield when the scheduled session ends, including while the app is closed. The app reconciles completed sessions when it becomes active again. Individual authorization is voluntary: the user can end a session early or revoke access. This is not a tamperproof parental-control app. OS callback timing, force quit, restart, permission changes, and time-zone changes must be tested on a real device before release.

## Verify

On macOS, run the model tests with an installed iPhone simulator (replace the destination name if needed):

```sh
xcodebuild -project BlazeFlow.xcodeproj -scheme BlazeFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO test
```

The test target covers midnight boundaries, interrupted session credit, uncompleted session exclusion, streaks, combined sessions, and persistence. Simulator tests cover the data model; they do not establish working Screen Time authorization or blocking.

Physical-device acceptance checks:

- Deny permission, retry, then grant it. Confirm the app displays the correct access state.
- Select an app and website, save, relaunch, and verify the selection persists.
- Start a 15-minute session. Open a selected app and verify Apple's shield appears. Verify unselected apps remain usable.
- Put Blaze Flow in the background and let the session expire. Verify the shield clears without reopening Blaze Flow.
- Relaunch and verify one completed session was recorded, with no duplication on another relaunch.
- End a session early. Verify apps unblock and only elapsed minutes are credited.
- Revoke access during a session; return to Blaze Flow and verify it stops the session.
- Check large text, VoiceOver, dark mode, and a session crossing midnight.

## Data and privacy

History, goals, active-session timestamps, and Apple's opaque selection tokens are stored in the shared App Group's UserDefaults. Only the app writes session history; the extension reads expiry state and clears shields. No app-usage reports or actual screen-time totals are collected. Session time measures scheduled focus, not proof of attention. Daily progress updates when sessions end. A session crossing midnight is split between the affected days, according to the current local calendar. Streaks use the current daily goal, including when reviewing past days. History is local and has no export or cloud-sync feature in this version.

## Release requirements

Request Apple's **Family Controls distribution entitlement** for the app and DeviceActivity extension before TestFlight/App Store distribution. Development entitlement availability does not establish distribution approval. Add release icons, complete device testing, and review the privacy manifest and App Store privacy answers for your final configuration.

## Project maintenance

`scripts/generate_project.py` deterministically generates the checked-in Xcode project and shared scheme using only Python 3. Run it after changing source membership. Signing identifiers are build settings; keep any team-specific overrides local or pass them to `xcodebuild`.

This implementation was authored in a Linux cloud environment without Xcode or an Apple SDK. Project structure and plist validation can run there; iOS compilation, XCTest execution, UI rendering, and Screen Time behavior still require the Mac/device checks above. Do not treat those checks as passed until they run.
