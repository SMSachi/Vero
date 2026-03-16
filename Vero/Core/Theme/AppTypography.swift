//
//  AppTypography.swift
//  Vero
//
//  Bold, warm typography hierarchy with personality
//

import SwiftUI

struct AppTypography {
    // MARK: - Display (Hero text, bold statements)

    /// Extra large hero text - main headlines
    static let displayHero = Font.system(size: 44, weight: .bold, design: .rounded)

    /// Large display text
    static let displayLarge = Font.system(size: 36, weight: .bold, design: .rounded)

    /// Medium display text
    static let displayMedium = Font.system(size: 30, weight: .bold, design: .rounded)

    /// Small display text
    static let displaySmall = Font.system(size: 26, weight: .semibold, design: .rounded)

    // MARK: - Headlines (Section titles, card headers)

    static let headlineLarge = Font.system(size: 22, weight: .semibold, design: .default)
    static let headlineMedium = Font.system(size: 19, weight: .semibold, design: .default)
    static let headlineSmall = Font.system(size: 17, weight: .semibold, design: .default)

    // MARK: - Titles (Card titles, list items)

    static let titleLarge = Font.system(size: 17, weight: .medium, design: .default)
    static let titleMedium = Font.system(size: 15, weight: .medium, design: .default)
    static let titleSmall = Font.system(size: 13, weight: .medium, design: .default)

    // MARK: - Body (Primary content, narratives)

    static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)

    // MARK: - Narrative (For insight paragraphs - slightly larger line height feel)

    static let narrativeLarge = Font.system(size: 18, weight: .regular, design: .default)
    static let narrativeMedium = Font.system(size: 16, weight: .regular, design: .default)

    // MARK: - Labels (Supporting text, metadata)

    static let labelLarge = Font.system(size: 13, weight: .semibold, design: .default)
    static let labelMedium = Font.system(size: 12, weight: .semibold, design: .default)
    static let labelSmall = Font.system(size: 11, weight: .semibold, design: .default)

    // MARK: - Captions (Fine print, timestamps)

    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let captionMedium = Font.system(size: 12, weight: .medium, design: .default)
    static let captionSmall = Font.system(size: 11, weight: .regular, design: .default)

    // MARK: - Metrics (Numbers, stats - rounded for friendliness)

    static let metricHero = Font.system(size: 56, weight: .bold, design: .rounded)
    static let metricLarge = Font.system(size: 44, weight: .bold, design: .rounded)
    static let metricMedium = Font.system(size: 32, weight: .bold, design: .rounded)
    static let metricSmall = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let metricMini = Font.system(size: 18, weight: .semibold, design: .rounded)

    // MARK: - Buttons

    static let buttonLarge = Font.system(size: 17, weight: .semibold, design: .default)
    static let buttonMedium = Font.system(size: 15, weight: .semibold, design: .default)
    static let buttonSmall = Font.system(size: 13, weight: .semibold, design: .default)

    // MARK: - Greeting (Friendly, warm)

    static let greeting = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let greetingSubtitle = Font.system(size: 17, weight: .regular, design: .default)

    // MARK: - Unified Screen Styles

    /// Screen title - 28pt bold rounded (Home, Workouts, Trends, Profile)
    static let screenTitle = Font.system(size: 28, weight: .bold, design: .rounded)

    /// Section header - 16pt semibold (card headers, section titles)
    static let sectionHeader = Font.system(size: 16, weight: .semibold, design: .rounded)

    /// Card title - 16pt semibold
    static let cardTitle = Font.system(size: 16, weight: .semibold, design: .default)

    /// Card subtitle - 14pt medium
    static let cardSubtitle = Font.system(size: 14, weight: .medium, design: .default)

    /// Card body - 14pt regular
    static let cardBody = Font.system(size: 14, weight: .regular, design: .default)

    /// Stat value - 18pt bold rounded
    static let statValue = Font.system(size: 18, weight: .bold, design: .rounded)

    /// Stat label - 12pt medium
    static let statLabel = Font.system(size: 12, weight: .medium, design: .default)

    /// Chip text - 13pt semibold
    static let chipText = Font.system(size: 13, weight: .semibold, design: .default)

    /// Mini label - 11pt medium
    static let miniLabel = Font.system(size: 11, weight: .medium, design: .default)
}

// MARK: - Text Style Modifiers

extension View {
    func textStyle(_ font: Font, color: Color = AppColors.textPrimary) -> some View {
        self.font(font)
            .foregroundStyle(color)
    }
}

// MARK: - Premade Text Components

struct HeroText: View {
    let text: String
    var color: Color = AppColors.textPrimary

    var body: some View {
        Text(text)
            .font(AppTypography.displayHero)
            .foregroundStyle(color)
            .lineSpacing(2)
    }
}

struct DisplayText: View {
    let text: String
    var size: DisplaySize = .medium
    var color: Color = AppColors.textPrimary

    enum DisplaySize {
        case large, medium, small

        var font: Font {
            switch self {
            case .large: return AppTypography.displayLarge
            case .medium: return AppTypography.displayMedium
            case .small: return AppTypography.displaySmall
            }
        }
    }

    var body: some View {
        Text(text)
            .font(size.font)
            .foregroundStyle(color)
    }
}

struct MetricText: View {
    let value: String
    var size: MetricSize = .medium
    var color: Color = AppColors.textPrimary

    enum MetricSize {
        case hero, large, medium, small, mini

        var font: Font {
            switch self {
            case .hero: return AppTypography.metricHero
            case .large: return AppTypography.metricLarge
            case .medium: return AppTypography.metricMedium
            case .small: return AppTypography.metricSmall
            case .mini: return AppTypography.metricMini
            }
        }
    }

    var body: some View {
        Text(value)
            .font(size.font)
            .foregroundStyle(color)
    }
}

struct NarrativeText: View {
    let text: String
    var color: Color = AppColors.textSecondary

    var body: some View {
        Text(text)
            .font(AppTypography.narrativeMedium)
            .foregroundStyle(color)
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Warm Greeting

struct WarmGreeting: View {
    let name: String
    var timeOfDay: TimeOfDay = .current

    enum TimeOfDay {
        case morning, afternoon, evening, night, current

        var greeting: String {
            switch self {
            case .morning: return "Good morning"
            case .afternoon: return "Good afternoon"
            case .evening: return "Good evening"
            case .night: return "Good night"
            case .current:
                let hour = Calendar.current.component(.hour, from: Date())
                switch hour {
                case 5..<12: return "Good morning"
                case 12..<17: return "Good afternoon"
                case 17..<21: return "Good evening"
                default: return "Good night"
                }
            }
        }
    }

    var body: some View {
        Text("\(timeOfDay.greeting), \(name)")
            .font(AppTypography.greeting)
            .foregroundStyle(AppColors.textPrimary)
    }
}
