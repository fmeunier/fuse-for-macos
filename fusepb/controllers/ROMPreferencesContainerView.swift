import AppKit
import Combine
import SwiftUI

struct ROMEntry: Identifiable {
  let id: Int
  let title: String

  var romKey: String { "rom\(id)" }
  var defaultROMKey: String { "default_rom\(id)" }
}

private let romEntries = [
  ROMEntry(id: 0, title: "ROM 0:"),
  ROMEntry(id: 1, title: "ROM 1:"),
  ROMEntry(id: 2, title: "ROM 2:"),
  ROMEntry(id: 3, title: "ROM 3:"),
]

func romPreferencesPane(model: ROMPreferencesModel,
                        chooseROM: @escaping (Int) -> Void,
                        resetROM: @escaping (Int) -> Void) -> AnyView {
  AnyView(
    ROMPaneView(
      model: model,
      chooseROM: { entry in chooseROM(entry.id) },
      resetROM: { entry in resetROM(entry.id) }
    )
  )
}

final class ROMPreferencesModel: ObservableObject {
  @Published private(set) var machineRows: [ROMMachineRow] = []
  @Published private(set) var selectedMachineIndex: Int?
  @Published private(set) var missingROMFiles: [String] = []
  @Published private(set) var unavailableMachines: Set<String> = []
  @Published private(set) var unavailablePeripherals: Set<String> = []

  private weak var machineRomsController: NSArrayController?
  private var cancellables: Set<AnyCancellable> = []

  init() {
    NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)
      .sink { [weak self] _ in self?.refreshSelection() }
      .store(in: &cancellables)
  }

  func configure(machineRomsController: NSArrayController?) {
    self.machineRomsController = machineRomsController
    refreshAll()
  }

  func refreshAll() {
    refreshMachineRows()
    refreshSelection()
  }

  func refreshSelection() {
    refreshAvailability()
    guard let machineRomsController else {
      selectedMachineIndex = nil
      missingROMFiles = []
      return
    }

    let selectionIndex = machineRomsController.selectionIndex
    selectedMachineIndex = selectionIndex == NSNotFound ? nil : selectionIndex
    refreshMissingROMFiles()
  }

  func selectMachine(_ row: ROMMachineRow) {
    machineRomsController?.setSelectionIndex(row.index)
    refreshSelection()
  }

  func romValue(for entry: ROMEntry) -> Binding<String> {
    /* A field may commit after selection changes. Keep its original row. */
    let row = selectedMachineDictionary()
    return Binding {
      let value = row?[entry.romKey] as? String ?? ""
      let defaultValue = row?[entry.defaultROMKey] as? String ?? ""
      let exists = !value.isEmpty && value.withCString { cocoa_machine_rom_file_exists_bridge($0) }
      return !exists && value == defaultValue ? "" : value
    } set: { newValue in
      guard let row, row[entry.defaultROMKey] != nil else { return }
      row[entry.romKey] = newValue
      self.refreshSelection()
    }
  }

  func isROMMissing(_ entry: ROMEntry) -> Bool {
    guard isEntryEnabled(entry) else { return false }
    let value = selectedValue(forKey: entry.romKey)
    return value.isEmpty || missingROMFiles.contains(value)
  }

  func isEntryEnabled(_ entry: ROMEntry) -> Bool {
    selectedMachineValue(forKey: entry.defaultROMKey) != nil
  }

  func refreshMachineRows() {
    guard let rows = machineRomsController?.arrangedObjects as? [NSMutableDictionary] else {
      machineRows = []
      return
    }

    machineRows = rows.enumerated().map { index, row in
      let name = row["display_name"] as? String ?? ""
      return ROMMachineRow(index: index, title: name, objectID: ObjectIdentifier(row))
    }
  }

  /* These checks describe configured files, not ROMs supplied by snapshots. */
  func refreshAvailability() {
    let rows = machineRomsController?.arrangedObjects as? [NSMutableDictionary] ?? []
    var machines: Set<String> = []
    var peripherals: Set<String> = []
    var fileAvailability: [String: Bool] = [:]

    for row in rows {
      let missing = romEntries.contains { entry in
        guard row[entry.defaultROMKey] != nil else { return false }
        let filename = row[entry.romKey] as? String ?? ""
        if filename.isEmpty { return true }
        if let exists = fileAvailability[filename] { return !exists }
        let exists = filename.withCString { cocoa_machine_rom_file_exists_bridge($0) }
        fileAvailability[filename] = exists
        return !exists
      }
      guard missing else { continue }
      if let key = row["special_type"] as? String {
        peripherals.insert(key)
      } else if let id = cocoa_rom_row_machine_id_bridge(row)?.takeUnretainedValue() as? String {
        machines.insert(id)
      }
    }

    unavailableMachines = machines
    unavailablePeripherals = peripherals
  }

  private func refreshMissingROMFiles() {
    guard let row = selectedMachineDictionary() else {
      missingROMFiles = []
      return
    }

    missingROMFiles = romEntries.compactMap { entry in
      guard row[entry.defaultROMKey] != nil else { return nil }
      let filename = row[entry.romKey] as? String ?? ""
      guard !filename.isEmpty else { return nil }
      let exists = filename.withCString {
        cocoa_machine_rom_file_exists_bridge( $0 )
      }
      return exists ? nil : filename
    }
  }

  private func selectedMachineDictionary() -> NSMutableDictionary? {
    guard let machineRomsController,
          let rows = machineRomsController.arrangedObjects as? [NSMutableDictionary] else {
      return nil
    }

    let selectionIndex = machineRomsController.selectionIndex
    guard selectionIndex != NSNotFound, selectionIndex < rows.count else {
      return nil
    }

    return rows[selectionIndex]
  }

  private func selectedMachineValue(forKey key: String) -> Any? {
    selectedMachineDictionary()?.value(forKey: key)
  }

  private func selectedValue(forKey key: String) -> String {
    (selectedMachineValue(forKey: key) as? String) ?? ""
  }

}

