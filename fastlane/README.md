fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios simulator

```sh
[bundle exec] fastlane ios simulator
```

Build and install to simulator

### ios take_screenshots

```sh
[bundle exec] fastlane ios take_screenshots
```

Run UI tests on both device sizes and extract screenshots to fastlane/screenshots

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Upload text metadata to App Store Connect (descriptions, keywords, subtitle, etc.)

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Upload screenshots to App Store Connect

### ios privacy

```sh
[bundle exec] fastlane ios privacy
```

Declare App Privacy nutrition labels (Data Not Collected) and publish

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Push a new beta build to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Upload metadata, screenshots, and binary to App Store

### ios build

```sh
[bundle exec] fastlane ios build
```

Build archive only (no upload)

### ios create_app

```sh
[bundle exec] fastlane ios create_app
```

Create app in App Store Connect

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
