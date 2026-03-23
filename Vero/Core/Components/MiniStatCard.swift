//
//  MiniStatCard.swift
//  Insio Health
//
//  Compact stat display for grids and summaries
//

import SwiftUI

struct MiniStatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconColor: Color = AppColors.navy
    var trend: Trend? = nil

    enum Trend {
        case up(String)
        case down(String)
        case neutral(String)

        var color: Color {
            switch self {
            case .up: return AppColors.recoveryGood
            case .down: return AppColors.recoveryLow
            case .neutral: return AppColors.textTertiary
            }
        }

        var icon: String {
            switch self {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .neutral: return "minus"
            }
        }

        var value: String {
            switch self {
            case .up(let v), .down(let v), .neutral(let v): return v
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // Icon or trend
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                Spacer()

                if let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend.icon)
                            .font(.system(size: 9, weight: .bold))
                        Text(trend.value)
                            .font(AppTypography.caption)
                    }
                    .foregroundStyle(trend.color)
                }
            }

            Spacer()

            // Value
            Text(value)
                .font(AppTypography.metricSmall)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Title and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(AppColors.textSecondary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardPaddingCompact()
        .frame(minHeight: 120)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge))
        .cardShadow()
    }
}

// MARK: - Horizontal Mini Stat

struct HorizontalMiniStat: View {
    let title: String
    let value: String
    var icon: String? = nil
    var iconColor: Color = AppColors.navy

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            if let icon = icon {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(iconColor)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(AppTypography.titleMedium)
                    .foregroundStyle(AppColors.textPrimary)

                Text(title)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(AppSpacing.xs)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
    }
}

// MARK: - Previews

#Preview("Mini Stat Cards") {
    VStack(spacing: 20) {
        // Grid of mini stats
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MiniStatCard(
                title: "Workouts",
                value: "12",
                subtitle: "this month",
                icon: "figure.run",
                iconColor: AppColors.orange,
                trend: .up("23%")
            )

            MiniStatCard(
                title: "Avg Recovery",
                value: "78%",
                icon: "heart.fill",
                iconColor: AppColors.olive,
                trend: .up("5%")
            )

            MiniStatCard(
                title: "Streak",
                value: "4",
                subtitle: "days",
                icon: "flame.fill",
                iconColor: AppColors.orange
            )

            MiniStatCard(
                title: "Rest Days",
                value: "2",
                subtitle: "this week",
                icon: "moon.fill",
                iconColor: AppColors.info
            )
        }

        Divider()

        HorizontalMiniStat(
            title: "Current streak",
            value: "4 days",
            icon: "flame.fill",
            iconColor: AppColors.orange
        )

        HorizontalMiniStat(
            title: "Best streak",
            value: "12 days",
            icon: "trophy.fill",
            iconColor: AppColors.olive
        )
    }
    .padding()
    .background(AppColors.background)
}
