import Foundation

/// Convert Simplified Chinese → Traditional Chinese.
/// Non-Chinese text passes through unchanged.
enum ChineseConverter {
    static func toTraditional(_ text: String) -> String {
        let mutable = NSMutableString(string: text)
        CFStringTransform(mutable, nil, "Simplified-Traditional" as CFString, false)
        return mutable as String
    }
}
