import SwiftUI

struct OutputAudiosView: View {
    @EnvironmentObject var appState: AppState
    @State private var renamingID: String?
    @State private var renameText = ""
    @State private var showDeleteAlert = false
    @State private var fileToDelete: AudioFile?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Output Audios")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if appState.outputs.isEmpty {
                Spacer()
                Text("选择音源和音色后点击生成")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else {
                List {
                    ForEach(appState.outputs) { file in
                        RecordingRow(
                            file: file,
                            isSelected: false,
                            isRenaming: renamingID == file.id,
                            renameText: $renameText,
                            onSelect: {},
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
                                    appState.renameOutput(file, to: renameText)
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
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let f = fileToDelete {
                    appState.deleteOutput(f)
                }
            }
        } message: {
            Text("确定要删除「\(fileToDelete?.name ?? "")」吗？此操作不可撤销。")
        }
    }
}
