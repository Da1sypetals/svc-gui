import SwiftUI
import UniformTypeIdentifiers

struct HistoryRecordingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var renamingID: String?
    @State private var renameText = ""
    @State private var showDeleteAlert = false
    @State private var fileToDelete: AudioFile?
    @State private var isImportTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("History Recordings")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button("导入 Recording") {
                    importFile()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // List
            if appState.recordings.isEmpty {
                Spacer()
                Text("点击下方录音按钮开始，或拖入已有音频文件")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else {
                List {
                    ForEach(appState.recordings) { file in
                        RecordingRow(
                            file: file,
                            isSelected: appState.selectedRecordingID == file.id,
                            isRenaming: renamingID == file.id,
                            renameText: $renameText,
                            onSelect: {
                                appState.selectedRecordingID = file.id
                            },
                            onPlay: { appState.play(file: file) },
                            onDelete: {
                                fileToDelete = file
                                showDeleteAlert = true
                            },
                            onRenameStart: {
                                renamingID = file.id
                                renameText = file.name
                            },
                            onRenameCommit: {
                                if !renameText.isEmpty, renameText != file.name {
                                    appState.renameRecording(file, to: renameText)
                                }
                                renamingID = nil
                            }
                        )
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isImportTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .overlay(
            isImportTargeted ?
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 2)
                    .padding(4)
                : nil
        )
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let f = fileToDelete {
                    appState.deleteRecording(f)
                }
            }
        } message: {
            Text("确定要删除「\(fileToDelete?.name ?? "")」吗？此操作不可撤销。")
        }
    }

    private func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = audioTypes()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            guard appState.storage.validateMonoAudio(url: url) else {
                let alert = NSAlert()
                alert.messageText = "文件校验失败"
                alert.informativeText = "音频文件必须是单声道 (mono)。"
                alert.runModal()
                return
            }
            appState.importRecording(from: url)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let path = String(data: data, encoding: .utf8),
                      let url = URL(string: path)
                else { return }
                DispatchQueue.main.async {
                    guard appState.storage.validateMonoAudio(url: url) else { return }
                    appState.importRecording(from: url)
                }
            }
        }
    }
}
