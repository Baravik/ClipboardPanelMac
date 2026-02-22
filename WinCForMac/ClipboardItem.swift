import Foundation

// MARK: - Clipboard Item Model

/// Represents a single clipboard history entry.
struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let timestamp: Date

    init(content: String) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
    }

    /// Returns a truncated preview of the content for display purposes.
    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let singleLine = trimmed.replacingOccurrences(of: "\n", with: " ")
        if singleLine.count > 120 {
            return String(singleLine.prefix(120)) + "…"
        }
        return singleLine
    }

    /// Human-readable relative timestamp.
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
