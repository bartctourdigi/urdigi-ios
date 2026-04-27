import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: DataStore
    @State private var selectedTab = 0

    private let darkGreen = Color(red: 0.17, green: 0.29, blue: 0.12)
    private let tabs = ["記錄", "歷史", "統計", "體重"]
    private let tabIcons = ["camera.viewfinder", "clock", "chart.bar.fill", "scalemass"]

    var body: some View {
        VStack(spacing: 0) {
            // ── Top Header ──────────────────────────────
            ZStack {
                darkGreen.ignoresSafeArea(edges: .top)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ÜrDigi")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("AI 飲食紀錄")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.75))
                    }
                    Spacer()
                    Text("BETA")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                        )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(height: 60)

            // ── Top Tab Bar ──────────────────────────────
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { i in
                    Button(action: { selectedTab = i }) {
                        VStack(spacing: 4) {
                            Image(systemName: tabIcons[i])
                                .font(.system(size: 16))
                            Text(tabs[i])
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(selectedTab == i ? darkGreen : Color.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(
                            Rectangle()
                                .frame(height: 2.5)
                                .foregroundColor(selectedTab == i ? darkGreen : .clear),
                            alignment: .bottom
                        )
                    }
                }
            }
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)

            // ── Tab Content ──────────────────────────────
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                switch selectedTab {
                case 0: RecordView().environmentObject(store)
                case 1: HistoryView().environmentObject(store)
                case 2: StatsView().environmentObject(store)
                case 3: WeightView().environmentObject(store)
                default: RecordView().environmentObject(store)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
