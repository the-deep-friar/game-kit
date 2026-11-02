Pod::Spec.new do |s|
  s.name           = 'GamepadCore'
  s.version        = '0.5.0'
  s.summary        = 'Game-agnostic pad logic in plain Swift'
  s.description    = 'Controls by position, pad layout and shape, the Nintendo face fix, stick directions and action maps (docs/swift-core.md). No GameController or UIKit; the same sources are the GamepadCore SwiftPM library tested on Linux.'
  s.author         = ''
  s.homepage       = 'https://github.com/the-deep-friar/game-kit'
  s.license        = 'MIT'
  s.platforms      = { :ios => '18.0', :tvos => '18.0' }
  s.source         = { git: '' }
  s.static_framework = true

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }

  s.source_files = 'GamepadCore/**/*.swift'
end
