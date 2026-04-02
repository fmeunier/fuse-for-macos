import AppKit
import SwiftUI

private let recordingMovieCompressionLevels = [
  "None",
  "Lossless",
  "High",
]

@objc(RecordingPreferencesContainerView)
@objcMembers
final class RecordingPreferencesContainerView: NSView {
  private var hostingView: NSHostingView<RecordingPreferencesView>?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    installHostingView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    installHostingView()
  }

  private func installHostingView() {
    let hostingView = NSHostingView(rootView: RecordingPreferencesView())
    hostingView.frame = bounds
    hostingView.autoresizingMask = [.width, .height]
    addSubview(hostingView)
    self.hostingView = hostingView
  }
}

private struct RecordingPreferencesView: View {
  @AppStorage("rzxautosaves") private var rzxAutosaves = false
  @AppStorage("embedsnapshot") private var embedSnapshot = false
  @AppStorage("competitionmode") private var competitionMode = false
  @AppStorage("competitioncode") private var competitionCode = 0
  @AppStorage("moviecompr") private var movieCompression = "None"

  var body: some View {
    CenteredPreferencesPane(width: 627, height: 146) {
      VStack(alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 8) {
          Toggle("Emulator recording create autosaves", isOn: $rzxAutosaves)
          Toggle("Emulator recording always embed snapshot", isOn: $embedSnapshot)
          Toggle("Emulator recording competition mode", isOn: $competitionMode)
        }

        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
          GridRow {
            Text("Emulator recording competition code")

            TextField("", value: $competitionCode, formatter: competitionCodeFormatter)
              .textFieldStyle(.roundedBorder)
              .frame(width: 170)
          }

          GridRow {
            Text("Movie Compression Level")

            Picker("Movie Compression Level", selection: $movieCompression) {
              ForEach(recordingMovieCompressionLevels, id: \.self) { value in
                Text(value).tag(value)
              }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 150, alignment: .leading)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      .padding(.horizontal, 18)
    }
  }

  private var competitionCodeFormatter: NumberFormatter {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimum = 0
    formatter.maximumFractionDigits = 0
    return formatter
  }
}
