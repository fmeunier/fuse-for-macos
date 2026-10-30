/* PokeFinderContainerView.swift: SwiftUI Poke Finder interface
   Copyright (c) 2026 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
*/

import AppKit
import SwiftUI

private struct PokeFinderLocation: Identifiable {
  let bank: Int
  let offset: Int
  var id: String { "\(bank):\(offset)" }
  var offsetText: String { String(format: "0x%04X", offset) }
}

private final class PokeFinderModel: ObservableObject {
  @Published var query = ""
  @Published var count = 0
  @Published var locations: [PokeFinderLocation] = []
  @Published var selection: String?

  var searchValue: Int? {
    guard let value = Int(query.trimmingCharacters(in: .whitespaces)),
          (0...255).contains(value) else { return nil }
    return value
  }
}

@objc(PokeFinderContainerView)
@objcMembers
final class PokeFinderContainerView: NSView {
  var searchHandler: ((Int) -> Void)?
  var incrementHandler: (() -> Void)?
  var decrementHandler: (() -> Void)?
  var resetHandler: (() -> Void)?
  var closeHandler: (() -> Void)?
  var breakpointHandler: ((Int, Int) -> Void)?
  private let model = PokeFinderModel()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    let view = NSHostingView(rootView: PokeFinderPane(model: model, container: self))
    view.frame = bounds
    view.autoresizingMask = [.width, .height]
    addSubview(view)
  }

  required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

  func update(count: Int, locations: [[String: NSNumber]]) {
    model.count = count
    model.locations = locations.compactMap { row in
      guard let bank = row["bank"], let offset = row["offset"] else { return nil }
      return PokeFinderLocation(bank: bank.intValue, offset: offset.intValue)
    }
    if !model.locations.contains(where: { $0.id == model.selection }) {
      model.selection = nil
    }
  }
}

private struct PokeFinderPane: View {
  private let actionLabelWidth: CGFloat = 60

  @ObservedObject var model: PokeFinderModel
  weak var container: PokeFinderContainerView?

  var body: some View {
    VStack(spacing: 16) {
      Grid(alignment: .trailing, horizontalSpacing: 8, verticalSpacing: 12) {
        GridRow {
          Text("Search for:")
          TextField("0–255", text: $model.query)
            .accessibilityLabel("Search for byte value, 0 to 255")
            .onSubmit { search() }
            .help("Enter a byte value from 0 to 255.")
        }
        GridRow {
          Text("Possible locations:")
          Text(model.count.formatted())
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Possible locations")
            .accessibilityValue(model.count.formatted())
        }
      }

      Table(model.locations, selection: $model.selection) {
        TableColumn("Page") { Text($0.bank.formatted()) }
          .width(min: 60, ideal: 80, max: 100)
        TableColumn("Offset") { Text($0.offsetText).monospaced() }
      }
      .tableStyle(.bordered(alternatesRowBackgrounds: true))
      .frame(minHeight: 160)
      .help(model.count > 20
        ? "Narrow the search to 20 matches or fewer to see locations."
        : "Double-click a location to add a write breakpoint, or use its context menu.")
      .contextMenu(forSelectionType: String.self) { ids in
        if let row = model.locations.first(where: { ids.contains($0.id) }) {
          Button("Break on Write") { breakpoint(row) }
        }
      } primaryAction: { ids in
        if let row = model.locations.first(where: { ids.contains($0.id) }) {
          breakpoint(row)
        }
      }

      HStack(alignment: .bottom, spacing: 16) {
        Grid(verticalSpacing: 8) {
          GridRow {
            Button("Incremented") { container?.incrementHandler?() }
          }
          GridRow {
            Button("Decremented") { container?.decrementHandler?() }
          }
        }
        .flexibleButtonSizingIfAvailable()
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity, alignment: .leading)
        Button(action: search) {
          Text("Search").frame(minWidth: actionLabelWidth)
        }
          .keyboardShortcut(.defaultAction)
          .disabled(model.searchValue == nil)
      }
      HStack(spacing: 8) {
        Button {
          model.query = ""
          container?.resetHandler?()
        } label: {
          Text("Reset").frame(minWidth: actionLabelWidth)
        }
        Button {
          container?.closeHandler?()
        } label: {
          Text("OK").frame(minWidth: actionLabelWidth)
        }
          .keyboardShortcut(.cancelAction)
          .help("Close Poke Finder and resume emulation.")
      }
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .buttonStyle(.bordered)
    .padding(20)
    .frame(minWidth: 320, minHeight: 380)
  }

  private func search() {
    guard let value = model.searchValue else { return }
    container?.searchHandler?(value)
  }

  private func breakpoint(_ row: PokeFinderLocation) {
    container?.breakpointHandler?(row.bank, row.offset)
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

