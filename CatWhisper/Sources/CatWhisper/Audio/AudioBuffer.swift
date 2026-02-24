import Foundation

/// Thread-safe audio sample accumulator
/// Collects Float32 samples from AVAudioEngine callbacks
final class AudioBuffer: @unchecked Sendable {
    private var samples: [Float] = []
    private let lock = NSLock()

    /// Append samples from an audio callback
    func append(_ newSamples: [Float]) {
        lock.lock()
        defer { lock.unlock() }
        samples.append(contentsOf: newSamples)
    }

    /// Consume and return all accumulated samples, resetting the buffer
    func consume() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        let result = samples
        samples.removeAll(keepingCapacity: true)
        return result
    }

    /// Current number of accumulated samples
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return samples.count
    }

    /// Reset the buffer
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        samples.removeAll(keepingCapacity: true)
    }
}
