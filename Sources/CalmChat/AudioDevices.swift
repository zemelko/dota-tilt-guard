import Foundation
import CoreAudio

struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let inputChannels: Int
    let outputChannels: Int
    var isVoiceBridge: Bool { uid == "BlackHole2ch_UID" && inputChannels == 2 && outputChannels == 2 }
}

enum VoiceError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

enum AudioDevices {
    static func list() -> [AudioDevice] {
        var address = property(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.map { AudioDevice(id: $0, uid: string($0, kAudioDevicePropertyDeviceUID), name: string($0, kAudioObjectPropertyName), inputChannels: channels($0, scope: kAudioDevicePropertyScopeInput), outputChannels: channels($0, scope: kAudioDevicePropertyScopeOutput)) }
    }
    static func property(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }
    static func string(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String {
        var address = property(selector)
        let data = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<CFString>.size, alignment: MemoryLayout<CFString>.alignment)
        defer { data.deallocate() }
        var size = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, data) == noErr else { return "" }
        // CoreAudio transfers ownership of these CFString properties to the caller.
        return data.load(as: Unmanaged<CFString>.self).takeRetainedValue() as String
    }
    static func channels(_ id: AudioObjectID, scope: AudioObjectPropertyScope) -> Int {
        var address = property(kAudioDevicePropertyStreamConfiguration, scope: scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let memory = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { memory.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, memory) == noErr else { return 0 }
        return UnsafeMutableAudioBufferListPointer(memory.assumingMemoryBound(to: AudioBufferList.self)).reduce(0) { $0 + Int($1.mNumberChannels) }
    }
    static func defaultInput() -> AudioDeviceID {
        var address = property(kAudioHardwarePropertyDefaultInputDevice)
        var device: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        _ = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return device
    }
    static func setDefaultInput(_ device: AudioDeviceID) throws {
        var address = property(kAudioHardwarePropertyDefaultInputDevice)
        var value = device
        guard AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &value) == noErr,
              defaultInput() == device else { throw VoiceError.message("Не удалось выбрать виртуальный микрофон системным входом.") }
    }
}
