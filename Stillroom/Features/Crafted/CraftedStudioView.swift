import SwiftUI

/// Coordinates cabinet/editor transactions. Playback always returns to the shared turntable.
struct CraftedStudioView: View {
    let tracks: [Track]
    let artworks: [String: UIImage]
    @ObservedObject var archive: CraftedRecordsStore
    var initialEditing: CraftedRecord? = nil
    var onOpen: (CraftedRecord) -> Void
    var onPlay: (CraftedRecord) -> Void
    var onClose: () -> Void
    @State private var editing: CraftedRecord?
    @State private var pendingPlayback: CraftedRecord?
    @State private var loadedInitialEditor = false

    var body: some View {
        ZStack(alignment: .top) {
            if !archive.ready {
                VStack(spacing: 20) {
                    Text("你的唱片柜").font(.largeTitle)
                    if let error = archive.error {
                        Text(error).font(.body)
                        Button("重新读取") { Task { await archive.restore() } }
                    } else { ProgressView("正在读取唱片柜") }
                    Button("返回", action: onClose).frame(minHeight: 44)
                }.foregroundStyle(CraftStyle.paper).padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CraftedCabinetView(records: archive.records, images: archive.images, tracks: tracks,
                    onCreate: { editing = CraftedRecord() }, onOpen: { record in
                        if record.isDraft { editing = record } else { onOpen(record) }
                    }, onEdit: { editing = $0 }, onClose: onClose)
            }
        }.background(CraftStyle.desk.ignoresSafeArea())
            .fullScreenCover(item: $editing, onDismiss: finishEditing) { record in
                CraftedRecordComposer(record: record, tracks: tracks, artworks: artworks,
                    existingCover: record.coverAsset.flatMap { archive.images[$0] }, onSave: { value, jpeg, start in
                        guard await archive.saveRecord(value, photoJPEG: jpeg) else { return false }
                        if start { pendingPlayback = archive.records.first { $0.id == value.id } }
                        return true
                    }, onClose: { editing = nil })
            }
            .alert("这次操作未能完成", isPresented: Binding(get: { archive.error != nil }, set: { if !$0 { archive.error = nil } })) {
                Button("知道了") { archive.error = nil }
            } message: { Text(archive.error ?? "请重试。") }
            .onAppear {
                guard !loadedInitialEditor else { return }
                loadedInitialEditor = true
                editing = initialEditing
            }
    }

    private func finishEditing() {
        guard let record = pendingPlayback else { return }
        pendingPlayback = nil
        // Wait for the editor's real dismissal before removing the cabinet underneath it. The audio
        // engine is started by the root callback, never by a second presentation-owned player.
        onPlay(record)
    }
}
