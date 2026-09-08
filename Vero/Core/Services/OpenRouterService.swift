//
//  OpenRouterService.swift
//  WellPattern Health
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
        #if DEBUG
        let key = WellPatternConfig.OpenRouter.apiKey
        let keyPrefix = key.count >= 5 ? String(key.prefix(5)) : key
        if WellPatternConfig.OpenRouter.isConfigured {
            print("🤖 OpenRouter: ✅ API key configured (prefix='\(keyPrefix)...'), model=\(WellPatternConfig.OpenRouter.model)")
        } else {
            print("🤖 OpenRouter: ❌ NOT CONFIGURED — key is placeholder '\(keyPrefix)...'")
            print("🤖 OpenRouter: ❌ All AI calls will use local fallback text.")
            print("🤖 OpenRouter: ❌ To enable: set WellPatternConfig.OpenRouter.apiKey to your real key from https://openrouter.ai/keys")
        }
        #endif
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
            #if DEBUG
            print("🤖 OpenRouter: ✅ Enhancement successful for \(cacheKey)")
            print("🤖 OpenRouter: 🖥️ UI TARGET — WorkoutInsightView: headline (narrativeHeadline), body (explanationText), next-step (takeawayText)")
            #endif
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

        let goalName = UserGoalService.shared.primaryGoal?.rawValue ?? "general fitness"

        var prompt = """
        You are a friendly fitness coach helping someone understand their workout. \
        Rewrite the following workout analysis into natural, encouraging language. \
        Keep it concise (2-3 sentences for summary, 3-4 for interpretation). \
        Be warm and supportive, but factual. Tailor advice to their goal.

        USER GOAL: \(goalName)

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

        // Add cycle phase if available (cautious, supportive framing)
        if let cyclePhase = output.recoveryContext?.cyclePhase {
            prompt += "\n\nCYCLE CONTEXT (use gently, only if relevant):"
            prompt += "\n- User is in their \(cyclePhase.aiContext)"
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
        // ── Key validation ──────────────────────────────────────────────────────
        let apiKey = WellPatternConfig.OpenRouter.apiKey
        #if DEBUG
        let keyPrefix = apiKey.count >= 5 ? String(apiKey.prefix(5)) : apiKey
        print("🤖 OpenRouter: ══════════════════════════════════════════════")
        print("🤖 OpenRouter: API CALL STARTING")
        print("🤖 OpenRouter: key prefix  = \"\(keyPrefix)...\" (isConfigured=\(WellPatternConfig.OpenRouter.isConfigured))")
        print("🤖 OpenRouter: model       = \(WellPatternConfig.OpenRouter.model)")
        print("🤖 OpenRouter: endpoint    = \(WellPatternConfig.OpenRouter.baseURL)/chat/completions")
        print("🤖 OpenRouter: max_tokens  = \(WellPatternConfig.OpenRouter.maxTokens)")
        print("🤖 OpenRouter: temperature = \(WellPatternConfig.OpenRouter.temperature)")
        #endif

        guard WellPatternConfig.OpenRouter.isConfigured else {
            #if DEBUG
            print("🤖 OpenRouter: ❌ ABORT — key is placeholder (starts with 'YOUR_'). Set a real key in WellPatternConfig.swift.")
            print("🤖 OpenRouter: ══════════════════════════════════════════════")
            #endif
            throw OpenRouterError.notConfigured
        }

        let url = URL(string: "\(WellPatternConfig.OpenRouter.baseURL)/chat/completions")!

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("WellPattern", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("WellPattern", forHTTPHeaderField: "X-Title")

        let body: [String: Any] = [
            "model": WellPatternConfig.OpenRouter.model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": WellPatternConfig.OpenRouter.maxTokens,
            "temperature": WellPatternConfig.OpenRouter.temperature
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // ── Pre-request log ─────────────────────────────────────────────────────
        #if DEBUG
        print("🤖 OpenRouter: 📤 PAYLOAD (prompt length=\(prompt.count) chars):")
        print("🤖 OpenRouter: --- prompt start ---")
        print(prompt)
        print("🤖 OpenRouter: --- prompt end ---")
        print("🤖 OpenRouter: Sending request to OpenRouter now...")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            #if DEBUG
            print("🤖 OpenRouter: ❌ ERROR — response is not HTTPURLResponse")
            print("🤖 OpenRouter: ══════════════════════════════════════════════")
            #endif
            throw OpenRouterError.invalidResponse
        }

        // ── Raw response log ────────────────────────────────────────────────────
        let rawBody = String(data: data, encoding: .utf8) ?? "<non-utf8 data>"
        #if DEBUG
        print("🤖 OpenRouter: 📥 RESPONSE status=\(httpResponse.statusCode)")
        print("🤖 OpenRouter: --- raw response start ---")
        print(rawBody)
        print("🤖 OpenRouter: --- raw response end ---")
        #endif

        guard httpResponse.statusCode == 200 else {
            #if DEBUG
            print("🤖 OpenRouter: ❌ API ERROR \(httpResponse.statusCode): \(rawBody)")
            print("🤖 OpenRouter: ══════════════════════════════════════════════")
            #endif
            throw OpenRouterError.apiError(httpResponse.statusCode, rawBody)
        }

        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            #if DEBUG
            print("🤖 OpenRouter: ❌ PARSE ERROR — could not extract content from response")
            print("🤖 OpenRouter: ══════════════════════════════════════════════")
            #endif
            throw OpenRouterError.parseError
        }

        #if DEBUG
        print("🤖 OpenRouter: ✅ SUCCESS — content extracted (\(content.count) chars)")
        print("🤖 OpenRouter: ══════════════════════════════════════════════")
        #endif
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

        let result = EnhancedAnalysis(
            enhancedSummary: json["summary"] ?? fallback.localSummary,
            enhancedInterpretation: json["interpretation"] ?? fallback.localInterpretation,
            enhancedRecommendation: json["recommendation"] ?? fallback.localRecommendation,
            source: .ai
        )
        #if DEBUG
        print("🤖 OpenRouter: 🔍 PARSE RESULT source=ai")
        print("🤖 OpenRouter:    summary        = \(result.enhancedSummary.prefix(80))...")
        print("🤖 OpenRouter:    interpretation = \(result.enhancedInterpretation.prefix(80))...")
        print("🤖 OpenRouter:    recommendation = \(result.enhancedRecommendation?.prefix(80).description ?? "nil")")
        #endif
        return result
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
        if cache.count > WellPatternConfig.Cache.aiEnhancementMaxCount {
            let sorted = cache.sorted { $0.value.timestamp > $1.value.timestamp }
            let prefixedEntries = Array(sorted.prefix(WellPatternConfig.Cache.aiEnhancementMaxCount))
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
        Date().timeIntervalSince(timestamp) > WellPatternConfig.Cache.aiEnhancementTTL
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

// MARK: - Daily Guidance (Plus Feature)

extension OpenRouterService {

    /// Generate a short, personalised daily tip based on today's context.
    /// Requires Plus tier or higher. Returns nil for free users.
    /// Cached per calendar day so it's only fetched once.
    func generateDailyGuidance(context: DailyContext) async -> String? {
        guard PremiumManager.shared.canAccessWeeklyAI() else { return nil }

        let cacheKey = "daily_guidance_\(dailyKey())"
        if let cached = cache[cacheKey], !cached.isExpired {
            return cached.enhancement.enhancedSummary
        }

        let goalName = UserGoalService.shared.primaryGoal?.rawValue ?? "general fitness"

        var prompt = """
        You are a concise wellness coach. Write ONE encouraging, practical tip for today \
        (1-2 sentences max). Be specific to the person's data. No fluff, no filler.

        USER GOAL: \(goalName)
        SLEEP LAST NIGHT: \(String(format: "%.1f", context.sleepHours)) hours (\(context.sleepQuality.rawValue))
        ENERGY TODAY: \(context.energyLevel.rawValue)
        STRESS TODAY: \(context.stressLevel.rawValue)
        """

        if let hrv = context.hrvScore {
            prompt += "\nHRV: \(String(format: "%.0f", hrv)) ms"
        }
        if let water = context.waterIntakeMl {
            prompt += "\nWater logged: \(String(format: "%.1f", Double(water) / 1000.0))L"
        }
        if let cal = context.calories {
            prompt += "\nCalories logged: \(cal) kcal"
        }
        if let phase = context.cyclePhase {
            prompt += "\nCycle phase: \(phase.aiContext)"
        }

        prompt += "\n\nRespond with ONLY the 1-2 sentence tip, nothing else."

        do {
            let tip = try await callOpenRouter(prompt: prompt)
            let cleaned = tip.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            let enhancement = EnhancedAnalysis(
                enhancedSummary: cleaned,
                enhancedInterpretation: "",
                enhancedRecommendation: nil,
                source: .ai
            )
            cache[cacheKey] = CachedEnhancement(enhancement: enhancement, timestamp: Date())
            saveCache()
            return cleaned
        } catch {
            return nil
        }
    }

    private func dailyKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
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
