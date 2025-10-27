/**
 * MediaPickerView - Photo library and camera access for media messages
 * Supports image selection, camera capture, and drag-and-drop
 */

import SwiftUI
import PhotosUI
import AVFoundation

struct MediaPickerView: View {
    @Binding var isPresented: Bool
    let onMediaSelected: (MediaItem) -> Void
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    @State private var showingPermissionAlert = false
    @State private var permissionMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Add Media")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Choose from your photos or take a new one")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Media Options
                VStack(spacing: 16) {
                    // Photo Library
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        MediaOptionButton(
                            icon: "photo.on.rectangle",
                            title: "Photo Library",
                            subtitle: "Choose from your photos",
                            color: .blue
                        )
                    }
                    
                    // Camera
                    Button {
                        requestCameraPermission()
                    } label: {
                        MediaOptionButton(
                            icon: "camera",
                            title: "Camera",
                            subtitle: "Take a new photo",
                            color: .green
                        )
                    }
                    
                    // Recent Photos (if available)
                    if let recentPhotos = getRecentPhotos(), !recentPhotos.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(recentPhotos.prefix(10), id: \.id) { photo in
                                        RecentPhotoThumbnail(photo: photo) {
                                            onMediaSelected(photo)
                                            isPresented = false
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Cancel Button
                Button("Cancel") {
                    isPresented = false
                }
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
            }
            .navigationTitle("Add Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            if let item = newItem {
                processSelectedItem(item)
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraView { image in
                let mediaItem = MediaItem(
                    id: UUID().uuidString,
                    type: .image,
                    image: image,
                    url: nil
                )
                onMediaSelected(mediaItem)
                isPresented = false
            }
        }
        .alert("Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(permissionMessage)
        }
    }
    
    // MARK: - Private Methods
    
    private func processSelectedItem(_ item: PhotosPickerItem) {
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    if let image = UIImage(data: data) {
                        let mediaItem = MediaItem(
                            id: item.itemIdentifier ?? UUID().uuidString,
                            type: .image,
                            image: image,
                            url: nil
                        )
                        await MainActor.run {
                            onMediaSelected(mediaItem)
                            isPresented = false
                        }
                    }
                }
            } catch {
                print("❌ Error processing selected item: \(error)")
            }
        }
    }
    
    private func requestCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showingCamera = true
                    } else {
                        permissionMessage = "Camera access is required to take photos."
                        showingPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            permissionMessage = "Camera access is required to take photos. Please enable it in Settings."
            showingPermissionAlert = true
        @unknown default:
            permissionMessage = "Camera access is required to take photos."
            showingPermissionAlert = true
        }
    }
    
    private func getRecentPhotos() -> [MediaItem]? {
        // TODO: Implement recent photos fetching
        // This would require PHPhotoLibrary access
        return nil
    }
}

// MARK: - Supporting Views

struct MediaOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

struct RecentPhotoThumbnail: View {
    let photo: MediaItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            if let image = photo.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipped()
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Camera View

struct CameraView: View {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        CameraViewController(onImageCaptured: onImageCaptured)
            .ignoresSafeArea()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
    }
}

// MARK: - Camera View Controller

struct CameraViewController: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraViewController
        
        init(_ parent: CameraViewController) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Media Item Model

struct MediaItem: Identifiable {
    let id: String
    let type: MediaType
    let image: UIImage?
    let url: URL?
    
    init(id: String, type: MediaType, image: UIImage?, url: URL?) {
        self.id = id
        self.type = type
        self.image = image
        self.url = url
    }
}

// MARK: - Preview

#Preview {
    MediaPickerView(isPresented: .constant(true)) { mediaItem in
        print("Selected media: \(mediaItem.id)")
    }
}
