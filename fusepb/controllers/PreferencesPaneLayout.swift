import SwiftUI

struct CenteredPreferencesPane<Content: View>: View {
  let width: CGFloat
  let height: CGFloat
  let content: Content

  init(width: CGFloat, height: CGFloat,
       @ViewBuilder content: () -> Content) {
    self.width = width
    self.height = height
    self.content = content()
  }

  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 0)

      HStack(spacing: 0) {
        Spacer(minLength: 0)

        content
          .frame(width: width, height: height, alignment: .topLeading)

        Spacer(minLength: 0)
      }

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}
