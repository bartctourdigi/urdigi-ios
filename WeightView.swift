import SwiftUI

struct WeightView: View {
    @EnvironmentObject var store: DataStore
    @State private var input = ""
    @State private var saved = false
    private let darkGreen = Color(red: 0.17, green: 0.29, blue: 0.12)

    var bmiValue: Double? {
        guard store.weightKg > 0 else { return nil }
        return store.weightKg / (1.70 * 1.70)
    }

    var bmiLabel: (String, Color) {
        guard let bmi = bmiValue else { return ("--", .secondary) }
        switch bmi {
        case ..<18.5: return ("體重過輕", .blue)
        case 18.5..<24: return ("正常範圍 ✅", darkGreen)
        case 24..<27: return ("體重過重", .orange)
        default: return ("肥胖", .red)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Current Weight Card
                VStack(spacing: 16) {
                    HStack(spacing: 40) {
                        VStack(spacing: 4) {
                            Text(store.weightKg > 0 ? String(format: "%.1f", store.weightKg) : "--")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundColor(darkGreen)
                            Text("公斤").font(.subheadline).foregroundColor(.secondary)
                        }
                        VStack(spacing: 4) {
                            Text(bmiValue.map { String(format: "%.1f", $0) } ?? "--")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                            Text("BMI").font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                    Text(bmiLabel.0).font(.subheadline).foregroundColor(bmiLabel.1)
                        .padding(.horizontal, 16).padding(.vertical, 6)
                        .background(bmiLabel.1.opacity(0.1)).cornerRadius(20)
                    Text("（身高預設 170cm）").font(.caption2).foregroundColor(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 6)

                // Input Card
                VStack(alignment: .leading, spacing: 14) {
                    Text("更新體重").font(.system(size: 15, weight: .semibold))
                    HStack(spacing: 10) {
                        TextField("輸入體重（kg）", text: $input)
                            .keyboardType(.decimalPad)
                            .padding(12)
                            .background(Color(.systemGroupedBackground))
                            .cornerRadius(10)
                        Button(action: saveWeight) {
                            Text("更新")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20).padding(.vertical, 12)
                                .background(input.isEmpty ? Color.gray.opacity(0.4) : darkGreen)
                                .cornerRadius(10)
                        }
                        .disabled(input.isEmpty)
                    }
                    if saved {
                        Label("體重已更新！", systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundColor(darkGreen)
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 6)
            }
            .padding(16)
        }
    }

    func saveWeight() {
        if let kg = Double(input), kg > 0 {
            store.saveWeight(kg); input = ""; saved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
        }
    }
}
