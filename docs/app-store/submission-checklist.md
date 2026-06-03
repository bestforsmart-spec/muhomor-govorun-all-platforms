# ShromSpeak App Store Submission Checklist

## Build

- Version: 1.0
- Build: 1
- Bundle ID: com.shromspeak.app
- Extension Bundle ID: com.shromspeak.app.speakaction
- Team ID: USBT669TK3
- Archive: build/archives/ShromSpeak-1.0.xcarchive

## App Store Connect

- Create app record for Bundle ID: com.shromspeak.app
- SKU: shromspeak-ios
- Category: Utilities
- Pricing: Free
- Privacy details: Data Not Collected
- Core app works offline
- No analytics
- No tracking
- No third-party SDKs in iOS v1.0

## Required URLs

- Public gist page: https://gist.github.com/bestforsmart-spec/baef9d17a302cc3102030804bc8ec858
- Privacy Policy URL: https://gist.githubusercontent.com/bestforsmart-spec/baef9d17a302cc3102030804bc8ec858/raw/a8ee9bb778c3532fcc347024809bfaa57a78477a/privacy-policy.md
- Support URL: https://gist.githubusercontent.com/bestforsmart-spec/baef9d17a302cc3102030804bc8ec858/raw/0eef4ee7309c97702725d996c62f04892a5faaef/support.md

## Review Notes

Use the review notes in docs/app-store/metadata-en.md.

## Known Blocker

Automatic upload from this Mac failed because the Apple account available to Xcode can sign development builds but currently has no App Store Connect provider access.

Observed export error:

```text
No Accounts with App Store Connect Access
No provider associated with App Store Connect user
```

Fix options:

- Sign in to Xcode with an Apple ID that has App Store Connect access.
- Open App Store Connect and accept pending agreements.
- Add this Apple ID in App Store Connect Users and Access with App Manager/Admin permissions.
- Use an App Store Connect API key with xcodebuild or Transporter.

Preferred CLI path after API access is available:

```bash
export ASC_KEY_PATH="/secure/path/AuthKey_XXXXXXXXXX.p8"
export ASC_KEY_ID="XXXXXXXXXX"
export ASC_ISSUER_ID="00000000-0000-0000-0000-000000000000"
./scripts/upload-ios-app-store.sh
```

Do not commit the `.p8` key.
