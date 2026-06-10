import SwiftUI
import UniformTypeIdentifiers

struct ControlPanelView: View {
    @EnvironmentObject var appState: AppState
    @State private var isTimbreDropTargeted = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 14) {
            Text("Control Panel")
                .font(.headline)
                .padding(.top, 12)

            algorithmSelector
            parameterSection
            buttonSection
            errorSection
            Spacer()
            logSection
        }
        .padding(.horizontal, 16)
        .alert("文件校验失败", isPresented: .constant(errorMessage != nil)) {
            Button("确定") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func resignAllFocus() {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    // MARK: - Algorithm selector

    private var algorithmSelector: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("算法").font(.caption).foregroundColor(.secondary)
            Picker("", selection: $appState.selectedAlgorithm) {
                ForEach(SVCAlgorithm.allCases) { algo in
                    Text(algo.rawValue).tag(algo)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Parameter section

    @ViewBuilder
    private var parameterSection: some View {
        switch appState.selectedAlgorithm {
        case .yingmusic: yingmusicParams
        case .rvc: rvcParams
        }
    }

    private var yingmusicParams: some View {
        Group {
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
                    Text("请先导入音色文件").font(.caption).foregroundColor(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Diffusion Steps").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text("\(appState.diffusionSteps)").font(.system(.body, design: .monospaced))
                }
                DiffusionStepSlider(value: $appState.diffusionSteps)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Pitch Shift").font(.caption).foregroundColor(.secondary)
                HStack {
                    Button("-12") { appState.pitchShift = -12 }
                        .buttonStyle(.bordered).controlSize(.small)
                    Stepper("", value: $appState.pitchShift, in: -24...24).labelsHidden()
                    TextField("", value: $appState.pitchShift, formatter: NumberFormatter())
                        .frame(width: 50)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.center)
                    Button("+12") { appState.pitchShift = +12 }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
        }
    }

    private var rvcParams: some View {
        Group {
            VStack(alignment: .leading, spacing: 6) {
                Text("模型").font(.caption).foregroundColor(.secondary)
                Picker("", selection: $appState.selectedRvcModelID) {
                    Text("请选择模型").tag(nil as String?)
                    ForEach(appState.rvcModels) { m in
                        Text(m.name).tag(m.id as String?)
                    }
                }
                .labelsHidden()
                if appState.rvcModels.isEmpty {
                    Text("未找到模型，请放入 ~/.svc-gui/rvc/models/<名称>/model.safetensors")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Pitch Shift").font(.caption).foregroundColor(.secondary)
                HStack {
                    Button("-12") { appState.pitchShift = -12 }
                        .buttonStyle(.bordered).controlSize(.small)
                    Stepper("", value: $appState.pitchShift, in: -24...24).labelsHidden()
                    TextField("", value: $appState.pitchShift, formatter: NumberFormatter())
                        .frame(width: 50)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.center)
                    Button("+12") { appState.pitchShift = +12 }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
            EditableSliderRow(label: "Index Rate", value: $appState.rvcIndexRate, range: 0...1, format: "%.2f")
            EditableSliderRow(label: "Volume", value: $appState.rvcVolumeEnvelope, range: 0...2, format: "%.1f")
            EditableSliderRow(label: "Protect", value: $appState.rvcProtect, range: 0...1, format: "%.2f")
            Toggle("F0 Autotune", isOn: $appState.rvcF0Autotune).font(.caption)
            if appState.rvcF0Autotune {
                EditableSliderRow(label: "Autotune Strength", value: $appState.rvcF0AutotuneStrength, range: 0...1, format: "%.2f")
            }
        }
    }

    // MARK: - Button

    private var buttonSection: some View {
        Group {
            if appState.isGenerating {
                Button(action: { appState.cancelGeneration() }) {
                    HStack {
                        ProgressView().scaleEffect(0.7)
                        Text("取消")
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
            } else {
                Button(action: { appState.generate() }) {
                    Text("生成").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canGenerate)
                .padding(.top, 8)
            }
        }
    }

    private var errorSection: some View {
        Group {
            if let error = appState.generationError {
                Text(error).font(.caption).foregroundColor(.red)
            }
        }
    }

    private var logSection: some View {
        Group {
            if !appState.logs.isEmpty {
                ScrollViewReader { scroll in
                    ScrollView {
                        Text(appState.logs)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(4)
                            .id("bottom")
                    }
                    .frame(height: 60)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(4)
                    .onChange(of: appState.logs) { _ in
                        scroll.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var canGenerate: Bool {
        switch appState.selectedAlgorithm {
        case .yingmusic:
            return appState.selectedRecordingID != nil && appState.selectedTimbreID != nil
        case .rvc:
            return appState.selectedRecordingID != nil && appState.selectedRvcModelID != nil
        }
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

// MARK: - Editable Slider Row

struct EditableSliderRow<V: BinaryFloatingPoint>: View where V.Stride: BinaryFloatingPoint {
    let label: String
    @Binding var value: V
    let range: ClosedRange<V>
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.caption).foregroundColor(.secondary)
                Spacer()
                EditableValueField(
                    text: String(format: format, value as! CVarArg),
                    onCommit: { text in
                        if let parsed = Double(text), !text.isEmpty {
                            value = V(max(Double(range.lowerBound), min(Double(range.upperBound), parsed)))
                        }
                    }
                )
                .frame(width: 50)
            }
            Slider(value: $value, in: range)
        }
    }
}

struct EditableValueField: NSViewRepresentable {
    let text: String
    let onCommit: (String) -> Void

    func makeNSView(context: Context) -> ClickableTextField {
        let tf = ClickableTextField()
        tf.isEditable = false
        tf.isSelectable = false
        tf.isBordered = false
        tf.drawsBackground = false
        tf.stringValue = text
        tf.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        tf.alignment = .center
        tf.delegate = context.coordinator
        tf.target = context.coordinator
        tf.action = #selector(Coordinator.textDidEndEditingSelector)
        tf.onDoubleClick = { [weak tf] in
            guard let tf else { return }
            context.coordinator.beginEditing(tf)
        }
        return tf
    }

    func updateNSView(_ nsView: ClickableTextField, context: Context) {
        if !context.coordinator.isEditing {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: text, onCommit: onCommit)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var text: String
        let onCommit: (String) -> Void
        var isEditing = false
        private var clickMonitor: Any?

        init(text: String, onCommit: @escaping (String) -> Void) {
            self.text = text
            self.onCommit = onCommit
        }

        func beginEditing(_ tf: NSTextField) {
            guard !isEditing else { return }
            isEditing = true
            tf.isEditable = true
            tf.isSelectable = true
            text = tf.stringValue
            tf.window?.makeFirstResponder(tf)
            DispatchQueue.main.async {
                if let editor = tf.currentEditor() as? NSTextView {
                    editor.selectAll(nil)
                }
            }
            clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                DispatchQueue.main.async {
                    self?.endEditing(from: tf)
                }
                return event
            }
        }

        func endEditing(from tf: NSTextField? = nil) {
            guard isEditing else { return }
            isEditing = false
            if let m = clickMonitor {
                NSEvent.removeMonitor(m)
                clickMonitor = nil
            }
            guard let window = NSApp.keyWindow,
                  let tf = tf ?? (window.firstResponder as? NSTextField)
            else { return }
            tf.isEditable = false
            tf.isSelectable = false
            window.makeFirstResponder(nil)
            onCommit(tf.stringValue)
        }

        @objc func textDidEndEditingSelector() {
            guard let window = NSApp.keyWindow,
                  let tf = window.firstResponder as? NSTextField
            else { return }
            endEditing(from: tf)
        }
    }
}

class ClickableTextField: NSTextField {
    var onDoubleClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
            return
        }
        super.mouseDown(with: event)
    }
}

// MARK: - Diffusion Step Slider

struct DiffusionStepSlider: View {
    @Binding var value: Int
    private let steps = AppState.diffusionStepValues

    var body: some View {
        GeometryReader { geometry in
            let stepWidth = geometry.size.width / CGFloat(steps.count - 1)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3)).frame(height: 4)
                if let idx = steps.firstIndex(of: value) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: stepWidth * CGFloat(idx), height: 4)
                }
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    Circle()
                        .fill(i <= steps.firstIndex(of: value)! ? Color.blue : Color.gray.opacity(0.5))
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
