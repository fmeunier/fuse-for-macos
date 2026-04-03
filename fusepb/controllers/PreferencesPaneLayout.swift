import SwiftUI

@_silgen_name("cocoa_media_phantom_typist_mode")
func cocoa_media_phantom_typist_mode_bridge() -> Unmanaged<AnyObject>?

@_silgen_name("cocoa_sound_speaker_type")
func cocoa_sound_speaker_type_bridge() -> Unmanaged<AnyObject>?

@_silgen_name("cocoa_sound_stereo_ay")
func cocoa_sound_stereo_ay_bridge() -> Unmanaged<AnyObject>?

@_silgen_name("cocoa_movie_movie_compr")
func cocoa_movie_movie_compr_bridge() -> Unmanaged<AnyObject>?

@_silgen_name("cocoa_inputs_joysticks")
func cocoa_inputs_joysticks_bridge() -> Unmanaged<AnyObject>?

@_silgen_name("cocoa_inputs_hid_joysticks")
func cocoa_inputs_hid_joysticks_bridge() -> Unmanaged<AnyObject>?

@_silgen_name("cocoa_string_media_phantom_typist_mode")
func cocoa_string_media_phantom_typist_mode_bridge(_ value: UnsafePointer<CChar>?) -> Unmanaged<AnyObject>?

@_silgen_name("cocoa_string_sound_speaker_type")
func cocoa_string_sound_speaker_type_bridge(_ value: UnsafePointer<CChar>?) -> Unmanaged<AnyObject>?

@_silgen_name("cocoa_string_sound_stereo_ay")
func cocoa_string_sound_stereo_ay_bridge(_ value: UnsafePointer<CChar>?) -> Unmanaged<AnyObject>?

@_silgen_name("cocoa_string_movie_movie_compr")
func cocoa_string_movie_movie_compr_bridge(_ value: UnsafePointer<CChar>?) -> Unmanaged<AnyObject>?

func optionChoices(_ provider: () -> Unmanaged<AnyObject>?, fallback: [String]) -> [String] {
  guard let object = provider()?.takeUnretainedValue() as? [String], !object.isEmpty else {
    return fallback
  }

  return object
}

func canonicalOptionString(_ value: String,
                           enumerator: (UnsafePointer<CChar>?) -> Unmanaged<AnyObject>?,
                           fallback: String) -> String {
  let result = value.withCString { enumerator( $0 )?.takeUnretainedValue() as? String }

  guard let result else { return fallback }
  return result
}

func enumeratedStringBinding(for value: Binding<String>,
                             canonicalize: @escaping (String) -> String) -> Binding<String> {
  Binding {
    canonicalize( value.wrappedValue )
  } set: { newValue in
    value.wrappedValue = newValue
  }
}

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
