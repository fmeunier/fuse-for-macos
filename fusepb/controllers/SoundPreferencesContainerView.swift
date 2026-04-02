import AppKit
import SwiftUI

private let soundSpeakerTypes = [
  "TV speaker",
  "Beeper",
  "Unfiltered",
]

private let soundStereoModes = [
  "None",
  "ACB",
  "ABC",
]

@objc(SoundPreferencesContainerView)
@objcMembers
final class SoundPreferencesContainerView: NSView {
  private var hostingView: NSHostingView<SoundPreferencesView>?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    installHostingView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    installHostingView()
  }

  private func installHostingView() {
    let hostingView = NSHostingView(rootView: SoundPreferencesView())
    hostingView.frame = bounds
    hostingView.autoresizingMask = [.width, .height]
    addSubview(hostingView)
    self.hostingView = hostingView
  }
}

private struct SoundPreferencesView: View {
  private let menuLabelWidth: CGFloat = 104
  private let menuWidth: CGFloat = 153

  @AppStorage("sound") private var soundEnabled = true
  @AppStorage("volumebeeper") private var volumeBeeper = 100
  @AppStorage("volumeay") private var volumeAY = 100
  @AppStorage("volumespecdrum") private var volumeSpecDrum = 100
  @AppStorage("volumecovox") private var volumeCovox = 100
  @AppStorage("volumeuspeech") private var volumeUSpeech = 100
  @AppStorage("speakertype") private var speakerType = "TV speaker"
  @AppStorage("separation") private var stereoAY = "None"
  @AppStorage("loading-sound") private var loadingSound = true

  var body: some View {
    CenteredPreferencesPane(width: 628, height: 302) {
      VStack(alignment: .leading, spacing: 18) {
        Toggle("Enabled", isOn: $soundEnabled)

        sliderColumn
          .padding(.leading, 18)

        VStack(alignment: .leading, spacing: 8) {
          Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
              Text("Speaker type")
                .frame(width: menuLabelWidth, alignment: .leading)

              Picker("Speaker type", selection: $speakerType) {
                ForEach(soundSpeakerTypes, id: \.self) { value in
                  Text(value).tag(value)
                }
              }
              .labelsHidden()
              .pickerStyle(.menu)
              .frame(width: menuWidth)
            }

            GridRow {
              Text("AY stereo mode")
                .frame(width: menuLabelWidth, alignment: .leading)

              Picker("AY stereo mode", selection: $stereoAY) {
                ForEach(soundStereoModes, id: \.self) { value in
                  Text(value).tag(value)
                }
              }
              .labelsHidden()
              .pickerStyle(.menu)
              .frame(width: menuWidth)
            }
          }

          Toggle("Loading  sounds", isOn: $loadingSound)
            .padding(.top, 10)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding(.leading, 217)
      .padding(.top, 22)
      .padding(.trailing, 28)
      .padding(.bottom, 18)
      .flexibleButtonSizingIfAvailable()
    }
  }

  private var sliderColumn: some View {
    VStack(alignment: .leading, spacing: 6) {
      volumeSliderRow(title: "Beeper Volume", value: sliderBinding(for: $volumeBeeper))
      volumeSliderRow(title: "AY Volume", value: sliderBinding(for: $volumeAY))
      volumeSliderRow(title: "SpecDrum Volume", value: sliderBinding(for: $volumeSpecDrum))
      volumeSliderRow(title: "Covox Volume", value: sliderBinding(for: $volumeCovox))
      volumeSliderRow(title: "\u{00B5}Speech Volume", value: sliderBinding(for: $volumeUSpeech))
    }
    .padding(.top, 2)
  }

  private func volumeSliderRow(title: String, value: Binding<Double>) -> some View {
    HStack(spacing: 12) {
      Text(title)
        .frame(width: 116, alignment: .leading)

      Slider(value: value, in: 0...100, step: 1)
        .frame(width: 116)
    }
  }

  private func sliderBinding(for value: Binding<Int>) -> Binding<Double> {
    Binding {
      Double(value.wrappedValue)
    } set: { newValue in
      value.wrappedValue = Int(newValue)
    }
  }
}

private extension View {
  @ViewBuilder
  func flexibleButtonSizingIfAvailable() -> some View {
    if #available(macOS 26.0, *) {
      buttonSizing(.flexible)
    } else {
      self
    }
  }
}
