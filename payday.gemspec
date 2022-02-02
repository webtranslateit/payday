$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'payday/version'

Gem::Specification.new do |s|
  s.name        = 'payday'
  s.version     = Payday::VERSION
  s.required_ruby_version = '>= 2.5'
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Alan Johnson', 'Edouard Briere']
  s.email       = ['edouard@webtranslateit.com']
  s.homepage    = 'https://github.com/webtranslateit/payday'
  s.summary     = 'A simple library for rendering invoices.'
  s.description = 'Payday is a library for rendering invoices to pdf.'

  s.add_dependency 'activesupport'
  s.add_dependency('i18n', '>= 0.7', '< 2.0')
  s.add_dependency('money', '~> 6.5')
  s.add_dependency('prawn', '>= 1.0', '< 2.5')
  s.add_dependency('prawn-svg', '>= 0.15.0', '< 0.32.1')
  s.add_dependency('prawn-table', '>= 0.2.2')
  s.add_dependency 'rexml'

  s.add_development_dependency('guard')
  s.add_development_dependency('guard-rspec')
  s.add_development_dependency 'guard-rubocop'
  s.add_development_dependency('rspec', '~> 3.10.0')
  s.add_development_dependency('rubocop')
  s.add_development_dependency('rubocop-rspec')

  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables =
    `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ['lib']
end
