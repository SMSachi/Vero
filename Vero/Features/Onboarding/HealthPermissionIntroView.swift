//
//  HealthPermissionIntroView.swift
//  Insio Health
//
//  Explains Apple Health data access requirements.
//  When the user taps Continue, this view requests HealthKit authorization
//  via HealthKitService before proceeding to the next onboarding step.
//

import SwiftUI

struct HealthPermissionIntroView: View {
    @EnvironmentObject var state: OnboardingState
    @State private var showContent = false
    @State private var isRequestingAuthorization = false

    private let requiredData: [(icon: String, title: String, description: String)] = [
        ("figure.run", "Workouts", "Types, duration, and timestamps"),
        ("heart.fill", "Heart Rate", "During workouts and resting"),
        ("waveform.path.ecg", "Heart Rate Variability", "Recovery indicator"),
        ("bed.double.fill", "Sleep", "Duration and quality"),
        ("flame.fill", "Active Energy", "Calories burned"),
        ("location.fill", "Distance", "For outdoor activities")
    ]

    private let optionalData: [(icon: String, title: String)] = [
        ("drop.fill", "Hydration"),
        ("fork.knife", "Nutrition")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Back button
                HStack {
                    OnboardingBackButton()
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.sm)

                Spacer()
                    .frame(height: AppSpacing.lg)

                // Apple Health icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.pink, Color.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.white)
                }
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.8)

                Spacer()
                    .frame(height: AppSpacing.lg)

                // Header
                VStack(spacing: AppSpacing.xs) {
                    Text("Connect Apple Health")
                        .font(AppTypography.displaySmall)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Insio reads your workout data to provide\npersonalized insights.")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .opacity(showContent ? 1 : 0)

                Spacer()
                    .frame(height: AppSpacing.xl)

                // Required data section
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("We'll request access to:")
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(AppColors.textTertiary)
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    VStack(spacing: 1) {
                        ForEach(0..<requiredData.count, id: \.self) { index in
                            HealthDataRow(
                                icon: requiredData[index].icon,
                                title: requiredData[index].title,
                                subtitle: requiredData[index].description,
                                isFirst: index == 0,
                                isLast: index == requiredData.count - 1
                            )
                        }
                    }
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
                    .cardShadow()
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }
                .opacity(showContent ? 1 : 0)

                Spacer()
                    .frame(height: AppSpacing.lg)

                // Optional data section
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Optional:")
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(AppColors.textTertiary)
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                    HStack(spacing: AppSpacing.xs) {
                        ForEach(0..<optionalData.count, id: \.self) { index in
                            OptionalDataChip(
                                icon: optionalData[index].icon,
                                title: optionalData[index].title
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }
                .opacity(showContent ? 1 : 0)

                Spacer()
                    .frame(height: AppSpacing.lg)

                // Privacy note
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textTertiary)

                    Text("Your data stays on your device and is never shared.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
                .opacity(showContent ? 1 : 0)

                Spacer()
                    .frame(height: AppSpacing.xxl)

                // CTA
                // When tapped, this button requests HealthKit authorization
                // The system will present the HealthKit permission sheet
                PrimaryButton(
                    isRequestingAuthorization ? "Connecting..." : "Continue",
                    isDisabled: isRequestingAuthorization
                ) {
                    requestHealthKitAuthorization()
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .onAppear {
            withAnimation(AppAnimation.entrance) {
                showContent = true
            }
        }
    }

    // MARK: - HealthKit Authorization

    /// Request HealthKit authorization and proceed to next step.
    /// This triggers the system HealthKit permission sheet.
    /// We proceed to the next step regardless of the user's choice,
    /// as the app can still function with mock data if permission is denied.
    private func requestHealthKitAuthorization() {
        isRequestingAuthorization = true

        Task {
            // Request authorization from HealthKitService
            // This will present the system HealthKit permission sheet
            let _ = await HealthKitService.shared.requestAuthorization()

            // Proceed to next step regardless of authorization result
            // The app will use mock data if permission was denied
            await MainActor.run {
                isRequestingAuthorization = false
                state.nextStep()
            }
        }
    }
}

// MARK: - Health Data Row

struct HealthDataRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var isFirst: Bool = false
    var isLast: Bool = false

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColors.orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.titleSmall)
                    .foregroundStyle(AppColors.textPrimary)

                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.olive)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.cardBackground)
    }
}

// MARK: - Optional Data Chip

struct OptionalDataChip: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)

            Text(title)
                .font(AppTypography.labelMedium)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.cardBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(AppColors.divider, lineWidth: 1)
        )
    }
}

#Preview {
    HealthPermissionIntroView()
        .environmentObject(OnboardingState())
}
