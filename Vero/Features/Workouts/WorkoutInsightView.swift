//
//  WorkoutInsightView.swift
//  Insio Health
//
//  Immersive, narrative workout insight experience
//  Feels like a calm, intelligent interpretation — not a stats dashboard
//

import SwiftUI

struct WorkoutInsightView: View {
    let workout: Workout
    var interpretation: WorkoutInterpretation? = nil

    @Environment(\.dismiss) private var dismiss

    // Animation states
    @State private var labelVisible = false
    @State private var headlineVisible = false
    @State private var bodyVisible = false
    @State private var bulletsVisible = false
    @State private var takeawayVisible = false
    @State private var pathAnimated = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // ═══════════════════════════════════════════
                // IMMERSIVE BACKGROUND
                // ═══════════════════════════════════════════

                ImmersiveBackground(
                    intensity: workout.intensity,
                    pathAnimated: pathAnimated
                )
                .ignoresSafeArea()

                // ═══════════════════════════════════════════
                // CONTENT
                // ═══════════════════════════════════════════

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // Top spacing for status bar
                        Spacer().frame(height: geometry.safeAreaInsets.top + AppSpacing.md)

                        // Back button
                        BackButton { dismiss() }
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                            .opacity(labelVisible ? 1 : 0)

                        Spacer().frame(height: AppSpacing.huge)

                        // ─────────────────────────────────────
                        // 1. SMALL LABEL
                        // ─────────────────────────────────────

                        Text(labelText)
                            .font(AppTypography.labelSmall)
                            .foregroundStyle(.white.opacity(0.6))
                            .tracking(1.5)
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                            .opacity(labelVisible ? 1 : 0)
                            .offset(y: labelVisible ? 0 : 10)

                        Spacer().frame(height: AppSpacing.md)

                        // ─────────────────────────────────────
                        // 2. LARGE NARRATIVE HEADLINE
                        // ─────────────────────────────────────

                        Text(narrativeHeadline)
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                            .opacity(headlineVisible ? 1 : 0)
                            .offset(y: headlineVisible ? 0 : 20)

                        Spacer().frame(height: AppSpacing.xl)

                        // ─────────────────────────────────────
                        // 3. EXPLANATION PARAGRAPH
                        // ─────────────────────────────────────

                        Text(explanationText)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineSpacing(7)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                            .opacity(bodyVisible ? 1 : 0)
                            .offset(y: bodyVisible ? 0 : 15)

                        Spacer().frame(height: AppSpacing.xxl)

                        // ─────────────────────────────────────
                        // 4. CONTEXT BULLETS
                        // ─────────────────────────────────────

                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            ForEach(Array(contextBullets.enumerated()), id: \.offset) { index, bullet in
                                ContextBulletRow(
                                    icon: bullet.icon,
                                    text: bullet.text,
                                    sentiment: bullet.sentiment
                                )
                                .opacity(bulletsVisible ? 1 : 0)
                                .offset(x: bulletsVisible ? 0 : -20)
                                .animation(
                                    AppAnimation.springGentle.delay(Double(index) * 0.08),
                                    value: bulletsVisible
                                )
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)

                        Spacer().frame(height: AppSpacing.xxl)

                        // ─────────────────────────────────────
                        // 5. TAKEAWAY / NEXT STEP
                        // ─────────────────────────────────────

                        TakeawaySection(content: takeawayText)
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                            .opacity(takeawayVisible ? 1 : 0)
                            .offset(y: takeawayVisible ? 0 : 20)

                        Spacer().frame(height: AppSpacing.xxl)

                        // ─────────────────────────────────────
                        // MINIMAL WORKOUT META
                        // ─────────────────────────────────────

                        WorkoutMetaStrip(workout: workout)
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                            .opacity(takeawayVisible ? 1 : 0)

