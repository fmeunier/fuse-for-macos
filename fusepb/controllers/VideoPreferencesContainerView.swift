import AppKit
import SwiftUI

private struct VideoFilterOption: Identifiable, Hashable {
  let id: String
  let title: String
  let availableOnTimex: Bool
  let availableOnNonTimex: Bool

  var allowsCurrentMachine: Bool {
    if videoMachineIsTimexEnabled() {
      return availableOnTimex
    } else {
      return availableOnNonTimex
    }
  }
}

private let videoFilterLeftColumn = [
  VideoFilterOption(id: "normal", title: "None", availableOnTimex: true,
                    availableOnNonTimex: true),
  VideoFilterOption(id: "2xsai", title: "2xSaI", availableOnTimex: false,
                    availableOnNonTimex: true),
  VideoFilterOption(id: "super2xsai", title: "Super 2xSaI", availableOnTimex: false,
                    availableOnNonTimex: true),
  VideoFilterOption(id: "supereagle", title: "SuperEagle", availableOnTimex: false,
                    availableOnNonTimex: true),
  VideoFilterOption(id: "advmame2x", title: "AdvMAME 2x", availableOnTimex: false,
                    availableOnNonTimex: true),
  VideoFilterOption(id: "advmame3x", title: "AdvMAME 3x", availableOnTimex: false,
                    availableOnNonTimex: true),
  VideoFilterOption(id: "tv2x", title: "TV 2x", availableOnTimex: false,
                    availableOnNonTimex: true),
  VideoFilterOption(id: "tv3x", title: "TV 3x", availableOnTimex: false,
                    availableOnNonTimex: true),
]

private let videoFilterRightColumn = [
  VideoFilterOption(id: "timextv", title: "Timex TV", availableOnTimex: true,
                    availableOnNonTimex: false),
  VideoFilterOption(id: "paltv", title: "PAL TV", availableOnTimex: true,
                    availableOnNonTimex: true),
  VideoFilterOption(id: "paltv2x", title: "PAL TV 2x", availableOnTimex: false,
                    availableOnNonTimex: true),
  VideoFilterOption(id: "paltv3x", title: "PAL TV 3x", availableOnTimex: false,
                    availableOnNonTimex: true),
  VideoFilterOption(id: "hq2x", title: "HQ 2x", availableOnTimex: false,
                    availableOnNonTimex: true),
  VideoFilterOption(id: "hq3x", title: "HQ 3x", availableOnTimex: false,
                    availableOnNonTimex: true),
  VideoFilterOption(id: "dotmatrix", title: "Dot Matrix", availableOnTimex: false,
                    availableOnNonTimex: true),
]

private let videoFilterOptions = videoFilterLeftColumn + videoFilterRightColumn

@objc(VideoPreferencesContainerView)
@objcMembers
final class VideoPreferencesContainerView: NSView {
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    installHostingView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    installHostingView()
  }

  private func installHostingView() {
    let hostingView = NSHostingView(rootView: VideoPreferencesView())
    hostingView.frame = bounds
    hostingView.autoresizingMask = [.width, .height]
    addSubview(hostingView)
  }
}

private struct VideoPreferencesView: View {
  @AppStorage("graphicsfilter") private var graphicsFilter = "normal"
  @AppStorage("machine") private var machine = "48"
  @AppStorage("bilinear") private var bilinear = false
  @AppStorage("bwtv") private var blackAndWhiteTV = false
  @AppStorage("paltv2x") private var usePALScanlines = false
  @AppStorage("fullscreenpanorama") private var panoramicFullscreen = true

  var body: some View {
    CenteredPreferencesPane(width: 627, height: 296) {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top, spacing: 32) {
          filterColumn(options: videoFilterLeftColumn)
          filterColumn(options: videoFilterRightColumn)
        }

        VStack(alignment: .leading, spacing: 8) {
          Toggle("Bilinear", isOn: $bilinear)
          Toggle("Black and white TV", isOn: $blackAndWhiteTV)
          Toggle("Use scanlines in PAL TV filters", isOn: $usePALScanlines)
          Toggle("Panoramic full screen", isOn: $panoramicFullscreen)
        }

        Spacer(minLength: 18)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding(.leading, 191)
      .padding(.top, 20)
    }
    .onAppear {
      repairSelectionIfNeeded()
    }
    .onChange(of: machine) { _ in
      repairSelectionIfNeeded()
    }
  }

  private func filterColumn(options: [VideoFilterOption]) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      ForEach(options) { option in
        Button {
          graphicsFilter = option.id
        } label: {
          HStack(spacing: 6) {
            Image(systemName: graphicsFilter == option.id ? "largecircle.fill.circle" : "circle")
              .font(.system(size: 13))
            Text(option.title)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!option.allowsCurrentMachine)
        .accessibilityLabel(option.title)
        .accessibilityValue(graphicsFilter == option.id ? "Selected" : "Not selected")
      }
    }
    .frame(width: 120, alignment: .topLeading)
    .fixedSize(horizontal: true, vertical: true)
  }

  private func repairSelectionIfNeeded() {
    let matchingOption = videoFilterOptions.first { $0.id == graphicsFilter }

    guard let matchingOption else {
      graphicsFilter = videoMachineIsTimexEnabled() ? "timextv" : "normal"
      return
    }

    if matchingOption.allowsCurrentMachine { return }

    graphicsFilter = videoMachineIsTimexEnabled() ? "timextv" : "normal"
  }
}
