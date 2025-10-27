/**
 * ImageAnalysisView - Displays AI image analysis results
 * Shows image descriptions, objects, colors, and extracted text
 */

import SwiftUI

struct ImageAnalysisView: View {
    let analysis: ImageAnalysis
    @State private var showFullDescription = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Analysis Header
            HStack {
                Image(systemName: "eye")
                    .foregroundColor(.blue)
                Text("Image Analysis")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Button(showFullDescription ? "Less" : "More") {
                    showFullDescription.toggle()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Description
            Text(analysis.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(showFullDescription ? nil : 2)
            
            // Objects and Colors (if available)
            if showFullDescription {
                if !analysis.objects.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Objects:")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Text(analysis.objects.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !analysis.colors.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Colors:")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Text(analysis.colors.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let text = analysis.text, !text.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Text:")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Text(text)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
        .accessibilitySupport(
            label: "Image analysis: \(analysis.accessibilityDescription)",
            traits: .isStaticText
        )
    }
}

// MARK: - Preview

#Preview {
    ImageAnalysisView(
        analysis: ImageAnalysis(
            id: "1",
            description: "A beautiful landscape with mountains and trees",
            objects: ["mountain", "tree", "sky", "cloud"],
            colors: ["blue", "green", "white"],
            text: "Welcome to the mountains",
            confidence: 0.95,
            timestamp: Date()
        )
    )
    .padding()
}
