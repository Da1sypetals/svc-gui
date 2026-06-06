import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top area: 3 columns
                HStack(spacing: 0) {
                    HistoryRecordingsView()
                        .frame(width: geometry.size.width / 3)
                    Divider()
                    ControlPanelView()
                        .frame(width: geometry.size.width / 3)
                    Divider()
                    OutputAudiosView()
                        .frame(width: geometry.size.width / 3)
                }
                .frame(height: geometry.size.height * 0.75)

                Divider()

                // Bottom transport bar
                TransportBar()
                    .frame(height: geometry.size.height * 0.25)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(.dark)
    }
}
