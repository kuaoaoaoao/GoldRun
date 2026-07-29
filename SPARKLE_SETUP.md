# Sparkle update setup

coolRun has Sparkle wired into the app, but Sparkle needs a signing key and an appcast before real updates can be shipped.

## 1. Resolve Sparkle in Xcode

Open `coolRun.xcodeproj` in Xcode. Xcode should resolve this Swift Package:

`https://github.com/sparkle-project/Sparkle`

## 2. Generate Sparkle keys

After Xcode resolves Sparkle, use Sparkle's `generate_keys` tool from the checked out package.

Keep the private key secret. Copy the public key into the target build setting:

`INFOPLIST_KEY_SUPublicEDKey`

It is currently set to:

`REPLACE_WITH_SPARKLE_PUBLIC_ED_KEY`

## 3. Configure the appcast URL

The current feed URL placeholder is:

`https://github.com/kuaoaoaoao/GoldRun/releases/download/appcast/appcast.xml`

You can replace `INFOPLIST_KEY_SUFeedURL` with any stable HTTPS URL that hosts your appcast.

## 4. Ship a release

For each release:

1. Archive and export the signed app.
2. Zip the `.app`.
3. Sign the zip with Sparkle's signing tool.
4. Update `appcast.xml` with the new version, download URL, file length, and signature.
5. Upload the zip and appcast to GitHub Releases or another HTTPS host.

The in-app Settings window calls Sparkle's `checkForUpdates` action.
