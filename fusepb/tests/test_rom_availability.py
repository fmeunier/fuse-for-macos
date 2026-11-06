#!/usr/bin/env python3
"""Compile and exercise the actual settings availability model on macOS."""
import pathlib
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[2]
source = (root / "fusepb/controllers/ROMPreferencesContainerView.swift").read_text()
entry = source[source.index("struct ROMEntry:"):source.index("func romPreferencesPane")]
model = source[source.index("final class ROMPreferencesModel:"):source.index("struct ROMPaneView")]
harness = r'''
var existing: Set<String> = ["present.rom"]
func cocoa_machine_rom_file_exists_bridge(_ filename: UnsafePointer<CChar>?) -> Bool {
  existing.contains(String(cString: filename!))
}
func cocoa_rom_row_machine_id_bridge(_ row: NSDictionary) -> Unmanaged<AnyObject>? {
  guard let id = row["testID"] as? NSString else { return nil }
  return Unmanaged.passUnretained(id)
}
let machine: NSMutableDictionary = ["testID": "128", "rom0": "present.rom", "rom1": "missing.rom", "default_rom0": "present.rom", "default_rom1": "missing.rom"]
let speech: NSMutableDictionary = ["special_type": "uspeech", "rom0": "present.rom", "rom1": "", "default_rom0": "present.rom", "default_rom1": "speech.rom"]
let controller = NSArrayController(content: [machine, speech])
let model = ROMPreferencesModel()
model.configure(machineRomsController: controller)
assert(model.unavailableMachines == ["128"])
assert(model.unavailablePeripherals == ["uspeech"])
// Repairing a file and editing an unselected row must both update availability.
existing.insert("missing.rom")
speech["rom1"] = "present.rom"
model.refreshSelection()
assert(model.unavailableMachines.isEmpty)
assert(model.unavailablePeripherals.isEmpty)
// Absent slots are not requirements; empty present slots are.
machine["rom0"] = ""
model.refreshAvailability()
assert(model.unavailableMachines == ["128"])
assert(model.unavailablePeripherals.isEmpty)
model.configure(machineRomsController: nil)
assert(model.unavailableMachines.isEmpty)
assert(model.unavailablePeripherals.isEmpty)
print("rom-availability: passed")

let pentagon: NSMutableDictionary = ["testID": "pentagon", "rom0": "present.rom", "default_rom0": "present.rom", "rom1": "present.rom", "default_rom1": "present.rom", "rom2": "present.rom", "default_rom2": "present.rom"]
let pentagon512 = pentagon.mutableCopy() as! NSMutableDictionary
pentagon512["testID"] = "pentagon512"
pentagon512["rom3"] = "missing.rom"
pentagon512["default_rom3"] = "missing.rom"
controller.content = [pentagon, pentagon512]
model.configure(machineRomsController: controller)
controller.setSelectionIndex(1)
model.refreshSelection()
let rom3 = ROMEntry(id: 3, title: "ROM 3:")
let pendingEdit = model.romValue(for: rom3)
controller.setSelectionIndex(0)
model.refreshSelection()
pendingEdit.wrappedValue = "present.rom"
assert(pentagon512["rom3"] as? String == "present.rom")
assert(pentagon["rom3"] == nil)
assert(!model.isEntryEnabled(rom3))
model.romValue(for: rom3).wrappedValue = ""
assert(pentagon["rom3"] == nil)
// A spurious value from an earlier session must not introduce a requirement.
pentagon["rom3"] = ""
model.refreshSelection()
assert(!model.isEntryEnabled(rom3))
assert(!model.unavailableMachines.contains("pentagon"))
assert(!model.unavailableMachines.contains("pentagon512"))
print("rom-row-isolation: passed")

'''
with tempfile.TemporaryDirectory() as directory:
  path = pathlib.Path(directory) / "main.swift"
  path.write_text("import AppKit\nimport Combine\nimport SwiftUI\n" + entry + model + harness)
  binary = pathlib.Path(directory) / "test"
  subprocess.run(["xcrun", "swiftc", str(path), "-o", str(binary)], check=True)
  subprocess.run([str(binary)], check=True)
