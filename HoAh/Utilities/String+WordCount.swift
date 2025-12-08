import Foundation

extension String {
    /// Calculates word count more intelligently, handling CJK characters correctly.
    /// - Returns: The estimated word count.
    var smartWordCount: Int {
        var count = 0
        let range = self.startIndex..<self.endIndex
        
        // Enumerate substrings by .byWords to catch standard words (English, numbers, etc.)
        self.enumerateSubstrings(in: range, options: [.byWords, .localized]) { _, _, _, _ in
            count += 1
        }
        
        // However, standard .byWords sometimes treats long CJK sequences as single words or works inconsistently depending on system locale.
        // A more robust hybrid approach for dictation:
        // 1. Count CJK characters as individual words (since they often represent single concepts).
        // 2. Count non-CJK alphanumeric sequences as words.
        
        // Regex for CJK characters (Han, Kana, Hangul)
        // Ranges:
        // \u{4E00}-\u{9FFF}: CJK Unified Ideographs (Chinese)
        // \u{3040}-\u{309F}: Hiragana
        // \u{30A0}-\u{30FF}: Katakana
        // \u{AC00}-\u{D7AF}: Hangul Syllables
        // \u{3400}-\u{4DBF}: CJK Extension A
        
        // Simplified Logic:
        // Iterate through characters.
        // If char is CJK -> count++.
        // If char is non-CJK -> accumulate. If run ends or space/boundary -> count++.
        
        return calculateMixedWordCount()
    }
    
    private func calculateMixedWordCount() -> Int {
        var count = 0
        var isInWord = false
        
        for char in self {
            if char.isCJK {
                // Determine if we were tracking a non-CJK word before this
                if isInWord {
                    count += 1
                    isInWord = false
                }
                // Count the CJK character itself as a word
                count += 1
            } else if char.isLetter || char.isNumber {
                // Part of a non-CJK word
                isInWord = true
            } else {
                // Separator (space, punctuation, etc.)
                if isInWord {
                    count += 1
                    isInWord = false
                }
            }
        }
        
        // Count the final trailing word if exists
        if isInWord {
            count += 1
        }
        
        return count
    }
}

extension Character {
    var isCJK: Bool {
        guard let scalar = self.unicodeScalars.first else { return false }
        let codePoint = scalar.value
        
        return (codePoint >= 0x4E00 && codePoint <= 0x9FFF) || // CJK Unified Ideographs
               (codePoint >= 0x3400 && codePoint <= 0x4DBF) || // CJK Unified Ideographs Extension A
               (codePoint >= 0x20000 && codePoint <= 0x2A6DF) || // CJK Unified Ideographs Extension B
               (codePoint >= 0x3040 && codePoint <= 0x309F) || // Hiragana
               (codePoint >= 0x30A0 && codePoint <= 0x30FF) || // Katakana
               (codePoint >= 0xAC00 && codePoint <= 0xD7AF)    // Hangul Syllables
    }
}
