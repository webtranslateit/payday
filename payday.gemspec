# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'webtranslateit-payday'
  s.version     = '2.0.0'
  s.required_ruby_version = '>= 3.2'
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Alan Johnson', 'Edouard Briere']
  s.email       = ['edouard@webtranslateit.com']
  s.homepage    = 'https://github.com/webtranslateit/payday'
  s.summary     = 'A simple library for rendering invoices.'
  s.description = 'Payday is a library for rendering invoices to pdf, using Typst.'
  s.license = 'MIT'

  s.add_dependency 'activesupport', '>= 7', '< 9'
  s.add_dependency 'i18n', '~> 1.12', '< 2'
  s.add_dependency 'money', '>= 6.16', '< 8.0'
  s.add_dependency 'rqrcode', '>= 2', '< 4'
  s.add_dependency 'typst', '~> 0.15'
  s.add_dependency 'zeitwerk', '~> 2.6', '< 3'

  # Only what the gem needs at run time, plus the docs. The spec suite carries several
  # hundred kilobytes of reference PDFs that nobody installing this wants.
  root_files = %w[README.md CHANGELOG.md payday.gemspec].freeze
  s.files = `git ls-files -z`.split("\x0").select do |path|
    path.start_with?('lib/', 'config/locales/', 'fonts/') || root_files.include?(path)
  end
  s.require_paths = ['lib']
  s.metadata['rubygems_mfa_required'] = 'true'
end
