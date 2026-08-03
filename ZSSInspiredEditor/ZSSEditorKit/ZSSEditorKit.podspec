Pod::Spec.new do |s|
  s.name             = 'ZSSEditorKit'
  s.version          = '0.4.21'
  s.summary          = 'ZSS-inspired UIKit rich text editor component.'
  s.description      = <<-DESC
    A UIKit-based rich text editor view controller with a configurable toolbar,
    formatting actions, list handling, and HTML interoperability.
  DESC
  s.homepage         = 'https://github.com/nikhildhavale/zssinspired'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Nikhil Dhavale' => 'nikhild@mangospring.com' }
  s.source           = { :git => 'https://github.com/nikhildhavale/zssinspired.git' }

  s.ios.deployment_target = '15.0'
  s.swift_versions   = ['5.9']

  s.source_files     = 'Sources/ZSSEditorKit/**/*.swift'
  s.exclude_files    = ['Package.swift', '**/Package.swift']
  s.frameworks       = 'UIKit'
end
