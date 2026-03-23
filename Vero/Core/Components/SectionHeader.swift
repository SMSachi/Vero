//
//  SectionHeader.swift
//  Insio Health
//
//  Reusable section header with optional action
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: subtitle != nil ? .top : .center) {
            VStack(alignment: .leading, spacing: AppSpacing.textLineGap) {
                Text(title)
                    .font(AppTypography.headlineSmall)
                    .foregroundStyle(AppColors.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()

            if let actionTitle = actionTitle, let action = action {
                TextButton(actionTitle, action: action)
            }
        }
    }
}

// MARK: - Large Section Header

struct LargeSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(AppTypography.headlineLarge)
                .foregroundStyle(AppColors.textPrimary)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

#Preview("Section Headers") {
    VStack(spacing: 32) {
        SectionHeader(title: "Recent Workouts")

        SectionHeader(
            title: "This Week",
            subtitle: "4 workouts completed"
        )

        SectionHeader(
            title: "Insights",
            actionTitle: "See All"
        ) {
            print("tapped")
        }

        LargeSectionHeader(
            title: "Good Morning, Sachi",
            subtitle: "Here's your recovery status"
        )
    }
    .padding()
    .background(AppColors.background)
}
