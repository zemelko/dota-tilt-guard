import Foundation

public struct VoiceWord: Sendable {
    public let text: String
    public let id: String
    public init(_ text: String, id: String) { self.text = text; self.id = id }
}

/// Wall-clock cooldown starts when a NEW abusive word/phrase is detected.
/// The speech input remains active while outgoing sound is muted.
public struct VoiceGate {
    public let cooldown: TimeInterval
    public private(set) var mutedUntil: TimeInterval = 0
    public private(set) var detections = 0
    private var seen: Set<String> = []
    private var order: [String] = []
    public init(cooldown: TimeInterval = 3) { self.cooldown = cooldown }

    @discardableResult public mutating func observe(_ words: [VoiceWord], now: TimeInterval) -> Bool {
        var found = false
        for index in ChatFilter.aggressiveWordEnds(words.map(\.text)) {
            let word = words[index]
            // Time/position identity stays stable when punctuation or casing changes.
            if seen.insert(word.id).inserted {
                order.append(word.id); found = true
            }
        }
        // Bounded session memory; no audio or transcripts are stored here.
        if order.count > 2048 {
            for id in order.prefix(1024) { seen.remove(id) }
            order.removeFirst(1024)
        }
        if found { mute(now: now); detections += 1 }
        return found
    }

    public mutating func mute(now: TimeInterval) { mutedUntil = now + cooldown }
    public func remaining(at now: TimeInterval) -> TimeInterval { max(0, mutedUntil - now) }
    public func isMuted(at now: TimeInterval) -> Bool { remaining(at: now) > 0 }
}
