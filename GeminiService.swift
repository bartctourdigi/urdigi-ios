import Foundation
import UIKit

class GeminiService {
    static let shared = GeminiService()

    // ⚠️ 請將 API Key 設定在此，不要 commit 到 git
    // 取得方式：https://console.cloud.google.com/apis/credentials
    private let apiKey  = "YOUR_GEMINI_API_KEY_HERE"
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent"

    func analyzeFood(image: UIImage) async throws -> NutritionResult {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw GeminiError.invalidImage
        }
        let base64 = imageData.base64EncodedString()

        let prompt = """
        請分析這張食物圖片，用繁體中文回答，以JSON格式輸出（不要任何其他文字，不要 markdown 格式）：
        {"food_name":"食物名稱","calories":熱量整數,"protein":蛋白質數字,"carbs":碳水數字,"fat":脂肪數字,"description":"描述"}
        """

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inline_data": ["mime_type": "image/jpeg", "data": base64]]
                ]
            ]],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 512
            ]
        ]

        var req = URLRequest(url: URL(string: "\(endpoint)?key=\(apiKey)")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: req)

        // HTTP 狀態碼檢查
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw GeminiError.apiError("HTTP \(http.statusCode): \(body.prefix(200))")
        }

        // 解析 Gemini 回應
        guard
            let json       = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first      = candidates.first,
            let content    = first["content"] as? [String: Any],
            let parts      = content["parts"] as? [[String: Any]],
            let rawText    = parts.first?["text"] as? String
        else {
            // 嘗試讀錯誤訊息
            if let errJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errInfo = errJson["error"] as? [String: Any],
               let msg     = errInfo["message"] as? String {
                throw GeminiError.apiError(msg)
            }
            let raw = String(data: data, encoding: .utf8) ?? "empty"
            throw GeminiError.parseError("無法解析回應: \(raw.prefix(300))")
        }

        // 清理 markdown code block
        let cleaned = rawText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 找 JSON 區段
        let jsonStr: String
        if let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}") {
            jsonStr = String(cleaned[start...end])
        } else {
            throw GeminiError.parseError("回應中找不到 JSON：\(cleaned.prefix(200))")
        }

        guard
            let resultData = jsonStr.data(using: .utf8),
            let result     = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any]
        else {
            throw GeminiError.parseError("JSON 解析失敗：\(jsonStr.prefix(200))")
        }

        return NutritionResult(
            foodName:    result["food_name"]   as? String ?? "未知食物",
            calories:    result["calories"]    as? Int    ?? 0,
            protein:     result["protein"]     as? Double ?? (result["protein"]    as? Int).map(Double.init) ?? 0,
            carbs:       result["carbs"]       as? Double ?? (result["carbs"]      as? Int).map(Double.init) ?? 0,
            fat:         result["fat"]         as? Double ?? (result["fat"]        as? Int).map(Double.init) ?? 0,
            description: result["description"] as? String ?? ""
        )
    }
}

enum GeminiError: LocalizedError {
    case invalidImage
    case parseError(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:         return "圖片處理失敗"
        case .parseError(let msg):  return "解析失敗：\(msg)"
        case .apiError(let msg):    return "API 錯誤：\(msg)"
        }
    }
}
