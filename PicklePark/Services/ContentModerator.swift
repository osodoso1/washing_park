import Foundation

public final class ContentModerator {
    public static let shared = ContentModerator()
    
    // Comprehensive word boundaries blocklist (profanity, slurs, harassment, vulgarity)
    private let blocklist: Set<String> = [
        "fuck", "shit", "bitch", "asshole", "bastard", "cunt", "dick", "pussy",
        "cock", "whore", "slut", "nigger", "nigga", "faggot", "fag", "retard",
        "chink", "spic", "kike", "gook", "twat", "wank", "wanker", "motherfucker",
        "bullshit", "dipshit", "dumbass", "jackass", "piss", "tits", "boobs",
        "blowjob", "handjob", "cum", "jizz", "porn", "anal", "penis", "vagina"
    ]
    
    // Leetspeak / symbol normalization map
    private let leetMap: [Character: Character] = [
        "@": "a", "4": "a",
        "8": "b",
        "(": "c", "<": "c",
        "3": "e",
        "1": "i", "!": "i", "|": "i",
        "0": "o",
        "$": "s", "5": "s",
        "7": "t", "+": "t",
        "v": "u"
    ]
    
    public init() {}
    
    /// Normalizes leetspeak, removes excessive punctuation and spaces to detect hidden bad words
    private func normalize(_ input: String) -> String {
        let lower = input.lowercased()
        var normalized = ""
        for char in lower {
            if let mapped = leetMap[char] {
                normalized.append(mapped)
            } else if char.isLetter || char.isNumber {
                normalized.append(char)
            }
        }
        return normalized
    }
    
    /// Checks if a string contains prohibited words
    public func containsProhibitedContent(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty { return false }
        
        // 1. Check direct word boundaries
        let words = trimmed.components(separatedBy: CharacterSet.alphanumerics.inverted)
        for word in words where !word.isEmpty {
            if blocklist.contains(word) {
                return true
            }
        }
        
        // 2. Check normalized leetspeak sequence
        let normalized = normalize(trimmed)
        for badWord in blocklist {
            if normalized.contains(badWord) {
                return true
            }
        }
        
        return false
    }
    
    /// Sanitizes text by replacing offensive words with asterisks (***)
    public func cleanse(_ text: String) -> String {
        var result = text
        
        for badWord in blocklist {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: badWord))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: result.utf16.count)
                let replacement = String(repeating: "*", count: badWord.count)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: replacement)
            }
        }
        
        // Secondary pass for embedded normalized profanity
        if containsProhibitedContent(result) {
            let words = result.components(separatedBy: " ")
            let sanitizedWords = words.map { word -> String in
                if containsProhibitedContent(word) {
                    return String(repeating: "*", count: max(3, word.count))
                }
                return word
            }
            return sanitizedWords.joined(separator: " ")
        }
        
        return result
    }
    
    /// Validates user name or snack input with strict community governance rules
    public func validateInput(_ text: String, fieldName: String = "Name") -> (isValid: Bool, cleanedText: String, errorMessage: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return (true, "", nil)
        }
        
        // 1. Length Governance
        let maxLength = fieldName.lowercased().contains("snack") ? 45 : 25
        if trimmed.count > maxLength {
            return (false, String(trimmed.prefix(maxLength)), "\(fieldName) must be \(maxLength) characters or less.")
        }
        
        // 2. Appropriate Content Governance
        if containsProhibitedContent(trimmed) {
            return (false, cleanse(trimmed), "Please keep your \(fieldName) friendly and respectful for the Washington Park community.")
        }
        
        return (true, trimmed, nil)
    }
}
