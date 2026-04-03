import AppKit
import SwiftUI

private struct MachinePreferenceOption: Identifiable {
  let id: String
  let name: String
}

private let fallbackMachineOptions = [
  MachinePreferenceOption(id: "16", name: "Spectrum 16K"),
  MachinePreferenceOption(id: "48", name: "Spectrum 48K"),
  MachinePreferenceOption(id: "48-ntsc", name: "Spectrum 48K (NTSC)"),
  MachinePreferenceOption(id: "128", name: "Spectrum 128K"),
  MachinePreferenceOption(id: "+2", name: "Spectrum +2"),
  MachinePreferenceOption(id: "+2a", name: "Spectrum +2A"),
  MachinePreferenceOption(id: "+3", name: "Spectrum +3"),
  MachinePreferenceOption(id: "+3e", name: "Spectrum +3e"),
  MachinePreferenceOption(id: "tc2048", name: "Timex TC2048"),
  MachinePreferenceOption(id: "tc2068", name: "Timex TC2068"),
  MachinePreferenceOption(id: "ts2068", name: "Timex TS2068"),
  MachinePreferenceOption(id: "pentagon", name: "Pentagon 128K"),
  MachinePreferenceOption(id: "pentagon512", name: "Pentagon 512K"),
  MachinePreferenceOption(id: "pentagon1024", name: "Pentagon 1024K"),
  MachinePreferenceOption(id: "scorpion", name: "Scorpion ZS 256"),
  MachinePreferenceOption(id: "se", name: "Spectrum SE"),
]

func machinePreferencesPane() -> AnyView {
  AnyView(MachinePreferencesView())
}

private struct MachinePreferencesView: View {
  @AppStorage("machine") private var machine = "48"

  private let machineOptions = availableMachineOptions()

  var body: some View {
    CenteredPreferencesPane(width: 200, height: 358) {
      Picker("Machine", selection: $machine) {
        ForEach(machineOptions) { option in
          Text(option.name)
            .tag(option.id)
        }
      }
      .labelsHidden()
      .pickerStyle(.radioGroup)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
  }
}

private func availableMachineOptions() -> [MachinePreferenceOption] {
  let names = optionChoices(
    { cocoa_machine_names_bridge() },
    fallback: fallbackMachineOptions.map( \.name )
  )
  let ids = optionChoices(
    { cocoa_machine_ids_bridge() },
    fallback: fallbackMachineOptions.map( \.id )
  )

  guard names.count == ids.count, !names.isEmpty else {
    return fallbackMachineOptions
  }

  return zip(ids, names).map { id, name in
    MachinePreferenceOption(id: id, name: name)
  }
}
