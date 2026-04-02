import AppKit
import SwiftUI

private enum MassStorageInterface: String, CaseIterable {
  case none = "None"
  case beta128 = "Beta 128"
  case currahUSource = "Currah \u{00B5}Source"
  case disciple = "DISCiPLE"
  case didaktik80 = "Didaktik 80"
  case divIDE = "DivIDE"
  case divMMC = "DivMMC"
  case interface1 = "Interface 1"
  case opusDiscovery = "Opus Discovery"
  case plusD = "+D"
  case simple8BitIDE = "Simple 8-bit IDE"
  case spectranet = "Spectranet"
  case zxatasp = "ZXATASP interface"
  case zxcf = "ZXCF interface"
  case zxmmc = "ZXMMC interface"
}

private enum ExternalSoundInterface: String, CaseIterable {
  case none = "None"
  case fuller = "Fuller"
  case melodik = "Melodik"
  case specDrum = "SpecDrum"
  case covox = "Covox"
  case uspeech = "\u{00B5}Speech"
}

private enum MultifaceType: String, CaseIterable {
  case none = "None"
  case multifaceOne = "Multiface One"
  case multiface128 = "Multiface 128"
  case multiface3 = "Multiface 3"
}

private enum PrinterFileType: Int {
  case graphics = 0
  case text = 1
}

@objc(PeripheralsPreferencesContainerView)
@objcMembers
final class PeripheralsPreferencesContainerView: NSView {
  private weak var fileChooserTarget: AnyObject?
  private var fileChooserAction: Selector?
  private var hostingView: NSHostingView<PeripheralsPreferencesView>?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    installHostingView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    installHostingView()
  }

  func configureWithFileChooserTarget(_ target: AnyObject?, action: Selector?) {
    fileChooserTarget = target
    fileChooserAction = action
    hostingView?.rootView = makeRootView()
  }

  private func installHostingView() {
    let hostingView = NSHostingView(rootView: makeRootView())
    hostingView.frame = bounds
    hostingView.autoresizingMask = [.width, .height]
    addSubview(hostingView)
    self.hostingView = hostingView
  }

  private func makeRootView() -> PeripheralsPreferencesView {
    PeripheralsPreferencesView { [weak self] fileType in
      self?.sendChooseFileAction(fileType)
    }
  }

  private func sendChooseFileAction(_ fileType: PrinterFileType) {
    guard let fileChooserAction else { return }

    let sender = NSButton()
    sender.tag = fileType.rawValue
    NSApp.sendAction(fileChooserAction, to: fileChooserTarget, from: sender)
  }
}

private struct PeripheralsPreferencesView: View {
  @AppStorage("interface1") private var interface1 = false
  @AppStorage("simpleide") private var simpleIDE = false
  @AppStorage("zxatasp") private var zxatasp = false
  @AppStorage("zxcf") private var zxcf = false
  @AppStorage("divide") private var divIDE = false
  @AppStorage("plusd") private var plusD = false
  @AppStorage("beta128") private var beta128 = false
  @AppStorage("opus") private var opusDiscovery = false
  @AppStorage("disciple") private var disciple = false
  @AppStorage("spectranet") private var spectranet = false
  @AppStorage("didaktik80") private var didaktik80 = false
  @AppStorage("usource") private var currahUSource = false
  @AppStorage("divmmc") private var divMMC = false
  @AppStorage("zxmmc") private var zxmmc = false

  @AppStorage("fuller") private var fuller = false
  @AppStorage("melodik") private var melodik = false
  @AppStorage("specdrum") private var specDrum = false
  @AppStorage("covox") private var covox = false
  @AppStorage("uspeech") private var uspeech = false

  @AppStorage("multiface1") private var multiface1 = false
  @AppStorage("multiface128") private var multiface128 = false
  @AppStorage("multiface3") private var multiface3 = false

  @AppStorage("multiface1stealth") private var multiface1Stealth = false
  @AppStorage("plus3detectspeedlock") private var plus3DetectSpeedlock = false
  @AppStorage("beta12848boot") private var beta12848Boot = false
  @AppStorage("dividewriteprotect") private var divideWriteProtect = false
  @AppStorage("divmmcwriteprotect") private var divMMCWriteProtect = false
  @AppStorage("spectranetdisable") private var spectranetDisable = false
  @AppStorage("zxataspupload") private var zxataspUpload = false
  @AppStorage("zxataspwriteprotect") private var zxataspWriteProtect = false
  @AppStorage("zxcfupload") private var zxcfUpload = false
  @AppStorage("mdrlen") private var mdrLength = 180

  @AppStorage("printer") private var printer = false
  @AppStorage("zxprinter") private var zxPrinter = true
  @AppStorage("graphicsfile") private var graphicsFile = ""
  @AppStorage("textfile") private var textFile = ""

  private let chooseFileAction: (PrinterFileType) -> Void

  init(chooseFileAction: @escaping (PrinterFileType) -> Void) {
    self.chooseFileAction = chooseFileAction
  }

