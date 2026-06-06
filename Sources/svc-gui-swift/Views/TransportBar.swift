import SwiftUI

struct TransportBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            recordingSection
                .frame(maxWidth: .infinity)
            Divider()
            playbackSection
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Recording

    private var recordingSection: some View {
        VStack(spacing: 6) {
            // Level meter + spacer to match playback bar height
            VStack(spacing: 2) {
                LevelMeterView(level: appState.meterLevel)
                    .frame(height: 14)
                // Invisible spacer matching time labels
                Color.clear
                    .frame(height: 12)
            }
            .padding(.horizontal, 0)

            RecordButton(isRecording: appState.isRecording) {
                if appState.isRecording {
                    appState.stopRecording()
                } else {
                    appState.startRecording()
                }
            }

            Text(appState.isRecording ? "Stop" : "Record")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var playbackSection: some View {
        VStack(spacing: 6) {
            // Progress bar + time
            VStack(spacing: 2) {
                SeekBarView(
                    progress: appState.playbackDuration > 0
                        ? appState.currentPlaybackTime / appState.playbackDuration : 0
                ) { ratio in
                    appState.seekPlayback(to: ratio * appState.playbackDuration)
                }
                .frame(height: 14)

                HStack {
                    Text(formatTime(appState.currentPlaybackTime))
                    Spacer()
                    Text(formatTime(appState.playbackDuration))
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
            }

            PlayButton(isPlaying: appState.isPlaying) {
                appState.togglePlayPause()
            }

            Text(appState.isPlaying ? "Pause" : "Play")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Level Meter

struct LevelMeterView: View {
    let level: CGFloat

    var body: some View {
        GeometryReader { geo in
            let barWidth = geo.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.25))
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor)
                    .frame(width: barWidth * level, height: 8)
            }
        }
        .frame(height: 8)
        .padding(.horizontal, 12)
        .animation(.linear(duration: 0.05), value: level)
    }

    private var barColor: Color {
        if level > 0.8 { return .red }
        if level > 0.5 { return .yellow }
        return .green
    }
}

// MARK: - Seek Bar

struct SeekBarView: View {
    let progress: Double
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let barWidth = geo.size.width
            let fill = max(0, min(barWidth, barWidth * progress))
            let thumbX = max(7, min(barWidth - 7, fill))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.25))
                    .frame(height: 8)
                if fill > 0 {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blue)
                        .frame(width: fill, height: 8)
                }
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .shadow(radius: 2)
                    .offset(x: thumbX - 7)
            }
            .frame(height: 14, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = max(0, min(1, value.location.x / barWidth))
                        onSeek(ratio)
                    }
            )
        }
        .frame(height: 14)
        .padding(.horizontal, 12)
    }
}

// MARK: - Buttons

struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.red.opacity(0.7))
                    .frame(width: 44, height: 44)
                if isRecording {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                } else {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isRecording ? 1.12 : 1.0)
        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isRecording)
    }
}

struct PlayButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: 44, height: 44)
                if isPlaying {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white)
                            .frame(width: 4, height: 14)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white)
                            .frame(width: 4, height: 14)
                    }
                } else {
                    Image(systemName: "play.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
