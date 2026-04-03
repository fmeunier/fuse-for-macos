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

  private weak var machineRomsController: NSArrayController?
  private var cancellables: Set<AnyCancellable> = []

  func configure(machineRomsController: NSArrayController?) {
    self.machineRomsController = machineRomsController
    refreshAll()
  }

  func refreshAll() {
    refreshMachineRows()
    refreshSelection()
  }

  func refreshSelection() {
    guard let machineRomsController else {
      selectedMachineIndex = nil
      objectWillChange.send()
      return
    }

    let selectionIndex = machineRomsController.selectionIndex
    selectedMachineIndex = selectionIndex == NSNotFound ? nil : selectionIndex
    objectWillChange.send()
  }

  func selectMachine(_ row: ROMMachineRow) {
    machineRomsController?.setSelectionIndex(row.index)
    refreshSelection()
  }

  func romValue(for entry: ROMEntry) -> Binding<String> {
    Binding {
      self.selectedValue(forKey: entry.romKey)
    } set: { newValue in
      self.setSelectedValue(newValue, forKey: entry.romKey)
    }
  }

  func isEntryEnabled(_ entry: ROMEntry) -> Bool {
    selectedMachineValue(forKey: entry.romKey) != nil
  }

  func refreshMachineRows() {
    guard let rows = machineRomsController?.arrangedObjects as? [NSMutableDictionary] else {
      machineRows = []
      objectWillChange.send()
      return
    }

    machineRows = rows.enumerated().map { index, row in
      let name = row["display_name"] as? String ?? ""
      return ROMMachineRow(index: index, title: name, objectID: ObjectIdentifier(row))
    }
    objectWillChange.send()
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

  private func setSelectedValue(_ value: String, forKey key: String) {
    selectedMachineDictionary()?.setValue(value, forKey: key)
    objectWillChange.send()
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
  private let panelHeight: CGFloat = 343

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
    CenteredPreferencesPane(width: panelWidth, height: panelHeight) {
      HStack(alignment: .top, spacing: 20) {
        machinesPanel

        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 12) {
          ForEach(romEntries) { entry in
            GridRow {
              Text(entry.title)
              TextField("", text: model.romValue(for: entry))
                .frame(width: 265)
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
      .padding(.leading, 4)
      .padding(.top, 20)
      .padding(.trailing, 4)
      .padding(.bottom, 20)
      .frame(width: panelWidth, height: panelHeight, alignment: .topLeading)
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
