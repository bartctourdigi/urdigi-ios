import Foundation
import SwiftUI

// MARK: - Food Entry Model
struct FoodEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var foodName: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var source: String // "AI" or "Barcode"
    var imageData: Data?

    var mealType: String {
        let hour = Calendar.current.component(.hour, from: timestamp)
        switch hour {
        case 6..<10: return "早餐 🌅"
        case 10..<14: return "午餐 ☀️"
        case 14..<18: return "下午茶 🍵"
        default: return "晚餐 🌙"
        }
    }
}

// MARK: - Nutrition Analysis Result
struct NutritionResult {
    var foodName: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var description: String
}

// MARK: - Daily Summary
struct DailySummary {
    var totalCalories: Int
    var totalProtein: Double
    var totalCarbs: Double
    var totalFat: Double
    var entryCount: Int
}
