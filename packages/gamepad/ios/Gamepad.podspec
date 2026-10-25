Pod::Spec.new do |s|
  s.name           = 'Gamepad'
  s.version        = '0.4.1'
  s.summary        = 'Game controllers through the GameController framework'
  s.description    = 'Reads connected game controllers (buttons, sticks, player slots) for game-kit: the Expo module for JS, and PadReader for native game loops. Pad logic comes from GamepadCore.'
  s.author         = ''
  s.homepage       = 'https://github.com/the-deep-friar/game-kit'
  s.license        = 'MIT'
  s.platforms      = { :ios => '18.0', :tvos => '18.0' }
  s.source         = { git: '' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'
  s.dependency 'GamepadCore'
  s.frameworks = 'GameController'

  # Swift/Objective-C compatibility
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }

  s.source_files = "**/*.{h,m,mm,swift,hpp,cpp}"
  # GamepadCore's sources are their own pod (GamepadCore.podspec), so apps and SwiftPM both
  # see them as the GamepadCore module.
  s.exclude_files = "GamepadCore/**/*"
end
