import Foundation
import AVFoundation
import CoreAudio

struct AudioDevice: Codable {
    let id: AudioDeviceID
    let name: String
}

class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var outputFile: AVAudioFile?
    
    // Function to list all audio devices in JSON format
    // Function to list only audio input devices in JSON format
    static func listAudioDevices() {
        var deviceCount: UInt32 = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        // Query for the number of audio devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize
        )

        deviceCount = propertySize / UInt32(MemoryLayout<AudioDeviceID>.size)
        var deviceIDs = [AudioDeviceID](repeating: 0, count: Int(deviceCount))
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )

        var devices = [AudioDevice]()

        // Iterate through each device
        for deviceID in deviceIDs {

            var inputStreamSize = UInt32(MemoryLayout<UInt32>.size)

            // Check if the device has input streams (for recording capability)
            var inputStreamsProperty = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            let status = AudioObjectGetPropertyDataSize(
                deviceID,
                &inputStreamsProperty,
                0,
                nil,
                &inputStreamSize
            )

            if status == noErr && inputStreamSize > 0 {
                // Allocate a CFString for the device name
                var name: Unmanaged<CFString>?
                propertySize = UInt32(MemoryLayout<CFString>.size)

                var deviceNameProperty = AudioObjectPropertyAddress(
                    mSelector: kAudioObjectPropertyName,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )

                // Get the property data
                let result = AudioObjectGetPropertyData(
                    deviceID,
                    &deviceNameProperty,
                    0,
                    nil,
                    &propertySize,
                    &name
                )

                // Check for success
                if result == noErr, let deviceName = name?.takeRetainedValue() {
                    let device = AudioDevice(id: deviceID, name: deviceName as String)
                    devices.append(device)
                } else {
                    print("Failed to get device name for device ID: \(deviceID), error: \(result)")
                }
            }
        }

        // Print the devices in JSON format
        if let jsonData = try? JSONEncoder().encode(devices),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }

    // Function to start recording using the specified audio device and output path
    func startRecording(deviceID: AudioDeviceID, outputPath: String) {
        audioEngine = AVAudioEngine()

        // Set the input device to the specified deviceID
        var inputDeviceID = deviceID
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &inputDeviceID
        )

        if status != noErr {
            print("Failed to set input device to specified device ID.")
            return
        }

        guard let inputNode = audioEngine?.inputNode else {
            print("Unable to access input node.")
            return
        }


        // Use hardware format sample rate for recording
        let hwFormat = inputNode.outputFormat(forBus: 0)

        // Set up the output file settings with 44.1 kHz
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: hwFormat.sampleRate,
            AVNumberOfChannelsKey: hwFormat.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]

        // Set up the output file for recording
        do {
            let audioURL = URL(fileURLWithPath: outputPath)
            outputFile = try AVAudioFile(forWriting: audioURL, settings: outputSettings)
        } catch {
            print("Failed to create audio file: \(error)")
            return
        }

        // Install tap on input node to capture audio with compatible format
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: hwFormat) { (buffer, time) in
            do {
                try self.outputFile?.write(from: buffer)
            } catch {
                print("Failed to write audio data: \(error)")
            }
        }

        // Start audio engine
        do {
            try audioEngine?.start()
            print("Recording started... Press Enter to stop.")
            _ = readLine() // Wait for Enter key to stop recording
            stopRecording()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        print("Recording stopped.")
    }
}

// Main logic
let arguments = CommandLine.arguments
let recorder = AudioRecorder()

if arguments.contains("--list-devices") {
    AudioRecorder.listAudioDevices()
} else if let deviceIndex = arguments.firstIndex(of: "--device-id"),
          let outputPathIndex = arguments.firstIndex(of: "--output-path"),
          deviceIndex + 1 < arguments.count,
          outputPathIndex + 1 < arguments.count {
    
    let deviceID = AudioDeviceID(UInt32(arguments[deviceIndex + 1]) ?? 0)
    let outputPath = arguments[outputPathIndex + 1]
    recorder.startRecording(deviceID: deviceID, outputPath: outputPath)
} else {
    print("Usage:")
    print("  --list-devices                  List all audio devices in JSON format")
    print("  --device-id <id>                Specify the device ID to use for recording")
    print("  --output-path <path>            Specify the output path for the WAV file")
}