struct ROMMachineRow: Identifiable {
  let index: Int
  let title: String
  let objectID: ObjectIdentifier

  var id: Int { index }
}

struct ROMPaneView: View {
  private let panelWidth: CGFloat = 627

  @ObservedObject private var model: ROMPreferencesModel

  private let chooseROM: (ROMEntry) -> Void
  private let resetROM: (ROMEntry) -> Void

  init(model: ROMPreferencesModel,
       chooseROM: @escaping (ROMEntry) -> Void,
       resetROM: @escaping (ROMEntry) -> Void) {
    self.model = model
    self.chooseROM = chooseROM
    self.resetROM = resetROM
  }

  var body: some View {
    CenteredPreferencesPane(width: panelWidth) {
      HStack(alignment: .top, spacing: 20) {
        machinesPanel

        VStack(alignment: .leading, spacing: 8) {
          Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 12) {
            ForEach(romEntries) { entry in
              GridRow {
                Text(entry.title)
                TextField(model.isEntryEnabled(entry) ? "Select ROM file…" : "",
                          text: model.romValue(for: entry))
                  .frame(width: 265)
                  .help(model.isROMMissing(entry) ? "ROM file not found. Select a ROM file." : "ROM file path")
                  .accessibilityLabel(entry.title)
                  .accessibilityHint(model.isROMMissing(entry) ? "ROM file not found. Select a ROM file." : "")
                  .disabled(!model.isEntryEnabled(entry))
                Button("Choose...") {
                  chooseROM(entry)
                }
                .frame(minWidth: 74, alignment: .leading)
                .disabled(!model.isEntryEnabled(entry))
                Button("Reset") {
                  resetROM(entry)
                }
                .frame(minWidth: 52, alignment: .leading)
                .disabled(!model.isEntryEnabled(entry))
              }
            }
          }
        }
      }
      .padding(.leading, 4)
      .padding(.top, 20)
      .padding(.trailing, 4)
      .padding(.bottom, 20)
      .frame(width: panelWidth, alignment: .topLeading)
      .flexibleButtonSizingIfAvailable()
    }
    .onAppear {
      model.refreshAll()
    }
  }

  private var machinesPanel: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Machines")
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
          Divider()
        }

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(model.machineRows) { row in
            machineRow(row)
          }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
      }
    }
    .frame(width: 137, height: 303, alignment: .topLeading)
    .overlay {
      RoundedRectangle(cornerRadius: 0)
        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
    }
  }

  private func machineRow(_ row: ROMMachineRow) -> some View {
    Button {
      model.selectMachine(row)
    } label: {
      Text(row.title)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(.primary)
        .background(machineSelectionColor(for: row))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func machineSelectionColor(for row: ROMMachineRow) -> Color {
    guard model.selectedMachineIndex == row.index else { return .clear }
    return Color(nsColor: .selectedContentBackgroundColor)
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
