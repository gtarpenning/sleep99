import SwiftUI

// MARK: - Hex helper (private to this module)

private func hex(_ value: String) -> Color {
    var h = value.trimmingCharacters(in: .whitespacesAndNewlines)
    h = h.hasPrefix("#") ? String(h.dropFirst()) : h
    let scanner = Scanner(string: h)
    var rgb: UInt64 = 0
    scanner.scanHexInt64(&rgb)
    return Color(
        red:   Double((rgb >> 16) & 0xFF) / 255,
        green: Double((rgb >> 8)  & 0xFF) / 255,
        blue:  Double(rgb         & 0xFF) / 255
    )
}

// MARK: - Design System

enum DS {
    // MARK: Backgrounds
    static let bg          = hex("#0D0D12")
    static let surface     = hex("#13131A")
    static let surfaceHigh = hex("#1C1C28")

    // MARK: Borders
    static let border      = hex("#252535")
    static let borderFaint = hex("#1A1A28")

    // MARK: Text
    static let textPrimary   = hex("#EEEEFF")
    static let textSecondary = hex("#8080A0")
    static let textTertiary  = hex("#484860")

    // MARK: Accents
    static let purple    = hex("#7B5CF6")
    static let purpleDim = hex("#3B2C80")
    static let green     = hex("#39FF6A")
    static let greenDim  = hex("#0D4020")

    // MARK: Arc / Category Colors
    static let sleepArc       = hex("#4F8EF7")
    static let recoveryArc    = hex("#A855F7")
    static let consistencyArc = hex("#39FF6A")

    // MARK: Score Colors
    static func scoreColor(for score: Double) -> Color {
        switch score {
        case 85...:   return green
        case 70..<85: return purple
        case 55..<70: return hex("#FF9F0A")
        default:      return hex("#FF453A")
        }
    }

    static func scoreLabel(for score: Double) -> String {
        switch score {
        case 85...:   return "Excellent"
        case 70..<85: return "Good"
        case 55..<70: return "Fair"
        default:      return "Poor"
        }
    }

    // MARK: Sleep Stage Colors
    static func stageColor(for stage: SleepStage) -> Color {
        switch stage {
        case .inBed:      return hex("#252535")
        case .awake:      return hex("#FF6B35").opacity(0.75)
        case .asleep:     return hex("#3A6EBF").opacity(0.55)
        case .asleepCore: return hex("#4F8EF7").opacity(0.65)
        case .asleepDeep: return hex("#7B5CF6").opacity(0.80)
        case .asleepREM:  return hex("#A855F7").opacity(0.75)
        }
    }
}

// MARK: - View Extensions

extension View {
    func dsCard(_ radius: CGFloat = 18) -> some View {
        self
            .background(DS.surface, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(DS.border, lineWidth: 0.5))
    }
}

// MARK: - Section Header

struct DSSectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.footnote.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(DS.textTertiary)
                .textCase(.uppercase)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DS.textTertiary)
                    .textCase(.uppercase)
            }
        }
        .padding(.horizontal, 4)
    }
}
