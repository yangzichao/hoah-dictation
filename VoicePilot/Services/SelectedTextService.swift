import Foundation
import AppKit

class SelectedTextService {
    static func fetchSelectedText() async -> String? {
        // Fallback to the current string pasteboard content as a lightweight substitute
        return NSPasteboard.general.string(forType: .string)
    }
}
