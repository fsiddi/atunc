# atunc

atunc is a simple macOS command line utility that allows recording audio from a single input 
device onto a single .wav file on the disk. The software is meant as a companion for the 
"Push to talk" Blender extension, which allows to record audio input within the Blender VSE.

Usage:

```
  --list-devices                  List all audio devices in JSON format
  --device-id <id>                Specify the device ID to use for recording
  --output-path <path>            Specify the output path for the WAV file
```

## Development info

This is how to make a new release of atunc using Xcode:

- Make a new build (code signing should be managed automatically)
- Go to organizer, distribute content
- zip -r atunc.zip atunc
- xcrun notarytool submit atunc.zip --keychain-profile "MyNotarizationProfile" --wait
- xcrun stapler staple atunc.zip

Notice that for the signing certificate we use "Developer ID Application". To setup the notarization pipeline:

- Generate Developer ID certificate at https://developer.apple.com/account/resources/certificates/list
- Download it and install it in the keychain


Used [this article](https://scriptingosx.com/2021/07/notarize-a-command-line-tool-with-notarytool/) as reference.
