/// Computes the minimal edit to turn already-injected text into a new
/// streaming hypothesis: delete N characters from the end, then insert.
/// Counts in Character (grapheme cluster) units so emoji and composed
/// characters are never split — one backspace key press deletes one cluster.
enum TextDelta {

    struct Delta: Equatable {
        let backspaces: Int
        let insert: String
    }

    static func compute(injected: String, hypothesis: String) -> Delta {
        let a = Array(injected)
        let b = Array(hypothesis)

        var common = 0
        while common < a.count, common < b.count, a[common] == b[common] {
            common += 1
        }

        return Delta(
            backspaces: a.count - common,
            insert: String(b[common...])
        )
    }
}