                        // Bottom spacing
                        Spacer().frame(height: 100)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startEntranceSequence()
        }
    }

    // MARK: - Narrative Content
    // Uses InterpretationEngine output when available, falls back to hardcoded logic

    private var labelText: String {
        let hour = Calendar.current.component(.hour, from: workout.endDate)
        if hour < 12 {
            return "MORNING SESSION"
        } else if hour < 17 {
            return "AFTERNOON SESSION"
        } else {
            return "EVENING SESSION"
        }
    }

    private var narrativeHeadline: String {
        // Priority 1: Use InterpretationEngine summary
        if let interp = interpretation {
            return interp.summaryText
        }

        // Priority 2: Use workout's stored interpretation
        if let whatItMeans = workout.whatItMeans {
            return whatItMeans
        }

        // Priority 3: Generate based on intensity
        switch workout.intensity {
        case .low:
            return "A gentle session that kept you moving without taxing your system."
        case .moderate:
            return "A solid effort that pushed your aerobic system in a sustainable way."
        case .high:
            return "This session likely cost more recovery than usual."
        case .max:
            return "You gave everything today. Your body will need time to rebuild."
        }
    }

    private var explanationText: String {
        // Priority 1: Use InterpretationEngine explanation
        if let interp = interpretation {
            return interp.interpretationText
        }

        // Priority 2: Use workout's stored explanation
        if let whatHappened = workout.whatHappened {
            return whatHappened
        }

        // Priority 3: Generate basic explanation
        let duration = workout.durationFormatted

        if let avgHR = workout.averageHeartRate, let maxHR = workout.maxHeartRate {
            return "During this \(duration) \(workout.type.rawValue.lowercased()), your heart rate averaged \(avgHR) bpm and peaked at \(maxHR) bpm. Based on your recent patterns, this represents a \(workout.intensity.rawValue.lowercased()) intensity effort for your current fitness level."
        } else {
            return "This \(duration) \(workout.type.rawValue.lowercased()) was a \(workout.intensity.rawValue.lowercased()) intensity effort based on your perceived exertion."
        }
    }

    private var contextBullets: [(icon: String, text: String, sentiment: BulletSentiment)] {
        // Priority 1: Use InterpretationEngine bullets
        if let interp = interpretation, !interp.bulletPoints.isEmpty {
            return interp.bulletPoints.map { bullet in
                let sentiment: BulletSentiment
                switch bullet.sentiment {
                case .positive: sentiment = .positive
                case .neutral: sentiment = .neutral
                case .caution: sentiment = .caution
                }
                return (bullet.icon, bullet.text, sentiment)
            }
        }

        // Priority 2: Generate from workout data
        var bullets: [(String, String, BulletSentiment)] = []

        // Heart rate context
        if let avgHR = workout.averageHeartRate, avgHR > 150 {
            bullets.append((
                "heart.fill",
                "Heart rate stayed elevated throughout",
                .caution
            ))
        } else if workout.averageHeartRate != nil {
            bullets.append((
                "heart.fill",
                "Heart rate remained in a comfortable zone",
                .positive
            ))
        }

        // Recovery heart rate
        if let recoveryHR = workout.recoveryHeartRate {
            if recoveryHR < 100 {
                bullets.append((
                    "arrow.down.heart",
                    "Recovery heart rate dropped quickly — good sign",
                    .positive
                ))
            } else {
                bullets.append((
                    "arrow.down.heart",
                    "Recovery heart rate was slower than ideal",
                    .caution
                ))
            }
        }

        // Perceived effort
        if let effort = workout.perceivedEffort {
            switch effort {
            case .veryLight, .light:
                bullets.append((
                    "figure.walk",
                    "Perceived effort was low — room for more next time",
                    .neutral
                ))
            case .moderate:
                bullets.append((
                    "figure.run",
                    "Effort felt balanced and sustainable",
                    .positive
                ))
            case .hard:
                bullets.append((
                    "flame",
                    "This felt hard — you pushed through resistance",
                    .neutral
                ))
            case .veryHard:
                bullets.append((
                    "flame.fill",
                    "Maximum effort — recovery is essential now",
                    .caution
                ))
            }
        }

        return bullets
    }

    private var takeawayText: String {
        // Priority 1: Use InterpretationEngine recommendation
        if let interp = interpretation {
            return interp.recommendationText
        }

        // Priority 2: Use workout's stored recommendation
        if let whatToDoNext = workout.whatToDoNext {
            return whatToDoNext
        }

        // Priority 3: Generate based on intensity
        switch workout.intensity {
        case .low:
            return "Light movement tomorrow is fine. Your body can handle more if you're feeling ready."
        case .moderate:
            return "A good balance of effort and recovery. Tomorrow could be another moderate day, or take it easy if needed."
        case .high:
            return "Consider prioritizing sleep tonight and starting tomorrow with a recovery focus. Your body did good work — let it adapt."
        case .max:
            return "Take tomorrow easy. Light movement only. Your nervous system needs time to recover from this level of effort."
        }
    }

    // MARK: - Animation Sequence

    private func startEntranceSequence() {
        withAnimation(AppAnimation.entrance.delay(0.1)) {
            labelVisible = true
        }
        withAnimation(AppAnimation.springGentle.delay(0.2)) {
            headlineVisible = true
        }
        withAnimation(AppAnimation.entrance.delay(0.4)) {
            bodyVisible = true
        }
        withAnimation(AppAnimation.springGentle.delay(0.55)) {
            bulletsVisible = true
        }
        withAnimation(AppAnimation.entrance.delay(0.75)) {
            takeawayVisible = true
        }
        withAnimation(.easeOut(duration: 2.0).delay(0.3)) {
            pathAnimated = true
        }
    }
}

// MARK: - Immersive Background

