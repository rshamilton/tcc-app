//
//  PhotoViews.swift
//  Tree Cost Calculator
//

import SwiftUI
import PhotosUI
import UIKit

// MARK: - Thumbnail

struct PhotoThumbnail: View {
    let id: UUID
    var size: CGFloat = 84

    @State private var image: UIImage?
    /// Bumped when the photo arrives from the backup after this view first tried to load it.
    @State private var attempt = 0

    var body: some View {
        ZStack {
            Color(.tertiarySystemFill)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .task(id: "\(id.uuidString)-\(attempt)") {
            let pixels = Int(size * 3)
            let photoID = id
            image = await Task.detached(priority: .userInitiated) {
                PhotoStore.image(for: photoID, maxPixel: pixels)
            }.value
        }
        .onReceive(NotificationCenter.default.publisher(for: .photoRestored)) { note in
            if image == nil, note.object as? UUID == id { attempt += 1 }
        }
    }
}

// MARK: - Attachments strip

/// Horizontal strip of photos with an "add" tile. Handles the camera, the photo library and a
/// full-screen viewer (which is also where photos are removed).
struct PhotoAttachments: View {
    @Binding var ids: [UUID]

    @State private var showSourceDialog = false
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var viewing: PhotoRef?

    private struct PhotoRef: Identifiable { let id: UUID }

    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        Group {
            if ids.isEmpty {
                Button(action: beginAdding) {
                    Label("Add Photos", systemImage: "camera.fill")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel("Add photos")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Button(action: beginAdding) {
                            VStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                    .font(.title3)
                                Text("Add")
                                    .font(.caption2.weight(.medium))
                            }
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 84, height: 84)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.accentColor.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add photos")

                        ForEach(ids, id: \.self) { id in
                            Button { viewing = PhotoRef(id: id) } label: {
                                PhotoThumbnail(id: id)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Photo")
                            .accessibilityHint("Opens the photo full screen")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .confirmationDialog("Add Photo", isPresented: $showSourceDialog, titleVisibility: .hidden) {
            Button("Take Photo") { showCamera = true }
            Button("Choose from Library") { showLibrary = true }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showLibrary, selection: $pickerItems, maxSelectionCount: 10, matching: .images)
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            pickerItems = []
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await add(data)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                if let data = image.jpegData(compressionQuality: 0.9) {
                    Task { await add(data) }
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $viewing) { ref in
            PhotoViewer(id: ref.id) {
                ids.removeAll { $0 == ref.id }
                Task.detached(priority: .utility) { PhotoStore.delete([ref.id]) }
            }
        }
    }

    private func beginAdding() {
        if cameraAvailable { showSourceDialog = true } else { showLibrary = true }
    }

    private func add(_ data: Data) async {
        let saved = await Task.detached(priority: .userInitiated) { PhotoStore.save(data) }.value
        if let saved { ids.append(saved) }
    }
}

// MARK: - Full-screen viewer

struct PhotoViewer: View {
    let id: UUID
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var attempt = 0
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel("Photo")
                } else {
                    ProgressView().tint(.white)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete photo")
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .confirmationDialog("Delete this photo?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Photo", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .task(id: attempt) {
            let photoID = id
            image = await Task.detached(priority: .userInitiated) {
                PhotoStore.image(for: photoID, maxPixel: 2000)
            }.value
        }
        .onReceive(NotificationCenter.default.publisher(for: .photoRestored)) { note in
            if image == nil, note.object as? UUID == id { attempt += 1 }
        }
    }
}

// MARK: - Camera

struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
