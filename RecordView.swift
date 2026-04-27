import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct RecordView: View {
    @EnvironmentObject var store: DataStore

    @State private var capturedImage: UIImage?
    @State private var showCameraPicker   = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isDragOver         = false
    @State private var isAnalyzing        = false
    @State private var analysisResult: NutritionResult?
    @State private var errorMessage: String?

    @State private var manualName    = ""
    @State private var manualCal     = ""
    @State private var manualProtein = ""
    @State private var manualCarbs   = ""
    @State private var manualFat     = ""
    @State private var savedToast    = false

    private let darkGreen = Color(red: 0.17, green: 0.29, blue: 0.12)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                aiSection
                manualSection
            }
            .padding(16)
        }
        // 相機拍照 sheet
        .sheet(isPresented: $showCameraPicker) {
            CameraPickerView(image: $capturedImage, onPicked: { img in
                Task { await runAnalysis(img) }
            })
        }
        // 相片庫選圖（PhotosPicker onChange）
        .onChange(of: selectedPhotoItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img  = UIImage(data: data) {
                    await MainActor.run { capturedImage = img }
                    await runAnalysis(img)
                }
                await MainActor.run { selectedPhotoItem = nil }
            }
        }
        .overlay(toastOverlay)
    }

    // MARK: ─ AI Section
    var aiSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("拍照辨識食物", systemImage: "camera.fill")
                .font(.system(size: 15, weight: .semibold))

            // Drop Zone
            dropZone
                .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 200)
                .onDrop(of: [UTType.image, UTType.fileURL, UTType.jpeg, UTType.png],
                        isTargeted: $isDragOver) { providers in
                    handleDrop(providers: providers)
                }

            // Buttons
            HStack(spacing: 10) {
                // 拍照 — 使用相機
                actionButton(icon: "camera.fill", label: "拍照") {
                    showCameraPicker = true
                }
                // 上傳圖片 — 使用原生 PhotosPicker，不觸發相機 crash
                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("上傳圖片", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.white)
                        .foregroundColor(darkGreen)
                        .font(.system(size: 15, weight: .semibold))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(darkGreen.opacity(0.4), lineWidth: 1))
                }
            }

            // Hint
            HStack(spacing: 4) {
                Image(systemName: "hand.point.up.left")
                Text("把圖片從 Finder 拖進上方框框，或點「上傳圖片」選照片")
            }
            .font(.caption2)
            .foregroundColor(.secondary)

            // Result / Error
            if let result = analysisResult { resultCard(result) }
            else if let err = errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6)
    }

    // MARK: ─ Drop Zone View
    var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDragOver ? darkGreen : Color.gray.opacity(0.35),
                    style: StrokeStyle(lineWidth: isDragOver ? 2.5 : 1.5, dash: [6])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isDragOver ? darkGreen.opacity(0.07) : Color(.systemGroupedBackground))
                )

            if let img = capturedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 10) {
                    Text(isDragOver ? "放開以分析！" : "🍱")
                        .font(isDragOver ? .title : .system(size: 44))
                        .foregroundColor(isDragOver ? darkGreen : .primary)
                    if !isDragOver {
                        Text("從 Finder 拖曳圖片到這裡")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if isAnalyzing {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.45))
                VStack(spacing: 8) {
                    ProgressView().tint(.white).scaleEffect(1.4)
                    Text("AI 分析中…").foregroundColor(.white).font(.subheadline)
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isDragOver)
    }

    // MARK: ─ Manual Section
    var manualSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("手動輸入", systemImage: "pencil")
                .font(.system(size: 15, weight: .semibold))

            Group {
                TextField("食物名稱（例：滷肉飯）", text: $manualName)
                TextField("熱量（kcal）", text: $manualCal)
                    .keyboardType(.numberPad)
            }
            .padding(12)
            .background(Color(.systemGroupedBackground))
            .cornerRadius(10)

            HStack(spacing: 10) {
                macroField("蛋白質 g", $manualProtein)
                macroField("碳水 g",   $manualCarbs)
                macroField("脂肪 g",   $manualFat)
            }

            actionButton(icon: "plus.circle.fill", label: "新增") {
                saveManual()
            }
            .opacity(manualName.isEmpty ? 0.4 : 1)
            .disabled(manualName.isEmpty)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6)
    }

    func macroField(_ label: String, _ binding: Binding<String>) -> some View {
        TextField(label, text: binding)
            .keyboardType(.decimalPad)
            .padding(12)
            .background(Color(.systemGroupedBackground))
            .cornerRadius(10)
    }

    func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.white)
                .foregroundColor(darkGreen)
                .font(.system(size: 15, weight: .semibold))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(darkGreen.opacity(0.4), lineWidth: 1))
        }
    }

    // MARK: ─ Result Card
    func resultCard(_ r: NutritionResult) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(r.foodName).font(.headline)
                    if !r.description.isEmpty {
                        Text(r.description).font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("\(r.calories)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(darkGreen)
                    Text("kcal").font(.caption).foregroundColor(.secondary)
                }
            }

            HStack {
                ForEach([("蛋白質", r.protein, Color(red:0.4,green:0.6,blue:1.0)),
                         ("碳水",   r.carbs,   Color(red:1.0,green:0.75,blue:0.2)),
                         ("脂肪",   r.fat,     Color(red:1.0,green:0.4,blue:0.4))], id: \.0) { name, val, color in
                    VStack(spacing: 2) {
                        Text(String(format: "%.1fg", val)).font(.subheadline).bold().foregroundColor(color)
                        Text(name).font(.caption2).foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity)
                }
            }

            actionButton(icon: "checkmark.circle.fill", label: "加入今日紀錄") {
                saveAnalysisResult(r)
            }
        }
        .padding(12)
        .background(darkGreen.opacity(0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(darkGreen.opacity(0.2), lineWidth: 1))
    }

    // MARK: ─ Toast
    var toastOverlay: some View {
        VStack {
            Spacer()
            if savedToast {
                Label("已加入今日紀錄！", systemImage: "checkmark.circle.fill")
                    .font(.subheadline).fontWeight(.medium)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(darkGreen).foregroundColor(.white)
                    .cornerRadius(30).shadow(radius: 8).padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(), value: savedToast)
    }

    // MARK: ─ Drop Handler
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                guard let data, let img = UIImage(data: data) else { return }
                DispatchQueue.main.async { capturedImage = img; Task { await runAnalysis(img) } }
            }
            return true
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let u = item as? URL { url = u }
                else if let d = item as? Data { url = URL(dataRepresentation: d, relativeTo: nil) }
                else { url = nil }
                guard let u = url,
                      u.startAccessingSecurityScopedResource() == true || true,
                      let data = try? Data(contentsOf: u),
                      let img  = UIImage(data: data) else { return }
                u.stopAccessingSecurityScopedResource()
                DispatchQueue.main.async { capturedImage = img; Task { await runAnalysis(img) } }
            }
            return true
        }

        return false
    }

    // MARK: ─ Actions
    func runAnalysis(_ image: UIImage) async {
        await MainActor.run { isAnalyzing = true; analysisResult = nil; errorMessage = nil }
        do {
            let result = try await GeminiService.shared.analyzeFood(image: image)
            await MainActor.run { analysisResult = result; isAnalyzing = false }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription; isAnalyzing = false }
        }
    }

    func saveAnalysisResult(_ r: NutritionResult) {
        store.addEntry(FoodEntry(foodName: r.foodName, calories: r.calories,
                                protein: r.protein, carbs: r.carbs, fat: r.fat, source: "AI辨識",
                                imageData: capturedImage?.jpegData(compressionQuality: 0.5)))
        capturedImage = nil; analysisResult = nil; showToast()
    }

    func saveManual() {
        guard !manualName.isEmpty else { return }
        store.addEntry(FoodEntry(foodName: manualName, calories: Int(manualCal) ?? 0,
                                protein: Double(manualProtein) ?? 0,
                                carbs: Double(manualCarbs) ?? 0,
                                fat: Double(manualFat) ?? 0, source: "手動輸入"))
        manualName = ""; manualCal = ""; manualProtein = ""; manualCarbs = ""; manualFat = ""
        showToast()
    }

    func showToast() {
        savedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedToast = false }
    }
}

// MARK: ─ Camera UIKit Bridge（僅用於拍照）
struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onPicked: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
            // 明確指定後鏡頭，避免 iPhone Pro BackTriple FigCaptureSourceRemote crash
            if UIImagePickerController.isCameraDeviceAvailable(.rear) {
                picker.cameraDevice = .rear
            }
        } else {
            picker.sourceType = .photoLibrary
        }
        return picker
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.image = img
                parent.onPicked(img)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
