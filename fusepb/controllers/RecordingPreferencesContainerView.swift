import AppKit
import SwiftUI

private let recordingMovieCompressionLevels = optionChoices(
  { cocoa_movie_movie_compr_bridge() },
  fallback: [
    "None",
    "Lossless",
    "High",
  ]
)

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
  private let fieldLabelWidth: CGFloat = 236
  private let pickerControlWidth: CGFloat = 129
  private let competitionCodeWidth: CGFloat = 96

  @AppStorage("rzxautosaves") private var rzxAutosaves = false
  @AppStorage("embedsnapshot") private var embedSnapshot = false
  @AppStorage("competitionmode") private var competitionMode = false
  @AppStorage("competitioncode") private var competitionCode = 0
  @AppStorage("moviecompr") private var movieCompression = ""

  var body: some View {
    CenteredPreferencesPane(width: 627, height: 172) {
      VStack(alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 8) {
          Toggle("Emulator recording create autosaves", isOn: $rzxAutosaves)
          Toggle("Emulator recording always embed snapshot", isOn: $embedSnapshot)
          Toggle("Emulator recording competition mode", isOn: $competitionMode)
        }

        VStack(alignment: .leading, spacing: 10) {
          HStack(spacing: 16) {
            Text("Emulator recording competition code")
              .lineLimit(1)
              .frame(width: fieldLabelWidth, alignment: .leading)

            HStack(spacing: 0) {
              Spacer(minLength: 0)

              TextField("", value: $competitionCode, formatter: competitionCodeFormatter)
                .textFieldStyle(.roundedBorder)
                .frame(width: competitionCodeWidth)
            }
            .frame(width: pickerControlWidth, alignment: .trailing)
          }

          HStack(spacing: 16) {
            Text("Movie Compression Level")
              .lineLimit(1)
              .frame(width: fieldLabelWidth, alignment: .leading)

            Picker(
              "Movie Compression Level",
              selection: enumeratedStringBinding(
                for: $movieCompression,
                canonicalize: {
                  canonicalOptionString(
                    $0,
                    enumerator: { cocoa_string_movie_movie_compr_bridge( $0 ) },
                    fallback: recordingMovieCompressionLevels[0]
                  )
                }
              )
            ) {
              ForEach(recordingMovieCompressionLevels, id: \.self) { value in
                Text(value).tag(value)
              }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: pickerControlWidth, alignment: .trailing)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding(.top, 14)
      .padding(.leading, 183)
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
