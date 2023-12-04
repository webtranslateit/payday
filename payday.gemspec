# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'webtranslateit-payday'
  s.version     = '1.6.6'
  s.required_ruby_version = '>= 3.1'
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Alan Johnson', 'Edouard Briere']
  s.email       = ['edouard@webtranslateit.com']
  s.homepage    = 'https://github.com/webtranslateit/payday'
  s.summary     = 'A simple library for rendering invoices.'
  s.description = 'Payday is a library for rendering invoices to pdf.'
  s.license = 'MIT'

  s.add_dependency 'activesupport', '~> 7', '< 8'
  s.add_dependency 'i18n', '~> 1.12', '< 2'
  s.add_dependency 'money', '~> 6.16', '< 7'
  s.add_dependency 'prawn', '~> 2.4', '< 3'
  s.add_dependency 'prawn-svg', '~> 0.32', '< 1'
  s.add_dependency 'prawn-table', '~> 0.2', '< 1'
  s.add_dependency 'zeitwerk', '~> 2.6', '< 3'

  s.files = `git ls-files`.split("\n")
  s.require_paths = ['lib']
  s.metadata['rubygems_mfa_required'] = 'true'
end
