import SwiftUI

private enum MetricsTimeRange: String, CaseIterable, Identifiable {
    case last7Days
    case last30Days
    case allTime

    var id: Self { self }

    var titleKey: LocalizedStringKey {
        switch self {
        case .last7Days: return "7 days"
        case .last30Days: return "30 days"
        case .allTime: return "All time"
        }
    }

    var daysBack: Int? {
        switch self {
        case .last7Days: return 7
        case .last30Days: return 30
        case .allTime: return nil
        }
    }
}

struct MetricsContent: View {
    let transcriptions: [Transcription]
    @State private var showKeyboardShortcuts = false
    @State private var selectedRange: MetricsTimeRange = .last7Days

    var body: some View {
        Group {
            if transcriptions.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 20) {
                    rangePicker
                    metricsSection
                }
                .padding(.vertical, 28)
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.windowBackgroundColor))
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 56, weight: .semibold))
                .foregroundColor(.secondary)
            Text("No Transcriptions Yet")
                .font(.title3.weight(.semibold))
            Text("Start your first recording to unlock value insights.")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Sections

    private var rangePicker: some View {
        HStack {
            Spacer()
            Picker("", selection: $selectedRange) {
                ForEach(MetricsTimeRange.allCases) { range in
                    Text(range.titleKey).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 260)
        }
    }

    private var filteredTranscriptions: [Transcription] {
        guard let days = selectedRange.daysBack else {
            return transcriptions
        }
        let calendar = Calendar.current
        let now = Date()
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: now) else {
            return transcriptions
        }
        return transcriptions.filter { $0.timestamp >= cutoff }
    }

    private var metricsSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
            MetricCard(
                icon: "mic.fill",
                title: "Sessions Recorded",
                value: "\(filteredTranscriptions.count)",
                detail: "HoAh sessions completed",
                color: Color(nsColor: .controlAccentColor)
            )
            
            MetricCard(
                icon: "text.alignleft",
                title: "Words Dictated",
                value: Formatters.formattedNumber(totalWordsTranscribed),
                detail: "words generated",
                color: Color(nsColor: .controlAccentColor)
            )
        }
    }
    
    // MARK: - Computed Metrics
    
    private var totalWordsTranscribed: Int {
        filteredTranscriptions.reduce(0) { $0 + $1.text.smartWordCount }
    }
}
    
private enum Formatters {
    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
    
    static func formattedNumber(_ value: Int) -> String {
        return numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
