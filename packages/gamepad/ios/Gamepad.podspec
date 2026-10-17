Pod::Spec.new do |s|
  s.name           = 'Gamepad'
  s.version        = '0.2.0'
  s.summary        = 'Game controllers through the GameController framework'
  s.description    = 'Reads connected game controllers (buttons, sticks, player slots) for game-kit. Discovery and raw values only; mapping lives in TypeScript.'
  s.author         = ''
  s.homepage       = 'https://github.com/the-deep-friar/game-kit'
  s.platforms      = { :ios => '18.0' }
  s.source         = { git: '' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'
  s.frameworks = 'GameController'

  # Swift/Objective-C compatibility
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }

  s.source_files = "**/*.{h,m,mm,swift,hpp,cpp}"
end
