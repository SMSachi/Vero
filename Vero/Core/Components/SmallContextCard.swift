//
//  SmallContextCard.swift
//  Vero
//
//  Compact context cards for daily metrics
//

import SwiftUI

struct SmallContextCard: View {
    let title: String
    let value: String
    let icon: String
    var status: ContextStatus = .neutral
    var action: (() -> Void)? = nil

    enum ContextStatus {
        case excellent
        case good
        case moderate
        case low
        case neutral

        var color: Color {
            switch self {
            case .excellent: return AppColors.recoveryExcellent
            case .good: return AppColors.recoveryGood
            case .moderate: return AppColors.recoveryModerate
            case .low: return AppColors.recoveryLow
            case .neutral: return AppColors.textSecondary
            }
        }
    }

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: AppSpacing.xs) {
                // Icon with status color
                ZStack {
                    RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                        .fill(status.color.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(status.color)
                }

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)

                    Text(value)
                        .font(AppTypography.titleSmall)
                        .foregroundStyle(AppColors.textPrimary)
                }

                Spacer()

                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .padding(AppSpacing.xs)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
            .cardShadow()
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.98))
        .disabled(action == nil)
    }
}

// MARK: - Context Card Row

struct ContextCardRow: View {
    let items: [ContextItem]

    struct ContextItem: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let icon: String
        var status: SmallContextCard.ContextStatus = .neutral
    }

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(items) { item in
                SmallContextCard(
                    title: item.title,
                    value: item.value,
                    icon: item.icon,
                    status: item.status
                )
            }
        }
    }
}

// MARK: - Previews

#Preview("Small Context Cards") {
    VStack(spacing: 16) {
        SectionHeader(title: "Today's Context")

        // Individual cards
        SmallContextCard(
            title: "Sleep",
            value: "7h 32m",
            icon: "moon.fill",
            status: .good
        )

        SmallContextCard(
            title: "HRV",
            value: "45 ms",
            icon: "waveform.path.ecg",
            status: .moderate
        )

        SmallContextCard(
            title: "Resting HR",
            value: "58 bpm",
            icon: "heart.fill",
            status: .excellent
        ) {
            print("tapped")
        }

        Divider()
            .padding(.vertical, 8)

        // Row of context cards
        ContextCardRow(items: [
            .init(title: "Sleep", value: "7.5h", icon: "moon.fill", status: .good),
            .init(title: "HRV", value: "45", icon: "waveform.path.ecg", status: .moderate),
            .init(title: "RHR", value: "58", icon: "heart.fill", status: .excellent)
        ])
    }
    .padding()
    .background(AppColors.background)
}
