Pod::Spec.new do |s|
  s.name             = 'ZSSEditorKit'
  s.version          = '0.4.8'
  s.summary          = 'ZSS-inspired UIKit rich text editor component.'
  s.description      = <<-DESC
    A UIKit-based rich text editor view controller with a configurable toolbar,
    formatting actions, list handling, HTML interoperability, and markdown export.
  DESC
  s.homepage         = 'https://github.com/nikhildhavale/zssinspired'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Nikhil Dhavale' => 'nikhild@mangospring.com' }
  s.source           = { :git => 'https://github.com/nikhildhavale/zssinspired.git' }

  s.ios.deployment_target = '15.0'
  s.swift_versions   = ['5.9']

  s.source_files     = 'ZSSInspiredEditor/ZSSEditorKit/Sources/ZSSEditorKit/**/*.swift'
  s.frameworks       = 'UIKit'
end
