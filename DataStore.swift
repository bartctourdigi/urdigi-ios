import Foundation
import Combine

class DataStore: ObservableObject {
    static let shared = DataStore()

    @Published var entries: [FoodEntry] = []
    @Published var weightKg: Double = 0
    @Published var isLoading: Bool = true   // 讓 UI 可以顯示載入狀態

    private let entriesKey = "food_entries"
    private let weightKey  = "weight_kg"

    // 用來 debounce 存檔，避免每次操作都寫磁碟
    private var saveWorkItem: DispatchWorkItem?

    init() {
        // weightKg 很小，直接讀沒關係
        weightKg = UserDefaults.standard.double(forKey: weightKey)

        // 資料載入移到背景執行緒，不阻塞 UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let loaded: [FoodEntry]
            if let data = UserDefaults.standard.data(forKey: self.entriesKey),
               let decoded = try? JSONDecoder().decode([FoodEntry].self, from: data) {
                loaded = decoded
            } else {
                loaded = []
            }
            DispatchQueue.main.async {
                self.entries   = loaded
                self.isLoading = false
            }
        }
    }

    // MARK: - Entries

    func addEntry(_ entry: FoodEntry) {
        entries.insert(entry, at: 0)
        scheduleSave()
    }

    func deleteEntry(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        scheduleSave()
    }

    func todayEntries() -> [FoodEntry] {
        let calendar = Calendar.current
        return entries.filter { calendar.isDateInToday($0.timestamp) }
    }

    func dailySummary() -> DailySummary {
        let today = todayEntries()
        return DailySummary(
            totalCalories: today.reduce(0) { $0 + $1.calories },
            totalProtein:  today.reduce(0) { $0 + $1.protein },
            totalCarbs:    today.reduce(0) { $0 + $1.carbs },
            totalFat:      today.reduce(0) { $0 + $1.fat },
            entryCount:    today.count
        )
    }

    // MARK: - Weight

    func saveWeight(_ kg: Double) {
        weightKg = kg
        UserDefaults.standard.set(kg, forKey: weightKey)
    }

    // MARK: - Persistence（debounced）

    /// 延遲 0.5 秒才真正寫入，連續操作只存一次
    private func scheduleSave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.performSave()
        }
        saveWorkItem = work
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func performSave() {
        // 先在主執行緒拿快照，再到背景 encode
        let snapshot = entries
        DispatchQueue.global(qos: .background).async {
            var lightweight = snapshot
            for i in lightweight.indices { lightweight[i].imageData = nil }
            if let data = try? JSONEncoder().encode(lightweight) {
                UserDefaults.standard.set(data, forKey: "food_entries")
            }
        }
    }
}
