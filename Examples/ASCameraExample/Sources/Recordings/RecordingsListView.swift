import SwiftUI

struct RecordingsListView: View {
    @Environment(RecordingsStore.self) private var store

    var body: some View {
        Group {
            if store.recordings.isEmpty {
                ContentUnavailableView(
                    "No Recordings",
                    systemImage: "film",
                    description: Text("Record a clip from either recorder to see it here.")
                )
            } else {
                List {
                    ForEach(store.recordings) { recording in
                        NavigationLink {
                            RecordingDetailView(recording: recording)
                        } label: {
                            RecordingRow(recording: recording)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            store.delete(store.recordings[index])
                        }
                    }
                }
            }
        }
        .navigationTitle("Recordings")
        .toolbar { EditButton() }
        .onAppear { store.reload() }
    }
}

/// A row that loads and shows the start timestamp embedded in the file's metadata.
struct RecordingRow: View {
    let recording: Recording
    @State private var startDate: Date?
    @State private var didLoad = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.rectangle.fill")
                .font(.title)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(startDate.map { RecordingFormatters.display.string(from: $0) } ?? recording.fileName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text(startDate == nil && didLoad ? "No embedded timestamp" : "Embedded start time")
                    Text("·")
                    Text(recording.fileSizeString)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .task {
            guard !didLoad else { return }
            startDate = await RecordingMetadata.startDate(for: recording.url)
            didLoad = true
        }
    }
}
