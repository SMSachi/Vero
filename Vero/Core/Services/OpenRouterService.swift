//
//  OpenRouterService.swift
//  Insio Health
//
//  AI enhancement service using OpenRouter.
//  Converts structured AnalysisOutput into natural, user-friendly language.
//
//  ARCHITECTURE:
//  - Takes AnalysisOutput (structured data from local rules) as input
//  - Sends minimal, structured data to OpenRouter (NOT raw HealthKit data)
//  - Returns enhanced natural language summaries
//  - Falls back to local text if AI fails
//  - Includes caching to avoid repeated calls
//  - CRITICAL: AI only REWRITES deterministic analysis - never hallucinates
//
//  TIER AWARENESS:
//  - Plus: Weekly trend summaries with nutrition awareness
//  - Pro: Per-workout AI summaries + weekly/monthly trends
//
//  USAGE:
//  let enhanced = await OpenRouterService.shared.enhanceAnalysis(output)
//

import Foundation

// MARK: - OpenRouter Service

@MainActor
final class OpenRouterService: ObservableObject {

    // MARK: - Singleton

    static let shared = OpenRouterService()

    // MARK: - Published State

    @Published private(set) var isProcessing = false
    @Published private(set) var lastError: String?

    // MARK: - Cache

    private var cache: [String: CachedEnhancement] = [:]

    // MARK: - Initialization

    private init() {
        // Load cached enhancements
        loadCache()
    }

    // MARK: - Enhancement (Pro Feature)

    /// Enhance an AnalysisOutput with AI-generated natural language
    /// Requires Pro tier
    func enhanceAnalysis(_ output: AnalysisOutput, workoutId: UUID) async -> EnhancedAnalysis {
        // Check if Pro tier and AI is configured
        guard PremiumManager.shared.canAccessWorkoutAI() else {
            print("🤖 OpenRouter: Workout AI not available (requires Pro tier)")
            return EnhancedAnalysis(
                enhancedSummary: output.localSummary,
                enhancedInterpretation: output.localInterpretation,
                enhancedRecommendation: output.localRecommendation,
                source: .local
            )
        }

        // Check cache
        let cacheKey = workoutId.uuidString
        if let cached = cache[cacheKey], !cached.isExpired {
            print("🤖 OpenRouter: Using cached enhancement for \(cacheKey)")
            return cached.enhancement
        }

        // Generate AI enhancement
        isProcessing = true
        lastError = nil

        do {
            let prompt = buildWorkoutPrompt(from: output)
            let response = try await callOpenRouter(prompt: prompt)
            let enhancement = parseResponse(response, fallback: output)

            // Cache the result
            let cachedItem = CachedEnhancement(
                enhancement: enhancement,
                timestamp: Date()
            )
            cache[cacheKey] = cachedItem
            saveCache()

            isProcessing = false
            print("🤖 OpenRouter: Enhancement successful for \(cacheKey)")
            return enhancement

        } catch {
            print("🤖 OpenRouter: Enhancement failed - \(error)")
            lastError = error.localizedDescription
            isProcessing = false

            // Fall back to local text
            return EnhancedAnalysis(
                enhancedSummary: output.localSummary,
                enhancedInterpretation: output.localInterpretation,
                enhancedRecommendation: output.localRecommendation,
                source: .local
            )
        }
    }

    // MARK: - Prompt Building

