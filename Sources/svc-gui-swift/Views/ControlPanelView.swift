import SwiftUI
import UniformTypeIdentifiers

struct ControlPanelView: View {
    @EnvironmentObject var appState: AppState
    @State private var isTimbreDropTargeted = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Control Panel")
                .font(.headline)
                .padding(.top, 12)

            // Timbre selector
            VStack(alignment: .leading, spacing: 6) {
                Text("音色").font(.caption).foregroundColor(.secondary)
                HStack {
                    Picker("", selection: $appState.selectedTimbreID) {
                        Text("请选择音色").tag(nil as String?)
                        ForEach(appState.timbres) { t in
                            Text(t.name).tag(t.id as String?)
                        }
                    }
                    .labelsHidden()

                    Button("导入音色") { importTimbre() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(8)
                .background(isTimbreDropTargeted ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                .cornerRadius(6)
                .contextMenu {
                    if let tid = appState.selectedTimbreID,
                       let timbre = appState.timbres.first(where: { $0.id == tid }) {
                        Button("删除「\(timbre.name)」", role: .destructive) {
                            appState.deleteTimbre(timbre)
                        }
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: $isTimbreDropTargeted) { providers in
                    handleTimbreDrop(providers: providers)
                    return true
                }

                if appState.timbres.isEmpty {
                    Text("请先导入音色文件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Diffusion Steps
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Diffusion Steps").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text("\(appState.diffusionSteps)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                }
                DiffusionStepSlider(value: $appState.diffusionSteps)
            }

            // Pitch Shift
            VStack(alignment: .leading, spacing: 6) {
                Text("Pitch Shift").font(.caption).foregroundColor(.secondary)
                HStack {
                    Stepper("", value: $appState.pitchShift, in: -24...24)
                        .labelsHidden()
                    TextField("", value: $appState.pitchShift, formatter: NumberFormatter())
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.center)
                }
            }

            // Generate button
            Button(action: { appState.generate() }) {
                if appState.isGenerating {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("生成中...")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Text("生成")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(appState.isGenerating || !canGenerate)
            .padding(.top, 8)

            if let error = appState.generationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .alert("文件校验失败", isPresented: .constant(errorMessage != nil)) {
            Button("确定") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var canGenerate: Bool {
        appState.selectedRecordingID != nil && appState.selectedTimbreID != nil
    }

    private func importTimbre() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = audioTypes()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            guard appState.storage.validateMonoAudio(url: url) else {
                errorMessage = "音频文件必须是单声道 (mono)。"
                return
            }
            appState.importTimbre(from: url)
        }
    }

    private func handleTimbreDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let path = String(data: data, encoding: .utf8),
                      let url = URL(string: path)
                else { return }
                DispatchQueue.main.async {
                    guard appState.storage.validateMonoAudio(url: url) else { return }
                    appState.importTimbre(from: url)
                }
            }
        }
    }
}

struct DiffusionStepSlider: View {
    @Binding var value: Int
    let steps = AppState().diffusionStepValues

    var body: some View {
        GeometryReader { geometry in
            let stepWidth = geometry.size.width / CGFloat(steps.count - 1)
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)

                // Active steps
                if let idx = steps.firstIndex(of: value) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: stepWidth * CGFloat(idx), height: 4)
                }

                // Tick marks
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    Circle()
                        .fill(i <= (steps.firstIndex(of: value) ?? 0) ? Color.blue : Color.gray.opacity(0.5))
                        .frame(width: 10, height: 10)
                        .position(x: stepWidth * CGFloat(i), y: geometry.size.height / 2)
                        .onTapGesture { value = step }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let idx = Int(round(gesture.location.x / stepWidth))
                        value = steps[min(max(idx, 0), steps.count - 1)]
                    }
            )
        }
        .frame(height: 24)
    }
}