  var body: some View {
    CenteredPreferencesPane(width: 637, height: 585) {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top, spacing: 14) {
          massStorageSection
          rightColumn
        }

        printersSection
      }
      .padding(.top, 10)
    }
  }

  private var massStorageSection: some View {
    GroupBox("Mass storage/ROM Interfaces") {
      HStack(alignment: .top, spacing: 18) {
        radioGroup(
          title: "Mass storage/ROM Interfaces",
          selection: massStorageBinding,
          options: MassStorageInterface.allCases
        )

        VStack(alignment: .leading, spacing: 8) {
          Toggle("+3 Detect Speedlock", isOn: $plus3DetectSpeedlock)
          Toggle("Beta autoboot in 48K", isOn: $beta12848Boot)
          Toggle("DivIDE write protect", isOn: $divideWriteProtect)
          Toggle("DivMMC write protect", isOn: $divMMCWriteProtect)
          Toggle("Spectranet disable", isOn: $spectranetDisable)
          Toggle("ZXATASP upload", isOn: $zxataspUpload)
          Toggle("ZXATASP write protect", isOn: $zxataspWriteProtect)
          Toggle("ZXCF upload", isOn: $zxcfUpload)

          HStack(alignment: .center, spacing: 10) {
            Text("MDR cartridge len:")
              .frame(width: 128, alignment: .leading)

            TextField("", value: $mdrLength, formatter: mdrLengthFormatter)
              .textFieldStyle(.roundedBorder)
              .frame(width: 56)
          }
          .padding(.top, 2)
        }
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .topLeading)
    }
  }

  private var rightColumn: some View {
    VStack(alignment: .leading, spacing: 10) {
      GroupBox("External sound interface") {
        radioGroup(
          title: "External sound interface",
          selection: externalSoundBinding,
          options: ExternalSoundInterface.allCases
        )
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
      }

      GroupBox("Romantic Robot Multiface") {
        VStack(alignment: .leading, spacing: 8) {
          radioGroup(
            title: "Romantic Robot Multiface",
            selection: multifaceBinding,
            options: MultifaceType.allCases
          )

          Toggle("Multiface One stealth", isOn: $multiface1Stealth)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
      }
    }
    .frame(width: 230)
  }

  private var printersSection: some View {
    GroupBox("Printers") {
      VStack(alignment: .leading, spacing: 8) {
        Toggle("Emulate printers", isOn: $printer)
        Toggle("Emulate ZX Printer", isOn: $zxPrinter)

        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
          GridRow {
            Text("Graphic Output File:")
            TextField("", text: $graphicsFile)
            Button("Choose...") {
              chooseFileAction(.graphics)
            }
          }

          GridRow {
            Text("Text Output File:")
            TextField("", text: $textFile)
            Button("Choose...") {
              chooseFileAction(.text)
            }
          }
        }
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .topLeading)
    }
  }

  private var massStorageBinding: Binding<MassStorageInterface> {
    Binding {
      if beta128 { return .beta128 }
      if currahUSource { return .currahUSource }
      if disciple { return .disciple }
      if didaktik80 { return .didaktik80 }
      if divIDE { return .divIDE }
      if divMMC { return .divMMC }
      if interface1 { return .interface1 }
      if opusDiscovery { return .opusDiscovery }
      if plusD { return .plusD }
      if simpleIDE { return .simple8BitIDE }
      if spectranet { return .spectranet }
      if zxatasp { return .zxatasp }
      if zxcf { return .zxcf }
      if zxmmc { return .zxmmc }
      return .none
    } set: { newValue in
      interface1 = false
      simpleIDE = false
      zxatasp = false
      zxcf = false
      divIDE = false
      plusD = false
      beta128 = false
      opusDiscovery = false
      disciple = false
      spectranet = false
      didaktik80 = false
      currahUSource = false
      divMMC = false
      zxmmc = false

      switch newValue {
      case .none:
        break
      case .beta128:
        beta128 = true
      case .currahUSource:
        currahUSource = true
      case .disciple:
        disciple = true
      case .didaktik80:
        didaktik80 = true
      case .divIDE:
        divIDE = true
      case .divMMC:
        divMMC = true
      case .interface1:
        interface1 = true
      case .opusDiscovery:
        opusDiscovery = true
      case .plusD:
        plusD = true
      case .simple8BitIDE:
        simpleIDE = true
      case .spectranet:
        spectranet = true
      case .zxatasp:
        zxatasp = true
      case .zxcf:
        zxcf = true
      case .zxmmc:
        zxmmc = true
      }
    }
  }

  private var externalSoundBinding: Binding<ExternalSoundInterface> {
    Binding {
      if fuller { return .fuller }
      if melodik { return .melodik }
      if specDrum { return .specDrum }
      if covox { return .covox }
      if uspeech { return .uspeech }
      return .none
    } set: { newValue in
      fuller = false
      melodik = false
      specDrum = false
      covox = false
      uspeech = false

      switch newValue {
      case .none:
        break
      case .fuller:
        fuller = true
      case .melodik:
        melodik = true
      case .specDrum:
        specDrum = true
      case .covox:
        covox = true
      case .uspeech:
        uspeech = true
      }
    }
  }

  private var multifaceBinding: Binding<MultifaceType> {
    Binding {
      if multiface1 { return .multifaceOne }
      if multiface128 { return .multiface128 }
      if multiface3 { return .multiface3 }
      return .none
    } set: { newValue in
      multiface1 = false
      multiface128 = false
      multiface3 = false

      switch newValue {
      case .none:
        break
      case .multifaceOne:
        multiface1 = true
      case .multiface128:
        multiface128 = true
      case .multiface3:
        multiface3 = true
      }
    }
  }

  private var mdrLengthFormatter: NumberFormatter {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = false
    formatter.minimum = 1
    formatter.maximumFractionDigits = 0
    return formatter
  }

  private func radioGroup<Option: Hashable & RawRepresentable>(
    title: String,
    selection: Binding<Option>,
    options: [Option]
  ) -> some View where Option.RawValue == String {
    Picker(title, selection: selection) {
      ForEach(options, id: \.self) { option in
        Text(option.rawValue)
          .tag(option)
      }
    }
    .labelsHidden()
    .pickerStyle(.radioGroup)
  }
}