    private func buildWorkoutPrompt(from output: AnalysisOutput) -> String {
        // Build a structured prompt with ONLY the necessary data
        // Never send raw HealthKit data or unnecessary user information

        var prompt = """
        You are a friendly fitness coach helping someone understand their workout. \
        Rewrite the following workout analysis into natural, encouraging language. \
        Keep it concise (2-3 sentences for summary, 3-4 for interpretation). \
        Be warm and supportive, but factual.

        WORKOUT DATA:
        - Type: \(output.metrics.workoutType)
        - Duration: \(formatDuration(output.metrics.duration))
        - Intensity: \(output.metrics.intensity)
        - Calories: \(output.metrics.calories)
        """

        if let avgHR = output.metrics.averageHeartRate {
            prompt += "\n- Average Heart Rate: \(avgHR) bpm"
        }

        if let distance = output.metrics.distance {
            prompt += "\n- Distance: \(String(format: "%.1f", distance)) km"
        }

        prompt += "\n\nCURRENT ANALYSIS:"
        prompt += "\nSummary: \(output.localSummary)"
        prompt += "\nInterpretation: \(output.localInterpretation)"

        if let recommendation = output.localRecommendation {
            prompt += "\nRecommendation: \(recommendation)"
        }

        // Add recovery context if available
        if let recovery = output.recoveryContext, recovery.hasData {
            prompt += "\n\nRECOVERY CONTEXT:"
            if let sleep = recovery.sleepHours {
                prompt += "\n- Sleep: \(String(format: "%.1f", sleep)) hours"
            }
            if let readiness = recovery.readinessScore {
                prompt += "\n- Readiness Score: \(readiness)%"
            }
        }

        // Add nutrition context if available (Pro feature)
        if let nutrition = output.nutritionContext, nutrition.hasData {
            prompt += "\n\nNUTRITION CONTEXT:"
            if let water = nutrition.waterIntakeLiters {
                prompt += "\n- Water intake: \(String(format: "%.1f", water))L (\(nutrition.hydrationStatus.displayText))"
            }
            if let calories = nutrition.calories {
                prompt += "\n- Calories: \(calories) kcal"
            }
            if let protein = nutrition.proteinGrams {
                prompt += "\n- Protein: \(protein)g"
            }
        }

        // Add data completeness note
        if let completeness = output.dataCompleteness {
            prompt += "\n\nDATA QUALITY: \(completeness.level.displayText)"
        }

        prompt += """

        RESPONSE FORMAT (JSON):
        {
            "summary": "Your enhanced 2-3 sentence summary here",
            "interpretation": "Your enhanced 3-4 sentence interpretation here",
            "recommendation": "Your enhanced recommendation here (optional)"
        }

        Respond ONLY with the JSON, no other text.
        """

        return prompt
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes) minutes"
    }

    // MARK: - API Call

    private func callOpenRouter(prompt: String) async throws -> String {
        guard InsioConfig.OpenRouter.isConfigured else {
            throw OpenRouterError.notConfigured
        }

        let url = URL(string: "\(InsioConfig.OpenRouter.baseURL)/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(InsioConfig.OpenRouter.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Insio Health App", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Insio Health", forHTTPHeaderField: "X-Title")

        let body: [String: Any] = [
            "model": InsioConfig.OpenRouter.model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": InsioConfig.OpenRouter.maxTokens,
            "temperature": InsioConfig.OpenRouter.temperature
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("🤖 OpenRouter: API error \(httpResponse.statusCode): \(errorBody)")
            throw OpenRouterError.apiError(httpResponse.statusCode, errorBody)
        }

        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenRouterError.parseError
        }

        return content
    }

    // MARK: - Response Parsing

    private func parseResponse(_ response: String, fallback: AnalysisOutput) -> EnhancedAnalysis {
        // Try to parse JSON response
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            print("🤖 OpenRouter: Failed to parse response as JSON, using fallback")
            return EnhancedAnalysis(
                enhancedSummary: fallback.localSummary,
                enhancedInterpretation: fallback.localInterpretation,
                enhancedRecommendation: fallback.localRecommendation,
                source: .local
            )
        }

        return EnhancedAnalysis(
            enhancedSummary: json["summary"] ?? fallback.localSummary,
            enhancedInterpretation: json["interpretation"] ?? fallback.localInterpretation,
            enhancedRecommendation: json["recommendation"] ?? fallback.localRecommendation,
            source: .ai
        )
    }

    // MARK: - Caching

    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ai_enhancements.json")
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([String: CachedEnhancement].self, from: data) else {
            return
        }

        // Filter out expired entries
        cache = decoded.filter { !$0.value.isExpired }

        // Limit cache size
        if cache.count > InsioConfig.Cache.aiEnhancementMaxCount {
            let sorted = cache.sorted { $0.value.timestamp > $1.value.timestamp }
            let prefixedEntries = Array(sorted.prefix(InsioConfig.Cache.aiEnhancementMaxCount))
            cache = Dictionary(uniqueKeysWithValues: prefixedEntries)
        }

        print("🤖 OpenRouter: Loaded \(cache.count) cached enhancements")
    }

    private func saveCache() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: cacheURL)
    }

    /// Clear all cached enhancements
    func clearCache() {
        cache.removeAll()
        try? FileManager.default.removeItem(at: cacheURL)
        print("🤖 OpenRouter: Cache cleared")
    }
}

// MARK: - Enhanced Analysis Result

