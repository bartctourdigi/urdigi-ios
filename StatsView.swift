import SwiftUI

struct StatsView: View {
    @EnvironmentObject var store: DataStore
    private let darkGreen = Color(red: 0.17, green: 0.29, blue: 0.12)

    var summary: DailySummary { store.dailySummary() }
    var total: Double { summary.totalProtein + summary.totalCarbs + summary.totalFat }
    var proteinPct: Double { total > 0 ? summary.totalProtein / total : 0.33 }
    var carbsPct: Double   { total > 0 ? summary.totalCarbs   / total : 0.34 }
    var fatPct: Double     { total > 0 ? summary.totalFat     / total : 0.33 }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Daily Summary
                dailyCard
                // Macro Bar
                macroBarCard
                // Weekly Bar Chart
                weeklyCard
                // Tips
                tipsCard
            }
            .padding(16)
        }
    }

    // MARK: Daily
    var dailyCard: some View {
        VStack(spacing: 14) {
            Text("今日總覽").font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 0) {
                statBox(label: "總熱量", value: "\(summary.totalCalories)", unit: "kcal", color: darkGreen)
                Divider().frame(height: 50)
                statBox(label: "達成率", value: "\(min(Int(Double(summary.totalCalories)/2000*100),100))", unit: "%", color: .orange)
                Divider().frame(height: 50)
                statBox(label: "紀錄筆數", value: "\(summary.entryCount)", unit: "筆", color: .blue)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6)
    }

    func statBox(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(color)
                Text(unit).font(.caption).foregroundColor(.secondary)
            }
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Macro Bar
    var macroBarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日三大營養素").font(.system(size: 15, weight: .semibold))
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle().fill(Color(red: 0.4, green: 0.6, blue: 1.0))
                        .frame(width: geo.size.width * proteinPct)
                    Rectangle().fill(Color(red: 1.0, green: 0.75, blue: 0.2))
                        .frame(width: geo.size.width * carbsPct)
                    Rectangle().fill(Color(red: 1.0, green: 0.4, blue: 0.4))
                }
                .frame(height: 22).cornerRadius(11)
            }
            .frame(height: 22)

            HStack(spacing: 16) {
                legendItem("蛋白質", value: summary.totalProtein, color: Color(red: 0.4, green: 0.6, blue: 1.0))
                legendItem("碳水", value: summary.totalCarbs, color: Color(red: 1.0, green: 0.75, blue: 0.2))
                legendItem("脂肪", value: summary.totalFat, color: Color(red: 1.0, green: 0.4, blue: 0.4))
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6)
    }

    func legendItem(_ name: String, value: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text("\(name) \(String(format: "%.0f", value))g")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    // MARK: Weekly
    var weeklyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本週熱量趨勢").font(.system(size: 15, weight: .semibold))
            let data = last7DaysCalories()
            let maxV = max(data.max() ?? 1, 1)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    let cal = data[i]
                    let h = max(CGFloat(cal) / CGFloat(maxV) * 100, 4)
                    VStack(spacing: 4) {
                        if cal > 0 { Text("\(cal)").font(.system(size: 8)).foregroundColor(.secondary) }
                        RoundedRectangle(cornerRadius: 6)
                            .fill(i == 6 ? darkGreen : darkGreen.opacity(0.3))
                            .frame(height: h)
                        Text(dayLabel(daysAgo: 6-i)).font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 130)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6)
    }

    // MARK: Tips
    var tipsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("💡 每日建議").font(.system(size: 15, weight: .semibold))
            ForEach([
                ("🥩", "蛋白質目標", "體重(kg) × 1.6g = 每日蛋白質(g)"),
                ("🔥", "熱量赤字", "減脂建議攝取 1500–1800 kcal"),
                ("💧", "水分攝取", "每天至少喝 2000ml 的水")
            ], id: \.1) { icon, title, desc in
                HStack(spacing: 12) {
                    Text(icon).font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.subheadline).fontWeight(.medium)
                        Text(desc).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6)
    }

    // MARK: Helpers
    func last7DaysCalories() -> [Int] {
        let cal = Calendar.current
        return (0..<7).map { ago in
            guard let d = cal.date(byAdding: .day, value: -ago, to: Date()) else { return 0 }
            return store.entries.filter { cal.isDate($0.timestamp, inSameDayAs: d) }.reduce(0) { $0 + $1.calories }
        }.reversed()
    }

    func dayLabel(daysAgo: Int) -> String {
        let days = ["日","一","二","三","四","五","六"]
        let cal = Calendar.current
        guard let d = cal.date(byAdding: .day, value: -daysAgo, to: Date()) else { return "" }
        return days[cal.component(.weekday, from: d) - 1]
    }
}
