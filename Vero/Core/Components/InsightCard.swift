//
//  InsightCard.swift
//  Insio Health
//
//  Editorial insight card with clean typography
//

import SwiftUI

struct InsightCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    var metric: String? = nil
    var metricLabel: String? = nil
    var isPositive: Bool? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Header row
                HStack(alignment: .top, spacing: AppSpacing.xs) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.12))
                            .frame(width: 40, height: 40)

                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(iconColor)
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.textLineGap) {
                        Text(title)
                            .font(AppTypography.titleMedium)
                            .foregroundStyle(AppColors.textPrimary)

                        Text(description)
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)

                    // Metric badge
                    if let metric = metric {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 2) {
                                if let isPositive = isPositive {
                                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                Text(metric)
                                    .font(AppTypography.labelMedium)
                            }
                            .foregroundStyle(metricColor)

                            if let metricLabel = metricLabel {
                                Text(metricLabel)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textTertiary)
                            }
                        }
                    }
                }
            }
            .cardPadding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge))
            .cardShadow()
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.98))
        .disabled(action == nil)
    }

    private var metricColor: Color {
        guard let isPositive = isPositive else { return AppColors.textSecondary }
        return isPositive ? AppColors.recoveryGood : AppColors.recoveryLow
    }
}

// MARK: - Compact Insight Card

struct CompactInsightCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 24)

            Text(title)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(AppTypography.titleSmall)
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
    }
}

// MARK: - Previews

#Preview("Insight Cards") {
    ScrollView {
        VStack(spacing: 16) {
            InsightCard(
                icon: "arrow.up.right.circle.fill",
                iconColor: AppColors.olive,
                title: "Consistency Streak",
                description: "You've worked out 4 days this week, matching your best streak.",
                metric: "+15%",
                metricLabel: "vs last week",
                isPositive: true
            )

            InsightCard(
                icon: "moon.stars.fill",
                iconColor: AppColors.info,
                title: "Sleep Opportunity",
                description: "Adding 30 minutes of sleep could improve your HRV by 8%."
            )

            InsightCard(
                icon: "exclamationmark.triangle.fill",
                iconColor: AppColors.warning,
                title: "Recovery Warning",
                description: "Your resting heart rate is elevated. Consider a lighter day.",
                metric: "-12%",
                isPositive: false
            )

            CompactInsightCard(
                icon: "flame.fill",
                iconColor: AppColors.orange,
                title: "Calories burned",
                value: "1,850"
            )
        }
        .padding()
    }
    .background(AppColors.background)
}
