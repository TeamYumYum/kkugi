import PhotosUI
import SwiftUI

struct MealPhotoPicker: View {
    let session: AuthSession
    let use: (MealPhotoRecognitionResponse) -> Void
    var manualSearch: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var scale
    @State private var selected: PhotosPickerItem?
    @State private var photo: Data?
    @State private var requestID = UUID()
    @State private var camera = false
    @State private var busy = false
    @State private var recognitionTask: Task<Void, Never>?
    @State private var message = ""

    var body: some View {
        NavigationStack {
            Group {
                if busy {
                    VStack(alignment: .leading, spacing: G.gap) {
                        Button {
                            recognitionTask?.cancel()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark").resizable().scaledToFit()
                                .frame(width: aligned(G.dp(22)), height: aligned(G.dp(22)))
                        }
                        .buttonStyle(.plain).accessibilityLabel("닫기")
                        .padding(.top, aligned(G.dp(11)))
                        if let photo, let image = UIImage(data: photo) {
                            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: G.dp(240))
                        }
                        GText(text: "꾸기가 음식을\n살펴보는 중이에요", size: 24, weight: 700)
                        ProgressView()
                        Spacer()
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, aligned(G.gutter))
                        .background(Color(hex: 0xF5F7FA))
                } else {
                Form {
                PhotosPicker("사진 보관함에서 선택", selection: $selected, matching: .images)
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("식사 사진 촬영") { camera = true }
                }
                if let photo, let image = UIImage(data: photo) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 250)
                        .accessibilityLabel("선택한 식사 사진")
                    Button("이 사진을 전송해 음식 인식") { recognitionTask = Task { await recognize(photo) } }
                }
                if !message.isEmpty {
                    Text(message)
                    if let manualSearch { Button("음식 검색") { manualSearch() } }
                }
                }
                }
            }
            .gListCanvas().navigationTitle("사진으로 식사 기록")
            .toolbar { if !busy { Button("닫기") { recognitionTask?.cancel(); dismiss() } } }
            .toolbar(busy ? .hidden : .visible, for: .navigationBar)
            .task(id: selected) {
                guard let selected else { return }
                photo = nil
                do {
                    let data = try await selected.loadTransferable(type: Data.self)
                    guard !Task.isCancelled else { return }
                    guard let data, let image = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
                    prepare(image)
                } catch { if !Task.isCancelled { message = "사진을 열지 못했어요" } }
            }
            .fullScreenCover(isPresented: $camera) {
                MealCamera { image in
                    camera = false
                    if let image { selected = nil; prepare(image) }
                }.ignoresSafeArea()
            }
        }.onDisappear { recognitionTask?.cancel() }
    }

    private func aligned(_ value: CGFloat) -> CGFloat { (value * scale).rounded() / scale }

    private func prepare(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85), data.count <= 10_000_000 else {
            photo = nil
            message = "10MB 이하의 식사 사진을 골라 주세요"
            return
        }
        requestID = UUID()
        photo = data
        message = ""
    }

    @MainActor private func recognize(_ photo: Data) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let boundary = "kkugi-" + UUID().uuidString
            var body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"clientUuid\"\r\n\r\n\(requestID.uuidString)\r\n".utf8)
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"meal.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".utf8))
            body.append(photo)
            body.append(Data("\r\n--\(boundary)--\r\n".utf8))
            let bytes = try await session.protectedRequest("api/v1/food-recognitions", method: "POST", body: body,
                                                         contentType: "multipart/form-data; boundary=" + boundary)
            let response = try JSONDecoder().decode(ApiResponseMealPhotoRecognitionResponse.self, from: bytes)
            guard response.success == true, let result = response.data else { throw URLError(.badServerResponse) }
            if !Task.isCancelled { use(result) }
        } catch { if !Task.isCancelled { message = "사진을 인식하지 못했어요. 같은 사진으로 다시 시도할 수 있어요" } }
    }
}

#if DEBUG
extension MealPhotoPicker {
    static func reference(session: AuthSession, photo: Data, recognizing: Bool) -> Self {
        var view = Self(session: session, use: { _ in }, manualSearch: {})
        view._photo = State(initialValue: photo)
        view._busy = State(initialValue: recognizing)
        view._message = State(initialValue: recognizing ? "" : "사진을 인식하지 못했어요. 같은 사진으로 다시 시도할 수 있어요")
        return view
    }
}
#endif

private struct MealCamera: UIViewControllerRepresentable {
    let finish: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(finish: finish) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let camera = UIImagePickerController()
        camera.sourceType = .camera
        camera.delegate = context.coordinator
        return camera
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let finish: (UIImage?) -> Void
        init(finish: @escaping (UIImage?) -> Void) { self.finish = finish }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { finish(nil) }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            finish(info[.originalImage] as? UIImage)
        }
    }
}
