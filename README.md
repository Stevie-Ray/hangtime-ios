# HangTime iOS App

## Building the App
Before you can start the submission process, you’ll need to build the Swift project that will load the PWA:

- Open a terminal in the root directory.
- Run this command: `pod install`

## Uploading a TestFlight build

The `TestFlight` GitHub Actions workflow builds a signed IPA with Xcode 26 on a hosted macOS runner and uploads it to App Store Connect. Start it manually from **Actions → TestFlight → Run workflow**.

Add these encrypted repository secrets before running it:

- `IOS_DISTRIBUTION_CERTIFICATE_BASE64`: an Apple Distribution `.p12` file, base64 encoded.
- `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`: the password used when exporting the `.p12` file.
- `IOS_APP_STORE_PROVISIONING_PROFILE_BASE64`: the App Store provisioning profile for `nl.stevie-ray.hangtime`, base64 encoded.
- `APP_STORE_CONNECT_API_KEY_BASE64`: the App Store Connect `AuthKey_*.p8` file, base64 encoded.
- `APP_STORE_CONNECT_API_KEY_ID`: the key ID shown in App Store Connect.
- `APP_STORE_CONNECT_ISSUER_ID`: the issuer ID shown in App Store Connect.
- `GOOGLE_SERVICE_INFO_PLIST_BASE64`: `HangTime/GoogleService-Info.plist`, base64 encoded.

The App Store Connect API key needs permission to upload builds (Developer, App Manager, Admin, or Account Holder).

On macOS, copy a file to the clipboard as base64 with:

```sh
base64 -i path/to/file | pbcopy
```

The uploaded build still needs to finish processing in App Store Connect before it appears in TestFlight.
