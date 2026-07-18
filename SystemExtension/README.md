# LaunchRights — System Extension packaging

The fully Apple-supported shape of the ES flavour: the `launchrightsd-es` interceptor
built as an **Endpoint Security System Extension**, embedded in a **host app**
(`launchrights-menu` grown up) that activates it via `OSSystemExtensionRequest`. This is
what deploys cleanly via MDM.

Everything here reuses the SwiftPM sources — no code is duplicated:

| Target | Product | Reuses | Entitlement |
|--------|---------|--------|-------------|
| `LaunchRights` | host `.app` | `LaunchRightsShared` + `LaunchRightsUI` + `Host/` | `com.apple.developer.system-extension.install` |
| `com.jigsaw24.launchrights.es` | `.systemextension` | `LaunchRightsShared` + `Sources/launchrightsd-es` | `com.apple.developer.endpoint-security.client` |

The extension is embedded into `LaunchRights.app/Contents/Library/SystemExtensions/`.
Its bundle id is prefixed by the host's (`com.jigsaw24.launchrights` →
`com.jigsaw24.launchrights.es`), as Apple requires.

## Prerequisites

- `brew install xcodegen` (the project is generated from `project.yml`).
- Xcode + a Team ID.
- **After the ES entitlement grant:** in the portal create two App IDs —
  `com.jigsaw24.launchrights` (capability: **System Extension**) and
  `com.jigsaw24.launchrights.es` (capability: **Endpoint Security**) — and a
  provisioning profile for each.

## Build

```bash
export DEVELOPMENT_TEAM="AB12CD34EF"
export SIGN_IDENTITY="Developer ID Application: Your Org (AB12CD34EF)"
export HOST_PROFILE="LaunchRights Host"        # profile name or UUID
export EXT_PROFILE="LaunchRights ES"
./build.sh
```

## Install & activate

System extensions **only activate from `/Applications`**:

```bash
cp -R build/Build/Products/Release/LaunchRights.app /Applications/
open /Applications/LaunchRights.app        # menu bar ▸ "Activate / Update Extension"
```

Then approve in **System Settings ▸ Privacy & Security** (or pre-approve via an MDM
System Extension policy + a PPPC profile granting Full Disk Access to the extension).
Once active, `launchrightsd-es` runs as a managed sysext — double-clicking an allowlisted
app is intercepted and relaunched as root, exactly as in the standalone flavour.

## Local development (no notarization)

To iterate with a development identity instead of Developer ID + notarization:

```bash
systemextensionsctl developer on         # relaxes sysext validation for dev
export SIGN_IDENTITY="Apple Development: You (…)"
# use development provisioning profiles (this Mac registered) for HOST_PROFILE/EXT_PROFILE
./build.sh
```

`systemextensionsctl list` shows activation state; `systemextensionsctl reset`
clears it if you get stuck.

## Distribution

Sign with Developer ID, then notarize the **host app** (the embedded extension is
notarized as part of it):

```bash
ditto -c -k --keepParent /Applications/LaunchRights.app LaunchRights.zip
xcrun notarytool submit LaunchRights.zip --keychain-profile LaunchRightsNotary --wait
xcrun stapler staple /Applications/LaunchRights.app
```

## Status

Verified with XcodeGen 2.46.0 + Xcode 26.6: `xcodegen generate` + a signing-disabled
`xcodebuild` **build succeeds**, and the extension embeds correctly at
`LaunchRights.app/Contents/Library/SystemExtensions/com.jigsaw24.launchrights.es.systemextension`
(bundle id prefixed by the host, `CFBundlePackageType = SYSX`, links
`libEndpointSecurity.dylib`). Only signing remains — that needs the granted
entitlement + the two provisioning profiles.

Shared code (`LaunchRightsShared`, `LaunchRightsUI`) is built as **static libraries** and
linked into the app + extension (not embedded), so module imports resolve without
framework-embedding/rpath setup.

## Notes

- The `.xcodeproj` and `build/` are generated (git-ignored); regenerate via `build.sh`.
- Only one ES daemon may own the Mach service — don't also run the standalone
  `launchrightsd-es` LaunchDaemon while the sysext is active.