struct ImmersiveBackground: View {
    let intensity: WorkoutIntensity
    let pathAnimated: Bool

    private var primaryColor: Color {
        switch intensity {
        case .low: return Color(red: 0.10, green: 0.14, blue: 0.20)
        case .moderate: return Color(red: 0.10, green: 0.13, blue: 0.20)
        case .high: return Color(red: 0.12, green: 0.12, blue: 0.18)
        case .max: return Color(red: 0.14, green: 0.10, blue: 0.16)
        }
    }

    private var accentColor: Color {
        switch intensity {
        case .low: return AppColors.olive
        case .moderate: return AppColors.olive
        case .high: return AppColors.coral
        case .max: return AppColors.orange
        }
    }

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    primaryColor,
                    primaryColor.opacity(0.95),
                    Color(red: 0.08, green: 0.10, blue: 0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Organic accent glows
            GeometryReader { geo in
                // Primary glow
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: geo.size.width * 0.9)
                    .offset(x: geo.size.width * 0.3, y: -geo.size.height * 0.1)
                    .blur(radius: 80)

                // Secondary glow
                Circle()
                    .fill(AppColors.navy.opacity(0.15))
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: -geo.size.width * 0.3, y: geo.size.height * 0.4)
                    .blur(radius: 60)

                // Tertiary subtle glow
                Circle()
                    .fill(accentColor.opacity(0.06))
                    .frame(width: geo.size.width * 0.4)
                    .offset(x: geo.size.width * 0.5, y: geo.size.height * 0.7)
                    .blur(radius: 50)
            }

            // Abstract flowing path illustration
            AbstractFlowPath(animated: pathAnimated, accentColor: accentColor)
                .opacity(0.15)
        }
    }
}

// MARK: - Abstract Flow Path

struct AbstractFlowPath: View {
    let animated: Bool
    let accentColor: Color

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Primary wave
                FlowingWave(
                    progress: animated ? 1 : 0,
                    amplitude: 40,
                    frequency: 1.5,
                    phase: 0
                )
                .stroke(
                    LinearGradient(
                        colors: [accentColor.opacity(0.3), accentColor.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .offset(y: geo.size.height * 0.3)

                // Secondary wave
                FlowingWave(
                    progress: animated ? 1 : 0,
                    amplitude: 25,
                    frequency: 2,
                    phase: .pi / 3
                )
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.08), .white.opacity(0.02)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
                .offset(y: geo.size.height * 0.45)

                // Tertiary wave
                FlowingWave(
                    progress: animated ? 1 : 0,
                    amplitude: 30,
                    frequency: 1,
                    phase: .pi / 2
                )
                .stroke(
                    accentColor.opacity(0.1),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round)
                )
                .offset(y: geo.size.height * 0.55)
            }
        }
    }
}

struct FlowingWave: Shape {
    var progress: CGFloat
    var amplitude: CGFloat
    var frequency: CGFloat
    var phase: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height
        let midY = height / 2

        path.move(to: CGPoint(x: -20, y: midY))

        let visibleWidth = (width + 40) * progress

        for x in stride(from: 0, through: visibleWidth, by: 2) {
            let relativeX = x / width
            let y = midY + sin((relativeX * frequency * .pi * 2) + phase) * amplitude
            path.addLine(to: CGPoint(x: x - 20, y: y))
        }

        return path
    }
}

// MARK: - Back Button

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("Back")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.75))
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(.white.opacity(0.08))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Context Bullet Row

enum BulletSentiment {
    case positive, neutral, caution

    var color: Color {
        switch self {
        case .positive: return AppColors.olive
        case .neutral: return .white.opacity(0.6)
        case .caution: return AppColors.coral
        }
    }

    var iconOpacity: Double {
        switch self {
        case .positive: return 1.0
        case .neutral: return 0.6
        case .caution: return 1.0
        }
    }
}

struct ContextBulletRow: View {
    let icon: String
    let text: String
    let sentiment: BulletSentiment

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // Bullet icon
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(sentiment.color)
                .frame(width: 20)
                .opacity(sentiment.iconOpacity)

            // Text
            Text(text)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Takeaway Section

struct TakeawaySection: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Label
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.olive)

                Text("NEXT STEP")
                    .font(AppTypography.labelSmall)
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1)
            }

            // Content
            Text(content)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppColors.olive.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppColors.olive.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Workout Meta Strip

struct WorkoutMetaStrip: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            MetaItem(icon: workout.type.icon, value: workout.type.rawValue)
            MetaItem(icon: "clock", value: workout.durationFormatted)
            MetaItem(icon: "flame.fill", value: "\(workout.calories) cal")

            Spacer()
        }
        .padding(.vertical, AppSpacing.sm)
    }
}

struct MetaItem: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// MARK: - Preview

#Preview {
    WorkoutInsightView(workout: MockData.detailedWorkout)
}
