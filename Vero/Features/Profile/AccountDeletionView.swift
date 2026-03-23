//
//  AccountDeletionView.swift
//  Insio Health
//
//  Account deletion flow with clear warning and confirmation.
//  Handles Supabase account deletion and local data cleanup.
//

import SwiftUI

// MARK: - Account Deletion View

struct AccountDeletionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService

    @State private var confirmationText = ""
    @State private var isDeleting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var deletionComplete = false

    /// User must type this to confirm deletion
    private let confirmationRequired = "DELETE"

    private var canDelete: Bool {
        confirmationText.uppercased() == confirmationRequired && !isDeleting
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.xl) {
                    // Warning icon
                    WarningHeader()

                    // Warning message
                    WarningContent()

                    // What will be deleted
                    DeletionDetails()

                    // Confirmation input
                    ConfirmationInput(
                        text: $confirmationText,
                        required: confirmationRequired
                    )

                    // Delete button
                    DeleteButton(
                        canDelete: canDelete,
                        isDeleting: isDeleting,
                        onDelete: performDeletion
                    )

                    // Cancel link
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(AppColors.navy)
                }
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppSpacing.Layout.bottomScrollPadding)
            }
            .background(AppColors.background)
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .alert("Deletion Failed", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Account Deleted", isPresented: $deletionComplete) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your account and data have been deleted.")
        }
        .interactiveDismissDisabled(isDeleting)
    }

    private func performDeletion() {
        guard canDelete else { return }

        isDeleting = true

        Task {
            do {
                // Delete account via AuthService
                try await authService.deleteAccount()

                // Clear local data
                clearLocalData()

                // Clear premium status
                PremiumManager.shared.clearPremiumStatus()

                // Sign out
                await appState.signOut()

                deletionComplete = true

            } catch {
                print("❌ AccountDeletion: Failed - \(error)")
                errorMessage = "Failed to delete account: \(error.localizedDescription)"
                showError = true
            }

            isDeleting = false
        }
    }

    private func clearLocalData() {
        // Clear user defaults
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()

        // Clear persistence
        PersistenceService.shared.clearAllData()

        // Clear nutrition data
        NutritionService.shared.deleteAllEntries()

        // Clear AI cache
        OpenRouterService.shared.clearCache()

        // Clear user goals
        UserGoalService.shared.clearGoals()

        print("🗑️ AccountDeletion: Local data cleared")
    }
}

// MARK: - Warning Header

private struct WarningHeader: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.error.opacity(0.15))
                .frame(width: 80, height: 80)

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(AppColors.error)
        }
    }
}

// MARK: - Warning Content

private struct WarningContent: View {
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("Delete Your Account?")
                .font(AppTypography.headlineLarge)
                .foregroundStyle(AppColors.textPrimary)

            Text("This action is permanent and cannot be undone. All your data will be permanently deleted from our servers.")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
    }
}

// MARK: - Deletion Details

private struct DeletionDetails: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("What will be deleted:")
                .font(AppTypography.labelMedium)
                .foregroundStyle(AppColors.textPrimary)

            VStack(spacing: AppSpacing.xs) {
                DeletionDetailRow(text: "Your account and profile")
                DeletionDetailRow(text: "All workout data synced to cloud")
                DeletionDetailRow(text: "Check-in history")
                DeletionDetailRow(text: "Trend and insight data")
                DeletionDetailRow(text: "Premium subscription (if active)")
            }

            Text("Note: Data stored locally on this device will also be cleared.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
                .padding(.top, AppSpacing.xs)
        }
        .padding(AppSpacing.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.error.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
    }
}

private struct DeletionDetailRow: View {
    let text: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(AppColors.error)

            Text(text)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textPrimary)

            Spacer()
        }
    }
}

// MARK: - Confirmation Input

private struct ConfirmationInput: View {
    @Binding var text: String
    let required: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Type \"\(required)\" to confirm:")
                .font(AppTypography.labelMedium)
                .foregroundStyle(AppColors.textPrimary)

            TextField("", text: $text)
                .font(AppTypography.bodyMedium)
                .padding(AppSpacing.md)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
                        .stroke(AppColors.divider, lineWidth: 1)
                )
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)
        }
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
    }
}

// MARK: - Delete Button

private struct DeleteButton: View {
    let canDelete: Bool
    let isDeleting: Bool
    let onDelete: () -> Void

    var body: some View {
        Button(action: onDelete) {
            HStack(spacing: AppSpacing.sm) {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                }

                Text(isDeleting ? "Deleting..." : "Delete My Account")
                    .font(AppTypography.buttonLarge)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(canDelete ? AppColors.error : AppColors.error.opacity(0.4))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
        }
        .disabled(!canDelete)
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
    }
}

// MARK: - Preview

#Preview {
    AccountDeletionView()
        .environmentObject(AppState())
        .environmentObject(AuthService.shared)
}