struct EnhancedAnalysis: Codable, Equatable {
    let enhancedSummary: String
    let enhancedInterpretation: String
    let enhancedRecommendation: String?
    let source: EnhancementSource
}

enum EnhancementSource: String, Codable {
    case ai = "ai"
    case local = "local"
}

// MARK: - Cached Enhancement

private struct CachedEnhancement: Codable {
    let enhancement: EnhancedAnalysis
    let timestamp: Date

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > InsioConfig.Cache.aiEnhancementTTL
    }
}

// MARK: - OpenRouter Errors

enum OpenRouterError: LocalizedError {
    case notConfigured
    case invalidResponse
    case apiError(Int, String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "OpenRouter API key not configured"
        case .invalidResponse:
            return "Invalid response from OpenRouter"
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        case .parseError:
            return "Failed to parse AI response"
        }
    }
}

// MARK: - Trend Summary Enhancement (Plus+ Feature)

extension OpenRouterService {

    /// Generate an AI-enhanced weekly or monthly trend summary
    /// Requires Plus tier or higher
    func enhanceTrendSummary(
        period: String, // "weekly" or "monthly"
        workoutCount: Int,
        totalDuration: TimeInterval,
        averageIntensity: String,
        patterns: [DetectedPattern],
        insights: [String],
        nutritionSummary: NutritionTrendSummary? = nil
    ) async -> String {
        // Check if Plus+ tier and AI is configured
        guard PremiumManager.shared.canAccessWeeklyAI() else {
            return generateLocalTrendSummary(
                period: period,
                workoutCount: workoutCount,
                totalDuration: totalDuration
            )
        }

        var prompt = """
        You are a friendly fitness coach summarizing someone's \(period) fitness progress. \
        Write a brief, encouraging summary (3-4 sentences).

        DATA:
        - Period: \(period)
        - Workouts completed: \(workoutCount)
        - Total training time: \(formatDuration(totalDuration))
        - Average intensity: \(averageIntensity)

        PATTERNS DETECTED:
        \(patterns.map { "- \($0.description)" }.joined(separator: "\n"))

        KEY INSIGHTS:
        \(insights.joined(separator: "\n"))
        """

        // Add nutrition summary if available (Plus+ feature)
        if let nutrition = nutritionSummary {
            prompt += "\n\nNUTRITION OVERVIEW:"
            if let avgWater = nutrition.averageWaterIntakeMl {
                prompt += "\n- Average daily water: \(String(format: "%.1f", Double(avgWater) / 1000.0))L"
            }
            if let avgCalories = nutrition.averageCalories {
                prompt += "\n- Average daily calories: \(avgCalories) kcal"
            }
            if let avgProtein = nutrition.averageProtein {
                prompt += "\n- Average daily protein: \(avgProtein)g"
            }
            if nutrition.daysTracked > 0 {
                prompt += "\n- Days tracked: \(nutrition.daysTracked)"
            }
        }

        prompt += """

        Write a warm, natural summary. Be specific but concise. \
        If nutrition data is available, mention how it relates to workout performance. \
        End with encouragement.
        """

        do {
            let response = try await callOpenRouter(prompt: prompt)
            // Clean up response (remove quotes if present)
            let cleaned = response.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            return cleaned
        } catch {
            print("🤖 OpenRouter: Trend summary failed - \(error)")
            return generateLocalTrendSummary(
                period: period,
                workoutCount: workoutCount,
                totalDuration: totalDuration
            )
        }
    }

    private func generateLocalTrendSummary(
        period: String,
        workoutCount: Int,
        totalDuration: TimeInterval
    ) -> String {
        let hours = Int(totalDuration / 3600)
        let minutes = Int((totalDuration.truncatingRemainder(dividingBy: 3600)) / 60)

        if workoutCount == 0 {
            return "No workouts recorded this \(period == "weekly" ? "week" : "month"). Start fresh and build momentum!"
        }

        let timeText = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes) minutes"
        return "You completed \(workoutCount) workout\(workoutCount == 1 ? "" : "s") totaling \(timeText) this \(period == "weekly" ? "week" : "month"). Keep up the consistent effort!"
    }
}

// MARK: - Nutrition Trend Summary

struct NutritionTrendSummary {
    let averageWaterIntakeMl: Int?
    let averageCalories: Int?
    let averageProtein: Int?
    let averageCarbs: Int?
    let daysTracked: Int

    var hasData: Bool {
        averageWaterIntakeMl != nil || averageCalories != nil || averageProtein != nil
    }
}
