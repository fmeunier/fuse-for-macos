/* BinaryDataContainerView.swift: SwiftUI binary import/export interface
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

private final class BinaryDataModel: ObservableObject {
  @Published var filename = ""
  @Published var start = ""
  @Published var length = ""
  @Published var importLength: Int?

  var startValue: Int? {
    guard let value = Self.parseInteger(start), (0...65535).contains(value) else { return nil }
    return value
  }

  var lengthValue: Int? {
    guard let value = Self.parseInteger(length), (1...65536).contains(value) else { return nil }
    return value
  }

  private static func parseInteger(_ text: String) -> Int? {
    let text = text.trimmingCharacters(in: .whitespaces)
    if let value = Int(text) { return value }
    // Require a complete, correctly grouped integer, not a numeric prefix.
    guard let value = try? Int(text, format: .number, lenient: false),
          text == value.formatted() else { return nil }
    return value
  }

  var maximumLength: Int {
    min(65536 - (startValue ?? 0), importLength ?? 65536)
  }

  var canApply: Bool {
    guard !filename.isEmpty, startValue != nil, let lengthValue else { return false }
    return lengthValue <= maximumLength
  }
}

@objc(BinaryDataContainerView)
@objcMembers
final class BinaryDataContainerView: NSView {
  var chooseHandler: (() -> Void)?
  var applyHandler: (() -> Void)?
  var cancelHandler: (() -> Void)?
  private let model = BinaryDataModel()

  var filename: String { model.filename }
  var startValue: Int { model.startValue ?? 0 }
  var lengthValue: Int { model.lengthValue ?? 0 }
  var canApply: Bool { model.canApply }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    let view = NSHostingView(rootView: BinaryDataPane(model: model, container: self))
    view.frame = bounds
    view.autoresizingMask = [.width, .height]
    addSubview(view)
  }

  required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

  func reset() {
    model.filename = ""
    model.start = ""
    model.length = ""
    model.importLength = nil
  }

  func selectFile(_ filename: String, importLength: NSNumber?) {
    model.filename = filename
    model.importLength = importLength?.intValue
    if let importLength {
      model.start = "0"
      model.length = min(importLength.intValue, 65536).formatted()
    }
  }
}

private struct BinaryDataPane: View {
  private let actionLabelWidth: CGFloat = 60
  @ObservedObject var model: BinaryDataModel
  weak var container: BinaryDataContainerView?
  private enum Field: Hashable { case choose, start, length, cancel, apply }
  @FocusState private var focusedField: Field?

  var body: some View {
    VStack(spacing: 20) {
      Grid(alignment: .trailing, horizontalSpacing: 8, verticalSpacing: 12) {
        GridRow {
          Text("Filename:")
          HStack {
            TextField("Choose a file", text: .constant(model.filename))
              .disabled(true)
              .accessibilityLabel("Selected filename")
              .help(model.filename)
            Button("Choose…") { container?.chooseHandler?() }
              .focused($focusedField, equals: .choose)
          }
        }
        GridRow {
          Text("Start:")
          TextField("0–65535", text: $model.start)
            .accessibilityLabel("Start address")
            .frame(width: 120)
            .focused($focusedField, equals: .start)
            .help("Starting address, from 0 to 65,535. The data must fit before the end of memory.")
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        GridRow {
          Text("Length:")
          TextField("1–\(model.maximumLength.formatted())", text: $model.length)
            .focused($focusedField, equals: .length)
            .accessibilityLabel("Length in bytes")
            .frame(width: 120)
            .help("Maximum length: \(model.maximumLength.formatted()) bytes, limited by the starting address and, for imports, the file size.")
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      HStack(spacing: 8) {
        Button { container?.cancelHandler?() } label: {
          Text("Cancel").frame(minWidth: actionLabelWidth)
        }
        .focused($focusedField, equals: .cancel)
        .keyboardShortcut(.cancelAction)
        Button { container?.applyHandler?() } label: {
          Text("OK").frame(minWidth: actionLabelWidth)
        }
        .focused($focusedField, equals: .apply)
        .keyboardShortcut(.defaultAction)
        .disabled(!model.canApply)
      }
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(20)
    .frame(minWidth: 540)
    .binaryTabNavigation(forward: { moveFocus(backward: false) },
                         backward: { moveFocus(backward: true) })
    .onAppear { focusedField = .start }
    .onChange(of: focusedField) { newField in
      if newField != .start, let value = model.startValue {
        model.start = value.formatted()
      }
      if newField != .length, let value = model.lengthValue {
        model.length = value.formatted()
      }
    }
  }

  private func moveFocus(backward: Bool) {
    let order: [Field] = [.choose, .start, .length, .cancel]
      + (model.canApply ? [.apply] : [])
    guard let current = focusedField, let index = order.firstIndex(of: current) else {
      focusedField = backward ? order.last : order.first
      return
    }
    let step = backward ? -1 : 1
    focusedField = order[(index + step + order.count) % order.count]
  }
}

private extension View {
  @ViewBuilder
  func binaryTabNavigation(forward: (() -> Void)? = nil,
                           backward: (() -> Void)? = nil) -> some View {
    if #available(macOS 14.0, *) {
      // AppKit can deliver Shift-Tab as Backtab (U+0019), not Tab.
      onKeyPress(keys: [.tab, KeyEquivalent("\u{19}")], phases: .down) { press in
        let isBackward = press.modifiers.contains(.shift)
          || press.key == KeyEquivalent("\u{19}")
        let action = isBackward ? backward : forward
        guard let action else { return .ignored }
        action()
        return .handled
      }
    } else {
      self
    }
  }
}
