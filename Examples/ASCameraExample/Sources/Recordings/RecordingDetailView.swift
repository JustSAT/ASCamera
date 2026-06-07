import AVKit
import SwiftUI

/// Plays a recording and shows the start timestamp read back from the file's embedded metadata —
/// the concrete proof that the recorded file contains the moment recording began.
struct RecordingDetailView: View {
    let recording: Recording

    @State private var player: AVPlayer?
    @State private var embeddedStartDate: Date?
    @State private var assetDuration: Duration?
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VideoPlayer(player: player)
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .background(.black, in: RoundedRectangle(cornerRadius: 16))

                infoCard

                Text(recording.fileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding()
        }
        .navigationTitle("Recording")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onDisappear { player?.pause() }
    }

    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow(
                icon: "clock.badge.checkmark",
                title: "Recording started",
                value: startValueText,
                highlight: embeddedStartDate != nil
            )
            Divider()
            infoRow(
                icon: "timer",
                title: "Duration",
                value: (assetDuration ?? recording.duration)?.clockString ?? "—"
            )
            Divider()
            infoRow(
                icon: "doc",
                title: "File size",
                value: recording.fileSizeString
            )
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func infoRow(icon: String, title: String, value: String, highlight: Bool = false) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(highlight ? Color.green : Color.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding()
    }

    private var startValueText: String {
        if isLoading { return "Reading…" }
        guard let embeddedStartDate else { return "Not found in file" }
        return RecordingFormatters.display.string(from: embeddedStartDate)
    }

    private func load() async {
        player = AVPlayer(url: recording.url)
        embeddedStartDate = await RecordingMetadata.startDate(for: recording.url)

        let asset = AVURLAsset(url: recording.url)
        if let cmDuration = try? await asset.load(.duration) {
            assetDuration = .seconds(max(0, cmDuration.seconds))
        }
        isLoading = false
    }
}
