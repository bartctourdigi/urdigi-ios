import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: DataStore
    private let darkGreen = Color(red: 0.17, green: 0.29, blue: 0.12)

    var groupedEntries: [(String, [FoodEntry])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "zh_TW")
        let grouped = Dictionary(grouping: store.entries) {
            formatter.string(from: $0.timestamp)
        }
        return grouped.sorted { a, b in
            let df = DateFormatter(); df.dateStyle = .medium; df.locale = Locale(identifier: "zh_TW")
            return (df.date(from: a.key) ?? .distantPast) > (df.date(from: b.key) ?? .distantPast)
        }
    }

    var body: some View {
        Group {
            if store.entries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 56)).foregroundColor(.gray.opacity(0.3))
                    Text("還沒有飲食紀錄").font(.headline).foregroundColor(.secondary)
                    Text("從「記錄」頁面開始吧！").font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(groupedEntries, id: \.0) { date, entries in
                        Section {
                            ForEach(entries) { entry in
                                HistoryRow(entry: entry)
                            }
                            .onDelete { offsets in
                                for i in offsets {
                                    if let idx = store.entries.firstIndex(where: { $0.id == entries[i].id }) {
                                        store.entries.remove(at: idx)
                                    }
                                }
                            }
                        } header: {
                            HStack {
                                Text(date).font(.subheadline).fontWeight(.semibold).foregroundColor(darkGreen)
                                Spacer()
                                let total = entries.reduce(0) { $0 + $1.calories }
                                Text("共 \(total) kcal").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

struct HistoryRow: View {
    let entry: FoodEntry
    private let darkGreen = Color(red: 0.17, green: 0.29, blue: 0.12)

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(darkGreen.opacity(0.1)).frame(width: 42, height: 42)
                Image(systemName: entry.source == "AI辨識" ? "sparkles" : "pencil")
                    .foregroundColor(darkGreen)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.foodName).font(.subheadline).fontWeight(.medium)
                Text("\(entry.mealType)  P:\(Int(entry.protein))g C:\(Int(entry.carbs))g F:\(Int(entry.fat))g")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text("\(entry.calories) kcal")
                .font(.subheadline).fontWeight(.semibold).foregroundColor(darkGreen)
        }
        .padding(.vertical, 4)
    }
}
