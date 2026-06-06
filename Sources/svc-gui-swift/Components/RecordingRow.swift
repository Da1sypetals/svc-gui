import SwiftUI
import UniformTypeIdentifiers

struct RecordingRow: View {
    let file: AudioFile
    let isSelected: Bool
    let isRenaming: Bool
    @Binding var renameText: String
    let onSelect: () -> Void
    let onPlay: () -> Void
    let onDelete: () -> Void
    let onRenameStart: () -> Void
    let onRenameCommit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if isRenaming {
                TextField("", text: $renameText, onCommit: onRenameCommit)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            } else {
                Text(file.name)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button(action: onPlay) {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.borderless)
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onTapGesture(count: 1) { onSelect() }
        .onTapGesture(count: 2) { onRenameStart() }
        .contextMenu {
            Button("播放") { onPlay() }
            Button("重命名") { onRenameStart() }
            Divider()
            Button("在 Finder 中显示") {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            }
            Divider()
            Button("删除", role: .destructive) { onDelete() }
        }
        .onDrag {
            NSItemProvider(contentsOf: file.url) ?? NSItemProvider()
        }
    }
}
